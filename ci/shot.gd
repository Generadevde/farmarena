extends Node
# CAPTURAS DE TELA (só GitHub Actions, com tela virtual): abre o menu novo e
# uma batalha de verdade e salva imagens pra conferir o visual.

func _shot(shot_name: String):
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("user://shot_%s.png" % shot_name)
	print("SHOT ", shot_name, " ", img.get_size())


func _ready():
	get_window().size = Vector2i(720, 1600)
	PlayerProfile.create_new_profile("João")
	PlayerBehaviorProfiler.load_for_active_profile()
	Leaderboard.load_for_active_profile()
	SeasonStats.load_for_active_profile()
	SeasonManager.load_for_active_profile()
	PollManager.load_for_active_profile()
	ArenaManager.load_for_active_profile()
	CustomContent.load_all()
	# um perfil "com história" pra tela ficar cheia
	PlayerProfile.add_coins(1234)
	ArenaManager.trophies[PlayerProfile.player_name] = 720
	Progresso.add_chest(0)
	Progresso.add_chest(2)
	Progresso.start_chest(0)
	Progresso._spawn_mascate()
	for id in ["cavalo_coiceiro", "pato_ninja", "espantalho", "sapo_linguarudo", "vovo_lampiao", "boi_marretao", "robo_balde"]:
		Progresso.give_card(Catalogo.card(id), 3)
	Progresso.d["uses"][Catalogo.card("vaca_brava").resource_path] = 160
	Progresso.d["uses"][Catalogo.card("raio").resource_path] = 80
	Progresso.d["uses"][Catalogo.card("pintaiada").resource_path] = 35
	Progresso.d["uses"][Catalogo.card("peao_forcado").resource_path] = 12
	Progresso.d["season_uses"][Catalogo.card("vaca_brava").resource_path] = 14
	Progresso.d["season_uses"][Catalogo.card("raio").resource_path] = 9
	Progresso.give_card(Catalogo.card("peao_forcado"), 30)
	Progresso.pop_pending()

	var prof = load("res://Scenes/profile_setup.tscn").instantiate()
	add_child(prof)
	await get_tree().create_timer(0.4).timeout
	await _shot("perfil")
	prof.queue_free()
	await get_tree().process_frame
	SeasonManager.load_for_active_profile()
	SeasonManager.force_new_season()
	var hub = load("res://Scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().create_timer(0.6).timeout
	Cla.join(Cla.NAMES[0])
	Cla.tick()
	Progresso.grant_power("relogio2", false)
	Progresso.grant_power("ouro2", false)
	Progresso.use_power("ouro2")
	for tab in 6:
		hub._go_tab(tab)
		await get_tree().create_timer(0.5).timeout
		await _shot("hub_%d" % tab)
	hub._go_tab(1)
	hub._show_card_popup(Catalogo.card("vaca_brava"))
	await get_tree().create_timer(0.4).timeout
	await _shot("carta")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._pending_card = Catalogo.card("cavalo_coiceiro")
	hub._queue_refresh()
	await get_tree().create_timer(0.4).timeout
	await _shot("escolher")
	hub._cancel_placing_and_refresh()
	await get_tree().create_timer(0.2).timeout
	hub._begin_drag(Catalogo.card("pato_ninja"))
	await get_tree().create_timer(0.3).timeout
	var drop_at = hub._drop_targets[-1][0].get_global_rect().get_center() if !hub._drop_targets.is_empty() else Vector2.ZERO
	hub._move_ghost(drop_at)
	await _shot("arrastar")
	hub._end_drag(drop_at)
	print("SHOT arrasto: pato ninja entrou no baralho? ", Progresso.deck_paths(0).has(Catalogo.card("pato_ninja").resource_path), " alvos=", hub._drop_targets.size())
	await get_tree().create_timer(0.2).timeout
	hub._go_tab(1)
	hub._set_cards_view(1)
	await get_tree().create_timer(0.5).timeout
	await _shot("torres")
	hub._set_cards_view(0)
	hub._show_ranking()
	await get_tree().create_timer(0.4).timeout
	await _shot("ranking")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_daily()
	await get_tree().create_timer(0.4).timeout
	await _shot("diario")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_deck_check()
	await get_tree().create_timer(0.4).timeout
	await _shot("analise")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_deck_suggest()
	await get_tree().create_timer(0.4).timeout
	await _shot("sugestao")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_settings()
	await get_tree().create_timer(0.4).timeout
	await _shot("config")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	print("SHOT sair: multa=", ArenaManager.loss_points_for("x", PlayerProfile.player_name), " | diario=", Progresso.daily_deck().map(func(c): return c.card_name), " tema=", Progresso.daily_theme())
	hub._show_ranking(3)
	await get_tree().create_timer(0.4).timeout
	await _shot("temporada")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	print("SHOT assembleia: pautas=", Assembleia.pautas(), " | propor nerf vaca -> '", Assembleia.propose(Catalogo.card("vaca_brava"), "nerf"), "' votos=", Assembleia.votes(Assembleia.pautas()[-1]) if !Assembleia.pautas().is_empty() else [])
	var vb: CardData = Catalogo.card("vaca_brava")
	var hp_before = DeckBuilder.get_unit_stats(vb).hp
	Progresso.d["assembleia"]["ajustes"][vb.resource_path] = {"hp": 1.04, "dmg": 1.02}
	Assembleia.apply_all()
	var inst = vb.unit_scene.instantiate()
	var hp_mid = inst.stats.hp
	inst.free()
	Progresso.d["assembleia"]["ajustes"].erase(vb.resource_path)
	Assembleia.apply_all()
	print("SHOT assembleia ajuste: vaca vida ", hp_before, " -> ", hp_mid, " (esperado ", int(round(hp_before * 1.04)), ") -> volta ", DeckBuilder.get_unit_stats(vb).hp)
	hub._show_assembleia()
	await get_tree().create_timer(0.5).timeout
	await _shot("assembleia")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_card_stats()
	await get_tree().create_timer(0.5).timeout
	await _shot("meta")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_bot(BotSimulator.roster_names[3])
	await get_tree().create_timer(0.4).timeout
	await _shot("bot")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_registro()
	await get_tree().create_timer(0.4).timeout
	await _shot("registro")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_tournament()
	await get_tree().create_timer(0.4).timeout
	await _shot("torneios")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	var entered = Progresso.enter_tournament("dez")
	var log_t: Array = []
	for won in [true, true, true, false, true]:
		log_t.append(Progresso.tournament_result(won))
	print("SHOT desafio: entrou? ", entered, " | ", log_t, " | ", Progresso.tournament_stage_text(), " | oponente=", Progresso.tournament_opponent(), " | torre jogador nv ", Progresso.tower_level())
	hub._show_tournament()
	await get_tree().create_timer(0.4).timeout
	await _shot("torneio")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	Progresso.abandon_tournament()
	Progresso.d["torneio"]["dia_gratis"] = ""
	Progresso.enter_tournament("mata")
	Progresso.tournament_result(true)
	hub._show_tournament()
	await get_tree().create_timer(0.4).timeout
	await _shot("chave")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	Gazeta.report_match(BotSimulator.roster_names[2], 14, 9, true)
	hub._show_jornal()
	await get_tree().create_timer(0.5).timeout
	await _shot("jornal")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._celebrate(Catalogo.card("robo_balde"), "NÍVEL 2!", "+15% de vida e de dano", Color(0.5, 1.0, 0.6))
	await get_tree().create_timer(0.7).timeout
	await _shot("comemora")
	await get_tree().create_timer(1.2).timeout
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._go_tab(1)
	await get_tree().create_timer(0.3).timeout
	hub._show_card_popup(Progresso.deck_cards(0)[0], 0)
	await get_tree().create_timer(0.4).timeout
	await _shot("carta_baralho")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	var pick_c = Progresso.owned_cards().filter(func(c): return !Progresso.deck_paths(0).has(c.resource_path))
	if !pick_c.is_empty():
		hub._on_collection_tapped(pick_c[0])
	hub._pages_root.get_child(1).scroll_vertical = 500
	await get_tree().create_timer(0.4).timeout
	await _shot("doca")
	hub._clear_selection()
	hub._show_compare(Catalogo.card("vaca_brava"), Catalogo.card("molecada"))
	await get_tree().create_timer(0.4).timeout
	await _shot("comparar")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_safra()
	await get_tree().create_timer(0.4).timeout
	await _shot("safra")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_loot("Baú do Celeiro", Progresso.roll_chest(2), Color("#c84838"))
	await get_tree().create_timer(1.6).timeout
	await _shot("bau")
	hub.queue_free()
	await get_tree().process_frame

	MatchSetup.mode = MatchSetup.MODE_1V1
	MatchSetup.tournament = true
	MatchSetup.rule = 3
	MatchSetup.arena_override = 6
	MatchSetup.next_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[0])
	var battle = load("res://Scenes/batlhe_scene.tscn").instantiate()
	get_tree().root.add_child(battle)
	await get_tree().create_timer(0.5).timeout
	await _shot("versus")
	battle._close_intro()
	await get_tree().create_timer(1.0).timeout
	var pb = ArenaBuilder.tower_positions(GameManager.Team.PLAYER)
	var eb = ArenaBuilder.tower_positions(GameManager.Team.ENEMY)
	var mid = ArenaBuilder.CENTER
	var plays = [["vaca_brava", GameManager.Team.PLAYER, mid + Vector2(-60, 90)], ["molecada", GameManager.Team.PLAYER, mid + Vector2(-60, 140)],
		["boi_marretao", GameManager.Team.ENEMY, mid + Vector2(-70, -60)], ["abelhas", GameManager.Team.ENEMY, mid + Vector2(40, -80)],
		["corujao", GameManager.Team.PLAYER, mid + Vector2(120, 100)], ["robo_balde", GameManager.Team.ENEMY, mid + Vector2(120, -150)],
		["canhao_pipoca", GameManager.Team.PLAYER, pb[1] + Vector2(-40, -70)], ["galo_e_cia", GameManager.Team.PLAYER, mid + Vector2(20, 60)],
		["capivarada", GameManager.Team.ENEMY, mid + Vector2(-20, -120)], ["et_abdutor", GameManager.Team.ENEMY, eb[0] + Vector2(0, 80)]]
	for p in plays:
		var c: CardData = Catalogo.card(p[0])
		battle.spawn_unit(c.unit_scene, p[1], p[2], c)
	battle.select_card(Catalogo.card("canhao_pipoca"), 0)
	await get_tree().create_timer(1.2).timeout
	await _shot("batalha_1")
	battle.select_card(Catalogo.card("geada"), 0)
	battle.cast_spell(Catalogo.card("lamacal").spell_data, mid + Vector2(-60, -40), GameManager.Team.PLAYER)
	battle.cast_spell(Catalogo.card("moda_de_viola").spell_data, mid + Vector2(-60, 110), GameManager.Team.PLAYER)
	await get_tree().create_timer(2.5).timeout
	battle.cast_spell(Catalogo.card("raio").spell_data, mid + Vector2(120, -150), GameManager.Team.PLAYER)
	await get_tree().create_timer(0.12).timeout
	await _shot("batalha_2")
	await get_tree().create_timer(5.0).timeout
	await _shot("batalha_3")
	battle._end_match(GameManager.Team.ENEMY)
	await get_tree().create_timer(0.3, true, false, true).timeout
	await _shot("resultado")
	get_tree().quit()
