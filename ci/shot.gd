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

	var hub = load("res://Scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().create_timer(0.6).timeout
	for tab in 5:
		hub._go_tab(tab)
		await get_tree().create_timer(0.5).timeout
		await _shot("hub_%d" % tab)
	hub._go_tab(1)
	hub._show_card_popup(Catalogo.card("vaca_brava"))
	await get_tree().create_timer(0.4).timeout
	await _shot("carta")
	for n in get_tree().get_nodes_in_group("hub_popup"):
		n.queue_free()
	hub._show_loot("Baú do Celeiro", Progresso.roll_chest(2), Color("#c84838"))
	await get_tree().create_timer(1.6).timeout
	await _shot("bau")
	hub.queue_free()
	await get_tree().process_frame

	MatchSetup.mode = MatchSetup.MODE_1V1
	MatchSetup.next_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[0])
	var battle = load("res://Scenes/batlhe_scene.tscn").instantiate()
	get_tree().root.add_child(battle)
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
	await get_tree().create_timer(1.2).timeout
	await _shot("batalha_1")
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
