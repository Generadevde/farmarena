extends Node
# LAB: as cartas que o criador automático (Safra) vai soltar saem no preço certo?
# Gera N safras futuras e estima cada tropa no "duelo no papel".
#   LAB_SAFRAS=40 (quantas)   LAB_SAFRA_DE=6930 (a partir de qual período)
func _ready():
	await get_tree().process_frame
	var n = int(OS.get_environment("LAB_SAFRAS")) if OS.get_environment("LAB_SAFRAS") != "" else 40
	var from = int(OS.get_environment("LAB_SAFRA_DE")) if OS.get_environment("LAB_SAFRA_DE") != "" else SafraTempo.current_period() + 1
	var by_role := {}
	var rows: Array = []
	var pool: Array = []
	if OS.get_environment("LAB_ARENAS") != "":
		# cartas de arena (as que o criador fez pra completar 12 por arena)
		var per := {}
		for c in Catalogo.cards():
			per[Catalogo.arena_of(c)] = int(per.get(Catalogo.arena_of(c), 0)) + 1
			if c.has_meta("arena_card"):
				pool.append(c)
		print("SAFRAARENAS cartas por arena: ", per, "  total ", Catalogo.cards().size())
	else:
		for p in range(from, from + n):
			Safra._build_period(p)
			pool.append_array(Safra._by_period.get(p, []))
	for _i in 1:
		for c in pool:
			if c.is_spell():
				continue
			var st: UnitData = DeckBuilder.get_unit_stats(c)
			if st == null:
				continue
			var e = DueloPapel.estimate(c)
			var role = CardData.role_name(c.role)
			if !by_role.has(role):
				by_role[role] = {"n": 0, "dif": 0.0, "t": 0.0, "duel": 0, "kills": 0}
			by_role[role]["n"] += 1
			by_role[role]["t"] += float(e.get("t", 0))
			if e.has("v"):
				by_role[role]["duel"] += 1
				by_role[role]["dif"] += float(e["v"]) - float(e["e"])
			if int(e.get("t", 0)) >= 100 and c.cost < 50:
				by_role[role]["kills"] += 1
			rows.append("SAFRA A%-2d %-26s %-13s %s custo %2d  vida %4d x%d  dano %3d/%.1f  vence %s (normal %s)  torre %s%%  %s" % [Catalogo.arena_of(c), c.card_name.substr(0, 26), role, ["N", "R", "E", "L", "M"][Catalogo.rarity_of(c)], c.cost, st.hp, st.unit_count, st.damage, st.attack_speed,
				str(e.get("v", "-")), str(e.get("e", "-")), str(e.get("t", "-")), c.get_nation_name()])
	if OS.get_environment("LAB_QUIET") == "":
		for r in rows:
			print(r)
	var tot_n := 0
	var tot_d := 0.0
	for role in by_role:
		var b = by_role[role]
		print("SAFRAPAPEL %-13s n=%2d  dif média %+5.1f  torre média %3d%%  derruba torre custando <50: %d" % [role, b["n"], b["dif"] / maxi(b["duel"], 1), int(b["t"] / maxi(b["n"], 1)), b["kills"]])
		tot_n += b["duel"]
		tot_d += b["dif"]
	print("SAFRAGERAL %d tropas de duelo, diferença média pro preço: %+.1f pontos" % [tot_n, tot_d / maxi(tot_n, 1)])
	get_tree().quit()
