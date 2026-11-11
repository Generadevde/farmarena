extends RefCounted
class_name DeckDoctor
## DOUTOR DO BARALHO: dá nota pro baralho, diz o que está bom, o que falta e
## quem costuma ganhar dele. Também MONTA uma sugestão de baralho.

const SMALL := 3


static func _stats(c: CardData) -> UnitData:
	return null if c == null or c.is_spell() else DeckBuilder.get_unit_stats(c)


static func hits_air(c: CardData) -> bool:
	if c.is_spell():
		return c.spell_data.damage > 0
	var st = _stats(c)
	return st != null and st.damage > 0 and (st.target_type == UnitData.TargetType.ALL or st.target_type == UnitData.TargetType.AIR)


static func is_area(c: CardData) -> bool:
	if c.is_spell():
		return c.spell_data.damage > 0 and c.spell_data.radius >= 55.0
	var st = _stats(c)
	return st != null and (st.is_aoe or st.kamikaze or st.explodes_on_death)


static func is_wincon(c: CardData) -> bool:
	var st = _stats(c)
	return st != null and st.unit_type != UnitData.UnitType.BUILDING and st.damage > 0 and (st.target_type == UnitData.TargetType.BUILDING or st.hp * st.unit_count >= 1800)


static func is_tank(c: CardData) -> bool:
	var st = _stats(c)
	return st != null and st.unit_type != UnitData.UnitType.BUILDING and st.unit_count == 1 and st.hp >= 1300


static func is_swarm(c: CardData) -> bool:
	var st = _stats(c)
	return st != null and st.unit_count >= SMALL


static func is_air(c: CardData) -> bool:
	var st = _stats(c)
	return st != null and st.unit_type == UnitData.UnitType.AIR


static func is_building(c: CardData) -> bool:
	var st = _stats(c)
	return st != null and st.unit_type == UnitData.UnitType.BUILDING


static func _names(list: Array, limit: int = 3) -> String:
	var out: Array = []
	for c in list.slice(0, limit):
		out.append(c.card_name)
	return ", ".join(out)


## cartas do jogo (até a arena dada) que passam num teste -- pra citar exemplos
static func _examples(test: Callable, arena_cap: int, avoid: Array) -> Array:
	var out: Array = []
	for c in CardDatabase.all_cards:
		if c != null and !CustomContent.is_spawn_only(c) and c.unlock_arena <= arena_cap and !avoid.has(c) and test.call(c):
			out.append(c)
	out.sort_custom(func(a, b): return a.unlock_arena > b.unlock_arena if a.unlock_arena != b.unlock_arena else a.card_name < b.card_name)
	return out


static func _dps(c: CardData) -> float:
	var st = _stats(c)
	if st == null or st.damage <= 0 or st.attack_speed <= 0:
		return 0.0
	return st.damage / st.attack_speed * st.unit_count


static func kills_tank(c: CardData) -> bool:
	var st = _stats(c)
	if st == null:
		return false
	return _dps(c) >= 120.0 or st.same_target_ramping_damage or st.ramping_damage or st.execute_threshold > 0


static func has_control(c: CardData) -> bool:
	var eff = c.spell_data.status_effect if c.is_spell() else (_stats(c).on_hit_effect if _stats(c) != null else UnitData.OnHitEffect.NONE)
	return eff in [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.KNOCKBACK, UnitData.OnHitEffect.PULL, UnitData.OnHitEffect.FREEZE]


