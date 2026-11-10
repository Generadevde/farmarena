extends RefCounted
class_name BattleBrain

# "Cérebro" tático compartilhado pelos bots na batalha (bot principal e os
# bots extras do 2v2). Resolve os 2 problemas que mais apareciam:
#  1) NÃO SABIAM DEFENDER -- só percebiam ameaça quando ela já estava colada
#     na base (raio 130/220), e escolhiam defensor só pela teia de categoria,
#     sem checar se a carta conseguia acertar a ameaça (ex: mandava tropa
#     terrestre contra aéreo). Agora: lê o campo inteiro (qualquer inimigo
#     na METADE do bot já conta), mede a "pressão" total do ataque, e escolhe
#     um defensor que realmente acerta o tipo de ameaça, com custo coerente,
#     posicionado ENTRE a ameaça e a base (à distância fica mais atrás).
#  2) FEITIÇO ERRADO -- jogava feitiço de dano em cima de 1 unidade barata,
#     feitiço de cura/fúria no inimigo, ou gastava a carta+dinheiro e
#     desistia sem lançar. Agora cada feitiço é avaliado pelo VALOR que ele
#     gera no ponto (soma do custo das unidades atingidas, considerando se
#     mata ou não), e só é lançado se valer a pena.

static var debug_log := false  # ligado só pelo teste automático do GitHub (ci/)

# pressão é medida na escala de custo do jogo (0-100)
const MIN_THREAT_PRESSURE = 8.0      # abaixo disso não é ameaça, é unidade perdida
const SERIOUS_THREAT_PRESSURE = 40.0  # "ataque de verdade" -- vale gastar pesado
const SPELL_VALUE_RATIO = 0.9        # feitiço só sai se gerar >= 90% do próprio custo em valor
const OFFENSIVE_SPELL_VALUE_RATIO = 1.15  # sem ameaça, exige mais (não é urgente)


# ------------------------------------------------------------------ util

static func is_unit(body) -> bool:
	return body != null and is_instance_valid(body) and body.is_in_group("units")


static func unit_value(u) -> float:
	if !is_unit(u) or u.stats == null:
		return 0.0
	var cost = 3.0
	if u.card_data != null:
		cost = float(u.card_data.cost)
	var count = max(u.stats.unit_count, 1)
	var hp_frac = 1.0
	if u.stats.hp > 0 and u.current_hp != null:
		hp_frac = clamp(float(u.current_hp) / u.stats.hp, 0.1, 1.0)
	return cost / count * (0.35 + 0.65 * hp_frac)


static func get_bases(tree: SceneTree, team) -> Array:
	return tree.get_nodes_in_group("player_base" if team == GameManager.Team.PLAYER else "enemy_base").filter(
		func(t): return is_instance_valid(t) and !t.is_queued_for_deletion())


# torre do time mais perto de um ponto (ou a primeira, sem ponto)
static func get_base(tree: SceneTree, team, near: Vector2 = Vector2.INF) -> Node:
	var best = null
	var best_d = INF
	for t in get_bases(tree, team):
		var d = 0.0 if near == Vector2.INF else near.distance_squared_to(t.global_position)
		if best == null or d < best_d:
			best = t
			best_d = d
	return best


# centro da "linha de torres" do time (mesmo se uma já caiu)
static func base_line(team) -> Vector2:
	var y = ArenaBuilder.CENTER.y + (ArenaBuilder.TOWER_DY if team == GameManager.Team.PLAYER else -ArenaBuilder.TOWER_DY)
	return Vector2(ArenaBuilder.CENTER.x, y)


static func other_team(team):
	return GameManager.Team.ENEMY if team == GameManager.Team.PLAYER else GameManager.Team.PLAYER


# ------------------------------------------------------------------ ameaças

