extends Node

const SAVE_DIR = "user://bots/"
const DECK_SIZE = 7

# carta com (derrotas - vitórias) maior ou igual a isso vira candidata a troca
const CARD_NET_LOSS_THRESHOLD = 5
# não mexe numa carta que ainda jogou poucas partidas -- dados de menos pra decidir
const MIN_GAMES_BEFORE_SWAP = 4

# --- economia própria do bot: ouro e xp, igual o jogador tem ---
const SIMULATED_USAGE_PER_MATCH = 3  # crédito aproximado de uso por carta, só pra partida simulada de fundo

# se perder isso tudo SEGUIDO, o bot passa a ter chance de trocar de
# arquétipo inteiro (não só de carta) -- quebra o ciclo de "personalidade
# ruim pro jeito que o jogo tá, nunca consegue upar nada, perde mais ainda"
const ARCHETYPE_SWITCH_LOSS_STREAK = 15
const ARCHETYPE_SWITCH_CHANCE = 0.3  # nem toda vez que bate o streak troca -- ainda aguenta mais um pouco às vezes

# --- progressão do bot em si (separado do nível de cada carta) ---
# quantas cartas ele já conhece de cara, antes de evoluir -- um pouco mais
# que o tamanho do deck, pra já ter alguma escolha desde o início
const DECK_STYLE_VERSION = 3  # sobe esse número pra forçar todo bot a remontar o deck com o montador atual
const BONUS_KNOWN_CARDS = 4  # cartas extras de começo, puxadas pelo estilo de cada bot
const STARTING_KNOWN_CARDS = 9  # exatamente o tamanho do deck -- um "starter" de verdade, sem sobrar variedade extra logo de cara. Era 9 antes


func _get_save_path(bot_name: String) -> String:
	# isolado por perfil ativo -- sem isso, todo perfil lia/escrevia no MESMO
	# arquivo global, compartilhando o progresso do bot entre perfis diferentes
	# (por isso um perfil novo já "nascia" com bot de 90 vitórias)
	return SAVE_DIR + "profile_%d_" % PlayerProfile.active_profile_id + bot_name.to_snake_case() + ".save"


func _load_raw(bot_name: String) -> Dictionary:
	var path = _get_save_path(bot_name)
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	return data if data != null else {}


