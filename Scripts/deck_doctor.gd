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


## devolve {nota, veredito, cor, fortes[], fracos[], counters[], custo}
static func analyze(cards: Array) -> Dictionary:
	var deck: Array = cards.filter(func(c): return c != null)
	var fortes: Array = []
	var fracos: Array = []
	var counters: Array = []
	if deck.is_empty():
		return {"nota": 0, "veredito": "Vazio", "cor": Color(0.7, 0.7, 0.7), "fortes": [], "fracos": ["Não tem carta nenhuma."], "counters": [], "custo": 0.0}
	var cap = ArenaManager.get_player_arena() + 1
	var cost = 0.0
	for c in deck:
		cost += c.cost
	cost /= deck.size()
	var wincons = deck.filter(func(c): return is_wincon(c))
	var anti_air = deck.filter(func(c): return hits_air(c))
	var area = deck.filter(func(c): return is_area(c))
	var spells = deck.filter(func(c): return c.is_spell())
	var tanks = deck.filter(func(c): return is_tank(c))
	var swarms = deck.filter(func(c): return is_swarm(c))
	var cheap = deck.filter(func(c): return c.cost <= 20)
	var buildings = deck.filter(func(c): return is_building(c))
	var nota = 50

	if wincons.is_empty():
		nota -= 15
		fracos.append("Falta uma carta pra derrubar torre (tanque ou quem vai direto na torre).")
		counters.append("Qualquer baralho que só se defende: você não tem como forçar a torre.")
	else:
		nota += 12
		fortes.append("Tem quem derruba torre: %s." % _names(wincons, 2))

	if anti_air.is_empty():
		nota -= 18
		fracos.append("Nada acerta voador.")
		var airs = _examples(func(c): return is_air(c), cap, deck)
		if !airs.is_empty():
			counters.append("Voadores passam livres: %s." % _names(airs))
	elif anti_air.size() == 1:
		fracos.append("Só %s acerta voador. Se ela cair, acabou a defesa aérea." % anti_air[0].card_name)
		var airs2 = _examples(func(c): return is_air(c), cap, deck)
		if !airs2.is_empty():
			counters.append("Dois voadores seguidos (%s)." % _names(airs2, 2))
	else:
		nota += 10
		fortes.append("Boa defesa contra voador (%d cartas)." % anti_air.size())

	if area.is_empty():
		nota -= 12
		fracos.append("Sem dano em área: bando vai te atropelar.")
		var sw = _examples(func(c): return is_swarm(c), cap, deck)
		if !sw.is_empty():
			counters.append("Bandos: %s." % _names(sw))
	else:
		nota += 8
		fortes.append("Tem dano em área: %s." % _names(area, 2))

	if spells.is_empty():
		nota -= 8
		fracos.append("Nenhum feitiço: falta um golpe de emergência.")
	elif spells.size() >= 4:
		nota -= 10
		fracos.append("Feitiço demais (%d): falta tropa pra segurar o campo." % spells.size())
	else:
		nota += 8
		fortes.append("%d feitiço(s) pra resolver aperto." % spells.size())

	if cost > 38.0:
		nota -= 10
		fracos.append("Baralho pesado (custo médio %.0f): você fica sem recurso pra reagir." % cost)
		var fast = _examples(func(c): return c.cost <= 20 and !c.is_spell(), cap, deck)
		if !fast.is_empty():
			counters.append("Baralho rápido e barato (%s) te ataca antes de você juntar recurso." % _names(fast))
	elif cost < 20.0:
		nota -= 5
		fracos.append("Baralho leve demais (custo médio %.0f): falta peso pra quebrar defesa." % cost)
	elif cost >= 24.0 and cost <= 34.0:
		nota += 8
		fortes.append("Custo médio equilibrado (%.0f)." % cost)

	if !tanks.is_empty():
		nota += 6
		fortes.append("Tem tanque pra ir na frente: %s." % _names(tanks, 2))
	else:
		fracos.append("Sem tanque: suas tropas de apoio apanham primeiro.")
	if cheap.is_empty():
		nota -= 4
		fracos.append("Nenhuma carta barata (até 20) pra girar a mão.")
	else:
		nota += 4
	if !buildings.is_empty():
		nota += 3
		fortes.append("Tem construção pra defender: %s." % _names(buildings, 2))
	else:
		var rushers = _examples(func(c): return _stats(c) != null and _stats(c).target_type == UnitData.TargetType.BUILDING, cap, deck)
		if !rushers.is_empty() and tanks.size() < 2:
			counters.append("Quem corre direto pra torre (%s): você não tem construção pra distrair." % _names(rushers, 2))
	if swarms.size() >= 3:
		nota -= 6
		fracos.append("Bando demais (%d cartas): um dano em área leva tudo." % swarms.size())
		var areas = _examples(func(c): return is_area(c), cap, deck)
		if !areas.is_empty():
			counters.append("Dano em área: %s." % _names(areas))
	if counters.is_empty():
		counters.append("Nada grita. O perigo é gastar tudo de uma vez e levar o contra-ataque.")

	nota = clampi(nota, 0, 100)
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
	return {"nota": nota, "veredito": verdict, "cor": color, "fortes": fortes, "fracos": fracos, "counters": counters, "custo": cost}


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