# lê o campo: todo inimigo (do ponto de vista de `my_team`) que está na
# metade de cá do mapa, ou que está mirando nossa base/nossas construções
static func analyze_threats(tree: SceneTree, my_team) -> Dictionary:
	var result = {"units": [], "pressure": 0.0, "primary": null, "has_air": false,
		"has_ground": false, "center": Vector2.ZERO, "max_danger": 0}
	if get_bases(tree, my_team).is_empty():
		return result
	var my_line = base_line(my_team)
	var total_dist = max(my_line.distance_to(base_line(other_team(my_team))), 1.0)

	var weight_sum = 0.0
	var closest_d = INF
	for u in tree.get_nodes_in_group("units"):
		if !is_instance_valid(u) or u.team == my_team or u.stats == null:
			continue
		if u.stats.unit_type == UnitData.UnitType.BUILDING:
			# construção inimiga só é ameaça se alcançar nossa área (raro) -- ignora
			continue
		var near_tower = get_base(tree, my_team, u.global_position)
		var d_mine = min(u.global_position.distance_to(near_tower.global_position), abs(u.global_position.y - my_line.y))
		var progress = 1.0 - clamp(d_mine / total_dist, 0.0, 1.0)  # 1 = colado na torre
		var targeting_us = u.target != null and is_instance_valid(u.target) and "team" in u.target and u.target.team == my_team
		if progress < 0.45 and !targeting_us:
			continue  # ainda do lado de lá do mapa

		var danger = u.card_danger_level if "card_danger_level" in u else 3
		var p = unit_value(u) * (0.5 + danger / 10.0) * (0.4 + progress * 1.2)
		result["pressure"] += p
		result["units"].append(u)
		result["max_danger"] = max(result["max_danger"], danger)
		result["center"] += u.global_position * p
		weight_sum += p
		if u.stats.unit_type == UnitData.UnitType.AIR:
			result["has_air"] = true
		else:
			result["has_ground"] = true
		if d_mine < closest_d:
			closest_d = d_mine
			result["primary"] = u

	if weight_sum > 0:
		result["center"] /= weight_sum
	return result


# ------------------------------------------------------------------ feitiços

static func spell_total_damage(spell: SpellData) -> float:
	if spell.damage <= 0:
		return 0.0
	if spell.duration > 0:
		return spell.damage * max(1.0, spell.duration / max(spell.tick_interval, 0.05))
	return float(spell.damage)


# feitiço de "ajuda" (cura, fúria) -- deve cair em ALIADO lutando
static func has_ally_buff(spell: SpellData) -> bool:
	return spell.rage_damage_mult > 1.0 or spell.rage_speed_mult > 1.0 or spell.rage_attack_speed_mult > 1.0 \
		or spell.shield_amount > 0 or spell.cleanses


static func is_summon_spell(spell: SpellData) -> bool:
	return spell.summon_scene != null and spell.summon_count > 0


static func is_support_spell(spell: SpellData) -> bool:
	if is_summon_spell(spell):
		return false
	var hurts_enemy = spell.affects_enemies and (spell.damage > 0 or spell.status_effect != UnitData.OnHitEffect.NONE)
	return (spell.affects_allies or has_ally_buff(spell)) and !hurts_enemy


# valor (em "custo de carta") que o feitiço gera se cair em `pos`
static func evaluate_spell_at(tree: SceneTree, spell: SpellData, pos: Vector2, caster_team) -> float:
	var value = 0.0
	var total_dmg = spell_total_damage(spell)
	for body in tree.get_nodes_in_group("damageable"):
		if !("team" in body) or !is_instance_valid(body):
			continue
		if body.global_position.distance_to(pos) > spell.radius:
			continue
		var ally = body.team == caster_team
		var is_base = body.is_in_group("player_base") or body.is_in_group("enemy_base")
		if is_base:
			if !ally and spell.affects_enemies and total_dmg > 0:
				var base_dmg = total_dmg * spell.base_damage_multiplier
				var max_hp = body.max_hp if "max_hp" in body else 1000
				var hp = body.hp if "hp" in body else max_hp
				# vale MUITO se finaliza; senão vale pouco
				value += 500.0 if base_dmg >= hp else base_dmg / 6.0
			continue
		if !is_unit(body):
			continue
		var uv = unit_value(body)
		if ally and (spell.affects_allies or has_ally_buff(spell)):
			var fighting = body.target != null and is_instance_valid(body.target)
			if has_ally_buff(spell):
				value += uv * (0.7 if fighting else 0.15)
			if spell.heal_amount > 0:
				var missing = 1.0 - clamp(float(body.current_hp) / max(body.stats.hp, 1), 0.0, 1.0)
				value += uv * missing * (1.0 if fighting else 0.3)
			elif spell.status_effect != UnitData.OnHitEffect.NONE:
				value += uv * (0.6 if fighting else 0.1)
		elif !ally and spell.affects_enemies:
			if total_dmg > 0:
				var hp_now = max(float(body.current_hp), 1.0)
				var frac = clamp(total_dmg / hp_now, 0.0, 1.0)
				value += uv * (0.25 + 0.75 * frac * frac)  # matar vale muito mais que arranhar
			if spell.status_effect != UnitData.OnHitEffect.NONE:
				value += uv * 0.35
	return value