func _save_raw(bot_name: String, data: Dictionary):
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(bot_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


# devolve o AIProfile atual desse nome -- se for a primeira vez, sorteia
# personalidade, o conjunto de cartas que ele já conhece, e o baralho.
# Sempre recalcula a reserva de dinheiro em cima da carta que o jogador mais
# usa contra ele (sem persistir esse ajuste, pra se adaptar sozinho se o seu
# estilo mudar mais pra frente)
# true se esse bot guarda rancor de você (perdeu demais em sequência
# especificamente contra o jogador -- não conta derrota pra outro bot)
func is_nemesis_of_player(bot_name: String) -> bool:
	var data = _load_raw(bot_name)
	return data.get("is_nemesis_of_player", false)


# consome a rixa -- chama isso ao MONTAR a partida (não no resultado),
# assim o "grudge" vale só pra próxima vez que encontrar você, uma vez só,
# depois volta ao normal (se perder de novo, a contagem recomeça do zero)
func consume_nemesis(bot_name: String):
	var data = _load_raw(bot_name)
	if data.is_empty():
		return
	data["is_nemesis_of_player"] = false
	data["player_loss_streak"] = 0
	_save_raw(bot_name, data)


func get_or_create_profile(bot_name: String) -> AIProfile:
	var profile = AIProfile.new()
	profile.profile_name = bot_name

	var data = _load_raw(bot_name)
	var is_new = data.is_empty()

	if is_new:
		var archetype = randi() % AIProfile.Archetype.size()
		var traits = _traits_for_archetype(archetype)

		data = {
			"archetype": archetype,
			"stubbornness": traits.stubbornness,
			"min_money_reserve": traits.min_money_reserve,
			"prefer_expensive": traits.prefer_expensive,
			"reacts_to_threats": traits.reacts_to_threats,
			"decision_interval": traits.decision_interval,
			"revenge_mode": traits.revenge_mode,
			"prefer_units_over_spells": traits.prefer_units_over_spells,
			"preferred_role": _roll_preferred_role(archetype),
			"preferred_base_category": _roll_preferred_base_category(traits.reacts_to_threats, traits.prefer_expensive, traits.decision_interval, archetype),
			"gold": 0,   # moeda própria do bot -- ganha vitória igual o jogador ganha
			"base_level": 1,
			"base_matches_played": 0,  # mesmo custo do jogador -- ouro + partidas jogadas com essa base
			"total_wins": 0,  # só informativo agora (vitalício, pro popup) -- não dirige mais nível nenhum
			"equipped_base_path": "",
			"known_card_paths": [],     # cartas que esse bot já conhece/pode usar
			"deck_paths": [],
			"card_stats": {},           # caminho da carta -> {wins, losses} (uso: decidir troca de carta ruim)
			"card_usage": {},           # caminho da carta -> quantas vezes essa carta ESPECÍFICA foi jogada de verdade (uso: upar ela)
			"card_levels": {},          # caminho da carta -> nível atual do bot nessa carta
			"player_card_usage": {},    # caminho da carta -> quantas vezes o jogador usou
		}

	# migração: bot antigo, criado antes do sistema de arquétipo existir,
	# nunca passou pelo sorteio (isso só rola no bloco is_new) -- sem essa
	# migração, ele caía sempre no valor padrão (Agressivo) só por não ter
	# a chave salva ainda, fazendo TODO bot antigo parecer Agressivo
	var archetype_just_migrated = false
	if !data.has("archetype"):
		var migrated_archetype = randi() % AIProfile.Archetype.size()
		var migrated_traits = _traits_for_archetype(migrated_archetype)
		data["archetype"] = migrated_archetype
		data["stubbornness"] = migrated_traits.stubbornness
		archetype_just_migrated = true

	profile.archetype = data.get("archetype", AIProfile.Archetype.AGRESSIVO)
	profile.base_level = data.get("base_level", 1)
	profile.stubbornness = data.get("stubbornness", 0.5)
	# o traço salvo está na escala antiga (0-6); o recurso vai de 0 a 100,
	# então multiplica por 10 -- senão um Poupador guardava só 5 de 100
	profile.min_money_reserve = int(data.get("min_money_reserve", 0)) * 10
	profile.prefer_expensive = data.get("prefer_expensive", false)
	profile.reacts_to_threats = data.get("reacts_to_threats", false)
	profile.decision_interval = data.get("decision_interval", 2.0)
	profile.revenge_mode = data.get("revenge_mode", false)
	profile.prefer_units_over_spells = data.get("prefer_units_over_spells", false)
	profile.preferred_role = data.get("preferred_role", CardData.CardRole.VERSATIL)
	profile.preferred_base_category = data.get("preferred_base_category", BaseData.BaseCategory.DEFENSIVO)
	profile.card_levels = data.get("card_levels", {})

	var base_path = data.get("equipped_base_path", "")
	var base_just_rolled = false
	var bot_arena_now = ArenaManager.get_participant_arena(bot_name)
	# torre de arena mais alta que a do bot não vale: sorteia outra da arena dele
	if base_path != "" and ResourceLoader.exists(base_path):
		var current_base = load(base_path)
		if current_base is BaseData and current_base.unlock_arena > bot_arena_now:
			base_path = ""
	if base_path == "" or !ResourceLoader.exists(base_path):
		# ainda não tem base (bot novo, ou base antiga sumiu) -- sorteia uma
		# de acordo com a categoria preferida
		base_path = _roll_initial_base(profile.preferred_base_category, bot_arena_now)
		data["equipped_base_path"] = base_path
		base_just_rolled = true

	if base_path != "" and ResourceLoader.exists(base_path):
		profile.equipped_base = load(base_path)

	# cartas que esse bot já conhece -- se for a primeira vez, sorteia um
	# conjunto inicial (favorecendo a categoria preferida dele)
	var known_paths: Array = data.get("known_card_paths", [])
	if known_paths.is_empty():
		var initial_known = _pick_initial_known_cards(profile.preferred_role, profile.archetype)
		known_paths = _deck_to_paths(initial_known)
		data["known_card_paths"] = known_paths
	profile.known_cards = _load_deck(known_paths)

	profile.deck = _load_deck(data.get("deck_paths", []))
	# carta marcada como "só invocação" no Criador sai do deck do bot
	for i in range(profile.deck.size() - 1, -1, -1):
		if CustomContent.is_spawn_only(profile.deck[i]):
			profile.deck.remove_at(i)
	var known_changed = false

	# DECKS VARIADOS (v2): todo bot ganha um estilo próprio fixo e algumas
	# cartas extras de começo puxadas por esse estilo, e o deck é remontado
	# UMA vez com o montador novo -- vale também pros bots que já existiam
	var style = DeckBuilder.style_for_bot(bot_name, profile.archetype, profile.preferred_role)
	if int(data.get("deck_style_version", 0)) < DECK_STYLE_VERSION:
		data["deck_style_version"] = DECK_STYLE_VERSION
		var bonus = DeckBuilder.bonus_known_cards(style, profile.known_cards, BONUS_KNOWN_CARDS)
		for card in bonus:
			if !known_paths.has(card.resource_path):
				known_paths.append(card.resource_path)
		data["known_card_paths"] = known_paths
		profile.known_cards = _load_deck(known_paths)
		profile.deck.clear()  # força remontar com o estilo novo logo abaixo (lista tipada: clear, não = [])
		data.erase("favorite_card_path")
		known_changed = true

	if profile.deck.is_empty():
		profile.deck = _generate_random_deck(profile.preferred_role, profile.known_cards, style)

		# se alguma carta entrou no deck via fallback (o bot não conhecia o
		# suficiente ainda), passa a contar como conhecida dele também
		for card in profile.deck:
			if card != null and !known_paths.has(card.resource_path):
				known_paths.append(card.resource_path)
				known_changed = true
		if known_changed:
			data["known_card_paths"] = known_paths
			profile.known_cards = _load_deck(known_paths)

	# cartas que VOCÊ criou no Criador: cada bot "descobre" uma parte delas
	# (sempre as mesmas pra ele) e às vezes já coloca no deck
	if _learn_custom_cards(bot_name, data, profile, style, known_paths):
		known_changed = true

	if int(data.get("copies_v", 0)) < 1 and !is_new:
		_catch_up_copies(data, bot_arena_now)
		profile.card_levels = data.get("card_levels", {})
		profile.base_level = data.get("base_level", 1)
		known_changed = true
	# ARENA: o bot só joga com carta que já existe na arena DELE. Carta de arena
	# mais alta (ex.: carta de safra que mudou de arena) sai e entra outra parecida.
	if _enforce_arena_on_deck(profile, data, bot_arena_now, known_paths):
		known_changed = true

	var needs_save = is_new or known_changed or base_just_rolled or archetype_just_migrated

	# carta favorita: sorteia uma do próprio deck na primeira vez, e depois
	# disso persiste sempre a mesma -- senão mudaria de assinatura toda partida
	var favorite_path = data.get("favorite_card_path", "")
	if favorite_path != "" and ResourceLoader.exists(favorite_path):
		profile.favorite_card = load(favorite_path)
	elif !profile.deck.is_empty():
		profile.favorite_card = profile.deck[randi() % profile.deck.size()]
		data["favorite_card_path"] = profile.favorite_card.resource_path
		needs_save = true

	# guarda reserva o suficiente pra sempre conseguir reagir à carta que o
	# jogador mais usa contra ele -- "sabe" que você gosta de Rainha Abelha
	# e já deixa dinheiro de sobra pronto pra quando ela aparecer
	var feared_card = _get_most_used_player_card(data.get("player_card_usage", {}))
	if feared_card != null:
		profile.min_money_reserve = max(profile.min_money_reserve, min(feared_card.cost, 40))  # teto, senão o bot ficava passivo demais

	if needs_save:
		data["deck_paths"] = _deck_to_paths(profile.deck)
		_save_raw(bot_name, data)

	return profile


# sorteia o conjunto inicial de cartas que um bot novo já conhece --
# favorece um pouco a categoria preferida, igual a montagem do deck
# Boomer só usa carta ANTIGA (metade de trás pra frente do CardDatabase --
# posição menor = adicionada primeiro), Baby só usa a MAIS NOVA (metade de
# frente pra trás -- posição maior = adicionada por último). Qualquer outro
# arquétipo não filtra nada, usa o banco inteiro normalmente
func _filter_cards_by_age(cards: Array, archetype: int) -> Array:
	if archetype != AIProfile.Archetype.BOOMER and archetype != AIProfile.Archetype.BABY:
		return cards

	var half = int(cards.size() / 2.0)
	if archetype == AIProfile.Archetype.BOOMER:
		return cards.slice(0, half)  # primeira metade -- as mais antigas
	return cards.slice(half, cards.size())  # segunda metade -- as mais novas


func _pick_initial_known_cards(preferred_role: int, archetype: int = -1) -> Array[CardData]:
	# só cartas SEM predecessora (Tier 1, ou melhor: desbloqueável desde o
	# início) entram no sorteio inicial -- é exatamente o que um jogador de
	# verdade teria acesso no começo
	var starter_pool_all_ages: Array[CardData] = []
	for card in CardDatabase.all_cards:
		if card != null and card.predecessor_cards.is_empty():
			starter_pool_all_ages.append(card)

	# tenta primeiro RESPEITANDO a idade (Boomer só antiga, Baby só nova)
	var card_pool = _filter_cards_by_age(starter_pool_all_ages, archetype)

	# se a combinação idade+tier-inicial deixar poucas opções (ex: as
	# cartas iniciais do jogo ficaram concentradas numa metade só do
	# banco), relaxa o filtro de IDADE pro pontapé inicial -- sem isso, um
	# Baby (só metade nova) podia sobrar sem quase nenhuma carta inicial
	# disponível e nascer repetindo carta no deck à toa. O filtro de idade
	# continua valendo igual pro desbloqueio CONTÍNUO (_maybe_unlock_card_for_bot),
	# só o pontapé inicial relaxa nesse caso raro
	if card_pool.size() < DECK_SIZE:
		card_pool = starter_pool_all_ages

	var preferred_pool: Array[CardData] = []
	var rest_pool: Array[CardData] = []

	for card in card_pool:
		if card == null:
			continue
		if card.role == preferred_role:
			preferred_pool.append(card)
		else:
			rest_pool.append(card)

	preferred_pool.shuffle()
	rest_pool.shuffle()

	var known: Array[CardData] = []
	var seen: Dictionary = {}
	var preferred_target = int(STARTING_KNOWN_CARDS / 2.0)

	for card in preferred_pool:
		if known.size() >= preferred_target:
			break
		if seen.has(card.resource_path):
			continue
		seen[card.resource_path] = true
		known.append(card)

	for card in rest_pool:
		if known.size() >= STARTING_KNOWN_CARDS:
			break
		if seen.has(card.resource_path):
			continue
		seen[card.resource_path] = true
		known.append(card)

	return known


# monta um baralho de 7 cartas a partir do que o bot JÁ CONHECE (não do banco
# inteiro), favorecendo a categoria preferida dele -- tenta encher metade do
# deck com cartas dessa categoria, e completa o resto com o resto que conhece
func _generate_random_deck(preferred_role: int, known_cards: Array[CardData], style: Dictionary = {}) -> Array[CardData]:
	if style.is_empty():
		style = {"primary_role": preferred_role, "secondary_role": (preferred_role + 2) % CardData.CardRole.size(), "curve": 1, "spells_wanted": 1, "favorite_nation": ""}
	var deck = DeckBuilder.build_deck(known_cards, style, DECK_SIZE)

	# se não fechou 7 (o bot conhece pouca carta), repete carta conhecida
	# antes de vazar pro banco inteiro -- mesmo comportamento de antes
	if deck.size() < DECK_SIZE and !known_cards.is_empty():
		var known_shuffled = known_cards.duplicate()
		known_shuffled.shuffle()
		var i = 0
		while deck.size() < DECK_SIZE and i < known_shuffled.size() * 3:
			if known_shuffled[i % known_shuffled.size()] != null:
				deck.append(known_shuffled[i % known_shuffled.size()])
			i += 1
	if deck.size() < DECK_SIZE:
		var fallback_pool = CardDatabase.all_cards.duplicate()
		fallback_pool.shuffle()
		for card in fallback_pool:
			if deck.size() >= DECK_SIZE:
				break
			if card != null and !deck.has(card):
				deck.append(card)
	return deck


func _learn_custom_cards(bot_name: String, data: Dictionary, profile: AIProfile, style: Dictionary, known_paths: Array) -> bool:
	var seen: Array = data.get("seen_custom_cards", [])
	var changed = false
	for card in CustomContent.custom_cards + Safra.all_cards():  # criadas no Criador + colhidas na Safra
		if card == null or seen.has(card.resource_path) or CustomContent.is_spawn_only(card):
			continue
		seen.append(card.resource_path)
		changed = true
		var roll = abs(hash(bot_name + card.resource_path)) % 100
		var fit = DeckBuilder.score_card(card, style, [])
		if roll < 35 + int(fit * 6.0):
			if !known_paths.has(card.resource_path):
				known_paths.append(card.resource_path)
			profile.known_cards.append(card)
			# metade das vezes já testa a carta nova no deck, no lugar da que
			# menos combina com o estilo dele
			if roll % 2 == 0 and !profile.deck.is_empty() and !profile.deck.has(card):
				var worst_i = 0
				var worst_s = INF
				for i in profile.deck.size():
					var sc = DeckBuilder.score_card(profile.deck[i], style, [])
					if sc < worst_s:
						worst_s = sc
						worst_i = i
				profile.deck[worst_i] = card
	if changed:
		data["seen_custom_cards"] = seen
		data["known_card_paths"] = known_paths
	return changed


# estilo de deck de um bot, pra mostrar no popup do ranking
func get_deck_style_text(bot_name: String) -> String:
	var data = _load_raw(bot_name)
	var style = DeckBuilder.style_for_bot(bot_name, data.get("archetype", 0), data.get("preferred_role", CardData.CardRole.VERSATIL))
	return DeckBuilder.describe_style(style)


func _load_deck(paths: Array) -> Array[CardData]:
	var deck: Array[CardData] = []
	for path in paths:
		if ResourceLoader.exists(path):
			deck.append(load(path))
	return deck


func _deck_to_paths(deck: Array[CardData]) -> Array:
	var paths = []
	for card in deck:
		if card != null:
			paths.append(card.resource_path)
	return paths


# pacote de traços coerente com a personalidade escolhida -- cada um ainda
# tem uma faixa de variação individual (não é 100% travado igual dentro do
# mesmo arquétipo), só a direção geral que já vem definida
func _traits_for_archetype(archetype: int) -> Dictionary:
	match archetype:
		AIProfile.Archetype.AGRESSIVO:
			return {
				"min_money_reserve": randi_range(0, 1),
				"prefer_expensive": true,
				"reacts_to_threats": randf() < 0.2,
				"decision_interval": randf_range(1.0, 2.0),
				"revenge_mode": randf() < 0.5,
				"prefer_units_over_spells": randf() < 0.3,
				"stubbornness": randf_range(0.2, 0.5),
			}
		AIProfile.Archetype.PASSIVO:
			return {
				"min_money_reserve": randi_range(3, 5),
				"prefer_expensive": false,
				"reacts_to_threats": true,
				"decision_interval": randf_range(3.0, 4.5),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.5, 0.7),
			}
		AIProfile.Archetype.ATACA_TUDO:
			return {
				"min_money_reserve": 0,
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": false,
				"decision_interval": randf_range(0.8, 1.8),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.2, 0.4),
			}
		AIProfile.Archetype.ESTRUTURAL:
			return {
				"min_money_reserve": randi_range(3, 5),
				"prefer_expensive": false,
				"reacts_to_threats": true,
				"decision_interval": randf_range(2.5, 4.0),
				"revenge_mode": false,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.7, 0.9),
			}
		AIProfile.Archetype.METAGAMER:
			# identidade dele é a ESCOLHA de categoria (segue o que tá bombando),
			# não os traços -- esses ficam num meio-termo equilibrado
			return {
				"min_money_reserve": randi_range(1, 3),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(1.8, 3.0),
				"revenge_mode": randf() < 0.3,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.1, 0.3),
			}
		AIProfile.Archetype.CAOTICO:
			# faixas ainda mais largas que o Curioso -- de propósito imprevisível
			return {
				"min_money_reserve": randi_range(0, 5),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(0.5, 5.0),
				"revenge_mode": randf() < 0.5,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf(),
			}
		AIProfile.Archetype.POUPADOR:
			# o mais econômico de todos -- guarda praticamente sempre, só
			# gasta o essencial, prioriza sobreviver a jogar bonito
			return {
				"min_money_reserve": 5,
				"prefer_expensive": false,
				"reacts_to_threats": true,
				"decision_interval": randf_range(3.5, 4.5),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.6,
				"stubbornness": randf_range(0.7, 0.9),
			}
		AIProfile.Archetype.VINGATIVO:
			# sempre em modo vingança -- vive meio na defensiva até levar
			# dano, e aí vira o jogo de agressividade por um tempo
			return {
				"min_money_reserve": randi_range(1, 3),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": true,
				"decision_interval": randf_range(1.5, 2.5),
				"revenge_mode": true,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.5, 0.8),
			}
		AIProfile.Archetype.OPORTUNISTA:
			# guarda recurso e espera o momento certo -- não se afoba, mas
			# quando ataca, ataca com algo que vale a pena
			return {
				"min_money_reserve": randi_range(3, 5),
				"prefer_expensive": true,
				"reacts_to_threats": false,
				"decision_interval": randf_range(2.5, 3.8),
				"revenge_mode": false,
				"prefer_units_over_spells": false,
				"stubbornness": randf_range(0.4, 0.6),
			}
		AIProfile.Archetype.PROVOCADOR:
			# joga barato primeiro (isca), depois pune quem morder --
			# reserva baixa (gasta fácil) mas com vingança ligada
			return {
				"min_money_reserve": randi_range(0, 1),
				"prefer_expensive": false,
				"reacts_to_threats": randf() < 0.4,
				"decision_interval": randf_range(1.2, 2.2),
				"revenge_mode": true,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.3, 0.5),
			}
		AIProfile.Archetype.ENXAMEADOR:
			# aposta em quantidade, não em poder individual -- barato e rápido
			return {
				"min_money_reserve": randi_range(0, 2),
				"prefer_expensive": false,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(1.2, 2.5),
				"revenge_mode": randf() < 0.3,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.2, 0.5),
			}
		AIProfile.Archetype.EMBOSCADA:
			# reage rapidíssimo e barato/eficiente -- sem querer, isso faz
			# ele ser naturalmente forte contra quem se estica demais
			# (agressivo), e meio sem graça contra quem nunca se estica
			# (turtle). Não é um "contador" explícito, emerge da personalidade
			return {
				"min_money_reserve": randi_range(1, 2),
				"prefer_expensive": false,
				"reacts_to_threats": true,
				"decision_interval": randf_range(0.8, 1.5),
				"revenge_mode": true,
				"prefer_units_over_spells": randf() < 0.3,
				"stubbornness": randf_range(0.2, 0.4),
			}
		AIProfile.Archetype.ACUMULADOR:
			# guarda MUITO, mas pra investir tudo de uma vez em carta cara --
			# diferente do Poupador, que guarda por medo, não por plano
			return {
				"min_money_reserve": 5,
				"prefer_expensive": true,
				"reacts_to_threats": randf() < 0.4,
				"decision_interval": randf_range(3.0, 4.2),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.5, 0.7),
			}
		AIProfile.Archetype.REATIVO_PURO:
			# nunca inicia -- sempre devagar e metódico, só reage ao que
			# aparece (diferente da Emboscada, que reage rápido e oportunista)
			return {
				"min_money_reserve": randi_range(3, 5),
				"prefer_expensive": false,
				"reacts_to_threats": true,
				"decision_interval": randf_range(3.5, 4.5),
				"revenge_mode": false,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.6, 0.8),
			}
		AIProfile.Archetype.TERRITORIAL:
			# gosta de construção, mas com economia mais agressiva -- não é
			# tão na defensiva quanto o Estrutural
			return {
				"min_money_reserve": randi_range(1, 3),
				"prefer_expensive": true,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(2.0, 3.0),
				"revenge_mode": false,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.4, 0.6),
			}
		AIProfile.Archetype.IMPULSIVO:
			# o mais rápido de todos pra decidir -- mas sem escolha esperta
			# nenhuma por trás, só reflexo
			return {
				"min_money_reserve": 0,
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": false,
				"decision_interval": randf_range(0.5, 1.2),
				"revenge_mode": randf() < 0.6,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.2, 0.4),
			}
		AIProfile.Archetype.ANALITICO:
			# equilibrado, pouco teimoso -- adapta rápido, sem vício de
			# personalidade forte pra nenhum lado
			return {
				"min_money_reserve": randi_range(2, 3),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(2.0, 2.8),
				"revenge_mode": randf() < 0.3,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.1, 0.3),
			}
		AIProfile.Archetype.APOSTADOR:
			# gasta tudo, sempre na carta mais cara disponível, ritmo bem
			# inconsistente -- mentalidade de jogador
			return {
				"min_money_reserve": 0,
				"prefer_expensive": true,
				"reacts_to_threats": randf() < 0.3,
				"decision_interval": randf_range(0.6, 4.0),
				"revenge_mode": randf() < 0.5,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.1, 0.3),
			}
		AIProfile.Archetype.PERFECCIONISTA:
			# guarda MUITO e reage a ameaça quase sempre -- mas diferente do
			# Poupador (guarda por medo) ou Acumulador (guarda pra estourar
			# tudo de uma vez), esse guarda esperando o CONTRA-CARTA certo
			# aparecer -- teimosia altíssima, decide bem devagar
			return {
				"min_money_reserve": randi_range(4, 6),
				"prefer_expensive": false,
				"reacts_to_threats": randf() < 0.85,
				"decision_interval": randf_range(3.5, 5.0),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.85, 0.95),
			}
		AIProfile.Archetype.MINIMALISTA:
			# nunca joga carta cara, mesmo tendo o dinheiro sobrando -- teto
			# de custo rígido de propósito, não é sobre categoria (diferente
			# do Enxameador) nem sobre economizar por medo (diferente do
			# Poupador), é disciplina de gasto barato sempre
			return {
				"min_money_reserve": randi_range(0, 1),
				"prefer_expensive": false,
				"reacts_to_threats": randf() < 0.6,
				"decision_interval": randf_range(1.5, 2.5),
				"revenge_mode": randf() < 0.2,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.8, 0.95),
			}
		AIProfile.Archetype.METRONOMO:
			# ritmo quase sem variação nenhuma -- decision_interval numa
			# faixa BEM estreita (todos os outros arquétipos têm faixa
			# larga de propósito). Fica extremamente previsível/regular,
			# quase mecânico -- o oposto do Caótico
			return {
				"min_money_reserve": randi_range(1, 2),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.4,
				"decision_interval": randf_range(1.9, 2.1),
				"revenge_mode": false,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.5, 0.6),
			}
		AIProfile.Archetype.COMBINADOR:
			# caça combo de propósito -- reserva alta pra segurar carta
			# esperando o momento certo de encaixar no COMBO_TABLE, em vez
			# de jogar reativo. Decide devagar (pensando na sequência),
			# teimosia alta (não abandona o plano de combo fácil)
			return {
				"min_money_reserve": randi_range(3, 4),
				"prefer_expensive": randf() < 0.4,
				"reacts_to_threats": randf() < 0.3,
				"decision_interval": randf_range(2.8, 3.8),
				"revenge_mode": false,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.7, 0.85),
			}
		AIProfile.Archetype.BOOMER:
			# "não muda o que já funciona" -- teimosia altíssima (resiste
			# a trocar carta do deck), decide devagar, sem pressa nenhuma.
			# O filtro de QUAIS cartas ele usa (só as mais antigas) é
			# aplicado em outro lugar (_pick_initial_known_cards/replacement)
			return {
				"min_money_reserve": randi_range(2, 4),
				"prefer_expensive": false,
				"reacts_to_threats": randf() < 0.4,
				"decision_interval": randf_range(3.0, 4.0),
				"revenge_mode": false,
				"prefer_units_over_spells": true,
				"stubbornness": randf_range(0.85, 0.95),
			}
		AIProfile.Archetype.BABY:
			# sempre animado com o que é novo -- teimosia baixíssima
			# (adota carta nova fácil), decide rápido, gosta de
			# experimentar. Mesma ideia do Boomer só que ao contrário: o
			# filtro de cartas (só as mais recentes) fica em outro lugar
			return {
				"min_money_reserve": randi_range(0, 2),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(1.0, 2.0),
				"revenge_mode": randf() < 0.3,
				"prefer_units_over_spells": randf() < 0.5,
				"stubbornness": randf_range(0.05, 0.2),
			}
		_:  # CURIOSO -- de propósito bem variado, sem direção fixa nenhuma
			return {
				"min_money_reserve": randi_range(0, 4),
				"prefer_expensive": randf() < 0.5,
				"reacts_to_threats": randf() < 0.5,
				"decision_interval": randf_range(1.0, 4.5),
				"revenge_mode": randf() < 0.3,
				"prefer_units_over_spells": randf() < 0.4,
				"stubbornness": randf_range(0.1, 0.3),
			}


