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