# melhor ponto pra lançar o feitiço -- testa em cima de cada unidade
# relevante e no centro de cada grupinho
static func best_spell_target(tree: SceneTree, spell: SpellData, caster_team) -> Dictionary:
	var candidates: Array = []
	var want_allies = is_support_spell(spell)
	for u in tree.get_nodes_in_group("units"):
		if !is_instance_valid(u):
			continue
		var ally = u.team == caster_team
		if ally != want_allies:
			continue
		candidates.append(u.global_position)
		# centro do grupinho em volta dessa unidade
		var sum = Vector2.ZERO
		var n = 0
		for o in tree.get_nodes_in_group("units"):
			if is_instance_valid(o) and (o.team == caster_team) == want_allies and o.global_position.distance_to(u.global_position) <= spell.radius:
				sum += o.global_position
				n += 1
		if n > 1:
			candidates.append(sum / n)
	if !want_allies and spell.affects_enemies and spell_total_damage(spell) > 0:
		for eb in get_bases(tree, other_team(caster_team)):
			candidates.append(eb.global_position)

	var best = {"pos": Vector2.INF, "value": 0.0}
	for pos in candidates:
		var v = evaluate_spell_at(tree, spell, pos, caster_team)
		if v > best["value"]:
			best = {"pos": pos, "value": v}
	return best


# ------------------------------------------------------------------ defesa

static func _card_threat_fit(card: CardData, threats: Dictionary) -> bool:
	var primary = threats["primary"]
	if primary == null:
		return true
	var air = primary.stats.unit_type == UnitData.UnitType.AIR
	return DeckBuilder.can_hit_air(card) if air else DeckBuilder.can_hit_ground(card)


# escolhe a melhor resposta à ameaça entre as cartas pagáveis.
# Devolve {card, pos} pra jogar, {"wait": true} pra segurar dinheiro
# esperando a carta certa, ou {} se não tem ameaça
static func choose_defense(tree: SceneTree, my_team, affordable: Array, hand: Array, money: int,
		max_money: int, spawn_area: CollisionShape2D, battle: Node, mistake_chance: float = 0.0) -> Dictionary:
	var threats = analyze_threats(tree, my_team)
	if threats["pressure"] < MIN_THREAT_PRESSURE or threats["primary"] == null:
		return {}
	var serious = threats["pressure"] >= SERIOUS_THREAT_PRESSURE or threats["max_danger"] >= 7
	# erro de timing realista -- só em ameaça pequena, nunca em ataque sério
	if !serious and randf() < mistake_chance:
		return {}

	var primary = threats["primary"]
	var threat_role = primary.card_role if "card_role" in primary else CardData.CardRole.VERSATIL
	var best_card: CardData = null
	var best_score = -INF
	var best_pos = Vector2.INF

	for card in affordable:
		if card == null:
			continue
		var score = 0.0
		var pos = Vector2.INF
		if card.is_spell():
			if card.spell_data == null or is_support_spell(card.spell_data):
				# feitiço de ajuda só se tiver aliado lutando ali
				if card.spell_data != null:
					var sup = best_spell_target(tree, card.spell_data, my_team)
					if sup["value"] >= card.cost * SPELL_VALUE_RATIO:
						score = (sup["value"] - card.cost * 0.5) / 10.0
						pos = sup["pos"]
					else:
						continue
				else:
					continue
			else:
				var v = evaluate_spell_at(tree, card.spell_data, threats["center"], my_team)
				var v2 = evaluate_spell_at(tree, card.spell_data, primary.global_position, my_team)
				pos = threats["center"] if v >= v2 else primary.global_position
				v = max(v, v2)
				if v < card.cost * SPELL_VALUE_RATIO:
					continue
				score = (v * 1.3 - card.cost * 0.4) / 10.0
		else:
			if !_card_threat_fit(card, threats):
				continue
			var stats = DeckBuilder.get_unit_stats(card)
			if stats != null and stats.target_type == UnitData.TargetType.BUILDING:
				continue  # só bate em construção, não defende nada
			score = 2.0
			if CardData.role_beats(card.role, threat_role):
				score += 3.0
			if stats != null and stats.is_aoe and threats["units"].size() >= 3:
				score += 2.5  # dano em área contra enxame
			if stats != null and (stats.forces_aggro or card.role == CardData.CardRole.CONSTRUCAO):
				score += 1.0  # puxa a ameaça pra longe da base
			# custo coerente com o tamanho do ataque: nem mandar a carta
			# mais cara contra 1 enxamezinho, nem mandar 1 elixir contra tanque
			var ideal_cost = clamp(threats["pressure"] * 0.9, 15.0, 80.0)
			score -= abs(card.cost - ideal_cost) * 0.045
			if serious:
				score += DeckBuilder.get_unit_stats(card).hp / 400.0 if stats != null else 0.0
			pos = defensive_position(card, stats, primary, my_team, tree, spawn_area, battle)
		score += randf_range(0.0, 0.6)
		if score > best_score:
			best_score = score
			best_card = card
			best_pos = pos

	if best_card != null:
		return {"card": best_card, "pos": best_pos, "threats": threats}

	# nenhuma resposta boa pagável AGORA -- se alguma carta da MÃO serviria
	# e o dinheiro ainda não está cheio, segura e espera juntar
	if money < max_money - 1:
		for card in hand:
			if card != null and !card.is_spell() and _card_threat_fit(card, threats):
				return {"wait": true, "threats": threats}
	# dinheiro cheio e nada perfeito -- em ataque sério manda o que acertar
	if serious:
		for card in affordable:
			if card != null and !card.is_spell() and _card_threat_fit(card, threats):
				var st = DeckBuilder.get_unit_stats(card)
				return {"card": card, "pos": defensive_position(card, st, primary, my_team, tree, spawn_area, battle), "threats": threats}
	return {}