# CURIOSO/ESTRUTURAL puxam pra uma categoria específica (experimenta tudo /
# gosta de construção); METAGAMER segue o que está bombando na temporada
# atual; os outros ficam com sorteio uniforme normal
# depois de uma sequência de derrota feia demais, dá chance de re-sortear
# o arquétipo INTEIRO (personalidade + traços), não só uma carta do deck --
# é a chance de um bot "nascido" com uma personalidade ruim pro momento
# conseguir um recomeço de verdade, em vez de ficar preso pra sempre
# espelha PlayerProfile.award_battle_xp() -- 84% pras nações, 16% livre.
# Diferença: bot não rastreia quantas vezes cada carta foi jogada DENTRO da
# partida (ele não joga carta por carta de verdade, decide na simulação),
# então divide os 84% igualmente entre as nações presentes no deck, em vez
# de proporcional ao uso -- aproximação razoável dado o que o bot rastreia
func _award_bot_nation_xp(data: Dictionary, total_xp: int, deck: Array[CardData]):
	var nation_xp: Dictionary = data.get("nation_xp", {})
	var free_xp: int = data.get("free_xp", 0)

	var nations_in_deck: Array[String] = []
	for card in deck:
		if card == null:
			continue
		var n = card.get_nation_name()
		if n != "" and n not in nations_in_deck:
			nations_in_deck.append(n)

	if nations_in_deck.is_empty():
		free_xp += total_xp
	else:
		var nation_share = int(total_xp * 0.84)
		var per_nation = nation_share / nations_in_deck.size()
		for n in nations_in_deck:
			nation_xp[n] = nation_xp.get(n, 0) + per_nation
		free_xp += total_xp - nation_share

	data["nation_xp"] = nation_xp
	data["free_xp"] = free_xp