## A NOTA é de COBERTURA, não de força bruta: o baralho é medido contra cada
## tipo de ameaça (voador, bando, tanque, corrida na torre), mais o seu
## ataque e o ritmo. Um ponto cego puxa a nota pra baixo mesmo que o resto
## seja ótimo -- pra tirar nota alta tem que aguentar de tudo.
## Devolve {nota, veredito, cor, linhas[[nome, 0-100]], fortes[], fracos[], counters[], custo}
static func analyze(cards: Array) -> Dictionary:
	var deck: Array = cards.filter(func(c): return c != null)
	var fortes: Array = []
	var fracos: Array = []
	var counters: Array = []
	if deck.is_empty():
		return {"nota": 0, "veredito": "Vazio", "cor": Color(0.7, 0.7, 0.7), "linhas": [], "fortes": [], "fracos": ["Não tem carta nenhuma."], "counters": [], "custo": 0.0}
	var cap = ArenaManager.get_player_arena() + 1
	var cost = 0.0
	for c in deck:
		cost += c.cost
	cost /= deck.size()
	var air_units = deck.filter(func(c): return hits_air(c) and !c.is_spell())
	var dmg_spells = deck.filter(func(c): return c.is_spell() and c.spell_data.damage > 0)
	var area_units = deck.filter(func(c): return is_area(c) and !c.is_spell())
	var area_spells = deck.filter(func(c): return is_area(c) and c.is_spell())
	var wincons = deck.filter(func(c): return is_wincon(c))
	var tanks = deck.filter(func(c): return is_tank(c))
	var swarms = deck.filter(func(c): return is_swarm(c))
	var buildings = deck.filter(func(c): return is_building(c))
	var killers = deck.filter(func(c): return kills_tank(c))
	var control = deck.filter(func(c): return has_control(c))
	var cheap_units = deck.filter(func(c): return c.cost <= 25 and !c.is_spell())
	var spells = deck.filter(func(c): return c.is_spell())
	var helpers = deck.filter(func(c): return (c.is_spell() and (c.spell_data.heal_amount > 0 or c.spell_data.rage_damage_mult > 1.0)) or (_stats(c) != null and _stats(c).can_heal_allies))

	var vs_air = minf(100.0, air_units.size() * 40.0 + dmg_spells.size() * 20.0)
	var vs_swarm = minf(100.0, area_units.size() * 45.0 + area_spells.size() * 35.0)
	var vs_tank = minf(100.0, killers.size() * 35.0 + swarms.size() * 20.0 + buildings.size() * 15.0)
	var vs_rush = minf(100.0, buildings.size() * 45.0 + cheap_units.size() * 20.0 + control.size() * 20.0 + tanks.size() * 10.0)
	var attack = minf(100.0, wincons.size() * 45.0 + dmg_spells.size() * 15.0 + (15.0 if !tanks.is_empty() else 0.0) + helpers.size() * 10.0)
	var pace = clampf(100.0 - maxf(0.0, absf(cost - 29.0) - 4.0) * 9.0, 20.0, 100.0)
	if deck.filter(func(c): return c.cost <= 20).is_empty():
		pace -= 15.0
	if spells.size() >= 4:
		pace -= 30.0
	if swarms.size() >= 4:
		pace -= 15.0
	pace = clampf(pace, 0.0, 100.0)
	var lines = [["Contra voador", vs_air], ["Contra bando", vs_swarm], ["Contra tanque", vs_tank], ["Contra corrida na torre", vs_rush], ["Ataque (derrubar torre)", attack], ["Ritmo (custo e giro)", pace]]
	var total = 0.0
	var worst = 100.0
	for l in lines:
		total += l[1]
		worst = minf(worst, l[1])
	var nota = clampi(int(round(0.55 * total / lines.size() + 0.45 * worst)), 0, 100)

	# ---- textos
	if vs_air >= 75.0:
		fortes.append("Segura voador bem (%s)." % _names(air_units, 2))
	elif vs_air <= 45.0:
		fracos.append("Voador passa: %s." % ("nada acerta o ar" if air_units.is_empty() and dmg_spells.is_empty() else "só %s acerta o ar" % _names(air_units + dmg_spells, 2)))
		var airs = _examples(func(c): return is_air(c), cap, deck)
		if !airs.is_empty():
			counters.append("Voadores: %s." % _names(airs))
	if vs_swarm >= 75.0:
		fortes.append("Limpa bando (%s)." % _names(area_units + area_spells, 2))
	elif vs_swarm <= 45.0:
		fracos.append("Pouco dano em área: bando te atropela.")
		var sw = _examples(func(c): return is_swarm(c), cap, deck)
		if !sw.is_empty():
			counters.append("Bandos: %s." % _names(sw))
	if vs_tank >= 75.0:
		fortes.append("Derrete tanque (%s)." % _names(killers + swarms, 2))
	elif vs_tank <= 45.0:
		fracos.append("Falta dano forte num alvo só: tanque chega inteiro na torre.")
		var tk = _examples(func(c): return is_tank(c), cap, deck)
		if !tk.is_empty():
			counters.append("Tanques: %s." % _names(tk))
	if vs_rush >= 75.0:
		fortes.append("Defesa rápida contra quem corre pra torre.")
	elif vs_rush <= 45.0:
		fracos.append("Defesa lenta: sem construção nem tropa barata pra parar uma corrida.")
		var ru = _examples(func(c): return _stats(c) != null and _stats(c).unit_type != UnitData.UnitType.BUILDING and _stats(c).target_type == UnitData.TargetType.BUILDING and _stats(c).move_speed >= 50, cap, deck)
		if !ru.is_empty():
			counters.append("Quem corre direto pra torre: %s." % _names(ru, 2))
	if attack >= 75.0:
		fortes.append("Ataque de verdade: %s." % _names(wincons, 2))
	elif attack <= 45.0:
		fracos.append("Falta quem derrube torre (tanque ou carta que vai direto nela).")
		counters.append("Baralho que só se defende: você não tem como forçar a torre dele.")
	if pace >= 85.0:
		fortes.append("Custo médio equilibrado (%.0f)." % cost)
	elif cost > 36.0:
		fracos.append("Pesado (custo médio %.0f): falta recurso pra reagir." % cost)
		var fast = _examples(func(c): return c.cost <= 20 and !c.is_spell(), cap, deck)
		if !fast.is_empty():
			counters.append("Baralho rápido e barato (%s)." % _names(fast))
	elif cost < 22.0:
		fracos.append("Leve demais (custo médio %.0f): falta peso pra quebrar defesa." % cost)
	if spells.size() >= 4:
		fracos.append("Feitiço demais (%d): falta tropa no campo." % spells.size())
	if swarms.size() >= 4:
		fracos.append("Bando demais (%d): um dano em área leva tudo." % swarms.size())
		var areas = _examples(func(c): return is_area(c), cap, deck)
		if !areas.is_empty():
			counters.append("Dano em área: %s." % _names(areas))
	if counters.is_empty():
		counters.append("Nenhum ponto cego. O perigo é gastar tudo de uma vez e levar o contra-ataque.")

	var verdict = "Fraco"
	var color = Color(1.0, 0.5, 0.45)
	if nota >= 80:
		verdict = "Ótimo"
		color = Color(0.5, 1.0, 0.55)
	elif nota >= 62:
		verdict = "Bom"
		color = Color(0.75, 1.0, 0.5)
	elif nota >= 42:
		verdict = "Regular"
		color = Color(1.0, 0.85, 0.4)
	return {"nota": nota, "veredito": verdict, "cor": color, "linhas": lines, "fortes": fortes, "fracos": fracos, "counters": counters, "custo": cost}


