extends RefCounted
class_name DeckBuilder

# Montagem de deck com IDENTIDADE por bot. Antes todo bot conhecia quase as
# mesmas cartas iniciais e a evolução puxava todo mundo pra "meta" da
# temporada -- resultado: decks quase iguais. Agora cada bot tem um ESTILO
# fixo (sorteado a partir do nome dele, então é sempre o mesmo pra ele):
#   - categoria principal + secundária
#   - curva de custo (barato/ciclo, médio, pesado)
#   - nação favorita
#   - quantos feitiços gosta de levar
# e o deck é montado por pontuação, com regras de composição (alguém que
# acerte aéreo, no máximo 3 da mesma categoria, 1-2 feitiços...).

const CURVE_CHEAP = 0
const CURVE_MEDIUM = 1
const CURVE_HEAVY = 2
const CURVE_NAMES = ["Ciclo barato", "Equilibrado", "Pesado"]

static var _stats_cache: Dictionary = {}  # instance_id da carta -> UnitData (ou null)


# espia o UnitData de uma carta de unidade, com cache (instanciar cena toda
# hora é caro, principalmente no celular)
static func get_unit_stats(card: CardData) -> UnitData:
	if card == null or card.unit_scene == null:
		return null
	var key = card.get_instance_id()
	if _stats_cache.has(key):
		return _stats_cache[key]
	var temp = card.unit_scene.instantiate()
	var stats: UnitData = temp.stats if "stats" in temp else null
	temp.free()
	_stats_cache[key] = stats
	return stats


static func clear_cache():
	_stats_cache.clear()


# true se essa carta consegue lidar com ameaça AÉREA
static func can_hit_air(card: CardData) -> bool:
	if card == null:
		return false
	if card.is_spell():
		return card.spell_data != null and card.spell_data.damage > 0 and card.spell_data.affects_enemies
	var stats = get_unit_stats(card)
	if stats == null:
		return false
	return stats.target_type == UnitData.TargetType.AIR or stats.target_type == UnitData.TargetType.ALL


static func can_hit_ground(card: CardData) -> bool:
	if card == null:
		return false
	if card.is_spell():
		return card.spell_data != null and card.spell_data.damage > 0 and card.spell_data.affects_enemies
	var stats = get_unit_stats(card)
	if stats == null:
		return false
	return stats.target_type == UnitData.TargetType.GROUND or stats.target_type == UnitData.TargetType.ALL