# espelha can_unlock_card/unlock_card do jogador -- nação + livre podem
# somar, cadeia de predecessoras precisa estar toda desbloqueada. Prioriza
# carta que bate com preferred_role do bot (sua "preferência" de arquétipo);
# só olha pra fora da preferência se não tiver nenhuma preferida disponível.
# Entre candidatas empatadas, escolhe sempre a de TIER mais baixo primeiro
# (progride a cadeia em ordem, não pula pra frente à toa), com sorteio só
# entre as do mesmo tier
func _maybe_unlock_card_for_bot(data: Dictionary):
	var known_paths: Array = data.get("known_card_paths", [])
	var nation_xp: Dictionary = data.get("nation_xp", {})
	var free_xp: int = data.get("free_xp", 0)
	var preferred_role = data.get("preferred_role", CardData.CardRole.VERSATIL)
	var archetype = data.get("archetype", -1)

	var preferred_candidates: Array[CardData] = []
	var other_candidates: Array[CardData] = []

	for card in _filter_cards_by_age(CardDatabase.all_cards, archetype):
		if card == null or card.nation_xp_cost <= 0:
			continue
		if card.resource_path in known_paths:
			continue

		var chain_ok = true
		for predecessor in card.predecessor_cards:
			if predecessor == null:
				continue
			var predecessor_known = predecessor.nation_xp_cost <= 0 or predecessor.resource_path in known_paths
			if !predecessor_known:
				chain_ok = false
				break
		if !chain_ok:
			continue

		var n = card.get_nation_name()
		var is_wildcard = n == "" or n == "Coringa"
		var available = free_xp if is_wildcard else (nation_xp.get(n, 0) + free_xp)
		if available < card.nation_xp_cost:
			continue

		if card.role == preferred_role:
			preferred_candidates.append(card)
		else:
			other_candidates.append(card)

	var pool = preferred_candidates if !preferred_candidates.is_empty() else other_candidates
	if pool.is_empty():
		return

	pool.sort_custom(func(a, b): return a.tier < b.tier)
	var lowest_tier = pool[0].tier
	var lowest_tier_pool = pool.filter(func(c): return c.tier == lowest_tier)
	var chosen: CardData = lowest_tier_pool[randi() % lowest_tier_pool.size()]

	var n = chosen.get_nation_name()
	var is_wildcard = n == "" or n == "Coringa"
	if is_wildcard:
		free_xp -= chosen.nation_xp_cost
	else:
		var nation_available = nation_xp.get(n, 0)
		var from_nation = min(nation_available, chosen.nation_xp_cost)
		var from_free = chosen.nation_xp_cost - from_nation
		nation_xp[n] = nation_available - from_nation
		free_xp -= from_free

	known_paths.append(chosen.resource_path)
	data["known_card_paths"] = known_paths
	data["nation_xp"] = nation_xp
	data["free_xp"] = free_xp


