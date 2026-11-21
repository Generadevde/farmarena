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
	if OS.get_environment("CI_ZEROMOD") != "":
		Config.data["do_zero_mod"] = true   # partida sem nenhum módulo (só a Casa Grande)
	if OS.get_environment("CI_ZERO") != "":
		Config.data["do_zero"] = true   # a partida inteira no modo "começar do zero"
		if OS.get_environment("CI_ZERO") == "1carta":
			# uma carta criada só: o baralho inteiro é ela repetida
			var pk = CustomContent.make_blank_card(false)
			pk["card"].card_name = "Carta Única"
			CustomContent.save_card(pk, true)
		print("TESTE começar do zero: em jogo ", CustomContent.zero_pool().map(func(c): return c.card_name))
	if mode == "arte":
		_art_sheet()
		get_tree().quit()
		return
	if mode == "telas":
		await _screens_test()
		get_tree().quit()
		return
	var bot_name = BotSimulator.roster_names[0]
	var prof = BotLearning.get_or_create_profile(bot_name)
	print("TESTE bot=", bot_name, " deck=", prof.deck.map(func(c): return c.card_name + ":" + str(c.cost)))
	print("TESTE base do bot=", prof.equipped_base.resource_path if prof.equipped_base else "nenhuma",
		" textura=", prof.equipped_base.base_texture.resource_path if prof.equipped_base and prof.equipped_base.base_texture else "nenhuma")
	print("TESTE reserva=", prof.min_money_reserve, " intervalo=", prof.decision_interval, " arquétipo=", prof.get_archetype_name())
	MatchSetup.next_ai_profile = prof
	if OS.get_environment("CI_TESTE") != "":
		MatchSetup.friendly = true   # partida inteira no "modo teste" do Criador: tudo no nível 1
		MatchSetup.teste = true
	if mode == "2v2":
		MatchSetup.mode = MatchSetup.MODE_2V2
		MatchSetup.ally_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[1])
		MatchSetup.second_enemy_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[2])

	# os testes de mecânica (empurrão, congelar, efeitos...) foram montados no
	# campo de 2 torres e medem a tropa, não o campo: o portão no meio só
	# atrapalharia a medida. Torres, simulação e partidas usam o campo de verdade
	if mode in ["empurrao", "congelar", "regras", "tornado", "antigas", "habilidades", "efeitos", "corpo", "torres", "novas"]:
		Regras.forced["portao"] = false
		Regras.forced["modulos"] = false   # mecânica de tropa é medida no campo antigo de 2 torres
	if mode == "torres":
		# o portão e as rotas nascem desligados (ficam no Laboratório): este teste liga os dois
		Regras.forced["portao"] = true
		Regras.forced["rotas"] = true
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
	if mode == "novas":
		await _new_mechanics_test()
		get_tree().quit()
		return
	if mode == "modulos":
		await _modules_test()
		get_tree().quit()
		return
	if mode == "regras":
		await _rules_test()
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
	_fake_player_on = true  # só nas partidas (1v1/2v2): nas auditorias ele gastava o recurso que o teste estava contando
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
	# FILA DE BAÚ (bug achado pelo João em 19/11): baú PRONTO esperando ser
	# pego travava a fila -- tinha que abrir ele antes de botar outro pra contar
	Progresso.d["chests"].clear()
	Progresso.add_chest(0)
	Progresso.add_chest(1)
	var q_start = Progresso.start_chest(0)
	var q_block = Progresso.start_chest(1)          # o 1º ainda está contando: só um por vez
	Progresso.d["chests"][0]["pulado"] = 999999.0   # o 1º ficou pronto, mas NÃO foi aberto
	var q_next = Progresso.start_chest(1)           # tem que deixar botar o 2º pra contar
	print("RESULTADO fila de baú: começa o 1º? ", q_start, " | 2º enquanto o 1º conta? ", q_block, " (esperado false) | 2º com o 1º pronto e fechado? ", q_next,
		" (esperado true) | 1º continua pronto? ", Progresso.chest_ready(0), " | contando agora=", Progresso.unlocking_index(), " (esperado 1)",
		"" if (q_start and !q_block and q_next and Progresso.chest_ready(0) and Progresso.unlocking_index() == 1) else " ❌ FALHOU")
	Progresso.d["chests"].clear()
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


