extends RefCounted
class_name DueloPapel
## DUELO NO PAPEL -- estimativa de quem vence um duelo 1 contra 1 entre duas
## cartas, feita só com os NÚMEROS delas (não roda a batalha de verdade).
##
## Pra que serve: o laboratório (ci/lab) mede as cartas oficiais e grava em
## DuelosMedidos. Mas carta de SAFRA nasce sozinha a cada 3 dias, carta pode
## ser criada no Criador e a Assembleia mexe em número -- essas ninguém mediu.
## Pra elas a carta mostra uma "Força estimada" tirada daqui.
##
## É conta aproximada (anda, entra no alcance, troca golpe, conta habilidade
## principal). `ci/lab/papel.tscn` compara com os duelos de verdade e diz o
## quanto ela acerta -- rodar de novo quando mexer nas regras de combate.

const GAP = 190.0          # distância inicial, igual ao duelo do laboratório
const DEPLOY = 1.0         # tempo de entrada em campo
const DT = 0.05
const MAX_T = 45.0
const CONTACT = 34.0       # distância centro a centro de dois corpos encostados
const TOWER_GAP = 430.0    # de onde a carta sai até a torre no teste "sozinha"
const TOWER_T = 75.0


class Grupo:
	var st: UnitData
	var hps: Array = []
	var cd := -1.0           # tempo até o próximo golpe (-1 = ainda não chegou)
	var first := true
	var hits := 0
	var period_k := 1.0
	var ramp := 1.0
	var stun_until := 0.0
	var slow_until := 0.0
	var slow_k := 1.0
	var weak_until := 0.0
	var weak_k := 1.0
	var mark_until := 0.0
	var mark_k := 1.0
	var poison_until := 0.0
	var poison_dps := 0.0
	var revived := false
	var traveled := 0.0
	var dashed := false
	var is_tower := false

	func alive() -> int:
		return hps.size()

	func ranged() -> bool:
		return st.is_ranged


class Lado:
	var groups: Array = []
	var x := 0.0
	var hp0 := 1.0

	func alive() -> bool:
		for g in groups:
			if g.alive() > 0:
				return true
		return false

	func hp() -> float:
		var total := 0.0
		for g in groups:
			for h in g.hps:
				total += h
		return total

	func units() -> int:
		var n := 0
		for g in groups:
			n += g.alive()
		return n


static var _scene_stats_cache := {}


static func _stats_of_scene(scene: PackedScene) -> UnitData:
	if scene == null:
		return null
	var key = scene.get_instance_id()
	if _scene_stats_cache.has(key):
		return _scene_stats_cache[key]
	var node = scene.instantiate()
	var st: UnitData = node.stats if "stats" in node else null
	node.free()
	_scene_stats_cache[key] = st
	return st


static func _group(st: UnitData, count: int) -> Grupo:
	var g = Grupo.new()
	g.st = st
	var each = float(st.hp) + (float(st.shield_amount) if st.has_shield else 0.0)
	for i in maxi(1, count):
		g.hps.append(each)
	return g


## monta o lado de uma carta: a tropa principal + quem vem junto
static func side_of(card: CardData) -> Lado:
	var s = Lado.new()
	var st: UnitData = DeckBuilder.get_unit_stats(card)
	if st == null:
		return s
	s.groups.append(_group(st, st.unit_count))
	for comp in card.companions:
		var cst = _stats_of_scene(comp.get("scene", null))
		if cst != null:
			s.groups.append(_group(cst, int(comp.get("count", 1))))
	s.hp0 = maxf(s.hp(), 1.0)
	return s


static func _can_hit(a: UnitData, target: Grupo) -> bool:
	if a.damage <= 0 and !a.kamikaze:
		return false
	if target.is_tower:
		return true
	if a.target_type == UnitData.TargetType.BUILDING:
		return false
	if target.st.unit_type == UnitData.UnitType.AIR:
		return a.target_type == UnitData.TargetType.ALL or a.target_type == UnitData.TargetType.AIR
	return a.target_type != UnitData.TargetType.AIR


static func _reach(g: Grupo, enemy: Lado) -> float:
	var extra = 26.0 if !enemy.groups.is_empty() and enemy.groups[0].is_tower else 0.0
	if g.is_tower:
		return g.st.attack_range + 12.0   # medido: tropa com alcance 170 leva tiro da torre, com 190 não leva
	var r = (g.st.attack_range + 18.0) if g.st.is_ranged else CONTACT
	r += extra
	# furtiva: só dá pra mirar de perto, até ela atacar
	for eg in enemy.groups:
		if eg.alive() > 0 and eg.st.can_stealth and eg.first:
			r = minf(r, eg.st.stealth_reveal_range + CONTACT)
	return r