func _maybe_switch_archetype(data: Dictionary):
	var loss_streak = data.get("current_loss_streak", 0)
	if loss_streak < ARCHETYPE_SWITCH_LOSS_STREAK:
		return
	if randf() > ARCHETYPE_SWITCH_CHANCE:
		return

	var new_archetype = randi() % AIProfile.Archetype.size()
	var traits = _traits_for_archetype(new_archetype)

	data["archetype"] = new_archetype
	data["stubbornness"] = traits.stubbornness
	data["min_money_reserve"] = traits.min_money_reserve
	data["prefer_expensive"] = traits.prefer_expensive
	data["reacts_to_threats"] = traits.reacts_to_threats
	data["decision_interval"] = traits.decision_interval
	data["revenge_mode"] = traits.revenge_mode
	data["prefer_units_over_spells"] = traits.prefer_units_over_spells
	data["preferred_role"] = _roll_preferred_role(new_archetype)
	data["preferred_base_category"] = _roll_preferred_base_category(
		traits.reacts_to_threats, traits.prefer_expensive, traits.decision_interval, new_archetype
	)
	data["current_loss_streak"] = 0  # começa do zero com a personalidade nova, merece a chance


func _roll_preferred_role(archetype: int) -> int:
	if (archetype == AIProfile.Archetype.ESTRUTURAL or archetype == AIProfile.Archetype.TERRITORIAL) and randf() < 0.6:
		return CardData.CardRole.CONSTRUCAO

	if archetype == AIProfile.Archetype.ENXAMEADOR and randf() < 0.6:
		return CardData.CardRole.ENXAME

	if archetype == AIProfile.Archetype.METAGAMER:
		var best_role = _get_trending_role()
		if best_role != -1:
			return best_role

	return randi() % CardData.CardRole.size()


# acha a categoria da carta com melhor taxa de vitória na temporada atual
# (com dado suficiente pra não ser só ruído) -- devolve -1 se ainda não
# tiver dado nenhum confiável (temporada muito nova)
func _get_trending_role() -> int:
	var best_role = -1
	var best_rate = 0.0
	for entry in SeasonStats.get_all_card_stats():
		if entry["wins"] + entry["losses"] < 3 or entry["card"] == null:
			continue
		if entry["win_rate"] > best_rate:
			best_rate = entry["win_rate"]
			best_role = entry["card"].role
	return best_role


# deriva a categoria de base preferida a partir de traços de personalidade
# já existentes -- não é 100% determinístico (ainda tem sorteio), só
# inclina o resultado pro lado que combina com o resto do jeito do bot.
# Poupador tem viés direto e forte pra Econômica, por identidade temática
func _roll_preferred_base_category(reacts_to_threats: bool, prefer_expensive: bool, decision_interval: float, archetype: int) -> int:
	if archetype == AIProfile.Archetype.POUPADOR and randf() < 0.75:
		return BaseData.BaseCategory.ECONOMICO

	var weights = {
		BaseData.BaseCategory.OFENSIVO: 1.0,
		BaseData.BaseCategory.DEFENSIVO: 1.0,
		BaseData.BaseCategory.ECONOMICO: 1.0,
	}
	if reacts_to_threats:
		weights[BaseData.BaseCategory.DEFENSIVO] += 1.0
	if prefer_expensive:
		weights[BaseData.BaseCategory.OFENSIVO] += 1.0
	if decision_interval < 2.0:
		weights[BaseData.BaseCategory.OFENSIVO] += 0.5
	elif decision_interval > 3.5:
		weights[BaseData.BaseCategory.ECONOMICO] += 0.5

	var total = 0.0
	for w in weights.values():
		total += w
	var roll = randf() * total
	var cumulative = 0.0
	for cat in weights:
		cumulative += weights[cat]
		if roll <= cumulative:
			return cat
	return BaseData.BaseCategory.DEFENSIVO


