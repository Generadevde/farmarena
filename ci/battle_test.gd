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
		if c.card_name.to_lower().contains("cow"):
			cow_card = c
		if c.card_name.to_lower() == "chicken":
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
	var sheet = Image.create_empty(6 * 136, 4 * 136, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("4f7f2f"))
	for i in 24:
		var img = CardGenerator.generate_styled_sprite(1000 + i * 7)
		img.resize(128, 128, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i((i % 6) * 136 + 4, (i / 6) * 136 + 4))
	sheet.save_png("user://arte_gerada.png")
	print("TESTE arte salva em ", ProjectSettings.globalize_path("user://arte_gerada.png"))


func _freeze_test():
	await get_tree().process_frame
	await get_tree().process_frame
	battle.get_node("Timer").stop()
	print("TESTE nações no Criador: ", NationDatabase.all_nations.map(func(n): return n.nation_name if n else "null"))
	var card: CardData = null
	for c in CardDatabase.all_cards:
		if c != null and c.card_name == "Chicken":
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
	print("RESULTADO congelar: andou congelada=", snapped(moved_frozen, 0.1), "px (esperado ~0) | travada=", frozen_flag,
		" | depois andou ", snapped(moved_after, 0.1), "px (esperado >0, imunidade)")


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
		var watch = c.card_name.contains("Cascalho") or c.card_name.contains("Bandido")
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