# estilo fixo do bot, derivado do nome (determinístico) + personalidade
static func style_for_bot(bot_name: String, archetype: int, preferred_role: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(bot_name + "#deckstyle")

	var role_count = CardData.CardRole.size()
	var secondary = rng.randi() % role_count
	if secondary == preferred_role:
		secondary = (secondary + 1 + rng.randi() % (role_count - 1)) % role_count

	var curve = rng.randi() % 3
	match archetype:
		AIProfile.Archetype.IMPULSIVO, AIProfile.Archetype.ATACA_TUDO, AIProfile.Archetype.ENXAMEADOR, AIProfile.Archetype.METRONOMO:
			curve = CURVE_CHEAP
		AIProfile.Archetype.ACUMULADOR, AIProfile.Archetype.POUPADOR, AIProfile.Archetype.PERFECCIONISTA:
			curve = CURVE_HEAVY

	var nations: Array = []
	for card in CardDatabase.all_cards:
		if card != null and card.nation_data != null and !nations.has(card.nation_data.nation_name):
			nations.append(card.nation_data.nation_name)
	nations.sort()
	var fav_nation = nations[rng.randi() % nations.size()] if !nations.is_empty() else ""

	return {
		"primary_role": preferred_role,
		"secondary_role": secondary,
		"curve": curve,
		"spells_wanted": 1 + rng.randi() % 2,
		"favorite_nation": fav_nation,
		"arena_cap": ArenaManager.get_participant_arena(bot_name),
		"seed": rng.randi(),
	}


static func describe_style(style: Dictionary) -> String:
	var parts: Array = []
	parts.append(CardData.role_name(style.get("primary_role", 9)) + " + " + CardData.role_name(style.get("secondary_role", 9)))
	parts.append(CURVE_NAMES[clamp(style.get("curve", 1), 0, 2)])
	if style.get("favorite_nation", "") != "":
		parts.append("fã de " + style["favorite_nation"])
	return " · ".join(parts)


static func _curve_score(cost: int, curve: int) -> float:
	var c = cost / 10.0  # custo do jogo vai de 0 a 100
	match curve:
		CURVE_CHEAP:
			return 2.0 - abs(c - 2.5) * 0.6
		CURVE_HEAVY:
			return 2.0 - abs(c - 5.5) * 0.5
	return 2.0 - abs(c - 4.0) * 0.5


# quanto essa carta "combina" com o estilo do bot e com o que já foi escolhido
static func score_card(card: CardData, style: Dictionary, chosen: Array) -> float:
	var s = 0.0
	if card.role == style.get("primary_role", -1):
		s += 3.0
	elif card.role == style.get("secondary_role", -1):
		s += 1.8
	s += _curve_score(card.cost, style.get("curve", CURVE_MEDIUM))
	if card.nation_data != null and card.nation_data.nation_name == style.get("favorite_nation", ""):
		s += 1.5

	var same_role = 0
	var spells = 0
	for other in chosen:
		if other == null:
			continue
		if other.role == card.role:
			same_role += 1
		if other.is_spell():
			spells += 1
		if CardData.has_affinity(card.role, other.role):
			s += 0.6
	if same_role >= 3:
		s -= 6.0  # nunca mais que 3 da mesma categoria
	if card.is_spell():
		if spells >= style.get("spells_wanted", 1):
			s -= 4.0
		else:
			s += 1.0
	return s


# 2.0: bot só usa carta que já "existe" na arena dele (igual o jogador) --
# se sobrar pouca carta, libera tudo pra não ficar sem baralho
static func _arena_gate(known_cards: Array, style: Dictionary) -> Array:
	var cap = int(style.get("arena_cap", 99))
	var out = known_cards.filter(func(c): return c != null and c.unlock_arena <= cap)
	return out if out.size() >= 7 else known_cards


static func build_deck(known_cards: Array, style: Dictionary, deck_size: int) -> Array[CardData]:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	known_cards = _arena_gate(known_cards, style)
	var pool: Array[CardData] = []
	var seen: Dictionary = {}
	for card in known_cards:
		if card != null and !seen.has(card.get_instance_id()):
			seen[card.get_instance_id()] = true
			pool.append(card)

	var deck: Array[CardData] = []
	while deck.size() < deck_size and !pool.is_empty():
		# escolha gulosa com ruído forte -- dois bots com o mesmo estilo
		# ainda montam decks diferentes
		var best_i = 0
		var best_s = -INF
		for i in pool.size():
			var sc = score_card(pool[i], style, deck) + rng.randf_range(0.0, 2.5)
			if sc > best_s:
				best_s = sc
				best_i = i
		deck.append(pool[best_i])
		pool.remove_at(best_i)

	_ensure_air_coverage(deck, known_cards)
	return deck


# se o deck não tem NADA que acerte aéreo, troca a pior carta por uma que
# acerte (se o bot conhecer alguma) -- deck sem anti-aéreo perde de graça
static func _ensure_air_coverage(deck: Array[CardData], known_cards: Array):
	for card in deck:
		if can_hit_air(card):
			return
	var anti_air: CardData = null
	for card in known_cards:
		if card != null and !deck.has(card) and can_hit_air(card):
			anti_air = card
			break
	if anti_air == null or deck.is_empty():
		return
	# troca a carta mais cara que não seja da categoria principal
	var worst_i = deck.size() - 1
	var worst_cost = -1
	for i in deck.size():
		if deck[i].cost > worst_cost:
			worst_cost = deck[i].cost
			worst_i = i
	deck[worst_i] = anti_air


# substituta pra evolução de deck: mistura combinação com o estilo +
# desempenho na temporada (antes era SÓ desempenho, por isso tudo convergia)
static func pick_replacement(current_deck: Array, known_cards: Array, style: Dictionary, trending: Dictionary) -> CardData:
	var current_ids: Dictionary = {}
	for card in current_deck:
		if card != null:
			current_ids[card.resource_path] = true

	known_cards = _arena_gate(known_cards, style)
	var candidates: Array = []
	var weights: Array = []
	var total = 0.0
	for card in known_cards:
		if card == null or current_ids.has(card.resource_path):
			continue
		var fit = max(score_card(card, style, current_deck) + 3.0, 0.3)
		var rate = trending.get(card.resource_path, 0.5)
		var w = fit * (0.6 + rate)
		candidates.append(card)
		weights.append(w)
		total += w

	if candidates.is_empty():
		return null
	var roll = randf() * total
	var acc = 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[-1]


# algumas cartas extras de "começo" pro bot conhecer, puxadas pelo estilo
# dele (Tier até 2, preferindo nação favorita e categorias do estilo) -- é
# isso que quebra o "todo mundo conhece as mesmas 9 cartas iniciais"
static func bonus_known_cards(style: Dictionary, already_known: Array, amount: int) -> Array[CardData]:
	var known_paths: Dictionary = {}
	for c in already_known:
		if c != null:
			known_paths[c.resource_path] = true
	var rng = RandomNumberGenerator.new()
	rng.seed = int(style.get("seed", 0))
	var scored: Array = []
	for card in CardDatabase.all_cards:
		if card == null or known_paths.has(card.resource_path) or card.tier > 2:
			continue
		scored.append({"card": card, "s": score_card(card, style, []) + rng.randf_range(0.0, 3.0)})
	scored.sort_custom(func(a, b): return a["s"] > b["s"])
	var result: Array[CardData] = []
	for entry in scored:
		if result.size() >= amount:
			break
		result.append(entry["card"])
	return result