# sorteia uma base pra esse bot -- prioriza a categoria preferida dele, mas
# só entre as que já estão liberadas de graça (nation_xp_cost 0, mesmo
# critério "sem custo" que o jogador usa pro início). Se não achar nenhuma
# da categoria preferida ainda liberada, cai pra qualquer uma liberada
func _enforce_arena_on_deck(profile: AIProfile, data: Dictionary, cap: int, known_paths: Array) -> bool:
	var changed = false
	for i in profile.deck.size():
		var old: CardData = profile.deck[i]
		if old == null or old.unlock_arena <= cap:
			continue
		var same_role: Array = []
		var any: Array = []
		for c in CardDatabase.all_cards:
			if c == null or CustomContent.is_spawn_only(c) or c.unlock_arena > cap or profile.deck.has(c):
				continue
			any.append(c)
			if c.role == old.role and c.is_spell() == old.is_spell():
				same_role.append(c)
		var pool = same_role if !same_role.is_empty() else any
		if pool.is_empty():
			continue
		var pick: CardData = pool[abs(hash(profile.profile_name + old.resource_path)) % pool.size()]
		profile.deck[i] = pick
		if !known_paths.has(pick.resource_path):
			known_paths.append(pick.resource_path)
		changed = true
	if changed:
		data["deck_paths"] = _deck_to_paths(profile.deck)
		data["known_card_paths"] = known_paths
		data.erase("favorite_card_path")
	return changed


## passa por todos os bots uma vez, pra arrumar baralho e torre fora da arena
func enforce_arena_everywhere():
	for n in BotSimulator.roster_names:
		get_or_create_profile(str(n))


func _roll_initial_base(preferred_category: int, arena_cap: int = 99) -> String:
	var unlocked = BotSimulator.available_bases.filter(func(b): return b != null and b.nation_xp_cost <= 0 and b.unlock_arena <= arena_cap)
	if unlocked.is_empty():
		unlocked = BotSimulator.available_bases.filter(func(b): return b != null and b.unlock_arena <= 0)
	if unlocked.is_empty():
		return ""

	var matching = unlocked.filter(func(b): return b.category == preferred_category)
	var pool = matching if !matching.is_empty() else unlocked

	var base_data = pool[randi() % pool.size()]
	return base_data.resource_path if base_data != null else ""


func _get_most_used_player_card(usage: Dictionary) -> CardData:
	var best_path = ""
	var best_count = 0
	for path in usage:
		if usage[path] > best_count:
			best_count = usage[path]
			best_path = path
	if best_path != "" and ResourceLoader.exists(best_path):
		return load(best_path)
	return null


# chama isso quando a partida termina e o adversário era um bot da lista de
# nomes -- registra o desempenho de cada carta do deck dele nessa partida,
# soma vitória geral (pra subir de nível e desbloquear carta nova), registra
# quais cartas o jogador usou, e evolui o deck trocando quem for mal
# o jogador venceu essa partida contra o bot -- descobre uma contra-carta
# (usando a mesma teia de vantagem CardData.role_beats que a IA já usa em
# tempo real de jogo) pra reagir da PRÓXIMA vez que enfrentar algo
# parecido. Troca só 1 carta do deck (não mais) -- mais conservador, evita
# destruir a sinergia do deck inteiro por causa de UMA ameaça específica
func record_loss_culprit(bot_name: String, culprit_card: CardData):
	var data = _load_raw(bot_name)
	if data.is_empty() or culprit_card == null:
		return

	var known_cards = _load_deck(data.get("known_card_paths", []))
	var counter_card = _find_counter_card(culprit_card.role, known_cards, data.get("deck_paths", []))
	if counter_card == null:
		return  # não conhece nenhuma contra-carta pra essa ameaça ainda -- nada a fazer

	var deck_paths: Array = data.get("deck_paths", [])
	if deck_paths.is_empty():
		return

	var swap_index = randi() % deck_paths.size()
	deck_paths[swap_index] = counter_card.resource_path
	data["deck_paths"] = deck_paths
	_save_raw(bot_name, data)


# acha uma carta CONHECIDA (já desbloqueada) que vence a categoria da
# ameaça, e que ainda não está no deck atual -- senão não tem o que trocar
func _find_counter_card(threat_role: int, known_cards: Array[CardData], current_deck_paths: Array) -> CardData:
	var candidates: Array[CardData] = []
	for card in known_cards:
		if card == null or card.resource_path in current_deck_paths:
			continue
		if CardData.role_beats(card.role, threat_role):
			candidates.append(card)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


const NEMESIS_LOSS_THRESHOLD = 2  # quantas derrotas SEGUIDAS contra o jogador até o bot "guardar rancor"


func record_result(bot_name: String, bot_won: bool, player_cards_played: Array[CardData], is_vs_player: bool = false):
	var data = _load_raw(bot_name)
	if data.is_empty():
		return  # bot ainda não existe por algum motivo -- nada a registrar

	var bot_arena = ArenaManager.get_participant_arena(bot_name)
	var reward = ArenaManager.get_match_reward(bot_arena, bot_won)

	if bot_won:
		data["total_wins"] = data.get("total_wins", 0) + 1  # só informativo (vitalício)
		data["gold"] = data.get("gold", 0) + reward["gold"]
		data["current_loss_streak"] = 0  # quebrou a má fase, começa a contar de novo
		_catch_up_copies(data, bot_arena)
		_bot_open_chest(data, bot_arena)
	else:
		data["total_losses"] = data.get("total_losses", 0) + 1
		data["gold"] = data.get("gold", 0) + reward["gold"]
		data["current_loss_streak"] = data.get("current_loss_streak", 0) + 1
		_catch_up_copies(data, bot_arena)
		if randf() < BOT_LOSS_CHEST_CHANCE:
			_bot_open_chest(data, bot_arena, 0)
		_maybe_switch_archetype(data)

	# rixa -- diferente da má-fase geral (que conta QUALQUER derrota), essa
	# conta só derrota ESPECÍFICA contra o jogador. Ao bater o teto, o bot
	# "guarda rancor" e fica marcado -- na próxima vez que enfrentar você
	# de novo, entra mais afiado (ver _maybe_apply_nemesis_boost, chamado
	# na cena de batalha ao montar a partida)
	if is_vs_player:
		if bot_won:
			data["player_loss_streak"] = 0
		else:
			data["player_loss_streak"] = data.get("player_loss_streak", 0) + 1
			if data["player_loss_streak"] >= NEMESIS_LOSS_THRESHOLD:
				data["is_nemesis_of_player"] = true

	# igual jogador -- bot também ganha XP de nação (mesma divisão 84%/16%)
	# baseado nas nações do PRÓPRIO deck, e pode ir desbloqueando carta nova
	# seguindo a preferência dele (preferred_role), até o arquétipo mudar
	var bot_deck_for_xp = _load_deck(data.get("deck_paths", []))
	_award_bot_nation_xp(data, reward["xp"], bot_deck_for_xp)
	_maybe_unlock_card_for_bot(data)

	# desempenho de cada carta do deck atual nessa partida (crédito/culpa
	# compartilhado entre todas as cartas que estavam no deck usado) --
	# usado só pra decidir SE uma carta está indo mal e merece ser trocada,
	# não decide mais nível de carta nenhum (isso agora é manual, ver embaixo)
	var card_stats: Dictionary = data.get("card_stats", {})
	var deck_paths: Array = data.get("deck_paths", [])
	for path in deck_paths:
		if !card_stats.has(path):
			card_stats[path] = {"wins": 0, "losses": 0}
		if bot_won:
			card_stats[path]["wins"] += 1
		else:
			card_stats[path]["losses"] += 1
	data["card_stats"] = card_stats

	# mesma lógica de custo híbrido (ouro + partidas jogadas) que o jogador
	# usa pra upar a base -- conta essa partida como "jogada com essa base"
	# e confere se já dá pra upar. Roda ANTES da carta de propósito: o
	# custo da base (300+) é bem maior que o de qualquer carta (100-250),
	# então se a carta checasse primeiro ela quase sempre "roubava" o ouro
	# disponível antes da base acumular o suficiente, e a base nunca subia
	data["base_matches_played"] = data.get("base_matches_played", 0) + 1
	_maybe_upgrade_base(data)

	# evolução MANUAL, carta por carta: gasta ouro + uso de verdade de uma
	# carta específica pra upar ela, exatamente como o jogador faz -- nunca
	# mais um cálculo automático que upava o deck inteiro de uma vez só
	_maybe_upgrade_cards(data)

	# quais cartas o jogador usou nessa partida, pra ir aprendendo seu estilo
	var player_usage: Dictionary = data.get("player_card_usage", {})
	for card in player_cards_played:
		if card == null:
			continue
		var path = card.resource_path
		player_usage[path] = player_usage.get(path, 0) + 1
	data["player_card_usage"] = player_usage

	# evolui o deck: troca cartas que estão indo mal demais por outras que
	# o bot já conhece (não do banco inteiro -- só do que ele desbloqueou)
	var known_cards = _load_deck(data.get("known_card_paths", []))
	var stubbornness = data.get("stubbornness", 0.5)
	_current_style = DeckBuilder.style_for_bot(bot_name, data.get("archetype", 0), data.get("preferred_role", CardData.CardRole.VERSATIL))
	data["deck_paths"] = _evolve_deck(deck_paths, card_stats, data.get("card_levels", {}), known_cards, stubbornness)
	_current_style = {}

	_save_raw(bot_name, data)


