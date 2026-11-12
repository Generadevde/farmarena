extends Node

# TESTE AUTOMÁTICO (só GitHub Actions): roda uma partida de verdade sem tela,
# acelerada, com um "jogador" falso soltando cartas, e imprime o que o bot faz.

var battle: Node
var _player_accum := 0.0


func _ready():
	BattleBrain.debug_log = true
	PlayerProfile.create_new_profile("Teste CI")
	PlayerBehaviorProfiler.load_for_active_profile()
	Leaderboard.load_for_active_profile()
	SeasonStats.load_for_active_profile()
	SeasonManager.load_for_active_profile()
	PollManager.load_for_active_profile()
	ArenaManager.load_for_active_profile()
	CustomContent.load_all()

	var mode = OS.get_environment("CI_MODE")
	if mode == "arte":
		_art_sheet()
		get_tree().quit()
		return
	var bot_name = BotSimulator.roster_names[0]
	var prof = BotLearning.get_or_create_profile(bot_name)
	print("TESTE bot=", bot_name, " deck=", prof.deck.map(func(c): return c.card_name + ":" + str(c.cost)))
	print("TESTE base do bot=", prof.equipped_base.resource_path if prof.equipped_base else "nenhuma",
		" textura=", prof.equipped_base.base_texture.resource_path if prof.equipped_base and prof.equipped_base.base_texture else "nenhuma")
	print("TESTE reserva=", prof.min_money_reserve, " intervalo=", prof.decision_interval, " arquétipo=", prof.get_archetype_name())
	MatchSetup.next_ai_profile = prof
	if mode == "2v2":
		MatchSetup.mode = MatchSetup.MODE_2V2
		MatchSetup.ally_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[1])
		MatchSetup.second_enemy_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[2])

	Engine.time_scale = 3.0
	battle = load("res://Scenes/batlhe_scene.tscn").instantiate()
	get_tree().root.add_child.call_deferred(battle)
	if mode == "empurrao":
		await _push_test()
		get_tree().quit()
		return
	if mode == "congelar":
		await _freeze_test()
		get_tree().quit()
		return
	if mode == "torres":
		await _towers_test()
		get_tree().quit()
		return
	if mode == "tornado":
		await _tornado_and_air_test()
		get_tree().quit()
		return
	if mode == "antigas":
		await _legacy_audit()
		get_tree().quit()
		return
	if mode == "habilidades":
		await _abilities_audit()
		get_tree().quit()
		return
	if mode == "simulacao":
		await _simulation_audit()
		get_tree().quit()
		return
	if mode == "efeitos":
		await _effects_audit()
		get_tree().quit()
		return
	if mode == "corpo":
		await _melee_test()
		get_tree().quit()
		return
	await get_tree().create_timer(75.0).timeout  # ~75s de jogo (time_scale acelera)
	_report()
	get_tree().quit()


# vaca (3.8) andando contra uma fileira de galinhas inimigas (0.9) paradas
func _push_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()  # bot não joga nesse teste
	battle.set_process(false)
	var cow_card: CardData = null
	var chick_card: CardData = null
	for c in CardDatabase.all_cards:
		if c == null or c.is_spell():
			continue
		var st = DeckBuilder.get_unit_stats(c)
		if st == null:
			continue
		if c.card_name == "Vaca Brava":
			cow_card = c
		if c.card_name == "Pintaiada":
			chick_card = c
	print("TESTE empurrão: vaca=", cow_card.card_name, " galinha=", chick_card.card_name)
	var eb = get_tree().get_first_node_in_group("enemy_base")
	var pb = get_tree().get_first_node_in_group("player_base")
	var start = pb.global_position.lerp(eb.global_position, 0.3)
	battle.spawn_unit(cow_card.unit_scene, GameManager.Team.PLAYER, start, cow_card)
	await get_tree().process_frame
	var cow = null
	for u in get_tree().get_nodes_in_group("units"):
		if u.team == GameManager.Team.PLAYER:
			cow = u
	cow.stats = cow.stats.duplicate()
	cow.stats.target_type = UnitData.TargetType.BUILDING  # só pra testar o empurrão, sem parar pra brigar
	var wall_center = start.lerp(eb.global_position, 0.15)
	for i in 6:
		var pos = wall_center + Vector2((i - 2.5) * 14.0, 0)
		var before = get_tree().get_nodes_in_group("units").size()
		battle.spawn_unit(chick_card.unit_scene, GameManager.Team.ENEMY, pos, chick_card)
		await get_tree().process_frame
	for u in get_tree().get_nodes_in_group("units"):
		if u.team == GameManager.Team.ENEMY:
			u.apply_incapacitate(60.0)  # galinhas paradas, não atacam
			u.global_position = wall_center + Vector2(randf_range(-40, 40), randf_range(-6, 6))
	var d0 = cow.global_position.distance_to(eb.global_position)
	var wall_d = wall_center.distance_to(eb.global_position)
	print("TESTE vaca a ", int(d0), "px da base inimiga; muro de galinhas a ", int(wall_d), "px")
	await get_tree().create_timer(10.0).timeout
	var d1 = cow.global_position.distance_to(eb.global_position) if is_instance_valid(cow) else -1
	print("RESULTADO empurrão: vaca andou ", int(d0 - d1), "px em ~10s de jogo; passou do muro? ", d1 < wall_d - 20)