static func _target_group(g: Grupo, enemy: Lado) -> Grupo:
	for eg in enemy.groups:
		if eg.alive() > 0 and _can_hit(g.st, eg):
			return eg
	return null


static func _hurt(tg: Grupo, idx: int, amount: float, t: float) -> float:
	if idx >= tg.hps.size():
		return 0.0
	var dealt = amount
	if tg.mark_until > t:
		dealt *= tg.mark_k
	if !tg.is_tower and tg.st.damage_reduction_percent > 0:
		dealt *= 1.0 - tg.st.damage_reduction_percent
	tg.hps[idx] -= dealt
	return dealt


static func _bury(tg: Grupo, attacker: Grupo, t: float):
	var i = 0
	while i < tg.hps.size():
		if tg.hps[i] > 0.0:
			i += 1
			continue
		if !tg.is_tower and tg.st.can_resurrect and !tg.revived:
			tg.revived = true
			tg.hps[i] = tg.st.hp * tg.st.resurrect_hp_percent
			i += 1
			continue
		tg.hps.remove_at(i)
		if attacker != null and attacker.alive() > 0:
			if attacker.st.heals_on_kill:
				attacker.hps[0] = minf(attacker.hps[0] + attacker.st.heal_on_kill_amount, attacker.st.hp)
			# explode ao morrer: pega quem está encostado
			if !tg.is_tower and tg.st.explodes_on_death and !tg.st.kamikaze and !attacker.st.is_ranged:
				for k in mini(attacker.alive(), 3):
					_hurt(attacker, k, tg.st.death_explosion_damage, t)
				_bury(attacker, null, t)


static func _strike(g: Grupo, mine: Lado, enemy: Lado, t: float):
	var tg = _target_group(g, enemy)
	if tg == null or g.alive() == 0:
		return
	var st = g.st
	# kamikaze: cada um explode ao encostar e some
	if st.kamikaze:
		for k in mini(tg.alive(), 4):
			_hurt(tg, k, st.death_explosion_damage, t)
		_bury(tg, null, t)
		g.hps.remove_at(0)
		return
	var dmg = float(st.damage) * g.ramp
	if g.weak_until > t:
		dmg *= g.weak_k
	if st.entrance_rage_duration > 0 and t < DEPLOY + st.entrance_rage_duration:
		dmg *= st.entrance_rage_damage_mult
	if g.first:
		if st.first_attack_bonus:
			dmg *= st.first_attack_multiplier
		if st.charge_attack and g.traveled >= st.charge_distance_needed:
			dmg *= st.charge_damage_multiplier
	if st.low_hp_rage_threshold > 0 and g.hps[0] <= st.hp * st.low_hp_rage_threshold:
		dmg *= st.low_hp_rage_damage_mult
	if st.execute_threshold > 0 and !tg.is_tower and tg.hps[0] <= tg.st.hp * st.execute_threshold:
		dmg *= st.execute_damage_mult
	var many = 1
	if st.is_aoe or st.spin_attack or st.frontal_cone_attack:
		many = mini(tg.alive(), 6)
	elif st.projectile_pierces:
		many = mini(tg.alive(), st.projectile_max_targets)
	elif st.projectile_splits:
		many = mini(tg.alive(), 1 + st.projectile_split_count)
	elif st.projectile_chains:
		many = mini(tg.alive(), st.projectile_chain_max_targets)
	for k in many:
		var dealt = _hurt(tg, k, dmg, t)
		if !tg.is_tower and tg.st.reflects_damage and g.alive() > 0:
			g.hps[0] -= dealt * tg.st.reflect_damage_percent
		if st.lifesteal_percent > 0 and g.alive() > 0:
			g.hps[0] = minf(g.hps[0] + dealt * st.lifesteal_percent, st.hp)
	# efeito do golpe no alvo
	if !tg.is_tower:
		match st.on_hit_effect:
			UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.FREEZE, UnitData.OnHitEffect.CONFUSE:
				tg.stun_until = maxf(tg.stun_until, t + st.on_hit_effect_duration)
			UnitData.OnHitEffect.SLOW:
				tg.slow_until = t + st.on_hit_effect_duration
				tg.slow_k = st.on_hit_effect_strength if st.on_hit_effect_strength <= 1.0 else 0.5
			UnitData.OnHitEffect.WEAKNESS:
				tg.weak_until = t + st.on_hit_effect_duration
				tg.weak_k = st.on_hit_effect_strength if st.on_hit_effect_strength <= 1.0 else 0.5
			UnitData.OnHitEffect.MARK:
				tg.mark_until = t + st.on_hit_effect_duration
				tg.mark_k = maxf(st.on_hit_effect_strength, 1.0)
			UnitData.OnHitEffect.POISON:
				tg.poison_until = t + st.on_hit_effect_duration
				tg.poison_dps = st.on_hit_effect_strength / maxf(st.on_hit_effect_tick_interval, 0.1)
			UnitData.OnHitEffect.KNOCKBACK:
				if !tg.st.immune_to_knockback and !tg.st.is_ranged:
					enemy.x += st.knockback_distance * (1.0 if enemy.x > mine.x else -1.0)
					tg.cd = maxf(tg.cd, 0.25)
			UnitData.OnHitEffect.PULL:
				if !tg.st.immune_to_pull:
					var d = absf(enemy.x - mine.x)
					var pull = minf(st.knockback_distance, maxf(d - CONTACT, 0.0))
					enemy.x -= pull * (1.0 if enemy.x > mine.x else -1.0)
	_bury(tg, g, t)
	if g.alive() > 0 and g.hps[0] <= 0.0:
		_bury(g, null, t)
	g.first = false
	g.hits += 1
	if st.ramping_damage:
		g.ramp = minf(st.ramping_damage_max_multiplier, 1.0 + g.hits * st.ramping_damage_per_hit)
	if st.ramping_attack_speed:
		g.period_k = maxf(st.attack_speed_ramp_min_multiplier, 1.0 - g.hits * st.attack_speed_ramp_per_hit)