## monta um baralho de 7 com as cartas dadas. Cada chamada dá um diferente.
static func suggest(pool_in: Array, size: int = 7) -> Array:
	var pool: Array = pool_in.filter(func(c): return c != null and !CustomContent.is_spawn_only(c))
	if pool.size() <= size:
		return pool
	pool.shuffle()
	var deck: Array = []
	# um de cada função, na ordem do que mais faz falta
	for test in [func(c): return is_wincon(c), func(c): return hits_air(c) and !c.is_spell(), func(c): return is_area(c), func(c): return c.is_spell() and c.spell_data.damage > 0,
			func(c): return c.cost <= 20 and !c.is_spell(), func(c): return is_tank(c), func(c): return is_building(c)]:
		if deck.size() >= size:
			break
		for c in pool:
			if !deck.has(c) and test.call(c):
				deck.append(c)
				break
	for c in pool:
		if deck.size() >= size:
			break
		if !deck.has(c):
			deck.append(c)
	# lapida: troca carta por carta enquanto a nota subir
	var best = int(analyze(deck)["nota"])
	for attempt in 60:
		var i = randi() % deck.size()
		var cand = pool[randi() % pool.size()]
		if deck.has(cand):
			continue
		var old = deck[i]
		deck[i] = cand
		var n = int(analyze(deck)["nota"])
		if n > best:
			best = n
		else:
			deck[i] = old
	deck.sort_custom(func(a, b): return a.cost < b.cost)
	return deck