# chama isso toda vez que o bot REALMENTE joga uma carta específica (não só
# quando ela está no deck) -- é esse número que decide se dá pra upar ela,
# então cada carta evolui no seu próprio ritmo, de acordo com o quanto foi
# de fato usada, em vez de todo o deck evoluir junto igual antes
# crédito de uso APROXIMADO pra partida simulada de fundo -- essa
# simulação nunca joga carta por carta de verdade (só compara força e
# declara vencedor na hora), então sem isso o uso de cada carta nunca saía
# do zero pra quem só participa da simulação, mesmo acumulando muito ouro
func record_simulated_match_usage(bot_name: String, deck: Array[CardData]):
	var data = _load_raw(bot_name)
	if data.is_empty():
		return

	var card_usage: Dictionary = data.get("card_usage", {})
	for card in deck:
		if card == null:
			continue
		var path = card.resource_path
		card_usage[path] = card_usage.get(path, 0) + SIMULATED_USAGE_PER_MATCH

	data["card_usage"] = card_usage
	_save_raw(bot_name, data)


func record_card_played(bot_name: String, card: CardData):
	if card == null:
		return
	var data = _load_raw(bot_name)
	if data.is_empty():
		return

	var card_usage: Dictionary = data.get("card_usage", {})
	var path = card.resource_path
	card_usage[path] = card_usage.get(path, 0) + 1
	data["card_usage"] = card_usage
	_save_raw(bot_name, data)


# confere CADA carta do deck atual: se já tiver uso suficiente E ouro
# suficiente (mesma fórmula híbrida do jogador), upa ela um nível. Passa
# por todas de uma vez, então se tiver ouro de sobra, dá pra upar mais de
# uma carta na mesma checagem -- exatamente como você pediu
# mesmo custo híbrido que o jogador usa pra upar a base (ouro + partidas
# jogadas com ela) -- reaproveita as MESMAS constantes de PlayerProfile,
# pra ficar igual dos dois lados, como pedido
func _maybe_upgrade_base(data: Dictionary):
	var level = data.get("base_level", 1)
	if level >= PlayerProfile.MAX_CARD_LEVEL:
		return

	# MESMOS valores de uma carta (antes a torre pedia 40 partidas + 300 de
	# ouro e, na prática, nunca saía do nível 1)
	var matches_needed = PlayerProfile.UPGRADE_BASE_USES + (level - 1) * PlayerProfile.UPGRADE_USES_GROWTH
	var cost_needed = PlayerProfile.UPGRADE_BASE_COST + (level - 1) * PlayerProfile.UPGRADE_COST_GROWTH
	var matches_have = data.get("base_matches_played", 0)
	var gold = data.get("gold", 0)

	if matches_have < matches_needed or gold < cost_needed:
		return

	data["base_matches_played"] = matches_have - matches_needed
	data["gold"] = gold - cost_needed
	data["base_level"] = level + 1


## Vitória do bot rende um baú, igual pra você: cópias de cartas da arena dele
## (pelos mesmos pesos de raridade) e um pouco de ouro. Nem toda vitória rende,
## porque você também espera o baú abrir e tem limite de espaço.
const BOT_CHEST_CHANCE = 1.0        # toda vitória rende baú (você ainda tem Feira, presentes, clã e torneio)
const BOT_LOSS_CHEST_CHANCE = 0.3   # e de vez em quando um Saco mesmo perdendo, pra não empacar


## ACERTO DE CONTAS (uma vez por bot): a regra de cópias começou agora, então
## bot antigo, cheio de vitórias, estava sem cópia nenhuma e empacou com carta
## nível 2 e torre nível 3. Aqui ele recebe as cópias que TERIA ganho nos baús
## das vitórias que já tem, e evolui o que der com o ouro guardado.
func _catch_up_copies(data: Dictionary, bot_arena: int):
	if int(data.get("copies_v", 0)) >= 1:
		return
	data["copies_v"] = 1
	var wins = int(data.get("total_wins", 0))
	if wins <= 0:
		return
	var pool_count = [0, 0, 0, 0, 0]
	for c in CardDatabase.all_cards:
		if c != null and !CustomContent.is_spawn_only(c) and c.unlock_arena <= bot_arena:
			pool_count[Catalogo.rarity_of(c)] += 1
	# quantas "sorteadas" de cada raridade um baú de vitória dá, em média
	var rolls_per_win = [0.0, 0.0, 0.0, 0.0, 0.0]
	var total_w = 0.0
	for w in Progresso.WIN_CHEST_WEIGHTS:
		total_w += w
	for t in Progresso.CHESTS.size():
		var chance = float(Progresso.WIN_CHEST_WEIGHTS[t]) / total_w
		var def: Dictionary = Progresso.CHESTS[t]
		var sum_p = 0.0
		for pw in def["pesos"]:
			sum_p += pw
		for r in 5:
			rolls_per_win[r] += chance * float(def["cartas"]) * float(def["pesos"][r]) / sum_p
	var copies: Dictionary = data.get("card_copies", {})
	for path in data.get("deck_paths", []):
		var card = Catalogo.find_card(str(path))
		if card == null:
			continue
		var r = Catalogo.rarity_of(card)
		if pool_count[r] <= 0:
			continue
		var avg_copies = (Progresso.COPIES_PER_ROLL[r][0] + Progresso.COPIES_PER_ROLL[r][1]) * 0.5
		var gained = int(round(wins * rolls_per_win[r] / pool_count[r] * avg_copies))
		copies[path] = mini(400, int(copies.get(path, 0)) + gained)
	data["card_copies"] = copies
	# ouro dos baús que ele teria aberto
	data["gold"] = int(data.get("gold", 0)) + wins * 30
	for i in 8:
		_maybe_upgrade_cards(data)
		_maybe_upgrade_base(data)