static func _step_side(mine: Lado, enemy: Lado, t: float, dir: float):
	var dist = absf(enemy.x - mine.x)
	# veneno e regeneração
	for g in mine.groups:
		if g.alive() == 0:
			continue
		if g.poison_until > t:
			g.hps[0] -= g.poison_dps * DT
			_bury(g, null, t)
		if g.alive() > 0 and !g.is_tower and g.st.passive_regen:
			for i in g.hps.size():
				g.hps[i] = minf(g.hps[i] + g.st.regen_amount / maxf(g.st.regen_interval, 0.1) * DT, g.st.hp)
	if t < DEPLOY:
		return
	# anda enquanto algum grupo que consegue bater ainda não alcança
	var lead: Grupo = null
	var must_walk = false
	for g in mine.groups:
		if g.alive() == 0 or g.is_tower:
			continue
		if lead == null:
			lead = g
		if _target_group(g, enemy) != null and dist > _reach(g, enemy):
			must_walk = true
	if lead != null and must_walk and lead.stun_until <= t:
		var sp = lead.st.move_speed
		if lead.slow_until > t:
			sp *= lead.slow_k
		if lead.st.entrance_rage_duration > 0 and t < DEPLOY + lead.st.entrance_rage_duration:
			sp *= lead.st.entrance_rage_speed_mult
		# bote: salta direto no alvo quando enxerga
		if lead.st.bandit_dash and !lead.dashed and dist <= lead.st.detection_range + 60.0:
			lead.dashed = true
			sp = maxf(dist - CONTACT, 0.0) / DT
		var move = minf(sp * DT, maxf(dist - CONTACT, 0.0))
		mine.x += move * dir
		for g in mine.groups:
			g.traveled += move
		dist = absf(enemy.x - mine.x)
	# golpes
	for g in mine.groups:
		if g.alive() == 0 or g.stun_until > t:
			continue
		var tg = _target_group(g, enemy)
		if tg == null or dist > _reach(g, enemy) + 0.5:
			if !g.is_tower:
				g.cd = -1.0
			continue
		# intocável andando: quem ainda está chegando não leva dano -- aqui,
		# só começa a apanhar depois de engajar (tratado em _immune)
		if g.cd < 0.0:
			g.cd = clampf(g.st.attack_speed * 0.35, 0.2, 0.7) if !g.is_tower else 0.3
		g.cd -= DT
		if g.cd > 0.0:
			continue
		g.cd += maxf(g.st.attack_speed * g.period_k, 0.15)
		var hitters = g.alive()
		if !g.st.is_ranged and !g.is_tower:
			hitters = mini(hitters, 4 + 2 * maxi(enemy.units() - 1, 0))
		for i in hitters:
			if g.alive() == 0 or !enemy.alive():
				break
			if _immune(_target_group(g, enemy), enemy, mine):
				break
			_strike(g, mine, enemy, t)


## intocável andando (assombração): enquanto não começou a bater, não apanha
static func _immune(tg: Grupo, its_side: Lado, other: Lado) -> bool:
	if tg == null or tg.is_tower or !tg.st.immune_while_moving:
		return false
	return tg.cd < 0.0 and tg.first


static func _run(a: Lado, b: Lado, gap: float, max_t: float) -> float:
	a.x = 0.0
	b.x = gap
	var t = 0.0
	var flip = false
	while t < max_t and a.alive() and b.alive():
		if flip:
			_step_side(b, a, t, -1.0)
			if a.alive() and b.alive():
				_step_side(a, b, t, 1.0)
		else:
			_step_side(a, b, t, 1.0)
			if a.alive() and b.alive():
				_step_side(b, a, t, -1.0)
		flip = !flip
		t += DT
	if a.alive() and !b.alive():
		return clampf(a.hp() / a.hp0, 0.02, 1.0)
	if b.alive() and !a.alive():
		return -clampf(b.hp() / b.hp0, 0.02, 1.0)
	return 0.0


