extends Node
# LAB: despeja os números de todas as cartas num JSON (usado por ci/lab/solo.py)
func _ready():
	await get_tree().process_frame
	var out = []
	for c in CardDatabase.all_cards:
		if c == null: continue
		var d = {"nome": c.card_name, "custo": c.cost, "papel": CardData.role_name(c.role), "arena": c.unlock_arena, "rar": Catalogo.rarity_of(c), "turma": c.get_nation_name(), "spell": c.is_spell(), "ficha": Catalogo.tokens().has(c), "safra": !Catalogo.cards().has(c) and !Catalogo.tokens().has(c)}
		if c.is_spell():
			var sp = c.spell_data
			d["dmg"] = sp.damage; d["raio"] = sp.radius; d["dur"] = sp.duration; d["base_mult"] = sp.base_damage_multiplier
		else:
			var st: UnitData = DeckBuilder.get_unit_stats(c)
			if st != null:
				for k in ["hp","damage","attack_speed","move_speed","attack_range","unit_count","is_ranged","unit_type","target_type","is_aoe","aoe_radius","unit_scale","push_weight","detection_range","initial_stun_duration","duration","projectile_speed"]:
					d[k] = st.get(k)
				d["comp"] = c.companions.size()
				d["abil"] = Catalogo.abilities_detail(c).map(func(p): return str(p[0]))
		out.append(d)
	var where = OS.get_environment("LAB_DUMP") if OS.get_environment("LAB_DUMP") != "" else "/tmp/lab/cards.json"
	var f = FileAccess.open(where, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("DUMP ", out.size())
	get_tree().quit()