func _bot_open_chest(data: Dictionary, bot_arena: int, forced_type: int = -1):
	if forced_type < 0 and randf() > BOT_CHEST_CHANCE:
		return
	var type = forced_type if forced_type >= 0 else Progresso._weighted(Progresso.WIN_CHEST_WEIGHTS)
	var def: Dictionary = Progresso.CHESTS[type]
	data["gold"] = int(data.get("gold", 0)) + randi_range(int(def["ouro"][0]), int(def["ouro"][1]))
	var pool: Array = []
	for c in CardDatabase.all_cards:
		if c != null and !CustomContent.is_spawn_only(c) and c.unlock_arena <= bot_arena:
			pool.append(c)
	if pool.is_empty():
		return
	var copies: Dictionary = data.get("card_copies", {})
	for i in int(def["cartas"]):
		var rarity = Progresso._weighted(def["pesos"])
		if i == 0 and int(def["garante"]) > 0:
			rarity = maxi(rarity, int(def["garante"]))
		var card: CardData = Progresso._pick_of_rarity(pool, rarity)
		if card == null:
			continue
		var range_q = Progresso.COPIES_PER_ROLL[Catalogo.rarity_of(card)]
		copies[card.resource_path] = mini(400, int(copies.get(card.resource_path, 0)) + randi_range(range_q[0], range_q[1]))
	data["card_copies"] = copies


## MESMA regra do jogador: pra subir uma carta o bot precisa das CÓPIAS dela
## (que vêm dos baús das vitórias) e do ouro, com o mesmo preço por raridade.
## Antes bastava ouro + ter usado a carta, e eles subiam rápido demais.
func _maybe_upgrade_cards(data: Dictionary):
	var deck_paths: Array = data.get("deck_paths", [])
	var card_levels: Dictionary = data.get("card_levels", {})
	var copies: Dictionary = data.get("card_copies", {})
	var gold: int = data.get("gold", 0)

	for path in deck_paths:
		var level = int(card_levels.get(path, 1))
		if level >= PlayerProfile.MAX_CARD_LEVEL:
			continue
		var card = Catalogo.find_card(str(path))
		if card == null:
			continue
		var rarity = Catalogo.rarity_of(card)
		var copies_needed = int(Progresso.COPIES_NEEDED[rarity][clampi(level - 1, 0, 7)])
		var cost_needed = int(round((PlayerProfile.UPGRADE_BASE_COST + (level - 1) * PlayerProfile.UPGRADE_COST_GROWTH) * Progresso.COIN_FACTOR[rarity]))
		var copies_have = int(copies.get(path, 0))
		if copies_have < copies_needed or gold < cost_needed:
			continue
		copies[path] = copies_have - copies_needed
		gold -= cost_needed
		card_levels[path] = level + 1

	data["card_copies"] = copies
	data["card_levels"] = card_levels
	data["gold"] = gold


func _evolve_deck(deck_paths: Array, card_stats: Dictionary, card_levels: Dictionary, known_cards: Array[CardData], stubbornness: float) -> Array:
	var new_deck = deck_paths.duplicate()

	for i in new_deck.size():
		var path = new_deck[i]
		var stats = card_stats.get(path, {"wins": 0, "losses": 0})
		var games_played = stats["wins"] + stats["losses"]
		var net_losses = stats["losses"] - stats["wins"]

		if games_played < MIN_GAMES_BEFORE_SWAP:
			continue

		# nível importa: carta já bem investida (alto nível) resiste mais a
		# sair -- precisa estar indo MUITO pior pra justificar jogar fora o
		# investimento já feito nela
		var level = card_levels.get(path, 1)
		var effective_threshold = CARD_NET_LOSS_THRESHOLD + (level - 1)

		if net_losses < effective_threshold:
			continue

		# teimosia: mesmo passando do limite, o bot pode simplesmente
		# insistir na carta -- quanto mais teimoso, menor a chance de trocar
		if randf() < stubbornness:
			continue

		var replacement = _pick_replacement_card(new_deck, known_cards)
		if replacement != null:
			new_deck[i] = replacement.resource_path
			card_stats.erase(path)   # a carta que saiu esquece o histórico dela
			card_levels.erase(path)  # e também o nível -- a substituta começa do zero

	return new_deck


# escolhe uma substituta entre as cartas que o bot JÁ CONHECE -- com viés
# forte pro que está REALMENTE vencendo na temporada atual (não é mais
# sorteio uniforme puro). É isso que faz uma "meta" emergir de verdade:
# bots insatisfeitos migram pro que está funcionando pra todo mundo, não
# só pro que calha de ser sorteado
var _current_style: Dictionary = {}  # estilo do bot sendo evoluído agora (setado em record_result)


func _pick_replacement_card(current_deck_paths: Array, known_cards: Array[CardData]) -> CardData:
	var current_deck: Array = _load_deck(current_deck_paths)
	var style = _current_style
	if style.is_empty():
		style = {"primary_role": CardData.CardRole.VERSATIL, "secondary_role": CardData.CardRole.TANQUE, "curve": 1, "spells_wanted": 1, "favorite_nation": ""}
	return DeckBuilder.pick_replacement(current_deck, known_cards, style, _get_trending_win_rates())


# taxa de vitória de cada carta na temporada atual, só pra quem já tem dado
# confiável (3+ partidas) -- usado pra puxar a substituição de carta pro
# que está realmente vencendo
func _get_trending_win_rates() -> Dictionary:
	var rates = {}
	for entry in SeasonStats.get_all_card_stats():
		if entry["card"] == null or entry["wins"] + entry["losses"] < 3:
			continue
		rates[entry["card"].resource_path] = entry["win_rate"]
	return rates


# leitura rápida só do nível geral do bot, sem montar o profile inteiro
# (sem gerar deck, sem carta favorita, sem nada disso) -- usa isso quando
# só precisa comparar nível de muitos bots de uma vez, tipo escolher adversário

# total de vitórias VITALÍCIO do bot (nunca reseta com a temporada, ao
# contrário de Leaderboard.get_record) -- é isso que decide o nível geral
# dele e influencia o nível de cada carta
func peek_lifetime_wins(bot_name: String) -> int:
	var data = _load_raw(bot_name)
	return data.get("total_wins", 0)


func peek_gold(bot_name: String) -> int:
	var data = _load_raw(bot_name)
	return data.get("gold", 0)


func peek_base_level(bot_name: String) -> int:
	var data = _load_raw(bot_name)
	return data.get("base_level", 1)


func peek_archetype(bot_name: String) -> int:
	var data = _load_raw(bot_name)
	return data.get("archetype", AIProfile.Archetype.AGRESSIVO)


# consulta pública: qual carta esse bot mais jogou (mais partidas com ela no
# deck, ganhando ou perdendo) -- usado no popup de informações do bot
func get_most_played_card(bot_name: String) -> CardData:
	var data = _load_raw(bot_name)
	var card_stats: Dictionary = data.get("card_stats", {})

	var best_path = ""
	var best_count = 0
	for path in card_stats:
		var total = card_stats[path].get("wins", 0) + card_stats[path].get("losses", 0)
		if total > best_count:
			best_count = total
			best_path = path

	if best_path != "" and ResourceLoader.exists(best_path):
		return load(best_path)
	return null