## TELAS: abre o menu de verdade e confere que o conteúdo CABE na tela.
## (Versões 105 a 107: um texto com quebra automática dentro da doca fixa fazia
## ela "medir" milhares de pixels e empurrava a coleção inteira pra fora da tela.)
func _screens_test():
	_aud_bad.clear()
	for id in ["pato_ninja", "espantalho", "sapo_linguarudo"]:
		Progresso.give_card(Catalogo.card(id), 3)
	Progresso.pop_pending()
	var hub = load("res://Scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().create_timer(0.6).timeout
	hub._go_tab(1)
	await get_tree().create_timer(0.6).timeout
	var screen_h = get_viewport().get_visible_rect().size.y
	var first_y = -1.0
	for c in hub._col_views:
		var v = hub._col_views[c]
		if is_instance_valid(v):
			first_y = v.global_position.y if first_y < 0.0 else minf(first_y, v.global_position.y)
	_check("coleção aparece na tela, embaixo do baralho", hub._col_views.size() > 0 and first_y > 0.0 and first_y < screen_h,
		"primeira carta em y=%d, tela=%d, cartas=%d" % [first_y, screen_h, hub._col_views.size()])
	var dock_h = hub._deck_dock.size.y if is_instance_valid(hub._deck_dock) else -1.0
	_check("doca do baralho não passa de metade da tela", dock_h > 0.0 and dock_h < screen_h * 0.5, "%d de %d" % [dock_h, screen_h])
	# ESPAÇOS: perfil novo (nível 1) tem 1 módulo só, e a tela diz quando abre o próximo
	var mods: Array = BotSimulator.available_bases.filter(func(b): return b != null)
	for b in mods:
		b.unlock_arena = 0
	hub._set_cards_view(1)
	await get_tree().create_timer(0.5).timeout
	_check("nível 1 tem 1 espaço de módulo", Progresso.module_loadout().size() == 1 and _find_text(hub, "Espaços de módulo: 1 de 3") and _find_text(hub, "abre no nível 5"),
		"módulos=%d" % Progresso.module_loadout().size())
	Regras.set_tune("slots", 3)
	hub._queue_refresh()
	await get_tree().create_timer(0.5).timeout
	var lo3 = Progresso.module_loadout()
	var pts3 := {}
	for o in lo3:
		pts3[int(o["ponto"])] = true
	_check("com 3 espaços a tela mostra 3 módulos, cada um num ponto", lo3.size() == 3 and pts3.size() == 3 and _find_text(hub, "Casa Grande + 3 módulos"), str(lo3.map(func(o): return [o["base"].base_name, o["ponto"]])))
	hub._use_module(2, mods[0])
	hub._use_module(1, mods[0])
	hub._use_module(0, mods[0])
	await get_tree().create_timer(0.5).timeout
	_check("dá pra pôr três iguais", Progresso.module_loadout().all(func(o): return o["base"] == mods[0]) and _find_text(hub, "EM USO ×3"))
	# MÓDULOS: dá pra pôr dois iguais pela tela, e a lista mostra isso
	Regras.set_tune("slots", 2)
	Progresso.d["modulos"] = []
	Progresso.set_module(0, mods[0], 0)
	Progresso.set_module(1, mods[1], 2)
	hub._set_cards_view(1)
	await get_tree().create_timer(0.5).timeout
	hub._use_module(1, mods[0])
	await get_tree().create_timer(0.5).timeout
	var lo = Progresso.module_loadout()
	_check("tela põe dois módulos iguais", lo.size() == 2 and lo[0]["base"] == mods[0] and lo[1]["base"] == mods[0] and int(lo[0]["ponto"]) != int(lo[1]["ponto"]))
	_check("lista mostra o módulo repetido", _find_text(hub, "EM USO ×2") and _find_text(hub, "Pôr mais um no lugar") == false, "x2=%s" % _find_text(hub, "EM USO ×2"))
	hub._use_module(0, mods[1])
	await get_tree().create_timer(0.5).timeout
	lo = Progresso.module_loadout()
	_check("tela troca só o espaço escolhido", lo.size() == 2 and lo[0]["base"] == mods[1] and lo[1]["base"] == mods[0])
	_check("lista oferece pôr mais um igual", _find_text(hub, "Pôr mais um no lugar"))
	Regras.set_tune("slots", 0, false)
	# TAMANHO pela força: tropa fraca pequena, tropa forte grande -- em TODAS as cartas de tropa
	var weak_max = 0.0
	var strong_min = 99.0
	var weak_name = ""
	var strong_name = ""
	for c in CardDatabase.all_cards:
		if c == null or c.is_spell() or c.has_meta("custom"):
			continue
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st == null or st.unit_type == UnitData.UnitType.BUILDING:
			continue
		if st.hp + 0.8 * st.damage < 250.0 and st.unit_scale > weak_max:
			weak_max = st.unit_scale
			weak_name = c.card_name
		if st.hp >= 1800.0 and st.unit_scale < strong_min:
			strong_min = st.unit_scale
			strong_name = c.card_name
	_check("nenhuma tropa fraca é maior que uma tropa forte", weak_max < strong_min and weak_max <= 0.9 and strong_min >= 1.05,
		"fraca maior: %s %.2f | forte menor: %s %.2f" % [weak_name, weak_max, strong_name, strong_min])
	var sizes = ["abelhas", "pintaiada", "galinha_atiradeira", "molecada", "peao_forcado", "vaca_brava", "robo_balde"].map(func(id): return DeckBuilder.get_unit_stats(Catalogo.card(id)).unit_scale)
	var growing = true
	for i in range(1, sizes.size()):
		growing = growing and sizes[i] > sizes[i - 1]
	_check("abelha < pintinho < galinha < moleque < peão < vaca < robô", growing, str(sizes))
	# BARALHO de 8 (4 na mão), oportunidade do dia e detalhes da carta
	_check("baralho tem 8 cartas", Progresso.DECK_SIZE == 8 and Progresso.deck_cards(Progresso.active_deck()).size() == 8 and Catalogo.starter_deck().size() == 8,
		"%d" % Progresso.deck_cards(Progresso.active_deck()).size())
	PlayerProfile.add_coins(1000)
	var op = Progresso.opportunity()
	var coins0 = PlayerProfile.coins
	var got = Progresso.take_opportunity()
	_check("oportunidade do dia fecha uma vez só e cobra o preço", !got.is_empty() and Progresso.opportunity()["feito"] and Progresso.take_opportunity().is_empty()
		and PlayerProfile.coins <= coins0 - int(op["preco"]) + 250, "%s: %s" % [op["id"], str(got.get("texto", ""))])
	var feat: CardData = Progresso.featured_card()
	var botp = BotLearning.get_or_create_profile(BotSimulator.roster_names[0])
	_check("carta da vez: liberada pra todos no nível da torre", feat != null and Progresso.is_owned(feat) and Progresso.level(feat) == Progresso.tower_level()
		and botp.get_card_level(feat) == Progresso.tower_level() and Progresso.featured_days_left() >= 1 and Progresso.featured_days_left() <= 3,
		"%s" % (feat.card_name if feat != null else "nenhuma"))
	# a carta da vez DENTRO do baralho não pode dar volta sem fim com o nível da torre (fechava o jogo)
	var deck_ok = Progresso.set_deck_card(Progresso.active_deck(), 0, feat) or Progresso.deck_cards(Progresso.active_deck()).has(feat)
	var tl = Progresso.tower_level()
	_check("carta da vez no baralho não trava o nível da torre", deck_ok and tl >= 1 and Progresso.level(feat) == tl)
	hub._go_tab(0)
	await get_tree().create_timer(0.4).timeout
	_check("feira mostra a oportunidade de hoje e a carta da vez", _find_text(hub, "Oportunidade de hoje") and _find_text(hub, "Carta da vez"))
	hub._show_card_popup(Catalogo.card("vaca_brava"))
	await get_tree().create_timer(0.3).timeout
	_check("carta: detalhes ficam atrás de um botão", _find_text(hub, "Mais detalhes"))
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	# CRIADOR novo: abre uma carta do jogo, mexe, salva (fica guardado à parte) e restaura
	hub.queue_free()
	await get_tree().process_frame
	var cr = load("res://creator/creator_menu.tscn").instantiate()
	add_child(cr)
	await get_tree().create_timer(0.4).timeout
	var peao: CardData = Catalogo.card("peao_forcado")
	var hp_before = DeckBuilder.get_unit_stats(peao).hp
	cr._open_card_form(CustomContent.open_card_for_edit(peao))
	var tabs_ok = true
	for i in 5:
		cr._show_ed_tab(i)
		await get_tree().process_frame
		tabs_ok = tabs_ok and cr._field_box.get_child_count() > 0
	_check("criador: as 5 abas da tropa montam, com o cabeçalho fixo", tabs_ok and cr._head.visible)
	cr._work["stats"].hp = hp_before + 500
	cr._toggle_ability(cr.ABILITIES[2][1][0], true)   # Escudo
	await get_tree().create_timer(0.3).timeout
	_check("criador: ligar habilidade já põe um valor inicial", cr._work["stats"].has_shield and cr._work["stats"].shield_amount > 0)
	cr._save_card()
	await get_tree().process_frame
	var st2: UnitData = DeckBuilder.get_unit_stats(peao)
	_check("criador: salvar muda a carta do jogo e guarda à parte", st2.hp == hp_before + 500 and st2.has_shield and CustomContent.has_override(peao), "vida %d" % st2.hp)
	# carta de duas tropas: o Peão passa a vir com 2 pintinhos, e volta ao normal
	cr._open_card_form(CustomContent.open_card_for_edit(peao))
	cr._work["card"].companion_id = "pintaiada"
	cr._work["card"].companion_count = 2
	cr._save_card()
	await get_tree().process_frame
	_check("criador: carta com outra tropa junto", peao.companions.size() == 1 and int(peao.companions[0]["count"]) == 2 and peao.companions[0]["scene"] == Catalogo.card("pintaiada").unit_scene)
	CustomContent.restore_original_card(peao)
	Catalogo.apply_companion(peao)
	_check("criador: restaurar tira a tropa que vinha junto", peao.companions.is_empty() and peao.companion_id == "", peao.companion_id)
	var st3: UnitData = DeckBuilder.get_unit_stats(peao)
	_check("criador: restaurar volta ao original", st3.hp == hp_before and !st3.has_shield, "vida %d (era %d)" % [st3.hp, hp_before])
	cr._open_card_form(CustomContent.make_blank_card(false))
	cr._work["card"].cost = 40
	cr._fill_kind = Regua.KIND_ORDER.find("bando")
	cr._apply_standard()
	var cmp = Regua.compare(cr._work["stats"], 40)
	_check("criador: preencher pelo padrão dá carta do tipo pedido, perto de 100%", cmp["kind"] == "bando" and abs(int(cmp["vida"]) - 100) <= 20 and abs(int(cmp["dano"]) - 100) <= 25, str(cmp))
	_check("criador: carta nova já nasce com desenho", !cr._work["image"].is_invisible())
	# peças novas e filtro por tema
	cr._theme = "Guerra"
	cr._parts_open = true
	cr._recipe = {"objeto": "tanque"}
	cr._regen_art()
	cr._show_ed_tab(3)
	await get_tree().process_frame
	_check("criador: peças novas e temas", SpriteForge.has_piece("objeto", "tanque") and SpriteForge.has_piece("torre", "farol") and SpriteForge.has_piece("arma", "katana")
		and cr._piece_in_theme("tanque") and !cr._piece_in_theme("vaca") and PecasIndex.TEMAS.size() >= 7 and !cr._work["image"].is_invisible())
	var before_r = cr._recipe.duplicate()
	cr._shuffle_pieces()
	_check("criador: sortear troca só as peças em uso, dentro do tema", cr._recipe.keys() == before_r.keys() and cr._recipe["objeto"] != "tanque" and cr._piece_in_theme(str(cr._recipe["objeto"])), str(cr._recipe))
	cr._theme = "Todos os temas"
	cr._close_form()
	# feitiço: 4 abas, com régua e teste
	cr._open_card_form(CustomContent.open_card_for_edit(Catalogo.card("raio")))
	var sp_ok = cr._ed_kind == "feitico" and cr._h_bars.size() == 3
	for i in 4:
		cr._show_ed_tab(i)
		await get_tree().process_frame
		sp_ok = sp_ok and cr._field_box.get_child_count() > 0
	var scmp = Regua.spell_compare(Catalogo.card("raio").spell_data, Catalogo.card("raio").cost)
	_check("criador: feitiço tem as 4 abas, régua e teste", sp_ok and int(scmp["dano"]) > 0 and int(scmp["raio"]) > 0, str(scmp))
	cr._close_form()
	cr._set_tab(1)
	cr._open_base_form(CustomContent.open_base_for_edit(mods[0]))
	var mod_ok = cr._head.visible
	for i in 3:
		cr._show_ed_tab(i)
		await get_tree().process_frame
		mod_ok = mod_ok and cr._field_box.get_child_count() > 0
	_check("criador: editor de módulo monta as 3 abas", mod_ok)
	cr._close_form()
	_check("criador: fechar esconde o cabeçalho", !cr._head.visible)
	print("RESULTADO telas: coleção em y=", int(first_y), " doca=", int(dock_h), " tela=", int(screen_h))
	print("RESULTADO telas COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)


## tem algum texto (rótulo ou botão) com esse pedaço debaixo de `node`?
func _find_text(node: Node, piece: String) -> bool:
	if (node is Label or node is Button) and str(node.text).contains(piece):
		return true
	for ch in node.get_children():
		if _find_text(ch, piece):
			return true
	return false


## MÓDULOS: base principal + 6 pontos + 2 módulos por lado
func _modules_test():
	_aud_bad.clear()
	var forte: BaseData = null
	var moinho: BaseData = null
	var guarita: BaseData = null
	var estabulo: BaseData = null
	for b in BotSimulator.available_bases:
		if b == null:
			continue
		if b.resource_path.ends_with("torre_moinho.tres"):
			moinho = b
		elif b.resource_path.ends_with("torre_guarita.tres"):
			guarita = b
		elif b.resource_path.ends_with("torre_estabulo.tres"):
			estabulo = b
		elif b.resource_path.ends_with("torre_forte.tres"):
			forte = b
	_check("os módulos novos existem", moinho != null and guarita != null and estabulo != null and forte != null)
	# ESPAÇOS por nível dos módulos: 1 até o 4, 2 do 5 ao 12, 3 do 13 em diante
	_check("espaços por nível: 1-4 = 1, 5-12 = 2, 13+ = 3", [1, 4, 5, 12, 13, 14].map(func(lv): return Regras.module_slots(lv)) == [1, 1, 2, 2, 3, 3],
		str([1, 4, 5, 12, 13, 14].map(func(lv): return Regras.module_slots(lv))))
	_check("perfil novo (nível 1) começa com 1 módulo", Progresso.module_slots() == 1 and Progresso.module_loadout().size() == 1, str(Progresso.module_loadout().size()))
	for want in [1, 3]:
		var bl = Progresso.bot_module_loadout(MatchSetup.next_ai_profile, want)
		var bp := {}
		for o in bl:
			bp[int(o["ponto"])] = true
		var eco_n = bl.filter(func(o): return o["base"].base_type in [BaseData.BaseType.PRODUCTION, BaseData.BaseType.CAPACITY]).size()
		_check("bot monta %d módulo(s), cada um num ponto, no máximo 1 de recurso" % want, bl.size() == want and bp.size() == want and eco_n <= 1,
			str(bl.map(func(o): return [o["base"].base_name, o["ponto"]])))
	Regras.set_tune("slots", 2)   # a partida deste teste é a de 2 módulos por lado
	# o jogador entra com Moinho (ponto 4, atrás da base) e Guarita (ponto 0); o teste libera os módulos na marra
	for b in [moinho, guarita, estabulo]:
		if b != null:
			b.unlock_arena = 0
	Progresso.set_module(0, moinho, 4)
	Progresso.set_module(1, guarita, 0)
	var saved = Progresso.module_loadout()
	_check("guarda os 2 módulos e os pontos", saved.size() == 2 and saved[0]["base"] == moinho and int(saved[0]["ponto"]) == 4 and saved[1]["base"] == guarita and int(saved[1]["ponto"]) == 0)
	# REPETIR: o mesmo módulo nos dois espaços vale (e continua valendo depois de salvar e ler de novo)
	Progresso.set_module(1, moinho, 0)
	var dup = Progresso.module_loadout()
	_check("dá pra pôr dois módulos iguais", dup.size() == 2 and dup[0]["base"] == moinho and dup[1]["base"] == moinho and int(dup[0]["ponto"]) == 4 and int(dup[1]["ponto"]) == 0,
		str(dup.map(func(o): return [o["base"].base_name, o["ponto"]])))
	Progresso.set_module(0, moinho, 0)   # mesmo ponto do outro: os dois trocam de ponto, ninguém some
	dup = Progresso.module_loadout()
	_check("dois iguais trocam de ponto sem sumir", dup.size() == 2 and int(dup[0]["ponto"]) == 0 and int(dup[1]["ponto"]) == 4 and dup[1]["base"] == moinho)
	Progresso.set_module(0, moinho, 4)
	Progresso.set_module(1, guarita, 0)
	await get_tree().create_timer(1.0).timeout
	battle.get_node("Timer").stop()
	var c = ArenaBuilder.CENTER
	var mine = get_tree().get_nodes_in_group("player_base")
	var bots = get_tree().get_nodes_in_group("enemy_base")
	var my_main = mine.filter(func(t): return t.is_main)
	var my_mods = mine.filter(func(t): return !t.is_main)
	var bot_main = bots.filter(func(t): return t.is_main)
	var bot_mods = bots.filter(func(t): return !t.is_main)
	print("RESULTADO módulos: meu lado=", mine.map(func(t): return [t.base_data.base_name, t.module_point, t.max_hp]), " | bot=", bots.map(func(t): return [t.base_data.base_name, t.module_point, t.max_hp]))
	_check("1 base principal + 2 módulos de cada lado", my_main.size() == 1 and my_mods.size() == 2 and bot_main.size() == 1 and bot_mods.size() == 2)
	_check("base principal igual pros dois", my_main[0].max_hp == bot_main[0].max_hp and my_main[0].base_data == bot_main[0].base_data, "%d x %d" % [my_main[0].max_hp, bot_main[0].max_hp])
	_check("base principal no meio", abs(my_main[0].global_position.x - c.x) < 2.0 and abs(bot_main[0].global_position.x - c.x) < 2.0)
	# a Casa Grande começa DORMINDO (não atira) e acorda quando leva dano ou perde um módulo
	_check("Casa Grande começa dormindo", my_main[0].asleep and bot_main[0].asleep)
	bot_main[0].take_damage(10)
	_check("levou dano: a Casa Grande acorda", !bot_main[0].asleep and my_main[0].asleep)
	var m_moinho = my_mods.filter(func(t): return t.base_data == moinho)
	var m_guarita = my_mods.filter(func(t): return t.base_data == guarita)
	_check("módulos nos pontos escolhidos", m_moinho.size() == 1 and m_guarita.size() == 1
		and m_moinho[0].global_position.distance_to(ArenaBuilder.module_position(GameManager.Team.PLAYER, 4)) < 2.0
		and m_guarita[0].global_position.distance_to(ArenaBuilder.module_position(GameManager.Team.PLAYER, 0)) < 2.0)
	_check("módulos do bot em pontos diferentes", bot_mods[0].module_point != bot_mods[1].module_point)
	_check("só módulo de tiro atira", !Regras.tower_shoots(moinho) and Regras.tower_shoots(Catalogo.main_base()))
	# PRODUÇÃO: o Moinho acelera o recurso enquanto está de pé; caiu, volta ao normal
	var with_mill = battle.get_node("ProductionTimer").wait_time
	# GUARDA: apanhou (depois do intervalo), solta tropa
	m_guarita[0]._spawn_clock = 99.0
	var before_units = get_tree().get_nodes_in_group("units").size()
	m_guarita[0].take_damage(10)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var guard_spawned = get_tree().get_nodes_in_group("units").size() - before_units
	_check("guarita solta tropa quando apanha", guard_spawned >= 1, str(guard_spawned))
	# VELOCIDADE: com o Estábulo de pé, carta barata anda mais rápido; carta cara não
	var cheap: CardData = Catalogo.card("caramelo")
	var costly: CardData = Catalogo.card("boi_marretao")
	var speed_none = battle.module_speed_for(GameManager.Team.PLAYER, cheap)
	m_guarita[0].base_data = estabulo
	var speed_cheap = battle.module_speed_for(GameManager.Team.PLAYER, cheap)
	var speed_costly = battle.module_speed_for(GameManager.Team.PLAYER, costly)
	# dois Estábulos somam (dá pra levar dois iguais)
	m_moinho[0].base_data = estabulo
	var speed_two = battle.module_speed_for(GameManager.Team.PLAYER, cheap)
	m_moinho[0].base_data = moinho
	_check("dois estábulos somam a velocidade", speed_two > speed_cheap + 0.2 and speed_two <= 1.0 + battle.MODULE_SPEED_CAP + 0.001, "%s -> %s" % [speed_cheap, speed_two])
	m_guarita[0].base_data = guarita
	_check("estábulo acelera só carta barata", speed_none == 1.0 and speed_cheap > 1.2 and speed_costly == 1.0, "%s %s %s" % [speed_none, speed_cheap, speed_costly])
	# PLACAR: derrubar um módulo não acaba a partida, mas conta
	m_moinho[0].take_damage(999999)
	await get_tree().process_frame
	var after_mill = battle.get_node("ProductionTimer").wait_time
	_check("moinho acelera o recurso e para quando cai", with_mill < after_mill - 0.0001, "%.3f -> %.3f" % [with_mill, after_mill])
	_check("perdeu um módulo: a Casa Grande acorda", !my_main[0].asleep)
	_check("perder módulo não acaba a partida", !battle.match_over)
	_check("no fim do tempo, quem perdeu módulo perde", battle.time_up_loser() == GameManager.Team.PLAYER, str(battle.time_up_loser()))
	bot_mods[0].take_damage(999999)
	bot_mods[1].take_damage(999999)
	await get_tree().process_frame
	_check("derrubar os 2 módulos do bot não acaba a partida", !battle.match_over)
	_check("placar 2 x 1 pra mim", battle.time_up_loser() == GameManager.Team.ENEMY, str(battle.time_up_loser()))
	# BASE PRINCIPAL: caiu, acabou -- mesmo com o placar a favor
	my_main[0].take_damage(999999)
	await get_tree().process_frame
	_check("base principal caiu = fim da partida", battle.match_over)
	get_tree().paused = false
	print("RESULTADO modulos COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)


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
	# PORTÃO: 3 torres por lado, a da frente no meio e com menos vida
	var gates = bots.filter(func(t): return t.is_gate)
	var backs = bots.filter(func(t): return !t.is_gate)
	var gate_ok = bots.size() == 3 and mine.size() == 3 and gates.size() == 1 and gates[0].max_hp < backs[0].max_hp \
		and abs(gates[0].global_position.x - c.x) < 2.0 and abs(gates[0].global_position.y - c.y) < abs(backs[0].global_position.y - c.y)
	print("RESULTADO portão: 3 torres por lado? ", bots.size() == 3 and mine.size() == 3, " | portão no meio, na frente e mais fraco? ", gate_ok,
		" | vida portão/torre=", gates[0].max_hp if !gates.is_empty() else 0, "/", backs[0].max_hp, " | mão=", DeckManager.hand.size(), " cartas (esperado ", Regras.hand_size(), ")")
	# tropa do jogador que atravessa pela ponte do lado vai no PORTÃO primeiro (é a torre mais perto)
	var probe = Vector2(c.x + ArenaBuilder.BRIDGE_X, c.y - ArenaBuilder.RIVER_HALF - 4)
	var nearest = bots[0]
	for t in bots:
		if probe.distance_to(t.global_position) < probe.distance_to(nearest.global_position):
			nearest = t
	var gate_first: bool = nearest.is_gate
	print("RESULTADO alvo: saindo da ponte do lado, a torre mais perto é o portão? ", gate_first)
	# ROTAS: quem é solto no lado vai na torre de trás daquele lado; quem é solto no meio, no portão
	var rt_left = Regras.route_tower(get_tree(), GameManager.Team.PLAYER, Regras.lane_of(c.x - 150.0))
	var rt_mid = Regras.route_tower(get_tree(), GameManager.Team.PLAYER, Regras.lane_of(c.x + 20.0))
	var rt_right = Regras.route_tower(get_tree(), GameManager.Team.PLAYER, Regras.lane_of(c.x + 150.0))
	var routes_ok = rt_left != null and rt_mid != null and rt_right != null and !rt_left.is_gate and rt_left.global_position.x < c.x \
		and rt_mid.is_gate and !rt_right.is_gate and rt_right.global_position.x > c.x
	var scout_card: CardData = Catalogo.card("peao_forcado")
	battle.spawn_unit(scout_card.unit_scene, GameManager.Team.PLAYER, Vector2(c.x - 150.0, c.y + 120.0), scout_card)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var scout = get_tree().get_nodes_in_group("units").back()
	scout._refresh_enemy_tower()
	var scout_ok = scout.lane == -1 and scout.enemy_base == rt_left
	print("RESULTADO rotas: esquerda/meio/direita levam na torre certa? ", routes_ok, " | tropa solta na esquerda mira a torre de trás da esquerda? ", scout_ok)
	scout.queue_free()
	await get_tree().process_frame
	# PLACAR: fim do tempo sem nada derrubado e vida igual = empate (-1);
	# arranhou uma torre minha = eu perco; derrubei UMA do bot = eu ganho mesmo assim
	var tie = battle.time_up_loser()
	mine[0].take_damage(50)
	var by_hp = battle.time_up_loser()
	gates[0].take_damage(999999)
	await get_tree().process_frame
	var after_one = battle.match_over
	var by_count = battle.time_up_loser()
	print("RESULTADO placar: tudo igual=", tie, " (esperado -1) | só vida, eu arranhado=", by_hp, " (esperado ", GameManager.Team.PLAYER,
		") | derrubei 1=", by_count, " (esperado ", GameManager.Team.ENEMY, ") | placar=", battle.towers_destroyed[GameManager.Team.ENEMY], "x", battle.towers_destroyed[GameManager.Team.PLAYER])
	# derruba as outras: só acaba na hora quando cai a ÚLTIMA
	backs[0].take_damage(999999)
	await get_tree().process_frame
	var after_two = battle.match_over
	backs[1].take_damage(999999)
	await get_tree().process_frame
	print("RESULTADO vitória: acabou com 1 torre? ", after_one, " (esperado false) | com 2? ", after_two, " (esperado false) | com as 3? ", battle.match_over, " (esperado true)")
	_check("espelhadas", mirror_ok)
	_check("portão no meio, na frente e mais fraco", gate_ok)
	_check("mão do tamanho da regra", DeckManager.hand.size() == Regras.hand_size(), "%d cartas" % DeckManager.hand.size())
	_check("portão é a torre mais perto", gate_first)
	_check("3 rotas levam na torre certa", routes_ok)
	_check("tropa segue a rota onde foi solta", scout_ok)
	_check("placar: tudo igual empata", tie == -1, str(tie))
	_check("placar: sem torre caída decide na vida", by_hp == GameManager.Team.PLAYER, str(by_hp))
	_check("placar: uma torre derrubada já ganha", by_count == GameManager.Team.ENEMY, str(by_count))
	_check("só acaba na hora com as 3 no chão", !after_one and !after_two and battle.match_over)
	print("RESULTADO torres COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)
	get_tree().paused = false


# BATALHA 2.5 (Scripts/regras.gd): a torre defende de verdade, a tropa leva
# 1 s pra entrar, o golpe tem preparo e a tropa tem cor de time
func _rules_test():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	var P = GameManager.Team.PLAYER
	var E = GameManager.Team.ENEMY
	var mid = ArenaBuilder.CENTER
	var tower = get_tree().get_nodes_in_group("player_base")[0]
	var forte: BaseData = null
	var celeiro: BaseData = null
	for b in Catalogo.bases():
		if b.base_type == BaseData.BaseType.HP and forte == null:
			forte = b
		if b.base_type == BaseData.BaseType.CANNON and celeiro == null:
			celeiro = b

	# 1) torre que não é "de tiro" também atira
	tower.install_base_data(forte, 1)
	tower.scale_hp(Regras.tower_hp_fraction())
	var foe = await _dummy(E, tower.global_position + Vector2(0, -150))
	await get_tree().create_timer(3.0).timeout
	_check("toda torre atira", foe.current_hp < 99999, "o Forte tirou %d em 3 s" % int(99999 - foe.current_hp))

	# 2) números e chave
	var hp_new = Regras.tower_hp(celeiro)
	var range_new = Regras.tower_range(celeiro)
	Regras.forced["torres"] = false
	var off_ok = !Regras.tower_shoots(forte) and Regras.tower_hp(celeiro) == int(round(celeiro.base_hp * 0.65)) and Regras.tower_range(celeiro) == celeiro.attack_range
	Regras.forced.erase("torres")
	_check("vida e alcance novos", hp_new == Regras.tidy(celeiro.base_hp * Regras.TOWER_HP_FRACTION) and range_new > 200.0, "Celeiro: %d de vida, alcance %d" % [hp_new, int(range_new)])
	_check("chave 'torres' desligada volta ao antigo", off_ok)

	# 3) VANTAGEM DE QUEM DEFENDE: tropa sozinha não derruba torre
	# (o Peão sozinho tirava até 40% da torre; com o tiro mais fraco da versão 109 passou a tirar perto de 45%.
	# Continua sem derrubar: a regra é "metade, no máximo")
	for spec in [["peao_forcado", 0.5, 45.0], ["pintaiada", 0.75, 30.0]]:
		await _wipe()
		tower.install_base_data(celeiro, 1)
		tower.scale_hp(Regras.tower_hp_fraction())
		var hp0 = tower.hp
		var squad = await _put(str(spec[0]), E, tower.global_position + Vector2(0, -320))
		var waited = 0.0
		while waited < float(spec[2]) and squad.any(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion()):
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
		var all_dead = !squad.any(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion())
		_check("%s sozinha não derruba a torre" % str(spec[0]), all_dead and tower.hp >= hp0 * float(spec[1]), "morreu? %s | torre ficou com %d%% (mínimo %d%%) em %ds" % [str(all_dead), int(100.0 * tower.hp / hp0), int(float(spec[1]) * 100), int(waited)])

	# 4) 1 s pra entrar em campo
	await _wipe()
	var u = (await _put("peao_forcado", P, mid + Vector2(0, 220)))[0]
	var p0 = u.global_position
	await get_tree().create_timer(0.8).timeout
	var still = u.global_position.distance_to(p0) < 2.0
	await get_tree().create_timer(0.9).timeout
	var moved = u.global_position.distance_to(p0) > 10.0
	_check("1 s pra entrar em campo", still and moved, "parado aos 0,8 s? %s | andando aos 1,7 s? %s" % [str(still), str(moved)])

	# 5) o golpe tem preparo (o primeiro não é mais instantâneo)
	await _wipe()
	var d = await _dummy(E, mid + Vector2(0, 100))
	u = (await _put("peao_forcado", P, mid + Vector2(0, 150)))[0]
	var t_ready = -1.0
	var t_hit = -1.0
	for k in 120:
		await get_tree().physics_frame
		if t_ready < 0.0 and !u._is_incapacitated() and u._in_attack_range(d):
			t_ready = GameManager.game_time
		if d.current_hp < 99999:
			t_hit = GameManager.game_time
			break
		if k % 3 == 0:
			await get_tree().create_timer(0.05).timeout
	var windup = Regras.windup_time(u.stats)
	var lag = t_hit - t_ready
	_check("golpe tem preparo", t_ready >= 0.0 and t_hit >= 0.0 and lag >= windup - 0.12 and lag <= windup + 0.5, "preparo esperado %.2f s, medido %.2f s" % [windup, lag])

	# 6) tropa maior e com cor de time
	var sp: Sprite2D = u.get_node("Sprite2D")
	var bar: ProgressBar = u.get_node("ProgressBar")
	_check("tropa grande com cor de time", sp.scale.x >= 1.3 and sp.material != null and !bar.visible, "escala %.2f, contorno? %s, barra escondida com vida cheia? %s" % [sp.scale.x, str(sp.material != null), str(!bar.visible)])
	u.take_damage(50)
	_check("barra aparece quando apanha", bar.visible)

	print("RESULTADO regras OK (", _aud_ok.size(), "): ", _aud_ok)
	print("RESULTADO regras COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)


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


var _fake_player_on := false


func _process(delta):
	if !_fake_player_on or battle == null or !battle.is_inside_tree() or battle.match_over:
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
	for pair in [["comitiva", 3], ["vaca_e_cria", 3], ["galo_e_cia", 5], ["dupla_caipira", 2], ["bezerrada", 4], ["pintaiada", 6]]:
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
			# o puxão sozinho desloca ~6-8px nesses alvos; antes passava de 8 por causa do esbarrão
			# da vaca aliada, que dependia do caminho dela. 5 mede o feitiço, não o esbarrão
			good = good and st["moveu"] > 5.0
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
	await get_tree().create_timer(1.55 + Regras.deploy_time(u.stats)).timeout
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


## MECÂNICAS NOVAS (versão 113): feitiço que rola, feitiço que escolhe alvo, espelho,
## construção que se esconde, cura a cada golpe e segundo ataque
func _new_mechanics_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()
	_aud_bad.clear()
	var P = GameManager.Team.PLAYER
	var E = GameManager.Team.ENEMY
	# opção "só batalha normal": ligada, a partida comum NUNCA sorteia modificador;
	# desligada, o sorteio continua existindo
	var so_before = Config.data.get("so_normal", false)
	Config.data["so_normal"] = true
	var weather_on = 0
	for k in 400:
		weather_on += 1 if MatchSetup.roll_weather() != 0 else 0
	Config.data["so_normal"] = false
	var weather_off = 0
	for k in 400:
		weather_off += 1 if MatchSetup.roll_weather() != 0 else 0
	Config.data["so_normal"] = so_before
	if weather_on != 0 or weather_off == 0:
		_aud_bad.append("so batalha normal: com a opcao %d modificadores, sem ela %d em 400" % [weather_on, weather_off])
	# selecionar SEM recurso: a carta fica selecionada, o toque no campo não gasta nem solta
	# a seleção, e clear_selection solta
	var sel_card: CardData = Catalogo.card("vaca_brava")
	var money_keep = GameManager.player_money
	GameManager.player_money = 0
	battle.select_card(sel_card, -1)
	var placed = battle.try_confirm_placement_at(ArenaBuilder.CENTER + Vector2(0, 200))
	var kept = battle.selected_card == sel_card
	battle.clear_selection()
	if placed or !kept or battle.selected_card != null or GameManager.player_money != 0:
		_aud_bad.append("selecionar sem recurso: jogou=%s manteve=%s limpou=%s" % [str(placed), str(kept), str(battle.selected_card == null)])
	GameManager.player_money = money_keep
	# histórico de partidas: guarda resultado, placar e os dois baralhos; não passa do limite
	var h_before = Historico.list().size()
	for k in Historico.MAX + 3:
		Historico.record(1, 30, 2, 1, 150.0, battle.ai_profile, DeckManager.full_deck)
	var h_e: Dictionary = Historico.list()[0]
	if Historico.list().size() != Historico.MAX or int(h_e["res"]) != 1 or h_e["placar"] != [2, 1] or (h_e["meu"] as Array).is_empty() or (battle.ai_profile != null and (h_e["dele"] as Array).is_empty()):
		_aud_bad.append("historico: tamanho %d (antes %d), entrada %s" % [Historico.list().size(), h_before, str(h_e).substr(0, 120)])
	# modo teste: nível travado em 1 pros dois lados; torneio continua 5; normal não trava
	var t_keep = [MatchSetup.teste, MatchSetup.tournament]
	MatchSetup.teste = true
	var lv_test = MatchSetup.fixed_level()
	var lv_main = battle._main_level()
	MatchSetup.teste = false
	MatchSetup.tournament = true
	var lv_tour = MatchSetup.fixed_level()
	MatchSetup.tournament = false
	var lv_none = MatchSetup.fixed_level()
	MatchSetup.teste = t_keep[0]
	MatchSetup.tournament = t_keep[1]
	if lv_test != 1 or lv_main != 1 or lv_tour != MatchSetup.TOURNAMENT_LEVEL or lv_none != 0:
		_aud_bad.append("modo teste: niveis %s" % str([lv_test, lv_main, lv_tour, lv_none]))
	# PLANOS DE JOGO dos bots: os 6 planos decidem diferente com o mesmo recurso na mão
	var fam_prof: AIProfile = battle.ai_profile if battle.ai_profile != null else BotLearning.get_or_create_profile(BotSimulator.roster_names[0])
	var thr: Array = []
	for f in 6:
		var pp = PushPlan.new()
		PushPlan.forced = {E: f}
		pp.hand = fam_prof.deck.slice(0, 4)
		pp.decide(0.0, 10, 100, false, fam_prof, get_tree(), E, 50)   # resolve o plano
		pp._jitter = 0.0
		pp._chaos = 0.0
		thr.append(pp.threshold(100, false, fam_prof))
		if pp.fam != f:
			_aud_bad.append("plano de jogo %d nao foi aplicado (ficou %d)" % [f, pp.fam])
	if !(thr[PushPlan.Fam.CORRERIA] < thr[PushPlan.Fam.BLOCO] - 15 and thr[PushPlan.Fam.CONTRA] >= 96):
		_aud_bad.append("planos de jogo: limiares %s" % str(thr))
	# Cerco com construção na mão e nenhuma de pé: pede pra plantar antes de atacar
	var b_card: CardData = null
	for c in Catalogo.cards():
		if PushPlan.is_building(c):
			b_card = c
			break
	if b_card != null:
		var pc = PushPlan.new()
		PushPlan.forced = {E: PushPlan.Fam.CERCO}
		pc.hand = [b_card]
		var dc = pc.decide(0.0, 99, 100, false, fam_prof, get_tree(), E, 50)
		if !dc.get("build", false) or pc.chip_pool([b_card, sel_card]) != [b_card]:
			_aud_bad.append("cerco nao pediu construcao: %s" % str(dc))
	# Combo: sem as duas cartas na mão segura (não ataca só por ter recurso); com as duas, ataca
	var pk = PushPlan.new()
	PushPlan.forced = {E: PushPlan.Fam.COMBO}
	pk.hand = []
	var d_hold = pk.decide(1.0, 90, 100, false, fam_prof, get_tree(), E, 50)
	if pk.combo.size() == 2:
		pk.hand = [pk.combo[0], pk.combo[1]]
		var d_go = pk.decide(2.0, 90, 100, false, fam_prof, get_tree(), E, 50)
		if d_hold.get("go", false) or !d_go.get("go", false) or pk.shape(null, pk.combo, d_go) != pk.combo[0]:
			_aud_bad.append("combo: segurou=%s atacou=%s" % [str(d_hold), str(d_go)])
	else:
		_aud_bad.append("combo: bot sem par de cartas")
	PushPlan.forced = {}
	# perfil de desenvolvedor: tudo liberado só com a chave ligada
	var dev_keep = Progresso.d.get("dev", false)
	var locked_card: CardData = null
	for c in CardDatabase.all_cards:
		if c != null and !Progresso.is_featured(c) and !Progresso.d["owned"].has(c.resource_path):
			locked_card = c
			break
	var locked_base: BaseData = null
	for b in BotSimulator.available_bases:
		if b != null and b.unlock_arena > ArenaManager.get_player_arena():
			locked_base = b
			break
	Progresso.d["dev"] = false
	var off_ok = (locked_card == null or !Progresso.is_owned(locked_card)) and (locked_base == null or !Progresso.is_base_unlocked(locked_base))
	Progresso.d["dev"] = true
	var on_ok = (locked_card == null or Progresso.is_owned(locked_card)) and (locked_base == null or Progresso.is_base_unlocked(locked_base))
	Progresso.d["dev"] = dev_keep
	if !off_ok or !on_ok or (locked_card == null and locked_base == null):
		_aud_bad.append("perfil dev: desligado=%s ligado=%s (carta %s, modulo %s)" % [str(off_ok), str(on_ok), str(locked_card != null), str(locked_base != null)])
	# raridade do módulo escolhida no Criador: vale por cima da automática e encarece o nível
	var rb: BaseData = BotSimulator.available_bases[0].duplicate()
	rb.rarity_pick = 0
	var cost_auto = PlayerProfile.get_upgrade_coin_cost_base(rb)
	var rar_auto = Catalogo.base_rarity(rb)
	rb.rarity_pick = 4
	if Catalogo.base_rarity(rb) != 3 or (rar_auto < 3 and PlayerProfile.get_upgrade_coin_cost_base(rb) <= cost_auto):
		_aud_bad.append("raridade de modulo: %d custo %d -> %d" % [Catalogo.base_rarity(rb), cost_auto, PlayerProfile.get_upgrade_coin_cost_base(rb)])
	# tipos de projétil: todos desenham alguma coisa em 16x16 e são bastante
	var proj_bad: Array = []
	for k in SpriteForge.pieces("proj"):
		var pim: Image = SpriteForge.projectile(str(k), SpriteForge.DEFAULT_PALETTE).get_image()
		if pim.get_size() != Vector2i(16, 16) or pim.get_used_rect().size.x < 3:
			proj_bad.append(str(k))
	if !proj_bad.is_empty() or SpriteForge.pieces("proj").size() < 40:
		_aud_bad.append("tipos de projetil: %d tipos, vazios %s" % [SpriteForge.pieces("proj").size(), str(proj_bad)])
	for cat in ["pernas", "corpo", "bracos", "costas"]:
		for k in SpriteForge.pieces(cat):
			if SpriteForge.make_image({cat: str(k)}, SpriteForge.DEFAULT_PALETTE).get_used_rect().size.x < 3:
				_aud_bad.append("peca vazia: %s/%s" % [cat, str(k)])
	# rio largo: quem luta corpo a corpo não alcança mais a outra margem
	if ArenaBuilder.RIVER_HALF * 2.0 < 60.0:
		_aud_bad.append("rio estreito de novo: %d" % int(ArenaBuilder.RIVER_HALF * 2.0))
	var mid = ArenaBuilder.CENTER + Vector2(135, 150)
	# 1) ROLA: acerta uma vez quem está no caminho, não acerta quem está fora da largura
	await _wipe()
	var a = await _dummy(E, mid + Vector2(0, -90))
	var b = await _dummy(E, mid + Vector2(10, -200))
	var c = await _dummy(E, mid + Vector2(-170, -120))
	var roll = SpellData.new()
	roll.rolls = true
	roll.radius = 45.0
	roll.damage = 100
	roll.roll_distance = 300.0
	roll.roll_speed = 500.0
	battle.cast_spell(roll, mid, P)
	await get_tree().create_timer(1.6).timeout
	_check("feitiço que rola acerta uma vez quem está no caminho", a.current_hp == 99899 and b.current_hp == 99899 and c.current_hp == 99999,
		"%d %d fora=%d" % [a.current_hp, b.current_hp, c.current_hp])
	# 2) ESCOLHE: só os 2 de mais vida
	await _wipe()
	var big = await _dummy(E, mid + Vector2(0, -60), 5000)
	var medium = await _dummy(E, mid + Vector2(30, -60), 3000)
	var small = await _dummy(E, mid + Vector2(-30, -60), 1000)
	var pick = SpellData.new()
	pick.radius = 120.0
	pick.damage = 200
	pick.picks_strongest = 2
	battle.cast_spell(pick, mid + Vector2(0, -60), P)
	await get_tree().process_frame
	_check("feitiço que escolhe acerta só os 2 de mais vida", big.current_hp == 4800 and medium.current_hp == 2800 and small.current_hp == 1000,
		"%d %d %d" % [big.current_hp, medium.current_hp, small.current_hp])
	# 3) ESPELHO: repete o último feitiço e a última tropa
	var raio: CardData = Catalogo.card("raio")
	var hp_a = big.current_hp
	battle.cast_spell(raio.spell_data, big.global_position, P, raio.resource_path)
	await get_tree().process_frame
	var one = hp_a - big.current_hp
	var mir = SpellData.new()
	mir.mirror = true
	battle.cast_spell(mir, big.global_position, P)
	await get_tree().process_frame
	_check("espelho repete o último feitiço", one > 0 and hp_a - big.current_hp == one * 2, "1x=%d total=%d" % [one, hp_a - big.current_hp])
	await _wipe()
	var chicks = await _put("pintaiada", P, mid + Vector2(0, 120))
	var n0 = get_tree().get_nodes_in_group("units").size()
	battle.cast_spell(mir, mid + Vector2(60, 120), P)
	await get_tree().process_frame
	_check("espelho repete a última tropa", get_tree().get_nodes_in_group("units").size() == n0 + chicks.size(), "%d -> %d" % [n0, get_tree().get_nodes_in_group("units").size()])
	# 4) ESCONDE: sem inimigo, ninguém acerta; com inimigo perto, aparece
	await _wipe()
	var cannon = (await _put("canhao_pipoca", P, mid + Vector2(0, 140)))[0]
	cannon.stats = cannon.stats.duplicate()
	cannon.stats.hides_underground = true
	await get_tree().create_timer(0.4).timeout
	var hp_c = cannon.current_hp
	cannon.take_damage(100)
	var hidden_ok = cannon.is_hidden() and cannon.current_hp == hp_c
	var foe = await _dummy(E, mid + Vector2(0, 60))
	await get_tree().create_timer(2.0).timeout
	_check("construção escondida não apanha e aparece quando acha alvo", hidden_ok and !cannon.is_hidden() and foe.current_hp < 99999,
		"escondida ok? %s | apareceu? %s | bateu? %s" % [str(hidden_ok), str(!cannon.is_hidden()), str(foe.current_hp < 99999)])
	# 5) CURA A CADA GOLPE
	await _wipe()
	var healer = (await _put("peao_forcado", P, mid + Vector2(0, 40)))[0]
	healer.stats = healer.stats.duplicate()
	healer.stats.heals_on_attack = true
	healer.stats.attack_heal_amount = 50
	var hurt = (await _put("vaca_brava", P, mid + Vector2(0, 110)))[0]
	hurt.stats = hurt.stats.duplicate()
	hurt.stats.move_speed = 0.0
	hurt.current_hp = 500
	await _dummy(E, mid + Vector2(0, 5))
	await get_tree().create_timer(3.0).timeout
	_check("cura quem está perto a cada golpe", hurt.current_hp > 500, str(hurt.current_hp))
	# 6) SEGUNDO ATAQUE: quem só bate em torre acerta tropa com o cavaleiro
	await _wipe()
	var ram = (await _put("vaca_brava", P, mid + Vector2(0, 100)))[0]
	ram.stats = ram.stats.duplicate()
	ram.stats.rider_attack = true
	ram.stats.rider_damage = 40
	ram.stats.rider_effect = UnitData.OnHitEffect.SLOW
	var near = await _dummy(E, mid + Vector2(60, 60))
	var far = await _dummy(E, mid + Vector2(-260, -300))
	await get_tree().create_timer(2.0).timeout
	_check("segundo ataque acerta tropa perto e não a de longe", near.current_hp < 99999 and far.current_hp == 99999, "%d %d" % [near.current_hp, far.current_hp])
	# --- leva "aura, pulso, rastro, cresce, armadilha, pisca"
	await _wipe()
	var chief = (await _put("vaca_brava", P, mid + Vector2(0, 100)))[0]
	chief.stats = chief.stats.duplicate()
	chief.stats.aura_buff = true
	chief.stats.aura_damage_mult = 1.5
	chief.stats.pulses = true
	chief.stats.pulse_interval = 0.6
	chief.stats.pulse_damage = 50
	chief.stats.grows_over_time = true
	chief.stats.grow_interval = 0.5
	chief.stats.grow_damage_step = 0.25
	chief.stats.leaves_trail = true
	var buddy = (await _put("vaca_brava", P, mid + Vector2(40, 110)))[0]
	var lonely = (await _put("vaca_brava", P, mid + Vector2(-250, 330)))[0]
	var p_near = await _dummy(E, mid + Vector2(50, 70))
	var p_far = await _dummy(E, mid + Vector2(-260, -300))
	await get_tree().create_timer(1.6).timeout
	_check("aura reforça o aliado perto e não o de longe", is_instance_valid(buddy) and is_instance_valid(lonely) and buddy._rage_damage >= 1.49 and buddy._rage_until > GameManager.game_time and lonely._rage_until <= GameManager.game_time,
		"%s" % str([buddy._rage_damage if is_instance_valid(buddy) else -1, lonely._rage_damage if is_instance_valid(lonely) else -1]))
	_check("pulso acerta quem está em volta e não o de longe", p_near.current_hp < 99999 and p_far.current_hp == 99999, "%d %d" % [p_near.current_hp, p_far.current_hp])
	_check("cresce com o tempo (até o teto)", is_instance_valid(chief) and chief._grow_mult >= 1.5 and chief._grow_mult <= chief.stats.grow_max_mult, str(chief._grow_mult if is_instance_valid(chief) else -1))
	var pocas = 0
	for n in battle.get_children() + (chief.get_parent().get_children() if is_instance_valid(chief) else []):
		pocas += 1 if n is Poca else 0
	_check("rastro deixa poça no chão", pocas >= 1, str(pocas))
	# armadilha: construção escondida, não leva dano, explode quando pisam
	await _wipe()
	var trap = await _dummy(P, mid + Vector2(0, 60))
	trap.stats.is_trap = true
	trap.stats.trap_damage = 300
	await get_tree().create_timer(0.3).timeout
	var trap_hid = trap.is_hidden()
	var hp_t = trap.current_hp
	trap.take_damage(500)
	var trap_imm = trap.current_hp == hp_t
	var victim2 = await _dummy(E, mid + Vector2(20, 70))
	var safe2 = await _dummy(E, mid + Vector2(-260, -300))
	await get_tree().create_timer(0.6).timeout
	_check("armadilha fica escondida e intocável, explode em quem pisa e some", trap_hid and trap_imm and victim2.current_hp <= 99999 - 300 and safe2.current_hp == 99999 and (!is_instance_valid(trap) or trap.current_hp <= 0 or trap.is_queued_for_deletion()),
		"%s" % str([trap_hid, trap_imm, victim2.current_hp, safe2.current_hp, is_instance_valid(trap)]))
	# pisca: com alvo longe, aparece do lado dele
	await _wipe()
	var blinker = (await _put("vaca_brava", P, mid + Vector2(0, 200)))[0]
	blinker.stats = blinker.stats.duplicate()
	blinker.stats.blinks = true
	blinker.stats.blink_interval = 1.0
	blinker.stats.blink_range = 400.0
	var prey = await _dummy(E, mid + Vector2(0, 20))
	blinker.target = prey
	await get_tree().create_timer(1.5).timeout
	_check("pisca teleporta pra perto do alvo", is_instance_valid(blinker) and blinker.global_position.distance_to(prey.global_position) < 120.0, str(blinker.global_position.distance_to(prey.global_position) if is_instance_valid(blinker) else -1))
	# atirador que só ataca construção: a tropa encostada nele NÃO come o tiro (bug do João)
	await _wipe()
	var snipers = await _put("galinha_atiradeira", P, mid + Vector2(0, 140))
	var sniper = snipers[0]
	for sn in snipers:
		sn.stats = sn.stats.duplicate()
		sn.stats.target_type = UnitData.TargetType.BUILDING
		sn.stats.is_aoe = true
		sn.stats.aoe_radius = 60.0
		sn.stats.attack_range = 260.0
		sn.stats.detection_range = 320.0
		sn.stats.move_speed = 0.0
		sn.stats.damage = 1000   # dano bem diferente do da torre aliada (que também atira no intruso)
		sn._reset_aggro()   # o alvo pego antes de virar "só construção" não vale
	var hut = await _dummy(E, mid + Vector2(0, 30))
	hut.stats.unit_type = UnitData.UnitType.BUILDING
	var blocker = await _dummy(E, mid + Vector2(0, 110))    # colado no atirador, no caminho do tiro
	var beside = await _dummy(E, mid + Vector2(24, 30))    # colado na construção (pegaria o dano em área)
	await get_tree().create_timer(4.0).timeout
	_check("quem só ataca construção acerta a construção e nenhuma tropa", sniper.stats.is_ranged and hut.current_hp <= 99999 - 1000 and blocker.current_hp > 99999 - 1000 and beside.current_hp > 99999 - 1000,
		"atira=%s construcao=%d no_caminho=%d do_lado=%d" % [str(sniper.stats.is_ranged), hut.current_hp, blocker.current_hp, beside.current_hp])
	# 7) bot não joga o Espelho sem ter o que repetir
	var mcard = CardData.new()
	mcard.cost = 20
	mcard.spell_data = mir
	battle._last_card.erase(E)
	var no_last = battle.ai_can_play(E, mcard)
	battle._last_card[E] = Catalogo.card("vaca_brava")
	_check("bot só joga o Espelho quando tem o que repetir", !no_last and battle.ai_can_play(E, mcard) and battle.ai_can_play(E, raio))
	# 8) COMEÇAR DO ZERO: liga, o jogo fica só com o baralho inicial emprestado; desliga, volta tudo
	var all_n = CardDatabase.all_cards.size()
	Config.data["do_zero"] = true
	CustomContent.apply_zero()
	var zero_n = CardDatabase.all_cards.size()
	var zero_want = CustomContent.zero_pool().size()
	var zd = CustomContent.zero_deck("bot qualquer")
	var blocked_ok = CustomContent.can_battle() == (zero_want > 0)
	Config.data["do_zero"] = false
	CustomContent.apply_zero()
	_check("começar do zero sem carta: coleção vazia e batalha travada (sem fechar o jogo)", blocked_ok and CustomContent.can_battle())
	# MÓDULOS do zero: sem nenhum módulo seu, ninguém leva módulo; desligar devolve os do jogo
	var bases_n = BotSimulator.available_bases.size()
	Config.data["do_zero_mod"] = true
	CustomContent.apply_zero()
	var zero_mods = BotSimulator.available_bases.size()
	var lo_p = Progresso.module_loadout().size()
	var lo_b = Progresso.bot_module_loadout(BotLearning.get_or_create_profile(BotSimulator.roster_names[0]), 2).size()
	Config.data["do_zero_mod"] = false
	CustomContent.apply_zero()
	_check("módulos do zero: só os criados; desligar devolve", zero_mods == CustomContent.custom_bases.size() and (zero_mods > 0 or (lo_p == 0 and lo_b == 0)) and BotSimulator.available_bases.size() == bases_n,
		"%d -> %d -> %d (jogador %d, bot %d)" % [bases_n, zero_mods, BotSimulator.available_bases.size(), lo_p, lo_b])
	# chaves da SAFRA e da ASSEMBLEIA
	var safra_n = CardDatabase.all_cards.filter(func(x): return x != null and x.has_meta("safra")).size()
	Config.data["safra_off"] = true
	CustomContent.apply_zero()
	var safra_hidden = CardDatabase.all_cards.filter(func(x): return x != null and x.has_meta("safra")).size()
	Config.data["safra_off"] = false
	CustomContent.apply_zero()
	var vaca: CardData = Catalogo.card("vaca_brava")
	var hp_raw = DeckBuilder.get_unit_stats(vaca).hp
	Assembleia._d()["ajustes"][vaca.resource_path] = {"hp": 1.5, "dmg": 1.0}
	Assembleia.apply_all()
	var hp_adj = DeckBuilder.get_unit_stats(vaca).hp
	Config.data["assembleia_off"] = true
	Assembleia.sync()
	var hp_off = DeckBuilder.get_unit_stats(vaca).hp
	Config.data["assembleia_off"] = false
	Assembleia._d()["ajustes"].erase(vaca.resource_path)
	Assembleia.apply_all()
	_check("chave da safra tira e devolve as cartas dela", safra_hidden == 0 and CardDatabase.all_cards.filter(func(x): return x != null and x.has_meta("safra")).size() == safra_n, "%d -> %d" % [safra_n, safra_hidden])
	_check("chave da assembleia desliga os ajustes", hp_adj > hp_raw and hp_off == hp_raw and DeckBuilder.get_unit_stats(vaca).hp == hp_raw, "%d %d %d" % [hp_raw, hp_adj, hp_off])
	_check("começar do zero esconde as cartas do jogo e desligar devolve", zero_n == zero_want and zero_n < all_n and zd.size() == (8 if zero_want > 0 else 0) and CardDatabase.all_cards.size() == all_n, "%d -> %d -> %d" % [all_n, zero_n, CardDatabase.all_cards.size()])
	print("RESULTADO novas COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)