# folha com 24 artes geradas (6x4), ampliadas 4x, pra conferir o estilo
func _art_sheet():
	var all: Array = Catalogo.cards() + Catalogo.tokens() + Safra.all_cards()
	for g in 22:
		var gen = CardGenerator.generate_def(7000 + g * 13)
		all.append(Catalogo.build_card(gen["def"], "", gen["stats"], gen["spell"]))
		print("TESTE gerada: ", gen["def"]["nome"], " [", gen["def"]["turma"], "] custo ", gen["def"]["custo"])
	var cols = 8
	var cell = 104
	var rows = int(ceil((all.size() + Catalogo.bases().size()) / float(cols)))
	var sheet = Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5f9648"))
	var i = 0
	for c in all:
		var img: Image = c.icon.get_image()
		img.resize(96, 96, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 96, 96), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
		i += 1
	for b in Catalogo.bases():
		var img2: Image = b.icon.get_image()
		img2.resize(96, 96, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img2, Rect2i(0, 0, 96, 96), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
		i += 1
	sheet.save_png("user://arte_gerada.png")
	print("TESTE arte salva em ", ProjectSettings.globalize_path("user://arte_gerada.png"))
	var p = "res://c2/vaca_brava.tres"
	print("RESULTADO catálogo: cartas=", Catalogo.cards().size(), " fichas=", Catalogo.tokens().size(), " torres=", Catalogo.bases().size(),
		" | exists(virtual)=", ResourceLoader.exists(p), " load igual=", load(p) == Catalogo.card("vaca_brava"),
		" | baralho inicial=", DeckManager.full_deck.map(func(c): return c.card_name))
	# progressão: baú, compra, subir de nível, baralhos
	var before_owned = Progresso.owned_cards().size()
	var loot = Progresso.roll_chest(3)
	PlayerProfile.add_coins(5000)
	var c0: CardData = Catalogo.card("peao_forcado")
	Progresso.give_card(c0, 50)
	var up_ok = Progresso.upgrade(c0)
	var shop_offers = Progresso.shop()["ofertas"].size()
	var deck_ok = Progresso.set_deck_card(1, 0, Catalogo.card("raio"))
	Progresso.add_xp(500)
	for use_n in 12:
		Progresso.record_use(c0)
	print("RESULTADO progresso: baú lendário deu ", loot.size(), " itens | cartas ", before_owned, " -> ", Progresso.owned_cards().size(),
		" | subiu nível? ", up_ok, " (nv ", Progresso.level(c0), ") | ofertas feira=", shop_offers, " | troca no baralho 2? ", deck_ok,
		" | nível jogador=", Progresso.player_level(), " | maestria peão=", Progresso.mastery(c0), " | marcos=", Progresso.road_milestones().size(),
		" | pendentes=", Progresso.d["pending"].size())
	print("RESULTADO safra: períodos=", Safra.periods.size(), " cartas=", Safra.all_cards().map(func(c): return "%s[%s,%d,%s]" % [c.card_name, c.get_nation_name(), c.cost, CardData.role_name(c.role)]),
		" | no banco? ", CardDatabase.all_cards.has(Safra.all_cards()[0]))
	var safra_stats: Array = []
	for sc in Safra.all_cards():
		var sst = DeckBuilder.get_unit_stats(sc)
		if sst != null:
			safra_stats.append("%s custo %d: vida %d x%d, dano %d a cada %.1fs" % [sc.card_name, sc.cost, sst.hp, sst.unit_count, sst.damage, sst.attack_speed])
	print("RESULTADO safra força: ", safra_stats, " | força/custo das oficiais (mediana)=", snapped(CardGenerator.power_per_cost(), 0.1))
	Safra.sync_profile()
	print("RESULTADO safra: amostra entregue? ", Progresso.is_owned(Safra.current_cards()[0]), " | missão=", Safra.mission_text())
	# Criador: gerar + salvar carta nova, e editar uma oficial
	var pack = CardGenerator.generate_card(1, CardData.CardRole.TANQUE, 40)
	var made: CardData = CustomContent.save_card(pack, true)
	var edit = CustomContent.open_card_for_edit(Catalogo.card("peao_forcado"))
	var hp_before = edit["stats"].hp
	edit["stats"].hp = hp_before + 111
	CustomContent.save_card(edit, false)
	print("RESULTADO criador: carta gerada '", made.card_name, "' salva? ", made.resource_path.begins_with("user://"), " no banco? ", CardDatabase.all_cards.has(made),
		" stats ok? ", DeckBuilder.get_unit_stats(made) != null, " | editar oficial: vida ", hp_before, " -> ", Catalogo.unit_stats(Catalogo.card("peao_forcado")).hp,
		" | torneio: entrou? ", Progresso.enter_tournament(), " oponentes=", Progresso.tournament().get("oponentes", []), " regra=", MatchSetup.RULE_NAMES[int(Progresso.tournament().get("regra", 0))])
	SeasonManager.force_new_season()
	var reg = Registro.entries()
	print("RESULTADO registro: temporadas guardadas=", reg.size(), " participantes=", reg[0]["ranking"].size() if reg.size() > 0 else 0, " você=", reg[0]["jogador"] if reg.size() > 0 else {}, " | temporada agora=", SeasonManager.season_number)
	Cla.join(Cla.NAMES[2])
	Cla._d()["prox_bot"] = 0.0
	Cla.tick()
	var req_ok = Cla.request(Catalogo.card("pintaiada"))
	Cla._d()["pedido"]["t"] = Cla._now() - 400.0
	Cla.tick()
	var don = Cla.donate(0) if !Cla.bot_requests().is_empty() else {}
	Progresso.add_chest(2)
	Progresso.grant_power("chave", false)
	var key_msg = Progresso.use_power("chave")
	Progresso.grant_power("relogio3", false)
	print("RESULTADO clã: membros=", Cla.members(Cla.mine()).size(), " pediu? ", req_ok, " recebidas=", Cla.current_request().get("got", 0), " doação=", don,
		" pontos=", Cla.harvest_points(), " clãs=", Cla.ranking().size(), " | poderes: chave->'", key_msg, "' baú pronto? ", Progresso.chest_ready(Progresso.chests().size() - 1),
		" relógio->'", Progresso.use_power("relogio3"), "' mult=", Progresso.clock_boost_mult())
	BotSimulator._load_extra_bots()
	ArenaManager.trophies[PlayerProfile.player_name] = 3300
	var born = BotSimulator.ensure_rivals()
	var near_now = BotSimulator.roster_names.filter(func(n): return abs(ArenaManager.get_trophies(n) - 3300) <= 150)
	var opp = MatchSetup.choose_opponent()
	print("RESULTADO gerador de bots: com 3300 troféus nasceram ", born, " | perto agora=", near_now.size(), " ex: ", near_now.slice(0, 3),
		" | adversário sorteado=", opp.profile_name, " (🏆 ", ArenaManager.get_trophies(opp.profile_name), ", baralho ", opp.deck.size(), " cartas, clã ", Cla.clan_of(opp.profile_name), ")")
	ArenaManager.trophies[PlayerProfile.player_name] = 0
	var by_rarity: Array = [[], [], [], [], []]
	for rc in Catalogo.cards():
		by_rarity[Catalogo.rarity_of(rc)].append(rc.card_name)
	for ri in 5:
		print("RESULTADO raridade ", Catalogo.RARITY_NAMES[ri], " (", by_rarity[ri].size(), "): ", by_rarity[ri])
	# AUDITORIA DO GERADOR (mesmo da Safra): 400 cartas, cada uma conferida
	var problems: Dictionary = {}
	var rar_count = [0, 0, 0, 0, 0]
	var ratios: Array = []
	var kinds = {"unidade": 0, "feitiço": 0, "construção": 0, "voadora": 0}
	CardGenerator.fixed_power = 15.0
	for seed_n in 400:
		var gen = CardGenerator.generate_def(50000 + seed_n * 37)
		var gd: Dictionary = gen["def"]
		var gcard: CardData = Catalogo.build_card(gd, "", gen["stats"], gen["spell"])
		var bad: Array = []
		if str(gd["nome"]).strip_edges().length() < 3:
			bad.append("nome vazio")
		if int(gd["custo"]) < 10 or int(gd["custo"]) > 70 or int(gd["custo"]) % 5 != 0:
			bad.append("custo fora da escala")
		for cat in gd["receita"]:
			if !SpriteForge.has_piece(cat, str(gd["receita"][cat])):
				bad.append("peça de arte inexistente")
		var img: Image = gcard.icon.get_image()
		var solid = 0
		for yy in range(0, 48, 3):
			for xx in range(0, 48, 3):
				if img.get_pixel(xx, yy).a > 0.5:
					solid += 1
		if solid < 20:
			bad.append("arte quase vazia")
		if gen["spell"] != null:
			kinds["feitiço"] += 1
			var gs: SpellData = gen["spell"]
			if gs.damage <= 0 and gs.heal_amount <= 0 and gs.shield_amount <= 0 and gs.rage_damage_mult <= 1.0 and gs.status_effect == UnitData.OnHitEffect.NONE and (gs.summon_scene == null or gs.summon_count <= 0):
				bad.append("feitiço que não faz nada")
			if gs.radius < 30 or gs.radius > 140:
				bad.append("área do feitiço estranha")
		else:
			var gst: UnitData = gen["stats"]
			var is_b = gst.unit_type == UnitData.UnitType.BUILDING
			kinds["construção" if is_b else ("voadora" if gst.unit_type == UnitData.UnitType.AIR else "unidade")] += 1
			if gst.hp <= 0:
				bad.append("sem vida")
			if gst.damage <= 0 and !gst.can_heal_allies and !gst.spawns_units and !gst.generates_resource:
				bad.append("não bate nem ajuda")
			if gst.is_ranged and gst.projectile_texture == null:
				bad.append("atirador sem projétil")
			if gst.is_ranged and gst.detection_range < gst.attack_range:
				bad.append("enxerga menos do que alcança")
			if !gst.is_ranged and gst.attack_range > 30:
				bad.append("corpo a corpo com alcance de tiro")
			if is_b and (gst.move_speed > 0 or gst.duration <= 0):
				bad.append("construção que anda ou não some")
			if !is_b and gst.move_speed <= 0:
				bad.append("tropa que não anda")
			if gst.unit_type == UnitData.UnitType.AIR and !gst.is_ranged and gst.target_type == UnitData.TargetType.GROUND and false:
				bad.append("")
			if gst.attack_speed <= 0.2 and gst.damage > 0:
				bad.append("ataque rápido demais")
			if !is_b:
				var ratio = CardGenerator._raw_power(gst) / max(int(gd["custo"]), 1)
				ratios.append(ratio)
				if (ratio < 6.0 or ratio > 26.0) and str(gd.get("especial", "")) == "":
					bad.append("força fora da faixa (%.0f por custo)" % ratio)
		rar_count[Catalogo.rarity_of(gcard)] += 1
		for b in bad:
			if !problems.has(b):
				problems[b] = []
			problems[b].append("%s[%d]" % [gd["nome"], int(gd["custo"])])
	CardGenerator.fixed_power = 0.0
	ratios.sort()
	print("RESULTADO gerador: 400 cartas -> ", kinds, " | raridades [normal..mística]=", rar_count, " | força/custo min=", snapped(ratios[0], 0.1), " mediana=", snapped(ratios[ratios.size() / 2], 0.1), " max=", snapped(ratios[-1], 0.1), " (oficiais: mediana ", snapped(CardGenerator.power_per_cost(), 0.1), ")")
	var prob_txt: Array = []
	for k in problems:
		prob_txt.append("%s: %d (ex: %s)" % [k, problems[k].size(), ", ".join(problems[k].slice(0, 3))])
	print("RESULTADO gerador problemas: ", prob_txt)
	# AMOSTRA: 50 cartas do gerador, uma por linha
	CardGenerator.fixed_power = 15.0
	for sn in 50:
		var sg = CardGenerator.generate_def(910000 + sn * 101)
		var sd: Dictionary = sg["def"]
		var kind_txt = "feitiço"
		var nums = ""
		if sg["spell"] != null:
			var ssp: SpellData = sg["spell"]
			nums = "dano %d cura %d escudo %d raio %d dura %.0fs" % [ssp.damage, ssp.heal_amount, ssp.shield_amount, int(ssp.radius), ssp.duration]
		else:
			var sst: UnitData = sg["stats"]
			kind_txt = "construção" if sst.unit_type == UnitData.UnitType.BUILDING else ("voador" if sst.unit_type == UnitData.UnitType.AIR else "tropa")
			nums = "vida %d dano %d a cada %.1fs x%d alcance %d vel %d" % [sst.hp, sst.damage, sst.attack_speed, sst.unit_count, int(sst.attack_range), int(sst.move_speed)]
		var sab = (Catalogo.spell_abilities(sg["spell"]) if sg["spell"] != null else Catalogo.unit_abilities(sg["stats"])).map(func(pair): return pair[0])
		print("AMOSTRA %02d | %s | custo %d | %s | %s | %s | arena %d | receita=%s | %s | habilidades=%s" % [sn + 1, sd["nome"], int(sd["custo"]), Catalogo.RARITY_NAMES[CardGenerator.gen_rarity(sg)], kind_txt, str(sd["turma"]), int(sd["arena"]), str(sd.get("especial", "")) if str(sd.get("especial", "")) != "" else "-", nums, str(sab)])
	CardGenerator.fixed_power = 0.0
	var tower_rar = [0, 0, 0, 0, 0]
	var tower_bad: Array = []
	for tn in 300:
		var tdef = CardGenerator.generate_base_def(7000 + tn)
		var tb: BaseData = Catalogo.build_base(tdef)
		tower_rar[Catalogo.base_rarity(tb)] += 1
		if tb.base_hp < 800 or tb.base_hp > 1900 or tb.icon == null or !SpriteForge.has_piece("torre", str(tdef["receita"]["torre"])):
			tower_bad.append(tdef["nome"])
	print("RESULTADO gerador de torres: 300 torres -> raridades [normal..mística]=", tower_rar, " | com problema=", tower_bad.slice(0, 5), " | ex: ", CardGenerator.generate_base_def(7001)["nome"], ", ", CardGenerator.generate_base_def(7002)["nome"])
	var sem_stats: Array = []
	for c in all:
		if !c.is_spell() and DeckBuilder.get_unit_stats(c) == null:
			sem_stats.append(c.card_name)
	print("RESULTADO catálogo: unidades sem stats=", sem_stats)


func _towers_test():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	var mine = get_tree().get_nodes_in_group("player_base")
	var bots = get_tree().get_nodes_in_group("enemy_base")
	var mp = mine.map(func(t): return t.global_position.round())
	var bp = bots.map(func(t): return t.global_position.round())
	var c = ArenaBuilder.CENTER
	var mirror_ok = true
	for p in mp:
		var mirrored = Vector2(p.x, 2 * c.y - p.y)
		if !bp.any(func(q): return q.distance_to(mirrored) < 2.0):
			mirror_ok = false
	print("RESULTADO torres: jogador=", mp, " bot=", bp, " | espelhadas? ", mirror_ok, " | vida cada=", mine.map(func(t): return t.max_hp))
	# caminho de uma tropa do jogador até a torre inimiga da esquerda
	var map_rid = battle.get_world_2d().navigation_map
	var from = ArenaBuilder.tower_positions(GameManager.Team.PLAYER)[0] + Vector2(0, -60)
	var to = ArenaBuilder.tower_positions(GameManager.Team.ENEMY)[0]
	var path = NavigationServer2D.map_get_path(map_rid, from, to, true, 0b01)
	var crosses_bridge = false
	for pt in path:
		if abs(pt.y - c.y) <= ArenaBuilder.RIVER_HALF + 1 and abs(abs(pt.x - c.x) - ArenaBuilder.BRIDGE_X) <= ArenaBuilder.BRIDGE_HALF + 1:
			crosses_bridge = true
	var reaches = !path.is_empty() and path[-1].distance_to(to) < 30.0
	print("RESULTADO caminho: ", path.size(), " pontos, chega na torre? ", reaches, " | passa pela ponte? ", crosses_bridge)
	# tropa no MEIO indo pra torre da esquerda: deve usar a ponte do meio
	var from_mid = Vector2(c.x, c.y + 60)
	var path_mid = NavigationServer2D.map_get_path(map_rid, from_mid, to, true, 0b01)
	var uses_center = Array(path_mid).any(func(pt): return abs(pt.y - c.y) <= ArenaBuilder.RIVER_HALF + 1 and abs(pt.x - c.x) <= ArenaBuilder.CENTER_BRIDGE_HALF + 1)
	print("RESULTADO ponte do meio: tropa no meio usa a ponte central? ", uses_center)
	# derruba uma torre do bot: partida continua; derruba a outra: acaba
	bots[0].take_damage(999999)
	await get_tree().process_frame
	var after_one = battle.match_over
	bots[1].take_damage(999999)
	await get_tree().process_frame
	print("RESULTADO vitória: acabou com 1 torre? ", after_one, " (esperado false) | acabou com 2? ", battle.match_over, " (esperado true)")
	get_tree().paused = false


func _find_card(fn: Callable) -> CardData:
	for c in CardDatabase.all_cards:
		if c != null and !c.is_spell() and fn.call(c):
			return c
	return null


func _tornado_and_air_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	var pb = get_tree().get_first_node_in_group("player_base")
	var eb = get_tree().get_first_node_in_group("enemy_base")
	# --- aérea atrás de tanque
	var tank = _find_card(func(c): return DeckBuilder.get_unit_stats(c).push_weight >= 3.0 and DeckBuilder.get_unit_stats(c).unit_type == UnitData.UnitType.GROUND)
	var air = _find_card(func(c): return DeckBuilder.get_unit_stats(c).unit_type == UnitData.UnitType.AIR)
	if tank != null and air != null:
		var start = pb.global_position.lerp(eb.global_position, 0.25)
		battle.spawn_unit(tank.unit_scene, GameManager.Team.PLAYER, start, tank)
		await get_tree().process_frame
		var t_unit = get_tree().get_nodes_in_group("units")[-1]
		battle.spawn_unit(air.unit_scene, GameManager.Team.PLAYER, start, air)
		await get_tree().process_frame
		var a_unit = get_tree().get_nodes_in_group("units")[-1]
		a_unit.global_position = start + (pb.global_position - eb.global_position).normalized() * 30.0
		t_unit.global_position = start
		await get_tree().create_timer(6.0).timeout
		var a_d = a_unit.global_position.distance_to(eb.global_position)
		var t_d = t_unit.global_position.distance_to(eb.global_position)
		print("RESULTADO aérea x tanque: ", air.card_name, " atrás de ", tank.card_name, " -> aérea passou na frente? ", a_d < t_d, " (aérea ", int(a_d), "px da base, tanque ", int(t_d), "px)")
		for u in get_tree().get_nodes_in_group("units"):
			u.queue_free()
		await get_tree().process_frame
	# --- tornado
	var chick = _find_card(func(c): return c.card_name == "Peão do Forcado")
	var center = pb.global_position.lerp(eb.global_position, 0.5)
	for i in 6:
		battle.spawn_unit(chick.unit_scene, GameManager.Team.ENEMY, center, chick)
		await get_tree().process_frame
	var victims: Array = []
	for u in get_tree().get_nodes_in_group("units"):
		u.apply_incapacitate(30.0)  # paradas, só o tornado mexe
		u.global_position = center + Vector2.RIGHT.rotated(victims.size() * TAU / 6.0) * 90.0
		victims.append(u)
	var sp = SpellData.new()
	sp.radius = 110.0
	sp.duration = 4.0
	sp.tick_interval = 0.25
	sp.status_effect = UnitData.OnHitEffect.PULL
	sp.knockback_distance = 22.0
	sp.affects_enemies = true
	battle.cast_spell(sp, center, GameManager.Team.PLAYER)
	var samples: Array = []
	var max_jump = 0.0
	var last: Array = victims.map(func(v): return v.global_position)
	for k in 16:
		await get_tree().create_timer(0.25).timeout
		var avg = 0.0
		for i in victims.size():
			var v = victims[i]
			avg += v.global_position.distance_to(center)
			max_jump = max(max_jump, v.global_position.distance_to(last[i]))
			last[i] = v.global_position
		samples.append(int(avg / victims.size()))
	print("RESULTADO tornado: distância média do centro ao longo do tempo ", samples, " | maior salto em 0,25s=", int(max_jump), "px")
	for u in get_tree().get_nodes_in_group("units"):
		u.queue_free()
	await get_tree().process_frame
	# --- 360° e cone: 1 atacante cercado por 4 inimigos parados
	for mode_name in ["360", "cone"]:
		battle.spawn_unit(chick.unit_scene, GameManager.Team.PLAYER, center, chick)
		await get_tree().process_frame
		var hero = get_tree().get_nodes_in_group("units")[-1]
		hero.stats = hero.stats.duplicate()
		hero.stats.damage = 10
		hero.stats.attack_speed = 0.5
		hero.stats.spin_attack = mode_name == "360"
		hero.stats.frontal_cone_attack = mode_name == "cone"
		hero.stats.cone_angle_degrees = 100.0
		hero.stats.aoe_radius = 0.0
		hero.global_position = center
		var ring: Array = []
		for i in 4:
			battle.spawn_unit(chick.unit_scene, GameManager.Team.ENEMY, center, chick)
			await get_tree().process_frame
			var e = get_tree().get_nodes_in_group("units")[-1]
			e.stats = e.stats.duplicate()
			e.stats.damage = 0
			e.apply_incapacitate(30.0)
			e.global_position = center + Vector2.RIGHT.rotated(i * TAU / 4.0) * 24.0
			ring.append(e)
		hero.apply_incapacitate(0.0)
		await get_tree().create_timer(3.0).timeout
		var hit = ring.filter(func(e): return !is_instance_valid(e) or e.current_hp < e.stats.hp).size()
		print("RESULTADO ataque ", mode_name, ": acertou ", hit, " de 4 em volta (360 esperado 4, cone esperado 1-2)")
		for u in get_tree().get_nodes_in_group("units"):
			u.queue_free()
		await get_tree().process_frame
	# --- fúria + escudo + purificar
	battle.spawn_unit(chick.unit_scene, GameManager.Team.PLAYER, center, chick)
	await get_tree().process_frame
	var ally = get_tree().get_nodes_in_group("units")[-1]
	ally.apply_on_hit_effect(UnitData.OnHitEffect.SLOW, 0.3, 10.0, 1.0, 0.0, Vector2.ZERO)
	var speed_before = ally._get_move_speed()
	var buff = SpellData.new()
	buff.radius = 60.0
	buff.affects_enemies = false
	buff.rage_damage_mult = 1.4
	buff.rage_speed_mult = 1.35
	buff.rage_attack_speed_mult = 1.35
	buff.shield_amount = 200
	buff.cleanses = true
	battle.cast_spell(buff, ally.global_position, GameManager.Team.PLAYER)
	await get_tree().process_frame
	print("RESULTADO reforço: velocidade lenta=", int(speed_before), " -> depois=", int(ally._get_move_speed()),
		" | dano x", snapped(ally._rage_mult(ally._rage_damage), 0.01), " | escudo=", ally.current_shield)


func _freeze_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()
	print("TESTE nações no Criador: ", CustomContent.all_nations().map(func(n): return n.nation_name if n else "null"))
	var card: CardData = null
	for c in CardDatabase.all_cards:
		if c != null and c.card_name == "Peão do Forcado":
			card = c
	var pb = get_tree().get_first_node_in_group("player_base")
	var eb = get_tree().get_first_node_in_group("enemy_base")
	battle.spawn_unit(card.unit_scene, GameManager.Team.PLAYER, pb.global_position.lerp(eb.global_position, 0.3), card)
	await get_tree().create_timer(1.0).timeout  # passa o atordoamento de nascer
	var u = null
	for x in get_tree().get_nodes_in_group("units"):
		u = x
	var p0 = u.global_position
	u.apply_on_hit_effect(UnitData.OnHitEffect.FREEZE, 0.2, 2.0, 1.0, 0.0, Vector2.ZERO)
	await get_tree().create_timer(1.5).timeout
	var moved_frozen = u.global_position.distance_to(p0)
	var frozen_flag = u._is_incapacitated()
	await get_tree().create_timer(1.0).timeout  # já descongelou (2s)
	var p1 = u.global_position
	u.apply_on_hit_effect(UnitData.OnHitEffect.FREEZE, 0.2, 2.0, 1.0, 0.0, Vector2.ZERO)  # dentro da imunidade
	await get_tree().create_timer(0.5).timeout
	var moved_after = u.global_position.distance_to(p1)
	# feitiço instantâneo de gelo com duração de efeito 4s
	await get_tree().create_timer(1.5).timeout  # sai da imunidade
	if !is_instance_valid(u):
		print("TESTE congelar: a unidade de teste morreu antes da 2ª parte (torre inimiga) -- pulando o resto")
		return
	u.stats = u.stats.duplicate()
	u.stats.hp = 99999
	u.current_hp = 99999
	var sp = SpellData.new()
	sp.damage = 0
	sp.radius = 60.0
	sp.status_effect = UnitData.OnHitEffect.FREEZE
	sp.status_effect_duration = 4.0
	battle.cast_spell(sp, u.global_position, GameManager.Team.ENEMY)
	var p2 = u.global_position
	await get_tree().create_timer(3.5).timeout
	print("RESULTADO feitiço gelo 4s: andou em 3,5s=", snapped(u.global_position.distance_to(p2), 0.1), "px (esperado ~0)")
	# filhote herda o nível: Abelha Rainha nível 5 invoca operária nível 5
	var queen: CardData = null
	for c in CardDatabase.all_cards:
		if c != null and c.card_name == "Galinheiro":
			queen = c
	if queen != null:
		var qs = DeckBuilder.get_unit_stats(queen)
		var parent = queen.unit_scene.instantiate()
		parent.team = GameManager.Team.PLAYER
		parent.card_level = 5
		battle.add_child(parent)
		parent.global_position = pb.global_position + Vector2(0, -60)
		var child = parent._spawn_child(qs.spawn_unit_scene, parent.global_position)
		var base_hp = DeckBuilder.get_unit_stats(queen).spawn_unit_scene.instantiate().stats.hp
		print("RESULTADO filhote: nível=", child.card_level, " vida=", child.stats.hp, " (base ", base_hp, ", esperado x", PlayerProfile.compute_stat_multiplier(5), ")")
	print("RESULTADO congelar: andou congelada=", snapped(moved_frozen, 0.1), "px (esperado ~0) | travada=", frozen_flag,
		" | depois andou ", snapped(moved_after, 0.1), "px (esperado >0, imunidade)")
	# construção de longo alcance: tem que atirar num inimigo parado a ~160 de distância
	for old_u in get_tree().get_nodes_in_group("units"):
		old_u.queue_free()
	await get_tree().process_frame
	var cannon_card: CardData = Catalogo.card("canhao_pipoca")
	var cow_card2: CardData = Catalogo.card("capivara_zen")
	battle.spawn_unit(cannon_card.unit_scene, GameManager.Team.PLAYER, pb.global_position + Vector2(60, -90), cannon_card)
	battle.spawn_unit(cow_card2.unit_scene, GameManager.Team.ENEMY, eb.global_position, cow_card2)
	await get_tree().process_frame
	var cannon = null
	var victim = null
	for uu in get_tree().get_nodes_in_group("units"):
		if uu.team == GameManager.Team.PLAYER:
			cannon = uu
		else:
			victim = uu
	victim.global_position = cannon.global_position + Vector2(0, -165)
	victim.apply_incapacitate(30.0)
	var hp0 = victim.current_hp
	await get_tree().create_timer(5.0).timeout
	print("RESULTADO canhão: alvo a ", int(victim.global_position.distance_to(cannon.global_position)), "px (alcance ", int(cannon.stats.attack_range), ") perdeu ", hp0 - victim.current_hp, " de vida em 5s (esperado > 0)")



# cada unidade corpo a corpo do jogo, sozinha, na frente da base inimiga:
# tem que causar dano em poucos segundos
func _melee_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	var eb = get_tree().get_first_node_in_group("enemy_base")
	var pb = get_tree().get_first_node_in_group("player_base")
	var ok_list: Array = []
	var fail_list: Array = []
	eb.max_hp = 999999  # base "infinita" -- o teste mede dano, não quer acabar a partida
	for c in CardDatabase.all_cards:
		if c == null or c.is_spell():
			continue
		var st = DeckBuilder.get_unit_stats(c)
		if st == null or st.is_ranged or st.unit_type == UnitData.UnitType.BUILDING or st.target_type == UnitData.TargetType.AIR:
			continue
		for u in get_tree().get_nodes_in_group("units"):
			u.queue_free()
		await get_tree().process_frame
		eb.hp = eb.max_hp
		var before = eb.hp
		if battle.match_over:
			print("TESTE partida acabou no meio do teste")
			break
		battle.spawn_unit(c.unit_scene, GameManager.Team.PLAYER, pb.global_position, c)
		await get_tree().process_frame
		for u in get_tree().get_nodes_in_group("units"):
			u.global_position = eb.global_position.lerp(pb.global_position, 0.12) + Vector2(randf_range(-20, 20), 0)
		var watch = false
		if watch:
			for k in 18:
				await get_tree().create_timer(0.5).timeout
				for u in get_tree().get_nodes_in_group("units"):
					if u.team != GameManager.Team.PLAYER:
						continue
					var tgt = "nada"
					if u.target != null and is_instance_valid(u.target):
						tgt = "base" if u._is_base(u.target) else str(u.target.name)
					print("FILME ", c.card_name, " t=", k * 0.5, " pos=", u.global_position.round(), " alvo=", tgt,
						" folga=", (snapped(u._gap_to(u.target), 0.1) if tgt != "nada" else -1.0),
						" atacando=", u._is_actively_attacking, " recarga=", snapped(u.attack_cooldown, 0.01),
						" atordoado=", u._is_incapacitated(), " vel=", u.velocity.round(), " base_hp=", eb.hp)
		else:
			await get_tree().create_timer(9.0).timeout
		var dealt = before - eb.hp
		if dealt > 0:
			ok_list.append("%s(%d)" % [c.card_name, dealt])
		else:
			fail_list.append(c.card_name)
	print("RESULTADO corpo a corpo OK: ", ok_list)
	print("RESULTADO corpo a corpo SEM DANO NA BASE: ", fail_list)


func _process(delta):
	if battle == null or !battle.is_inside_tree() or battle.match_over:
		return
	_player_accum += delta
	if _player_accum < 3.0:
		return
	_player_accum = 0.0
	# "jogador" falso: solta uma carta de unidade aleatória do deck do jogador
	var cards = DeckManager.full_deck.filter(func(c): return c != null and !c.is_spell())
	if cards.is_empty():
		return
	var card = cards[randi() % cards.size()]
	if GameManager.player_money < card.cost:
		return
	GameManager.player_money -= card.cost
	var pos = battle._random_point_in_area(battle.spawn_player_area)
	battle.spawn_unit(card.unit_scene, GameManager.Team.PLAYER, pos, card)
	print("JOGADOR jogou ", card.card_name)


func _report():
	var mine = 0
	var theirs = 0
	for u in get_tree().get_nodes_in_group("units"):
		if u.team == GameManager.Team.PLAYER:
			mine += 1
		else:
			theirs += 1
	var pb = get_tree().get_first_node_in_group("player_base")
	var eb = get_tree().get_first_node_in_group("enemy_base")
	print("RESULTADO unidades jogador=", mine, " bot=", theirs, " $bot=", GameManager.enemy_money,
		" vida base jogador=", pb.hp if pb else -1, " vida base bot=", eb.hp if eb else -1,
		" acoes bot=", battle.match_action_log.filter(func(a): return a["side"] != "player").size())


# AUDITORIA: cada carta com efeito no golpe ataca uma vítima parada e a gente
# confere se o efeito prometido realmente aconteceu
func _effects_audit():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	var pb = get_tree().get_first_node_in_group("player_base")
	var eb = get_tree().get_first_node_in_group("enemy_base")
	for b in get_tree().get_nodes_in_group("enemy_base") + get_tree().get_nodes_in_group("player_base"):
		b.max_hp = 9999999
		b.hp = 9999999
	var spot = pb.global_position.lerp(eb.global_position, 0.5) + Vector2(135, 60)
	var ok: Array = []
	var bad: Array = []
	var victim_card: CardData = Catalogo.card("porco_cozinheiro")
	for c in Catalogo.cards() + Catalogo.tokens():
		var st = DeckBuilder.get_unit_stats(c)
		if st == null or st.on_hit_effect == UnitData.OnHitEffect.NONE or st.damage <= 0:
			continue
		for old_u in get_tree().get_nodes_in_group("units"):
			old_u.queue_free()
		await get_tree().process_frame
		battle.spawn_unit(victim_card.unit_scene, GameManager.Team.ENEMY, eb.global_position, victim_card)
		await get_tree().process_frame
		var victim = get_tree().get_nodes_in_group("units")[0]
		victim.stats = victim.stats.duplicate()
		victim.stats.hp = 99999
		victim.current_hp = 99999
		victim.stats.damage = 0
		victim.stats.move_speed = 0.0
		victim.global_position = spot + Vector2(0, -70 if st.is_ranged else -34)
		battle.spawn_unit(c.unit_scene, GameManager.Team.PLAYER, pb.global_position, c)
		await get_tree().process_frame
		for u in get_tree().get_nodes_in_group("units"):
			if u != victim:
				u.global_position = spot + Vector2(randf_range(-8, 8), 0)
		var start = victim.global_position
		var seen = {"slow": false, "weak": false, "stun": false, "poison": false, "root": false, "confuse": false, "silence": false, "mark": false}
		var max_toward = 0.0
		var max_away = 0.0
		for k in 30:
			await get_tree().create_timer(0.2).timeout
			if !is_instance_valid(victim):
				break
			var now = GameManager.game_time
			seen["slow"] = seen["slow"] or victim.speed_multiplier < 0.99
			seen["weak"] = seen["weak"] or victim.damage_multiplier < 0.99
			seen["stun"] = seen["stun"] or victim._incapacitated_until > now
			seen["poison"] = seen["poison"] or victim._poison_ticks_left > 0
			seen["root"] = seen["root"] or victim._rooted_until > now
			seen["confuse"] = seen["confuse"] or victim._confused_until > now
			seen["silence"] = seen["silence"] or victim._silenced_until > now
			seen["mark"] = seen["mark"] or victim._marked_until > now
			var dy = victim.global_position.y - start.y  # + = veio pra perto do atacante (que está embaixo)
			max_toward = max(max_toward, dy)
			max_away = max(max_away, -dy)
		var worked = false
		match st.on_hit_effect:
			UnitData.OnHitEffect.SLOW: worked = seen["slow"]
			UnitData.OnHitEffect.WEAKNESS: worked = seen["weak"]
			UnitData.OnHitEffect.FREEZE, UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.SHOCK: worked = seen["stun"]
			UnitData.OnHitEffect.POISON: worked = seen["poison"]
			UnitData.OnHitEffect.ROOT: worked = seen["root"]
			UnitData.OnHitEffect.CONFUSE: worked = seen["confuse"]
			UnitData.OnHitEffect.SILENCE: worked = seen["silence"]
			UnitData.OnHitEffect.MARK: worked = seen["mark"]
			UnitData.OnHitEffect.PULL: worked = max_toward > 8.0
			UnitData.OnHitEffect.KNOCKBACK: worked = max_away > 8.0
		var line = "%s[%s%s]" % [c.card_name, CustomContent.EFFECT_NAMES[st.on_hit_effect], " puxou %dpx" % int(max_toward) if st.on_hit_effect == UnitData.OnHitEffect.PULL else (" empurrou %dpx" % int(max_away) if st.on_hit_effect == UnitData.OnHitEffect.KNOCKBACK else "")]
		if worked:
			ok.append(line)
		else:
			bad.append(line)
	print("RESULTADO efeitos OK: ", ok)
	print("RESULTADO efeitos QUE NÃO FUNCIONARAM: ", bad)
	# Criador: criar uma torre nova
	var bpack = CustomContent.make_blank_base()
	bpack["base"].base_name = "Torre de Teste"
	bpack["image"] = SpriteForge.make_image({"torre": "capela"}, {})
	var made_base = CustomContent.save_base(bpack, true)
	print("RESULTADO criador de torres: salva? ", made_base != null and made_base.resource_path.begins_with("user://"), " | na lista? ", BotSimulator.available_bases.has(made_base),
		" | liberada? ", PlayerProfile.is_base_unlocked(made_base), " | torres oficiais=", Catalogo.bases().size())


# ================================================================ AUDITORIA DE HABILIDADES E FEITIÇOS
var _aud_ok: Array = []
var _aud_bad: Array = []


func _check(name: String, passed: bool, detail: String = ""):
	if passed:
		_aud_ok.append(name + ("(" + detail + ")" if detail != "" else ""))
	else:
		_aud_bad.append(name + "(" + detail + ")")


func _wipe():
	for u in get_tree().get_nodes_in_group("units"):
		u.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _put(id: String, team, pos: Vector2) -> Array:
	var before = get_tree().get_nodes_in_group("units")
	var c: CardData = Catalogo.card(id)
	var anchor = get_tree().get_first_node_in_group("player_base" if team == GameManager.Team.PLAYER else "enemy_base")
	battle.spawn_unit(c.unit_scene, team, anchor.global_position, c)
	await get_tree().process_frame
	var out: Array = []
	for u in get_tree().get_nodes_in_group("units"):
		if !before.has(u):
			out.append(u)
	for i in out.size():
		out[i].global_position = pos + Vector2((i - (out.size() - 1) * 0.5) * 16.0, 0)
	return out


func _dummy(team, pos: Vector2, hp: int = 99999):
	var list = await _put("porco_cozinheiro", team, pos)
	var d = list[0]
	d.stats = d.stats.duplicate()
	d.stats.hp = hp
	d.current_hp = hp
	d.stats.damage = 0
	d.stats.move_speed = 0.0
	d.stats.on_hit_effect = UnitData.OnHitEffect.NONE
	return d


func _first_hit(victim, seconds: float) -> float:
	var hp0 = victim.current_hp
	var t = 0.0
	while t < seconds:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if !is_instance_valid(victim):
			return 99999.0
		if victim.current_hp < hp0:
			return hp0 - victim.current_hp
	return 0.0


func _abilities_audit():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	battle.get_node("ProductionTimer").stop()
	var P = GameManager.Team.PLAYER
	var E = GameManager.Team.ENEMY
	var pb = get_tree().get_first_node_in_group("player_base")
	for b in get_tree().get_nodes_in_group("enemy_base") + get_tree().get_nodes_in_group("player_base"):
		b.max_hp = 9999999
		b.hp = 9999999
	var mid = ArenaBuilder.CENTER + Vector2(135, 150)  # no caminho da direita, lado do jogador

	# investida (bezerro corre e bate em dobro)
	await _wipe()
	var d = await _dummy(E, mid + Vector2(0, -60))
	await _put("cavalo_coiceiro", P, mid + Vector2(0, 150))
	var hit = await _first_hit(d, 8.0)
	_check("investida", hit >= 250, "1º golpe %d, normal 150" % int(hit))

	# primeira mordida do jacaré (dobro)
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -40))
	await _put("jacare_acude", P, mid)
	hit = await _first_hit(d, 6.0)
	_check("primeiro golpe em dobro", hit >= 400, "%d, normal 210" % int(hit))

	# furtivo: inimigo não enxerga o Pato Ninja de longe
	await _wipe()
	var pato = (await _put("pato_ninja", P, mid))[0]
	var guard = (await _put("peao_forcado", E, mid + Vector2(0, -110)))[0]
	guard.stats = guard.stats.duplicate()
	guard.stats.move_speed = 0.0
	await get_tree().create_timer(0.3).timeout
	_check("furtivo", !guard._is_valid_enemy(pato), "inimigo a 110px enxerga? %s" % str(guard._is_valid_enemy(pato)))
	# ... de perto enxerga, e depois do primeiro golpe todo mundo enxerga
	pato.global_position = guard.global_position + Vector2(0, 30)
	var near_sees = guard._is_valid_enemy(pato)
	await get_tree().create_timer(4.0).timeout
	var far_guard = (await _put("molecada", E, mid + Vector2(0, -230)))[0]
	var seen_after = is_instance_valid(pato) and far_guard._is_valid_enemy(pato)
	_check("furtivo aparece de perto e depois de atacar", near_sees and (seen_after or !is_instance_valid(pato)), "de perto? %s | de longe depois do golpe? %s" % [str(near_sees), str(seen_after) if is_instance_valid(pato) else "já morreu"])

	# fúria de entrada do Galo Rei
	await _wipe()
	var galo = (await _put("galo_rei", P, mid + Vector2(0, 100)))[0]
	await get_tree().create_timer(1.0).timeout
	_check("fúria ao entrar", galo._get_move_speed() > galo.stats.move_speed * 1.2, "velocidade %d, normal %d" % [int(galo._get_move_speed()), int(galo.stats.move_speed)])

	# roubo de vida (mosquito)
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -30))
	var mosq = (await _put_card(_make({"lifesteal_percent": 0.5, "unit_count": 3, "hp": 200}), P, mid))
	for m in mosq:
		m.current_hp = 5
	await get_tree().create_timer(4.0).timeout
	var healed = mosq.filter(func(m): return is_instance_valid(m) and m.current_hp > 5).size()
	_check("roubo de vida", healed > 0, "%d de %d se curaram" % [healed, mosq.size()])

	# provocar: inimigo prefere a Capivara Zen mesmo com outro alvo mais perto
	await _wipe()
	var capi = (await _put("capivara_zen", P, mid + Vector2(40, 0)))[0]
	var bait = (await _put("peao_forcado", P, mid + Vector2(-20, -20)))[0]
	var foe = (await _put("peao_forcado", E, mid + Vector2(-20, -60)))[0]
	await get_tree().create_timer(1.2).timeout
	_check("provocar", is_instance_valid(foe) and foe.target == capi, "alvo do inimigo: %s" % ("capivara" if foe.target == capi else ("peão isca" if foe.target == bait else "outro")))

	# redução de dano (Tatu 35%) e regeneração (Capivara)
	await _wipe()
	var tatu = (await _put("tatu_bola", P, mid))[0]
	await get_tree().create_timer(0.8).timeout
	var hp0 = tatu.current_hp
	tatu.take_damage(100)
	_check("redução de dano", abs((hp0 - tatu.current_hp) - 65) <= 1, "100 de dano tirou %d" % int(hp0 - tatu.current_hp))
	capi = (await _put("capivara_zen", P, mid + Vector2(60, 60)))[0]
	capi.current_hp = 500
	await get_tree().create_timer(4.0).timeout
	_check("regeneração", capi.current_hp > 500, "500 -> %d em 4s" % int(capi.current_hp))

	# capivaras ligadas dividem o dano
	await _wipe()
	var caps = await _put_card(_make({"unit_count": 4, "is_linked": true, "link_share_percent": 0.3}), P, mid)
	await get_tree().create_timer(0.8).timeout
	caps[0].take_damage(300)
	var shared = caps.slice(1).filter(func(c): return c.current_hp < c.stats.hp).size()
	_check("dano dividido", shared > 0, "%d das outras 3 sentiram" % shared)

	# Sapo Rei vira sapinhos
	await _wipe()
	var rei = (await _put("sapo_rei", P, mid))[0]
	await get_tree().create_timer(0.6).timeout
	rei.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	var frogs = get_tree().get_nodes_in_group("units").filter(func(u): return is_instance_valid(u) and !u.is_queued_for_deletion()).size()
	_check("filhotes ao morrer", frogs == 4, "%d sapinhos" % frogs)

	# abóbora explode
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -50))
	var abo = await _put("aboborinha", P, mid + Vector2(0, 40))
	await get_tree().create_timer(5.0).timeout
	_check("kamikaze explode", 99999 - d.current_hp >= 200 and !is_instance_valid(abo[0]), "tirou %d, abóbora sumiu? %s" % [int(99999 - d.current_hp), str(!is_instance_valid(abo[0]))])

	# milho: tiro se divide
	await _wipe()
	var ds: Array = []
	for off in [Vector2(0, -90), Vector2(-45, -110), Vector2(45, -110)]:
		ds.append(await _dummy(E, mid + off))
	await _put("milho_pipoqueiro", P, mid + Vector2(0, 20))
	await get_tree().create_timer(5.0).timeout
	var hit_n = ds.filter(func(x): return x.current_hp < 99999).size()
	_check("tiro que se divide", hit_n >= 2, "%d de 3 atingidos" % hit_n)

	# cacto: espinho atravessa
	await _wipe()
	ds = []
	for off in [Vector2(0, -70), Vector2(0, -105), Vector2(0, -140)]:
		ds.append(await _dummy(E, mid + off))
	await _put("cacto_pistoleiro", P, mid + Vector2(0, 40))
	await get_tree().create_timer(5.0).timeout
	hit_n = ds.filter(func(x): return x.current_hp < 99999).size()
	_check("tiro que atravessa", hit_n >= 2, "%d de 3 atingidos" % hit_n)

	# ovelha cura aliado
	await _wipe()
	var hurt = (await _put("vaca_brava", P, mid + Vector2(30, 0)))[0]
	hurt.current_hp = 300
	await _put("ovelha_violeira", P, mid)
	await get_tree().create_timer(3.5).timeout
	_check("cura em volta", hurt.current_hp > 300, "300 -> %d" % int(hurt.current_hp))

	# construções que invocam
	await _wipe()
	await _put("galinheiro", P, mid + Vector2(-60, 0))
	await _put("colmeia", P, mid + Vector2(0, 40))
	await _put("fornalha", P, mid + Vector2(60, 0))
	await get_tree().create_timer(10.5).timeout
	var kinds: Dictionary = {}
	for u in get_tree().get_nodes_in_group("units"):
		if u.stats.unit_type != UnitData.UnitType.BUILDING:
			kinds[u.stats.hp] = int(kinds.get(u.stats.hp, 0)) + 1
	_check("construções invocam", kinds.size() >= 3, "tipos de filhote em 10s: %d %s" % [kinds.size(), str(kinds.values())])

	# assombração: intocável andando
	await _wipe()
	var ghosts = await _put("assombracao", P, mid + Vector2(0, 150))
	await get_tree().create_timer(1.5).timeout
	var g = ghosts[0]
	var ghp = g.current_hp
	var moving = g.velocity.length() > 1.0
	g.take_damage(50)
	_check("imune andando", moving and g.current_hp == ghp, "andando? %s vida %d -> %d" % [str(moving), int(ghp), int(g.current_hp)])
	# ... e o contrário: parada atacando, tem que APANHAR (era aqui o defeito: ficava imortal)
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -36))
	ghosts = await _put("assombracao", P, mid)
	await get_tree().create_timer(3.0).timeout
	var stopped = ghosts.filter(func(x): return is_instance_valid(x) and !x._really_moving)
	var hurt_ok = false
	if !stopped.is_empty():
		var hp_b = stopped[0].current_hp
		stopped[0].take_damage(30)
		hurt_ok = stopped[0].current_hp < hp_b
	_check("assombração apanha quando para pra atacar", hurt_ok, "%d de %d paradas atacando; levou dano? %s" % [stopped.size(), ghosts.size(), str(hurt_ok)])
	# e morre de verdade pra uma tropa comum
	await _wipe()
	ghosts = await _put("assombracao", P, mid)
	for n in 2:
		await _put("peao_forcado", E, mid + Vector2(-20 + n * 40, -50))
	await get_tree().create_timer(12.0).timeout
	var alive_ghosts = ghosts.filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion()).size()
	_check("assombração morre em combate", alive_ghosts < 4, "%d de 4 vivas depois de 12s contra 2 peões" % alive_ghosts)

	# robô: onda de choque ao entrar
	await _wipe()
	d = await _dummy(E, mid + Vector2(40, 0))
	var cr: CardData = Catalogo.card("robo_balde")
	var robot = cr.unit_scene.instantiate()
	robot.team = P
	robot.card_data = cr
	robot.position = battle.to_local(mid)
	battle.add_child(robot)
	await get_tree().create_timer(0.3).timeout
	_check("onda de choque ao entrar", 99999 - d.current_hp >= 150, "tirou %d" % int(99999 - d.current_hp))

	# lenhador acelera
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -40))
	var lumber = (await _put("lenhador", P, mid))[0]
	await get_tree().create_timer(9.0).timeout
	_check("ataque acelera", lumber._attack_speed_ramp_multiplier < 0.95, "multiplicador %.2f" % lumber._attack_speed_ramp_multiplier)

	# jegue gera recurso
	await _wipe()
	GameManager.player_money = 0
	await _put("jegue_cargueiro", P, mid)
	await get_tree().create_timer(6.0).timeout
	_check("gera recurso", GameManager.player_money >= 2, "+%d em 6s" % int(GameManager.player_money))

	# tatu devolve dano
	await _wipe()
	tatu = (await _put("tatu_bola", P, mid))[0]
	var hitter = (await _put("peao_forcado", E, mid + Vector2(0, -34)))[0]
	await get_tree().create_timer(4.0).timeout
	_check("devolve dano", is_instance_valid(hitter) and hitter.current_hp < hitter.stats.hp - 90, "atacante perdeu %d (os golpes do tatu dão 45)" % int(hitter.stats.hp - hitter.current_hp) if is_instance_valid(hitter) else "atacante morreu")

	# urubu executa
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -40), 1000)
	d.current_hp = 300
	await _put("urubu", P, mid)
	hit = await _first_hit(d, 6.0)
	_check("executar (dobro em quem está morrendo)", hit >= 160, "%d, normal 85" % int(hit))

	# boi da cara preta levanta
	await _wipe()
	var boi = (await _put("caveira_boi", P, mid))[0]
	await get_tree().create_timer(0.6).timeout
	boi.take_damage(999999)
	await get_tree().process_frame
	_check("ressuscita uma vez", is_instance_valid(boi) and !boi.is_queued_for_deletion() and boi.current_hp > 0, "vida depois: %d" % (int(boi.current_hp) if is_instance_valid(boi) else -1))
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(boi):
		boi.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	_check("na segunda morte, morre", !is_instance_valid(boi) or boi.is_queued_for_deletion(), "ainda em campo? %s" % str(is_instance_valid(boi) and !boi.is_queued_for_deletion()))

	# caramelo: dano sobe no mesmo alvo
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -34))
	await _put_card(_make({"attack_speed": 0.8, "same_target_ramping_damage": true, "same_target_ramping_damage_per_hit": 0.15, "same_target_ramping_damage_max_multiplier": 2.5}), P, mid)
	var first = await _first_hit(d, 5.0)
	await get_tree().create_timer(4.0).timeout
	var last_hp = d.current_hp
	var later = await _first_hit(d, 3.0)
	_check("dano crescente no mesmo alvo", later > first, "1º golpe %d, depois %d" % [int(first), int(later)])

	# cartas com acompanhantes
	var counts: Array = []
	var comp_ok = true
	for pair in [["comitiva", 3], ["vaca_e_cria", 3], ["galo_e_cia", 5], ["dupla_caipira", 2], ["bezerrada", 3], ["pintaiada", 6]]:
		await _wipe()
		var got = (await _put(pair[0], P, mid)).size()
		counts.append("%s=%d" % [pair[0], got])
		if got != pair[1]:
			comp_ok = false
	_check("quantidade de unidades por carta", comp_ok, ", ".join(counts))

	# FEITIÇOS: cada um tem que fazer alguma coisa de verdade
	for c in Catalogo.cards():
		if !c.is_spell():
			continue
		await _wipe()
		var foes: Array = []
		for off in [Vector2(-25, -10), Vector2(25, -10), Vector2(0, 25)]:
			foes.append(await _dummy(E, mid + off))
		var ally = (await _put("vaca_brava", P, mid + Vector2(0, 5)))[0]
		ally.current_hp = 400
		var units_before = get_tree().get_nodes_in_group("units").size()
		var start_pos: Array = foes.map(func(f): return f.global_position)
		battle.cast_spell(c.spell_data, mid, P, c.resource_path)
		var st = {"dano": 0.0, "cura": 0.0, "escudo": 0, "furia": false, "status": false, "moveu": 0.0, "invocou": 0}
		for k in 12:
			await get_tree().create_timer(0.25).timeout
			var now = GameManager.game_time
			for i in foes.size():
				var f = foes[i]
				if !is_instance_valid(f):
					continue
				st["dano"] = max(st["dano"], 99999 - f.current_hp)
				st["status"] = st["status"] or f.speed_multiplier < 0.99 or f._incapacitated_until > now or f._marked_until > now or f._poison_ticks_left > 0
				st["moveu"] = max(st["moveu"], f.global_position.distance_to(start_pos[i]))
			if is_instance_valid(ally):
				st["cura"] = max(st["cura"], ally.current_hp - 400)
				st["escudo"] = max(st["escudo"], ally.current_shield)
				st["furia"] = st["furia"] or ally._get_move_speed() > ally.stats.move_speed * 1.1
			st["invocou"] = max(st["invocou"], get_tree().get_nodes_in_group("units").size() - units_before)
		var sp: SpellData = c.spell_data
		var good = true
		var why: Array = []
		if sp.damage > 0:
			good = good and st["dano"] > 0
			why.append("dano %d" % int(st["dano"]))
		if sp.heal_amount > 0:
			good = good and st["cura"] > 0
			why.append("cura %d" % int(st["cura"]))
		if sp.shield_amount > 0:
			good = good and st["escudo"] > 0
			why.append("escudo %d" % int(st["escudo"]))
		if sp.rage_speed_mult > 1.0:
			good = good and st["furia"]
			why.append("fúria %s" % str(st["furia"]))
		if sp.summon_count > 0:
			good = good and st["invocou"] >= sp.summon_count
			why.append("invocou %d" % st["invocou"])
		if sp.status_effect in [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.FREEZE, UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.MARK, UnitData.OnHitEffect.POISON]:
			good = good and st["status"]
			why.append("efeito %s" % str(st["status"]))
		if sp.status_effect in [UnitData.OnHitEffect.PULL, UnitData.OnHitEffect.KNOCKBACK]:
			good = good and st["moveu"] > 8.0
			why.append("moveu %dpx" % int(st["moveu"]))
		_check("feitiço " + c.card_name, good, ", ".join(why))

	# TORRES: aura, cura
	await _wipe()
	var tower = get_tree().get_nodes_in_group("player_base")[0]
	for base in Catalogo.bases():
		if base.base_type != BaseData.BaseType.AURA and base.base_type != BaseData.BaseType.HEAL and base.base_type != BaseData.BaseType.CANNON:
			continue
		await _wipe()
		tower.install_base_data(base, 1)
		tower.max_hp = 9999999
		tower.hp = 9999999
		var near_foe = await _dummy(E, tower.global_position + Vector2(0, -75))
		var near_ally = (await _put("vaca_brava", P, tower.global_position + Vector2(50, -40)))[0]
		near_ally.current_hp = 400
		var saw = false
		for k in 16:
			await get_tree().create_timer(0.25).timeout
			var now2 = GameManager.game_time
			match base.base_type:
				BaseData.BaseType.AURA:
					saw = saw or near_foe.speed_multiplier < 0.99 or near_foe._poison_ticks_left > 0 or near_foe._incapacitated_until > now2
				BaseData.BaseType.HEAL:
					saw = saw or near_ally.current_hp > 400
				BaseData.BaseType.CANNON:
					saw = saw or near_foe.current_hp < 99999
		_check("torre " + base.base_name, saw)

	await _wipe()
	var e_tower = get_tree().get_nodes_in_group("enemy_base")[0]
	var tower_pos = e_tower.global_position
	for n in 3:
		await _put("cavalo_coiceiro", P, tower_pos + Vector2(0, 160 + n * 20))
	await get_tree().create_timer(8.0).timeout
	_check("torre não sai do lugar com investida", e_tower.global_position.distance_to(tower_pos) < 0.5, "moveu %.1fpx" % e_tower.global_position.distance_to(tower_pos))
	var immortal: Array = []
	for c in Catalogo.cards() + Catalogo.tokens():
		if c.is_spell():
			continue
		await _wipe()
		var squad = await _put(c.resource_path.get_file().get_basename(), P, mid)
		if squad.is_empty():
			continue
		var subject = squad[0]
		var foes2: Array = []
		for n in 3:  # 3 atiradores inimigos que acertam chão e ar
			var shooter = (await _put("molecada", E, mid + Vector2(-40 + n * 40, -95)))[0]
			foes2.append(shooter)
		var full = 0.0
		for x in squad:
			full += x.current_hp
		await get_tree().create_timer(7.0).timeout
		var left = 0.0
		for x in squad:
			if is_instance_valid(x) and !x.is_queued_for_deletion():
				left += x.current_hp
		if left >= full:
			immortal.append(c.card_name)
	_check("nenhuma carta é imortal (7s sob tiro de 9 moleques)", immortal.is_empty(), "sem perder vida: %s" % str(immortal))
	print("RESULTADO habilidades OK (", _aud_ok.size(), "): ", _aud_ok)
	print("RESULTADO habilidades COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)


# ================================================================ SIMULAÇÃO DOS BOTS: sobem troféu? em que ritmo?
func _trophy_summary() -> Array:
	var vals: Array = []
	var seen: Dictionary = {}
	for n in BotSimulator.roster_names:
		if !seen.has(n):
			seen[n] = true
			vals.append(ArenaManager.get_trophies(n))
	vals.sort()
	var total = 0
	for v in vals:
		total += v
	return [vals.size(), int(total / max(vals.size(), 1)), vals[vals.size() / 2], vals[0], vals[-1]]


func _simulation_audit():
	battle.queue_free()
	Engine.time_scale = 1.0
	BotSimulator._load_extra_bots()
	BotSimulator._profile_ready = true
	print("RESULTADO simulação: intervalo=", BotSimulator.SIMULATION_INTERVAL_SECONDS, "s | partidas por rodada=", BotSimulator._get_matches_per_tick(),
		" | fora do jogo vale ", snapped(BotSimulator.OFFLINE_SIMULATION_FACTOR, 0.01), "x, no máximo ", BotSimulator.MAX_CATCHUP_TICKS, " rodadas por volta")
	print("RESULTADO simulação início [bots, média, mediana, menor, maior]: ", _trophy_summary())
	var t0 = Time.get_ticks_msec()
	for round_n in 60:
		await BotSimulator._run_simulation_tick()
		if round_n == 29:
			print("RESULTADO simulação após 30 rodadas (1h de jogo aberto): ", _trophy_summary())
	var ms = Time.get_ticks_msec() - t0
	print("RESULTADO simulação após 60 rodadas (2h de jogo aberto): ", _trophy_summary(), " | tempo por rodada=", ms / 60, "ms")
	var top: Array = BotSimulator.roster_names.duplicate()
	top.sort_custom(func(a, b): return ArenaManager.get_trophies(a) > ArenaManager.get_trophies(b))
	var changes_total = 0
	var changed_bots = 0
	for bn in BotSimulator.roster_names:
		var ch = int(BotLearning._load_raw(str(bn)).get("deck_changes", 0))
		changes_total += ch
		if ch > 0:
			changed_bots += 1
	print("RESULTADO simulação baralhos: ", changed_bots, " de ", BotSimulator.roster_names.size(), " bots experimentaram carta nova; ", changes_total, " trocas no total em 2h")
	print("RESULTADO simulação top 5: ", top.slice(0, 5).map(func(n): return "%s %d" % [n, ArenaManager.get_trophies(n)]),
		" | arenas: ", range(1, 8).map(func(a): return top.filter(func(n): return ArenaManager.get_participant_arena(n) == a).size()))


# ================================================================ HABILIDADES ANTIGAS (do jogo anterior, hoje sem carta oficial)
func _make(fields: Dictionary, extra: Dictionary = {}) -> CardData:
	var u = {"hp": 600, "damage": 60, "attack_speed": 1.0, "move_speed": 55.0}
	for k in fields:
		u[k] = fields[k]
	var def = {"nome": "Teste", "turma": "Peões", "custo": 30, "papel": "VERSATIL", "receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano"}, "paleta": {}, "u": u}
	for k in extra:
		def[k] = extra[k]
	return Catalogo.build_card(def, "res://c2/teste_%d.tres" % randi())