# posição de defesa: ENTRE a ameaça e a base. Corpo a corpo mais na frente
# (intercepta), à distância mais atrás (protegido), construção no meio
# (puxa a ameaça pro centro)
static func defensive_position(card: CardData, stats: UnitData, threat: Node, my_team, tree: SceneTree,
		spawn_area: CollisionShape2D, battle: Node) -> Vector2:
	var my_base = get_base(tree, my_team, threat.global_position if threat != null else Vector2.INF)
	if my_base == null or threat == null:
		return battle._random_point_in_area(spawn_area)
	var t = 0.3
	if stats != null:
		if stats.unit_type == UnitData.UnitType.BUILDING:
			t = 0.55
		elif stats.is_ranged or stats.attack_range >= 80.0:
			t = 0.65
		elif stats.forces_aggro or card.role == CardData.CardRole.TANQUE:
			t = 0.15
	var raw = threat.global_position.lerp(my_base.global_position, t)
	raw += Vector2(randf_range(-12, 12), randf_range(-8, 8))
	if stats != null and stats.can_spawn_anywhere:
		return raw
	return battle._clamp_to_area(raw, spawn_area)


# ------------------------------------------------------------------ ataque

# antes de jogar um feitiço de forma proativa: só se valer a pena de verdade
static func proactive_spell_target(tree: SceneTree, card: CardData, caster_team) -> Vector2:
	if card == null or card.spell_data == null:
		return Vector2.INF
	var best = best_spell_target(tree, card.spell_data, caster_team)
	if best["value"] >= card.cost * OFFENSIVE_SPELL_VALUE_RATIO:
		return best["pos"]
	return Vector2.INF


# posição de ataque: tanque/pesado mais atrás (junta elixir e vai junto com
# suporte), rápido/barato perto da ponte. `lane_x` mantém o ataque numa
# "rota" escolhida em vez de espalhar cada carta num canto
static func offensive_position(card: CardData, stats: UnitData, my_team, tree: SceneTree,
		spawn_area: CollisionShape2D, battle: Node, lane_x: float) -> Vector2:
	var rect = spawn_area.shape.get_rect()
	var p = battle._random_point_in_area(spawn_area)
	var my_line = base_line(my_team)
	var their_line = base_line(other_team(my_team))
	# fração 0 = colado na base, 1 = linha de frente da área
	var front = 0.85
	if stats != null:
		if card.role == CardData.CardRole.TANQUE or stats.push_weight >= 3.0:
			front = 0.35  # tanque atrás da própria base... vai devagar e junta
		elif stats.is_ranged or card.role == CardData.CardRole.SUPORTE:
			front = 0.55
		elif stats.unit_type == UnitData.UnitType.BUILDING:
			return battle._get_building_placement(spawn_area, -1)
	var global_rect_center = spawn_area.to_global(rect.position + rect.size / 2.0)
	var toward_enemy = (their_line - my_line).normalized()
	var depth = rect.size.y if abs(toward_enemy.y) > abs(toward_enemy.x) else rect.size.x
	var pos = global_rect_center + toward_enemy * (front - 0.5) * depth * 0.9
	pos.x = lerp(pos.x, lane_x, 0.75) + randf_range(-15, 15)
	return battle._clamp_to_area(pos, spawn_area)