## duelo A x B: > 0 = A vence (o número é quanto da vida sobra), < 0 = B vence, 0 = empate
static func duel(a: CardData, b: CardData) -> float:
	var sa = side_of(a)
	var sb = side_of(b)
	if sa.groups.is_empty() or sb.groups.is_empty():
		return 0.0
	return _run(sa, sb, GAP, MAX_T)


## a carta entra em duelo? (feitiço, construção e quem só bate em torre ficam de fora)
static func duels(card: CardData) -> bool:
	if card == null or card.is_spell():
		return false
	var st: UnitData = DeckBuilder.get_unit_stats(card)
	return st != null and st.unit_type != UnitData.UnitType.BUILDING and st.target_type != UnitData.TargetType.BUILDING


## quanto da vida de uma torre a carta tira sozinha, se ninguém defender (0..1)
static func tower_share(card: CardData) -> float:
	var sa = side_of(card)
	if sa.groups.is_empty() or DeckBuilder.get_unit_stats(card).unit_type == UnitData.UnitType.BUILDING:
		return 0.0
	return _tower_share(sa)


static func _tower_share(sa: Lado) -> float:
	var base: BaseData = Catalogo.bases()[0] if !Catalogo.bases().is_empty() else null
	if base == null:
		return 0.0
	var tw = UnitData.new()
	tw.hp = int(Regras.tower_hp(base, 1.0))
	tw.damage = int(Regras.tower_damage(base))
	tw.attack_speed = Regras.tower_interval(base)
	tw.attack_range = Regras.tower_range(base)
	tw.is_ranged = true
	tw.move_speed = 0.0
	tw.target_type = UnitData.TargetType.ALL
	tw.unit_type = UnitData.UnitType.BUILDING
	var sb = Lado.new()
	var g = _group(tw, 1)
	g.is_tower = true
	sb.groups.append(g)
	sb.hp0 = float(tw.hp)
	_run(sa, sb, TOWER_GAP, TOWER_T)
	return clampf(1.0 - sb.hp() / sb.hp0, 0.0, 1.0)


# ---- pro Criador: as mesmas contas em cima de números que ainda não foram salvos
static func side_of_stats(st: UnitData) -> Lado:
	var s = Lado.new()
	if st == null:
		return s
	s.groups.append(_group(st, st.unit_count))
	s.hp0 = maxf(s.hp(), 1.0)
	return s


## duelo dos números `st` contra a carta `b`: > 0 = `st` vence (quanto da vida sobra), < 0 = perde
static func duel_stats(st: UnitData, b: CardData) -> float:
	var sa = side_of_stats(st)
	var sb = side_of(b)
	if sa.groups.is_empty() or sb.groups.is_empty():
		return 0.0
	return _run(sa, sb, GAP, MAX_T)


static func tower_share_stats(st: UnitData) -> float:
	if st == null or st.unit_type == UnitData.UnitType.BUILDING:
		return 0.0
	return _tower_share(side_of_stats(st))


## resumo pra carta que o laboratório não mediu, no mesmo formato do
## DuelosMedidos: {"v", "e", "g", "p", "t", "est": true}
static func estimate(card: CardData) -> Dictionary:
	var out: Dictionary = {"est": true}
	if card == null or card.is_spell():
		return out
	var st: UnitData = DeckBuilder.get_unit_stats(card)
	if st == null:
		return out
	if st.unit_type != UnitData.UnitType.BUILDING:
		out["t"] = int(round(tower_share(card) * 100.0))
	if !duels(card):
		return out
	var wins: Array = []
	var losses: Array = []
	var total := 0
	for c in Catalogo.cards():
		if c == card or !duels(c) or !DuelosMedidos.DATA.has(c.card_name) or !DuelosMedidos.DATA[c.card_name].has("v"):
			continue
		total += 1
		var r = duel(card, c)
		if r > 0.02:
			wins.append(c.card_name)
		elif r < -0.02:
			losses.append(c.card_name)
	if total == 0:
		return out
	var power = func(n: String) -> int: return int(DuelosMedidos.DATA[n].get("v", 0))
	wins.sort_custom(func(x, y): return power.call(x) > power.call(y))
	losses.sort_custom(func(x, y): return power.call(x) < power.call(y))
	out["v"] = int(round(100.0 * wins.size() / total))
	out["e"] = int(round(clampf(DuelosMedidos.LINHA_A + DuelosMedidos.LINHA_B * card.cost, 0.0, 1.0) * 100.0))
	out["g"] = wins.slice(0, 3)
	out["p"] = losses.slice(0, 3)
	return out