func _put_card(c: CardData, team, pos: Vector2) -> Array:
	var before = get_tree().get_nodes_in_group("units")
	var anchor = get_tree().get_first_node_in_group("player_base" if team == GameManager.Team.PLAYER else "enemy_base")
	battle.spawn_unit(c.unit_scene, team, anchor.global_position, c)
	await get_tree().process_frame
	var out: Array = []
	for u in get_tree().get_nodes_in_group("units"):
		if !before.has(u):
			out.append(u)
	for i in out.size():
		out[i].global_position = pos + Vector2((i - (out.size() - 1) * 0.5) * 16.0, 0)
	return out


func _legacy_audit():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	battle.get_node("ProductionTimer").stop()
	battle.get_node("EnemyProductionTimer").stop()
	var P = GameManager.Team.PLAYER
	var E = GameManager.Team.ENEMY
	for b in get_tree().get_nodes_in_group("enemy_base") + get_tree().get_nodes_in_group("player_base"):
		b.max_hp = 9999999
		b.hp = 9999999
	var mid = ArenaBuilder.CENTER + Vector2(135, 150)
	var d
	var hit: float
	var u

	# escudo fixo
	await _wipe()
	u = (await _put_card(_make({"has_shield": true, "shield_amount": 100}), P, mid))[0]
	await get_tree().create_timer(0.8).timeout
	u.take_damage(60)
	_check("escudo", u.current_hp == u.stats.hp and u.current_shield == 40, "vida %d/%d escudo %d" % [int(u.current_hp), u.stats.hp, u.current_shield])

	# escudo temporário
	await _wipe()
	u = (await _put_card(_make({"has_temp_shield": true, "temp_shield_amount": 80, "temp_shield_duration": 2.0}), P, mid))[0]
	var sh0 = u.current_shield
	await get_tree().create_timer(3.0).timeout
	_check("escudo temporário", sh0 == 80 and u.current_shield == 0, "começou %d, depois de 3s %d" % [sh0, u.current_shield])

	# clone ao morrer
	await _wipe()
	u = (await _put_card(_make({"can_clone": true, "clone_hp_percent": 0.5, "clone_count": 2}), P, mid))[0]
	await get_tree().create_timer(0.6).timeout
	u.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	var clones = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion())
	_check("clone ao morrer", clones.size() == 2 and clones[0].current_hp == 300, "%d clones, vida %s" % [clones.size(), str(clones[0].current_hp) if clones.size() > 0 else "-"])
	for cl in clones:
		cl.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	var after_clones = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion()).size()
	_check("clone não clona de novo", after_clones == 0, "sobraram %d" % after_clones)

	# contra-ataque
	await _wipe()
	u = (await _put_card(_make({"counter_attack_chance": 1.0, "damage": 40, "hp": 5000}), P, mid))[0]
	var foe = (await _put("peao_forcado", E, mid + Vector2(0, -34)))[0]
	foe.stats = foe.stats.duplicate()
	foe.stats.hp = 50000
	foe.current_hp = 50000
	u.stats.attack_speed = 99.0  # só o contra-ataque conta
	await get_tree().create_timer(4.0).timeout
	_check("contra-ataque", 50000 - foe.current_hp >= 80, "atacante perdeu %d" % int(50000 - foe.current_hp))

	# invoca ao atacar
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -34))
	var summoner = _make({"summons_on_attack": true, "attack_summon_chance": 1.0})
	DeckBuilder.get_unit_stats(summoner).attack_summon_scene = Catalogo.card("pintinho").unit_scene
	await _put_card(summoner, P, mid)
	await get_tree().create_timer(4.0).timeout
	var kids = get_tree().get_nodes_in_group("units").filter(func(x): return x.team == P).size() - 1
	_check("invoca ao atacar", kids >= 2, "%d pintinhos em 4s" % kids)

	# recurso ao matar
	await _wipe()
	GameManager.player_money = 0
	await _put_card(_make({"converts_kills_to_gold": true, "gold_per_kill": 7, "damage": 300}), P, mid)
	await _put("pintinho", E, mid + Vector2(0, -34))
	await get_tree().create_timer(3.0).timeout
	_check("recurso ao matar", int(GameManager.player_money) == 7, "ganhou %d" % int(GameManager.player_money))

	# rouba recurso batendo na torre
	await _wipe()
	GameManager.player_money = 0
	GameManager.enemy_money = 50
	var e_tower = get_tree().get_nodes_in_group("enemy_base")[1]
	await _put_card(_make({"steals_resource_on_base_hit": true, "resource_steal_amount": 5}), P, e_tower.global_position + Vector2(0, 70))
	await get_tree().create_timer(4.0).timeout
	_check("rouba recurso da torre", GameManager.player_money >= 5 and GameManager.enemy_money < 50, "eu +%d, inimigo %d" % [int(GameManager.player_money), int(GameManager.enemy_money)])

	# dano maior de longe
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -150))
	await _put_card(_make({"is_ranged": true, "attack_range": 180.0, "distance_damage_bonus_per_100px": 0.5, "move_speed": 0.0, "unit_type": "BUILDING", "duration": 30.0}, {"proj": "pedra"}), P, mid)
	hit = await _first_hit(d, 5.0)
	_check("dano maior de longe", hit >= 85, "%d a ~150px, base 60" % int(hit))

	# tiro em corrente
	await _wipe()
	var ds: Array = []
	for off in [Vector2(0, -90), Vector2(-40, -110), Vector2(40, -110)]:
		ds.append(await _dummy(E, mid + off))
	await _put_card(_make({"is_ranged": true, "attack_range": 140.0, "projectile_chains": true, "projectile_chain_max_targets": 3, "projectile_chain_range": 90.0, "move_speed": 0.0, "unit_type": "BUILDING", "duration": 30.0}, {"proj": "raio"}), P, mid)
	await get_tree().create_timer(4.0).timeout
	var n_hit = ds.filter(func(x): return x.current_hp < 99999).size()
	_check("tiro em corrente", n_hit >= 2, "%d de 3 atingidos" % n_hit)

	# golpe pega um inimigo a mais
	await _wipe()
	ds = [await _dummy(E, mid + Vector2(-14, -34)), await _dummy(E, mid + Vector2(18, -34))]
	await _put_card(_make({"aoe_hits_extra_one": true, "aoe_radius": 50.0}), P, mid)
	await get_tree().create_timer(3.0).timeout
	n_hit = ds.filter(func(x): return x.current_hp < 99999).size()
	_check("golpe pega um a mais", n_hit == 2, "%d de 2 atingidos" % n_hit)

	# invulnerável ao nascer
	await _wipe()
	u = (await _put_card(_make({"spawn_invulnerability_duration": 2.0, "initial_stun_duration": 0.0}), P, mid))[0]
	u.take_damage(200)
	var inv_ok = u.current_hp == u.stats.hp
	await get_tree().create_timer(2.5).timeout
	u.take_damage(200)
	_check("invulnerável ao nascer", inv_ok and u.current_hp == u.stats.hp - 200, "no começo intacta? %s, depois vida %d" % [str(inv_ok), int(u.current_hp)])

	# avanço (dash) ao achar alvo
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -100))
	u = (await _put_card(_make({"bandit_dash": true, "dash_speed_multiplier": 3.0, "dash_duration": 0.5}), P, mid + Vector2(0, 20)))[0]
	var top_speed = 0.0
	for k in 20:
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(u):
			top_speed = max(top_speed, u.velocity.length())
	_check("avanço ao achar alvo", top_speed >= 130, "velocidade máxima %d, normal 55" % int(top_speed))

	# dano extra contra uma categoria
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -34))
	await _put_card(_make({"extra_damage_vs_role": CardData.CardRole.TANQUE, "extra_damage_vs_role_mult": 1.0}), P, mid)
	hit = await _first_hit(d, 4.0)
	_check("dano extra contra tanque", hit >= 115, "%d num tanque, base 60" % int(hit))

	# vira construção depois de um tempo
	await _wipe()
	var transformer = _make({"transforms_into_building": true, "transform_after_seconds": 2.0})
	DeckBuilder.get_unit_stats(transformer).transformed_scene = Catalogo.card("canhao_pipoca").unit_scene
	await _put_card(transformer, P, mid)
	await get_tree().create_timer(3.0).timeout
	var blds = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion() and x.stats.unit_type == UnitData.UnitType.BUILDING).size()
	_check("vira construção", blds == 1, "%d construção em campo" % blds)

	# converte inimigo
	await _wipe()
	foe = (await _put("peao_forcado", E, mid + Vector2(0, -34)))[0]
	foe.stats = foe.stats.duplicate()
	foe.stats.hp = 50000
	foe.current_hp = 50000
	u = (await _put_card(_make({"can_convert_enemy": true, "convert_max_targets": 1, "hp": 5000}), P, mid))[0]
	await get_tree().create_timer(4.0).timeout
	var conv_team = is_instance_valid(foe) and foe.team == P
	var still_fighting = is_instance_valid(foe) and is_instance_valid(u) and (foe.target == u or u.target == foe)
	_check("converte inimigo", conv_team and !still_fighting, "mudou de time? %s | os dois ainda brigam entre si? %s" % [str(conv_team), str(still_fighting)])

	# atravessa o rio
	await _wipe()
	u = (await _put_card(_make({"crosses_water": true, "move_speed": 70.0}), P, ArenaBuilder.CENTER + Vector2(75, 70)))[0]
	var walker = (await _put("peao_forcado", P, ArenaBuilder.CENTER + Vector2(-75, 70)))[0]
	walker.stats = walker.stats.duplicate()
	walker.stats.move_speed = 70.0
	await get_tree().create_timer(2.05).timeout
	_check("atravessa o rio", is_instance_valid(u) and u.global_position.y < ArenaBuilder.CENTER.y - 20 and walker.global_position.y > ArenaBuilder.CENTER.y - 20,
		"com a habilidade y=%d, sem ela y=%d (rio em y=%d)" % [int(u.global_position.y), int(walker.global_position.y), int(ArenaBuilder.CENTER.y)])

	# imune a um efeito
	await _wipe()
	u = (await _put_card(_make({"immune_to_effect": "SLOW"}), P, mid))[0]
	u.apply_on_hit_effect(UnitData.OnHitEffect.SLOW, 0.3, 3.0, 1.0, 0.0, mid)
	_check("imune a lentidão", u.speed_multiplier == 1.0, "multiplicador %.1f" % u.speed_multiplier)

	# guarda mais recurso enquanto vive
	await _wipe()
	var cap0 = battle.player_max_money
	u = (await _put_card(_make({"stores_resource": true, "storage_capacity_bonus": 20}), P, mid))[0]
	var cap1 = battle.player_max_money
	u.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	_check("guarda mais recurso", cap1 == cap0 + 20 and battle.player_max_money == cap0, "limite %d -> %d -> %d depois de morrer" % [cap0, cap1, battle.player_max_money])

	# dá recurso ao inimigo quando morre
	await _wipe()
	GameManager.enemy_money = 0
	u = (await _put_card(_make({"grants_resource_on_death": true, "death_resource_amount": 10}), P, mid))[0]
	await get_tree().create_timer(0.6).timeout
	u.take_damage(999999)
	await get_tree().process_frame
	_check("dá recurso ao morrer", int(GameManager.enemy_money) == 10, "inimigo ganhou %d" % int(GameManager.enemy_money))

	# disfarce
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -34))
	u = (await _put_card(_make({"spawns_disguised": true}), P, mid))[0]
	var disguised0 = u._is_disguised
	await get_tree().create_timer(3.0).timeout
	_check("disfarce", disguised0 and !u._is_disguised, "nasceu disfarçada? %s, revelou ao atacar? %s" % [str(disguised0), str(!u._is_disguised)])

	# ataque contínuo
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -34))
	await _put_card(_make({"continuous_attack": true, "continuous_damage_per_second": 50.0}), P, mid)
	await get_tree().create_timer(4.0).timeout
	_check("ataque contínuo", 99999 - d.current_hp >= 100, "tirou %d em ~3s" % int(99999 - d.current_hp))

	# 90 cartas do gerador entram em campo e lutam um pouco: pega erro de script em combinação de habilidades
	CardGenerator.fixed_power = 15.0
	var fought = 0
	var no_damage: Array = []
	for seed_n in 90:
		var gen = CardGenerator.generate_def(90000 + seed_n * 53, "", 1)
		if gen["stats"] == null:
			continue
		var gcard: CardData = Catalogo.build_card(gen["def"], "res://c2/ger_%d.tres" % seed_n, gen["stats"], gen["spell"])
		await _wipe()
		d = await _dummy(E, mid + Vector2(0, -40 if !gen["stats"].is_ranged else -80))
		await _put_card(gcard, P, mid)
		await get_tree().create_timer(3.2).timeout
		fought += 1
		if gen["stats"].damage > 0 and gen["stats"].target_type != UnitData.TargetType.BUILDING and gen["stats"].target_type != UnitData.TargetType.AIR and is_instance_valid(d) and d.current_hp >= 99999:
			no_damage.append("%s%s" % [gen["def"]["nome"], str(Catalogo.abilities(gcard))])
	CardGenerator.fixed_power = 0.0
	print("RESULTADO gerador em campo: ", fought, " cartas lutaram | sem causar dano em 3s: ", no_damage)
	print("RESULTADO antigas OK (", _aud_ok.size(), "): ", _aud_ok)
	print("RESULTADO antigas COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)
