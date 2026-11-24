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
	if mode in ["empurrao", "congelar", "regras", "tornado", "antigas", "habilidades", "efeitos", "corpo", "torres", "novas", "geral"]:
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
	if mode == "geral":
		await _general_audit()
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
	_check("nível 1 tem 1 espaço de módulo", Progresso.module_loadout().size() == 1 and _find_text(hub, "Espaços de módulo: 1 de 2") and _find_text(hub, "abre no nível 8"),
		"módulos=%d" % Progresso.module_loadout().size())
	Regras.set_tune("slots", 2)
	hub._queue_refresh()
	await get_tree().create_timer(0.5).timeout
	var lo3 = Progresso.module_loadout()
	var pts3 := {}
	for o in lo3:
		pts3[int(o["ponto"])] = true
	_check("no máximo 2 espaços: a tela mostra 2 módulos, cada um num ponto", Regras.MODULE_SLOTS_MAX == 2 and lo3.size() == 2 and pts3.size() == 2 and _find_text(hub, "Casa Grande + 2 módulos"), str(lo3.map(func(o): return [o["base"].base_name, o["ponto"]])))
	hub._use_module(1, mods[0])
	hub._use_module(0, mods[0])
	await get_tree().create_timer(0.5).timeout
	_check("dá pra pôr dois iguais", Progresso.module_loadout().all(func(o): return o["base"] == mods[0]) and _find_text(hub, "EM USO ×2"))
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
	await get_tree().process_frame
	# lista do Criador por classificação: tem bloco de mais de um tipo, com grade de cartas, e fecha/abre
	cr._show_custom_only = false
	cr._search = ""
	cr._closed_groups = {}
	cr._fill_card_rows()
	await get_tree().process_frame
	await get_tree().process_frame
	var heads_n = 0
	var grids_n = 0
	var cards_n = 0
	for n in cr._rows_box.get_children():
		if n is Button:
			heads_n += 1
		elif n is GridContainer:
			grids_n += 1
			cards_n += n.get_child_count()
	cr._closed_groups = {"bando": true, "tanque": true}
	cr._fill_card_rows()
	await get_tree().process_frame
	await get_tree().process_frame
	var grids_closed = 0
	for n in cr._rows_box.get_children():
		grids_closed += 1 if n is GridContainer else 0
	cr._closed_groups = {}
	_check("lista do Criador por classificação (grade que abre e fecha)", heads_n >= 4 and grids_n == heads_n and cards_n >= 20 and grids_closed < grids_n,
		"%d títulos, %d grades, %d cartas, %d grades com 2 fechadas" % [heads_n, grids_n, cards_n, grids_closed])
	# duplicar: a cópia vira carta nova, igual, e a original não muda
	var src_c: CardData = Catalogo.card("vaca_brava")
	var src_hp = DeckBuilder.get_unit_stats(src_c).hp
	var n_cards = CardDatabase.all_cards.size()
	var cp = CustomContent.copy_card_pack(src_c)
	cp["stats"].hp = src_hp + 123
	var copied: CardData = CustomContent.save_card(cp, true)
	var copy_ok = copied != null and copied != src_c and copied.resource_path != src_c.resource_path and CustomContent.is_custom(copied) \
		and copied.card_name == src_c.card_name + " (cópia)" and DeckBuilder.get_unit_stats(copied).hp == src_hp + 123 \
		and DeckBuilder.get_unit_stats(src_c).hp == src_hp and CardDatabase.all_cards.size() == n_cards + 1 and copied.unit_scene != src_c.unit_scene
	if copied != null:
		CustomContent.delete_custom_card(copied)
	_check("duplicar carta: a cópia é carta nova e a original não muda", copy_ok)
	# duplicar módulo, e a lista de módulos em grade por função
	var src_b: BaseData = BotSimulator.available_bases[0]
	var n_bases = CustomContent.all_bases([]).size()
	var bp = CustomContent.copy_base_pack(src_b)
	bp["base"].base_hp = src_b.base_hp + 77
	var copied_b: BaseData = CustomContent.save_base(bp, true)
	var copy_b_ok = copied_b != null and copied_b != src_b and CustomContent.is_custom(copied_b) and copied_b.base_name == src_b.base_name + " (cópia)" \
		and copied_b.base_hp == src_b.base_hp + 77 and CustomContent.all_bases([]).size() == n_bases + 1
	cr._tab = 1
	cr._show_list()
	await get_tree().process_frame
	await get_tree().process_frame
	var mod_grids = 0
	var mod_cells = 0
	for n in cr._body.get_children():
		if n is GridContainer:
			mod_grids += 1
			mod_cells += n.get_child_count()
	if copied_b != null:
		CustomContent.delete_custom_base(copied_b)
	cr._tab = 0
	cr._show_list()
	await get_tree().process_frame
	_check("duplicar módulo e lista de módulos em grade por função", copy_b_ok and mod_grids >= 2 and mod_cells == n_bases + 1, "cópia=%s, %d grades, %d módulos (esperado %d)" % [str(copy_b_ok), mod_grids, mod_cells, n_bases + 1])
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
	var shield_ab = null
	for grp in cr.ABILITIES:
		for ab_x in grp[1]:
			if ab_x[1] == "has_shield":
				shield_ab = ab_x
	cr._toggle_ability(shield_ab, true)   # Escudo
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
	# ESPAÇOS por nível dos módulos: 1 do nível 1 ao 7, 2 do 8 em diante (máximo 2)
	_check("espaços por nível: 1-7 = 1, 8+ = 2", [1, 4, 7, 8, 12, 14].map(func(lv): return Regras.module_slots(lv)) == [1, 1, 1, 2, 2, 2],
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
	# POSIÇÃO: frente leva 10% menos dano, trás nada; cair na FRENTE abre bolsão, atrás não
	bot_mods[0].module_point = 1
	bot_mods[1].module_point = 4
	var arm_ok = true
	var arm_txt = ""
	for bm in [bot_mods[0], bot_mods[1]]:
		var dr0 = bm.base_data.damage_reduction_percent
		var hp0 = bm.hp
		bm.take_damage(1000)
		var lost = hp0 - bm.hp
		var want = 1000.0 * (1.0 - clampf(dr0 + Regras.point_armor(bm.module_point), 0.0, 0.9))
		arm_txt += "ponto %d perdeu %d (esperado %d) " % [bm.module_point, lost, want]
		if absf(lost - want) > 2.0:
			arm_ok = false
	_check("frente leva 10% menos dano, trás normal", arm_ok and Regras.point_armor(1) == 0.10 and Regras.point_armor(3) == 0.05 and Regras.point_armor(6) == 0.0, arm_txt)
	var mid_enemy = ArenaBuilder.module_position(GameManager.Team.ENEMY, 1)
	var probe = Vector2(mid_enemy.x, mid_enemy.y + 60.0)   # entre o módulo da frente do bot e o rio
	var probe_area = battle.spawn_player_area
	var before_pocket = battle.can_spawn(probe, probe_area)
	bot_mods[1].take_damage(999999)
	await get_tree().process_frame
	var after_back = battle.can_spawn(probe, probe_area)
	bot_mods[0].take_damage(999999)
	await get_tree().process_frame
	var after_front = battle.can_spawn(probe, probe_area)
	var far_probe = Vector2(mid_enemy.x + 200.0, mid_enemy.y + 60.0)
	_check("módulo da frente caiu: abre bolsão pequeno pro adversário (o de trás não)", !before_pocket and !after_back and after_front \
		and !battle.can_spawn(far_probe, probe_area) and !battle.can_spawn(mid_enemy + Vector2(0, -80), probe_area),
		"antes %s, trás caiu %s, frente caiu %s" % [before_pocket, after_back, after_front])
	# soltar tropa no bolsão: ela NASCE lá (antes voltava pro seu lado)
	var pk_card: CardData = Catalogo.card("caramelo")
	battle.spawn_unit(pk_card.unit_scene, GameManager.Team.PLAYER, probe, pk_card)
	await get_tree().process_frame
	var in_pk_units = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == GameManager.Team.PLAYER \
		and battle.in_pocket(x.global_position, GameManager.Team.PLAYER))
	_check("tropa solta no bolsão nasce lá", in_pk_units.size() >= 1, "%d no bolsão" % in_pk_units.size())
	# bot usa o bolsão: com bolsão do JOGADOR aberto no campo do bot, o robô do jogador (time PLAYER) solta lá
	var fast: CardData = Catalogo.card("caramelo")
	var in_pk = 0
	for k in 40:
		var bp = battle.bot_pocket_pos(fast, DeckBuilder.get_unit_stats(fast), GameManager.Team.PLAYER, mid_enemy.x, Vector2(mid_enemy.x, 0))
		if battle.in_pocket(bp, GameManager.Team.PLAYER):
			in_pk += 1
	_check("robô solta tropa no bolsão (às vezes)", in_pk >= 10 and in_pk < 40, "%d de 40" % in_pk)
	# construção: nunca em cima de módulo/base nem de outra construção
	var my_main_pos = my_main[0].global_position
	var free_far = battle.building_spot_free(ArenaBuilder.CENTER + Vector2(-120, 120))
	var spot = battle.free_building_spot(my_main_pos, battle.spawn_player_area)
	_check("construção não nasce em cima de módulo/base (robô acha outro lugar)", !battle.building_spot_free(my_main_pos) and free_far \
		and spot != Vector2.INF and battle.building_spot_free(spot), "livre longe %s, achou %s" % [free_far, spot])
	_check("derrubar os 2 módulos do bot não acaba a partida", !battle.match_over)
	_check("placar 2 x 1 pra mim", battle.time_up_loser() == GameManager.Team.ENEMY, str(battle.time_up_loser()))
	# BASE PRINCIPAL: caiu, acabou -- mesmo com o placar a favor
	# feitiço de gelo em cima da Casa Grande: ela congela (para de atirar) pelo tempo do efeito
	var ice_m = SpellData.new()
	ice_m.radius = 120.0
	ice_m.status_effect = UnitData.OnHitEffect.FREEZE
	ice_m.status_effect_duration = 3.0
	battle.cast_spell(ice_m, my_main[0].global_position, GameManager.Team.ENEMY)
	await get_tree().create_timer(0.3).timeout
	_check("feitiço de gelo congela a Casa Grande", my_main[0].is_frozen(), str(my_main[0].is_frozen()))
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
	# SEM PONTE DO MEIO: a tropa solta no meio atravessa por uma das pontes do lado
	var from_mid = Vector2(c.x, c.y + 60)
	var path_mid = NavigationServer2D.map_get_path(map_rid, from_mid, to, true, 0b01)
	var uses_center = Array(path_mid).any(func(pt): return abs(pt.y - c.y) <= ArenaBuilder.RIVER_HALF - 4 and abs(pt.x - c.x) <= ArenaBuilder.BRIDGE_X * 0.5)
	var mid_side = Array(path_mid).any(func(pt): return abs(pt.y - c.y) <= ArenaBuilder.RIVER_HALF + 1 and abs(abs(pt.x - c.x) - ArenaBuilder.BRIDGE_X) <= ArenaBuilder.BRIDGE_HALF + 1)
	print("RESULTADO ponte do meio: atravessa pelo meio do rio? ", uses_center, " | vai por uma ponte do lado? ", mid_side)
	if uses_center or !mid_side:
		_aud_bad.append("meio do rio: tropa do meio passou pelo meio=%s, pela ponte do lado=%s" % [str(uses_center), str(mid_side)])
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
	# ÁREA SÓ DE CHÃO não pega voador (bug: carta de dano em área terrestre acertava voador perto)
	await _wipe()
	var gd = await _dummy(E, mid + Vector2(0, -40))
	var air = (await _put("corujao", E, mid + Vector2(12, -40)))[0]
	air.stats = air.stats.duplicate()
	air.stats.hp = 99999
	air.current_hp = 99999
	air.stats.move_speed = 0.0
	air.stats.damage = 0
	var splasher = (await _put_card(_make({"is_aoe": true, "aoe_radius": 90.0, "damage": 200, "hp": 99999, "target_type": UnitData.TargetType.GROUND}), P, mid))[0]
	await get_tree().create_timer(4.0).timeout
	_check("área só de chão não acerta voador", is_instance_valid(air) and air.current_hp >= 99999 and is_instance_valid(gd) and gd.current_hp < 99999,
		"voador %s, chão %s" % [str(air.current_hp) if is_instance_valid(air) else "morreu", str(gd.current_hp) if is_instance_valid(gd) else "morreu"])

	await _wipe()
	gd = await _dummy(E, mid + Vector2(0, -120))
	air = (await _put("corujao", E, mid + Vector2(12, -120)))[0]
	air.stats = air.stats.duplicate()
	air.stats.hp = 99999
	air.current_hp = 99999
	air.stats.move_speed = 0.0
	air.stats.damage = 0
	await _put_card(_make({"is_ranged": true, "attack_range": 160.0, "move_speed": 0.0, "is_aoe": true, "aoe_radius": 90.0, "damage": 200, "hp": 99999,
		"target_type": UnitData.TargetType.GROUND}), P, mid)
	await get_tree().create_timer(4.0).timeout
	_check("tiro em área só de chão não acerta voador", is_instance_valid(air) and air.current_hp >= 99999 and is_instance_valid(gd) and gd.current_hp < 99999,
		"voador %s, chão %s" % [str(air.current_hp) if is_instance_valid(air) else "morreu", str(gd.current_hp) if is_instance_valid(gd) else "morreu"])

	# VÁRIOS PROJÉTEIS POR ATAQUE: leque (3 juntos) e rajada (3 em sequência)
	for mode_burst in [0.0, 0.15]:
		await _wipe()
		var tgt = await _dummy(E, mid + Vector2(0, -120))
		# 1 ataque só (intervalo enorme): tem que chegar 3 x 10 de dano
		var sh = (await _put_card(_make({"is_ranged": true, "attack_range": 160.0, "move_speed": 0.0, "damage": 10, "attack_speed": 60.0, "hp": 99999,
			"projectiles_per_attack": 3, "projectile_burst_delay": mode_burst}), P, mid))[0]
		await get_tree().create_timer(3.5).timeout
		var lost = 99999 - tgt.current_hp if is_instance_valid(tgt) else 0
		_check("vários projéteis por ataque (%s)" % ("rajada" if mode_burst > 0 else "leque"), lost >= 25 and lost <= 35, "dano %d em 1 ataque (1 tiro = 10)" % lost)

	# TIRO QUE PODE ERRAR + DANO EM ÁREA: errou o alvo, mas explode onde caiu
	await _wipe()
	var runner = await _dummy(E, mid + Vector2(0, -150))
	var bystander = await _dummy(E, mid + Vector2(45, -150))
	var pj = Projectile.new()
	pj.target = runner
	pj.damage = 100
	pj.speed = 300.0
	pj.can_miss = true
	pj.is_aoe = true
	pj.aoe_radius = 70.0
	pj.attacker_team = P
	battle.add_child(pj)
	pj.global_position = mid
	await get_tree().physics_frame
	await get_tree().physics_frame
	runner.global_position = mid + Vector2(-200, -150)   # o alvo saiu do lugar: o tiro erra
	await get_tree().create_timer(1.5).timeout
	_check("tiro que erra ainda dá o dano em área onde cai", is_instance_valid(bystander) and bystander.current_hp < 99999 and is_instance_valid(runner) and runner.current_hp >= 99999,
		"quem estava do lado: %s | quem fugiu: %s" % [str(bystander.current_hp) if is_instance_valid(bystander) else "-", str(runner.current_hp) if is_instance_valid(runner) else "-"])

	# BOWLER: pedra rola em linha e pega todo mundo no caminho (só chão), empurrando
	await _wipe()
	var r1 = await _dummy(E, mid + Vector2(0, -90))
	var r2 = await _dummy(E, mid + Vector2(0, -150))
	var rair = (await _put("corujao", E, mid + Vector2(0, -120)))[0]
	rair.stats = rair.stats.duplicate()
	rair.stats.hp = 99999
	rair.current_hp = 99999
	rair.stats.move_speed = 0.0
	rair.stats.damage = 0
	var r2_y0 = r2.global_position.y
	await _put_card(_make({"is_ranged": true, "attack_range": 100.0, "move_speed": 0.0, "damage": 100, "attack_speed": 60.0, "hp": 99999,
		"target_type": UnitData.TargetType.GROUND, "projectile_rolls": true, "projectile_line_distance": 120.0, "projectile_line_knockback": 40.0}), P, mid)
	await get_tree().create_timer(2.5).timeout
	_check("bowler: rola em linha, pega os dois no caminho, não pega voador", is_instance_valid(r1) and r1.current_hp < 99999 and is_instance_valid(r2) and r2.current_hp < 99999 \
		and is_instance_valid(rair) and rair.current_hp >= 99999, "1º %s, 2º %s, voador %s" % [r1.current_hp, r2.current_hp, rair.current_hp])
	# PESCADOR: puxa o alvo que está longe
	await _wipe()
	var far = (await _put("vaca_brava", E, mid + Vector2(0, -190)))[0]
	far.stats = far.stats.duplicate()
	far.stats.move_speed = 0.0
	far.stats.hp = 99999
	far.current_hp = 99999
	var fisher = (await _put_card(_make({"attack_range": 30.0, "move_speed": 0.0, "hp": 99999, "detection_range": 260.0, "hook_pull": true, "hook_range": 240.0}), P, mid))[0]
	var d0 = fisher.global_position.distance_to(far.global_position)
	await get_tree().create_timer(2.0).timeout
	var d1 = fisher.global_position.distance_to(far.global_position) if is_instance_valid(far) else 999.0
	_check("gancho puxa o alvo longe", d1 < d0 - 60.0, "antes %.0f, depois %.0f" % [d0, d1])
	# MONGE: rebate o tiro de volta pra quem atirou
	await _wipe()
	var monk = (await _put_card(_make({"hp": 99999, "move_speed": 0.0, "reflect_projectile_chance": 1.0}), E, mid + Vector2(0, -120)))[0]
	var gunner = (await _put_card(_make({"is_ranged": true, "attack_range": 160.0, "move_speed": 0.0, "damage": 50, "attack_speed": 60.0, "hp": 5000}), P, mid))[0]
	var g_hp0 = gunner.current_hp
	await get_tree().create_timer(2.5).timeout
	_check("monge rebate o tiro", is_instance_valid(monk) and monk.current_hp >= 99999 and is_instance_valid(gunner) and gunner.current_hp < g_hp0,
		"monge %s, atirador %s/%s" % [monk.current_hp, gunner.current_hp, g_hp0])
	# REI ESQUELETO: mortes perto viram almas; com 2, invoca
	await _wipe()
	var king = (await _put_card(_make({"hp": 99999, "move_speed": 0.0, "damage": 0, "collects_souls": true, "souls_needed": 2, "soul_spawn_count": 2}), P, mid))[0]
	king.stats.soul_spawn_scene = Catalogo.card("peao_forcado").unit_scene
	var victims = []
	for k in 2:
		victims.append((await _put("peao_forcado", E, mid + Vector2(40 + k * 20, -40)))[0])
	var before_k = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P).size()
	for vv in victims:
		if is_instance_valid(vv):
			vv.take_damage(999999)
	await get_tree().create_timer(0.5).timeout
	var after_k = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P).size()
	_check("rei esqueleto coleta almas e invoca", after_k >= before_k + 2, "aliados %d -> %d" % [before_k, after_k])

	# ESQUIVA: golpe de tropa às vezes passa batido; feitiço sempre pega
	await _wipe()
	var dg = (await _put_card(_make({"dodge_chance": 0.5, "hp": 99999}), P, mid))[0]
	dg.stats.attack_speed = 99.0
	var hp_a = dg.current_hp
	for k in 200:
		dg.take_damage(10)
	var hits = int(round((hp_a - dg.current_hp) / 10.0))
	dg.set_meta("spell_hit", true)
	var hp_b = dg.current_hp
	for k in 50:
		dg.take_damage(10)
	dg.remove_meta("spell_hit")
	_check("esquiva (metade dos golpes passa batido; feitiço sempre pega)", hits > 60 and hits < 140 and int(hp_b - dg.current_hp) == 500,
		"pegou %d de 200, feitiço %d de 500" % [hits, int(hp_b - dg.current_hp)])
	# ROUBO DE VELOCIDADE: alvo fica lento, ela fica rápida
	await _wipe()
	var thief = (await _put_card(_make({"steals_speed": true, "speed_steal_amount": 0.3, "speed_steal_duration": 3.0, "hp": 5000}), P, mid))[0]
	var slowfoe = (await _put("vaca_brava", E, mid + Vector2(0, -34)))[0]
	slowfoe.stats = slowfoe.stats.duplicate()
	slowfoe.stats.hp = 50000
	slowfoe.current_hp = 50000
	await get_tree().create_timer(2.5).timeout
	_check("rouba velocidade", is_instance_valid(slowfoe) and slowfoe.speed_multiplier < 0.9 and thief.speed_multiplier > 1.1,
		"alvo x%.2f, ladra x%.2f" % [slowfoe.speed_multiplier if is_instance_valid(slowfoe) else -1.0, thief.speed_multiplier])
	# TRANSFORMA na metade da vida
	await _wipe()
	var tf = (await _put_card(_make({"hp": 1000}), P, mid))[0]
	tf.stats.transforms_at_half_hp = true
	tf.stats.half_hp_scene = Catalogo.card("vaca_brava").unit_scene
	var n_before = get_tree().get_nodes_in_group("units").size()
	tf.take_damage(300)
	await get_tree().process_frame
	var still = is_instance_valid(tf) and !tf.is_queued_for_deletion()
	tf.take_damage(300)
	await get_tree().process_frame
	await get_tree().process_frame
	var cows = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and x.stats != null and x.stats.resource_path == Catalogo.card("vaca_brava").unit_scene.instantiate().stats.resource_path)
	_check("transforma na metade da vida", still and !is_instance_valid(tf) and cows.size() >= 1, "ficou com 70%%: %s | virou vaca: %d" % [still, cows.size()])
	# MURALHA: invocações do feitiço nascem em FILA (mesma altura, espalhadas de lado)
	await _wipe()
	var wall_sp = SpellData.new()
	wall_sp.radius = 70.0
	wall_sp.summon_count = 4
	wall_sp.summon_in_line = true
	wall_sp.affects_enemies = false
	wall_sp.summon_scene = Catalogo.card("peao_forcado").unit_scene
	var before_w = get_tree().get_nodes_in_group("units").size()
	battle.cast_spell(wall_sp, mid, P)
	await get_tree().create_timer(0.3).timeout
	var ws = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P)
	var xs = ws.map(func(x): return x.global_position.x)
	var ys = ws.map(func(x): return x.global_position.y)
	_check("muralha: invocação nasce em fila", ws.size() == 4 and xs.max() - xs.min() > 100.0 and ys.max() - ys.min() < 20.0,
		"%d peças, largura %.0f, altura %.0f" % [ws.size(), (xs.max() - xs.min()) if ws.size() > 0 else 0.0, (ys.max() - ys.min()) if ws.size() > 0 else 0.0])
	# REAÇÕES (gatilho + efeito)
	await _wipe()
	var rv = await _dummy(E, mid + Vector2(30, -20))
	var bomb = (await _put_card(_make({"hp": 500, "move_speed": 0.0, "damage": 0, "r1_trigger": 5, "r1_effect": 1, "r1_value": 150.0, "r1_radius": 90.0}), P, mid))[0]
	await get_tree().create_timer(0.3).timeout
	bomb.take_damage(999999)
	await get_tree().create_timer(0.3).timeout
	_check("reação: explode ao morrer", is_instance_valid(rv) and rv.current_hp < 99999, str(rv.current_hp) if is_instance_valid(rv) else "-")
	await _wipe()
	var regen = (await _put_card(_make({"hp": 1000, "move_speed": 0.0, "damage": 0, "r1_trigger": 6, "r1_effect": 3, "r1_value": 200.0, "r1_cooldown": 1.0}), P, mid))[0]
	regen.take_damage(600)
	var hp_low = regen.current_hp
	await get_tree().create_timer(1.6).timeout
	_check("reação: se cura a cada X segundos", regen.current_hp > hp_low, "%d -> %d" % [hp_low, regen.current_hp])
	await _wipe()
	var stone = (await _put_card(_make({"hp": 1000, "move_speed": 0.0, "damage": 0, "r1_trigger": 7, "r1_effect": 4, "r1_value": 300.0, "r1_duration": 5.0}), P, mid))[0]
	await get_tree().create_timer(0.2).timeout
	stone.take_damage(600)
	await get_tree().create_timer(0.2).timeout
	_check("reação: escudo na metade da vida", stone.current_shield > 0, str(stone.current_shield))
	await _wipe()
	var sentry_t = await _dummy(E, mid + Vector2(0, -40))
	await _put_card(_make({"hp": 9999, "move_speed": 0.0, "damage": 0, "r1_trigger": 10, "r1_effect": 1, "r1_value": 120.0, "r1_radius": 80.0, "r1_cooldown": 5.0}), P, mid)
	await get_tree().create_timer(0.4).timeout
	_check("reação: explode quando inimigo chega perto", is_instance_valid(sentry_t) and sentry_t.current_hp < 99999, str(sentry_t.current_hp) if is_instance_valid(sentry_t) else "-")
	await _wipe()
	await _dummy(E, mid + Vector2(0, -30))
	var learner = (await _put_card(_make({"hp": 9999, "move_speed": 0.0, "damage": 10, "attack_speed": 0.3, "r1_trigger": 2, "r1_effect": 19, "r1_value": 50.0}), P, mid))[0]
	await get_tree().create_timer(2.0).timeout
	_check("reação: fica mais forte a cada golpe", learner._react_power > 1.05, "%.2f" % learner._react_power)

	# as 32 PRONTAS rodam sem quebrar (entra, bate, apanha, cai pra 20%, morre)
	var cm = load("res://creator/creator_menu.gd")
	var crashed_free = 0
	for pr in cm.REACT_PRESETS:
		await _wipe()
		await _dummy(E, mid + Vector2(0, -30))
		var u_p = (await _put_card(_make({"hp": 1000, "move_speed": 0.0, "damage": 20, "attack_speed": 0.5,
			"r1_trigger": int(pr[1]), "r1_effect": int(pr[2]), "r1_value": float(pr[3]), "r1_radius": float(pr[4]), "r1_duration": float(pr[5]),
			"r1_chance": float(pr[6]), "r1_cooldown": float(pr[7])}), P, mid))[0]
		u_p.stats.r1_scene = Catalogo.card("peao_forcado").unit_scene
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(u_p):
			u_p.take_damage(800)
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(u_p):
			u_p.take_damage(999999)
		await get_tree().create_timer(0.2).timeout
		crashed_free += 1
	_check("as 32 reações prontas rodam", crashed_free == cm.REACT_PRESETS.size() and cm.REACT_PRESETS.size() == 32, "%d de %d" % [crashed_free, cm.REACT_PRESETS.size()])

	# PRORROGAÇÃO: tempo acabou empatado em torres -> +1 minuto x2,5; a 1ª torre que cair decide
	await _wipe()
	battle.towers_destroyed[GameManager.Team.PLAYER] = 0
	battle.towers_destroyed[GameManager.Team.ENEMY] = 0
	var wt0 = battle.get_node("ProductionTimer").wait_time
	battle._battle_time_remaining = 0.05
	battle._update_battle_timer(0.1)   # o relógio fica parado nos testes: anda ele na mão
	var ot_ok = battle._overtime and !battle.match_over and battle._battle_time_remaining > 50.0
	var wt1 = battle.get_node("ProductionTimer").wait_time
	battle.towers_destroyed[GameManager.Team.ENEMY] = 1
	battle._update_battle_timer(0.1)
	await get_tree().create_timer(0.3).timeout
	_check("prorrogação: +1 minuto, recurso mais rápido, 1ª torre decide", ot_ok and wt1 < wt0 and battle.match_over,
		"prorrogou %s, intervalo %.2f -> %.2f, acabou %s" % [ot_ok, wt0, wt1, battle.match_over])
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
	# batalha normal NUNCA sorteia modificador (eles moram em "Modos malucos")
	var weather_any = 0
	for k in 400:
		weather_any += 1 if MatchSetup.roll_weather() != 0 else 0
	if weather_any != 0 or !MatchSetup.has_method("start_rule_match"):
		_aud_bad.append("batalha normal sorteou modificador %d vezes em 400 (ou falta Modos malucos)" % weather_any)
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
	# MONTADO: cavaleiro em cima da montaria -- a imagem tem os dois (mais pixels que a montaria sozinha
	# e gente acima do lombo), e sem cavaleiro continua igual a antes
	var only_mount: Image = SpriteForge.make_image({"quatro": "cavalo", "cabeca": "cavalo"}, SpriteForge.DEFAULT_PALETTE)
	var mounted: Image = SpriteForge.make_image({"quatro": "cavalo", "montaria_cabeca": "cavalo", "corpo": "armadura", "bracos": "humanos", "cabeca": "humano"}, SpriteForge.DEFAULT_PALETTE)
	var px_a = 0
	var px_b = 0
	var top_b = 0
	for yy in 48:
		for xx in 48:
			px_a += 1 if only_mount.get_pixel(xx, yy).a > 0.0 else 0
			if mounted.get_pixel(xx, yy).a > 0.0:
				px_b += 1
				top_b += 1 if yy < 14 and xx < 30 else 0
	if px_b < px_a + 60 or top_b < 40:
		_aud_bad.append("montado: %d pixels contra %d da montaria, %d do cavaleiro em cima" % [px_b, px_a, top_b])
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
	# conserta e cúpula (mecânicas de construção)
	await _wipe()
	var mender = await _dummy(P, mid + Vector2(0, 240), 5000)
	mender.stats.unit_type = UnitData.UnitType.BUILDING
	mender.stats.repairs_buildings = true
	mender.stats.repair_amount = 200
	mender.stats.repair_interval = 0.4
	mender.stats.ward_allies = true
	mender.stats.ward_reduction = 0.5
	var broken = await _dummy(P, mid + Vector2(50, 250), 5000)
	broken.stats.unit_type = UnitData.UnitType.BUILDING
	broken.current_hp = 1000
	var troop = await _dummy(P, mid + Vector2(-40, 250), 5000)     # tropa não é consertada
	troop.current_hp = 1000
	var far_b = await _dummy(P, mid + Vector2(-250, 380), 5000)
	far_b.stats.unit_type = UnitData.UnitType.BUILDING
	far_b.current_hp = 1000
	await get_tree().create_timer(1.2).timeout
	_check("conserta só construção aliada perto", broken.current_hp > 1000 and troop.current_hp == 1000 and far_b.current_hp == 1000, "%d %d %d" % [broken.current_hp, troop.current_hp, far_b.current_hp])
	var w_before = [troop.current_hp, far_b.current_hp, mender.current_hp]
	troop.take_damage(200)
	far_b.take_damage(200)
	mender.take_damage(200)
	_check("cúpula tira dano de quem está perto (não de longe, nem dela mesma)", w_before[0] - troop.current_hp == 100 and w_before[1] - far_b.current_hp == 200 and w_before[2] - mender.current_hp == 200,
		"%s" % str([w_before[0] - troop.current_hp, w_before[1] - far_b.current_hp, w_before[2] - mender.current_hp]))
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
	var sniper_ranged: bool = snipers[0].stats.is_ranged
	for sn in snipers:
		sn.stats = sn.stats.duplicate()
		sn.stats.target_type = UnitData.TargetType.BUILDING
		sn.stats.is_aoe = true
		sn.stats.aoe_radius = 60.0
		sn.stats.attack_range = 260.0
		sn.stats.detection_range = 320.0
		sn.stats.move_speed = 0.0
		sn.stats.damage = 1000   # dano bem diferente do da torre aliada (que também atira no intruso)
		sn.stats.hp = 99999      # a torre inimiga às vezes alcança: o atirador não pode morrer no meio do teste
		sn.current_hp = 99999
		sn._reset_aggro()   # o alvo pego antes de virar "só construção" não vale
	var hut = await _dummy(E, mid + Vector2(0, 30))
	hut.stats.unit_type = UnitData.UnitType.BUILDING
	var blocker = await _dummy(E, mid + Vector2(0, 110))    # colado no atirador, no caminho do tiro
	var beside = await _dummy(E, mid + Vector2(24, 30))    # colado na construção (pegaria o dano em área)
	await get_tree().create_timer(4.0).timeout
	_check("quem só ataca construção acerta a construção e nenhuma tropa", sniper_ranged and hut.current_hp <= 99999 - 1000 and blocker.current_hp > 99999 - 1000 and beside.current_hp > 99999 - 1000,
		"atira=%s construcao=%d no_caminho=%d do_lado=%d" % [str(sniper_ranged), hut.current_hp, blocker.current_hp, beside.current_hp])
	# animações e efeitos: todos os jeitos de andar, bater e morrer e todos os estilos de feitiço rodam sem erro
	await _wipe()
	var US = load("res://Scripts/unit_base.gd")
	var actor = (await _put("vaca_brava", P, mid + Vector2(0, 150)))[0]
	actor.stats = actor.stats.duplicate()
	var dummy_t = await _dummy(E, mid + Vector2(0, 110))
	for g in US.GAIT_NAMES.size():
		actor._gait = g
		actor._walk_anim(0.05, true)
		actor._walk_anim(0.05, false)
	actor.target = dummy_t
	for h in US.HIT_NAMES.size():
		actor._hit_style = h
		actor._attack_anim()
	for dth in US.DEATH_NAMES.size():
		actor.stats.anim_death = dth
		actor._death_fx()
	for en in US.ENTRY_NAMES.size():
		actor.stats.anim_entry = en
		actor._entry_fx(26.0)
	for stl in Fx.STYLE_NAMES.size():
		Fx.styled(actor.get_parent(), mid, 80.0, Color(1, 0.5, 0.2), stl, 0.0 if stl % 2 == 0 else 1.0)
	await get_tree().create_timer(1.4).timeout
	actor.stats.anim_gait = US.Gait.QUICA + 1
	actor.stats.anim_hit = US.Hit.TREMOR + 1
	var re = (await _put("vaca_brava", P, mid + Vector2(60, 150)))[0]
	_check("animações e estilos de feitiço rodam, e a lista do Criador bate com o código", US.GAIT_NAMES.size() == US.Gait.size() and US.HIT_NAMES.size() == US.Hit.size() and Fx.STYLE_NAMES.size() == Fx.STYLE_COLORS.size() and is_instance_valid(re),
		"%d/%d %d/%d %d/%d" % [US.GAIT_NAMES.size(), US.Gait.size(), US.HIT_NAMES.size(), US.Hit.size(), Fx.STYLE_NAMES.size(), Fx.STYLE_COLORS.size()])
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


# ---------------------------------------------------------------- GERAL DAS HABILIDADES
## As habilidades do Criador que não tinham teste, mais as novas (salto, vários avanços,
## investida, esquenta, acelera perto do alvo). Cada uma numa cena pequena e medida.
func _hits_on(victim, seconds: float) -> Array:
	var drops: Array = []
	var last = victim.current_hp
	var t = 0.0
	while t < seconds:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if !is_instance_valid(victim):
			break
		if victim.current_hp < last:
			drops.append(int(last - victim.current_hp))
		last = victim.current_hp
	return drops


func _top_speed(u, seconds: float) -> float:
	var top = 0.0
	var t = 0.0
	while t < seconds:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if is_instance_valid(u):
			top = maxf(top, u.velocity.length())
	return top


func _general_audit():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	battle.get_node("Timer").stop()
	battle.set_process(false)
	battle.get_node("ProductionTimer").stop()
	_aud_bad.clear()
	_aud_ok.clear()
	var P = GameManager.Team.PLAYER
	var E = GameManager.Team.ENEMY
	for b in get_tree().get_nodes_in_group("enemy_base") + get_tree().get_nodes_in_group("player_base"):
		b.max_hp = 9999999
		b.hp = 9999999
		b.set_process(false)          # torre nenhuma atira: só a habilidade em teste mexe na vida
		b.set_physics_process(false)
	var mid = ArenaBuilder.CENTER + Vector2(135, 150)
	var anchor: Vector2 = get_tree().get_first_node_in_group("player_base").global_position
	var u
	var d
	var drops: Array

	# 1) investida do príncipe: corre mais enquanto carrega e o golpe sai em dobro
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -90))
	u = (await _put_card(_make({"charge_attack": true, "charge_distance_needed": 50.0, "charge_damage_multiplier": 2.0, "charge_speed_mult": 2.0}), P, mid + Vector2(0, 150)))[0]
	var cues := {}
	var sp_charge = 0.0
	drops = []
	var last_hp = d.current_hp
	for k in 90:
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(u):
			sp_charge = maxf(sp_charge, u.velocity.length())
			if u.ability_cue != "":
				cues[u.ability_cue] = true
		if d.current_hp < last_hp:
			drops.append(int(last_hp - d.current_hp))
		last_hp = d.current_hp
	_check("investida: corre mais e bate em dobro", sp_charge >= 95.0 and !drops.is_empty() and drops[0] >= 110, "velocidade %d (normal 55), golpes %s" % [int(sp_charge), str(drops.slice(0, 3))])
	_check("animação: mostra que está acelerando e que o golpe forte está pronto", cues.keys().any(func(c): return "acelerando" in c) and cues.keys().any(func(c): return "golpe forte" in c or "carregando" in c), str(cues.keys()))

	# 2) primeiro ataque mais forte
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"first_attack_bonus": true, "first_attack_multiplier": 3.0}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(d, 3.5)
	_check("1º ataque mais forte", drops.size() >= 2 and drops[0] >= 170 and drops[1] <= 70, str(drops.slice(0, 3)))

	# 3) ataca cada vez mais rápido
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"ramping_attack_speed": true, "attack_speed_ramp_per_hit": 0.25, "attack_speed_ramp_min_multiplier": 0.3}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(d, 6.0)
	_check("ataca cada vez mais rápido", drops.size() >= 8, "%d golpes em 6s (sem a habilidade: ~6)" % drops.size())

	# 4) acelera quando chega perto do alvo (a que parecia não funcionar)
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -90))
	u = (await _put_card(_make({"pre_attack_speed_boost": true, "pre_attack_boost_multiplier": 2.5, "pre_attack_boost_range": 170.0}), P, mid + Vector2(0, 170)))[0]
	# anda até dar o primeiro golpe: a velocidade longe do alvo é a normal, e perto dele passa do dobro
	var sp_far = 0.0
	var sp_near = 0.0
	var hit_at = -1.0
	var t_p = 0.0
	while t_p < 9.0 and hit_at < 0.0:
		await get_tree().create_timer(0.05).timeout
		t_p += 0.05
		if !is_instance_valid(u):
			break
		if u.global_position.distance_to(d.global_position) > 215.0:
			sp_far = maxf(sp_far, u.velocity.length())
		else:
			sp_near = maxf(sp_near, u.velocity.length())
		if d.current_hp < 99999:
			hit_at = t_p
	_check("acelera quando chega perto do alvo", sp_far <= 75.0 and sp_near >= 110.0 and hit_at >= 0.0, "longe %d, perto %d, 1º golpe em %.1fs" % [int(sp_far), int(sp_near), hit_at])

	# 5) executa alvo fraco
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0), 1000)
	d.current_hp = 300
	u = (await _put_card(_make({"execute_threshold": 0.5, "execute_damage_mult": 3.0}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(d, 2.5)
	_check("executa alvo fraco", !drops.is_empty() and drops[0] >= 170, str(drops.slice(0, 2)))

	# 6) projétil que atravessa: acerta o alvo e quem está atrás na linha
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -20))
	var behind = await _dummy(E, mid + Vector2(0, -75))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 150.0, "projectile_pierces": true, "projectile_max_targets": 3, "move_speed": 0.0}), P, mid + Vector2(0, 110)))[0]
	await get_tree().create_timer(3.0).timeout
	_check("projétil atravessa", d.current_hp < 99999 and behind.current_hp < 99999, "%d %d" % [d.current_hp, behind.current_hp])

	# 7) projétil que se divide
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -20))
	var side_a = await _dummy(E, mid + Vector2(60, -20))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 150.0, "projectile_splits": true, "projectile_split_count": 2, "projectile_split_range": 120.0, "move_speed": 0.0}), P, mid + Vector2(0, 110)))[0]
	u.target = d
	await get_tree().create_timer(3.0).timeout
	_check("projétil se divide", d.current_hp < 99999 and side_a.current_hp < 99999, "%d %d" % [d.current_hp, side_a.current_hp])

	# 8) redução de dano
	await _wipe()
	u = (await _put_card(_make({"damage_reduction_percent": 0.5, "hp": 2000}), P, mid + Vector2(0, 40)))[0]
	var hp0 = u.current_hp
	u.take_damage(200)
	_check("redução de dano", hp0 - u.current_hp == 100, str(hp0 - u.current_hp))

	# 9) regenera vida
	await _wipe()
	u = (await _put_card(_make({"passive_regen": true, "regen_amount": 50, "regen_interval": 0.5, "hp": 2000}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(1000)
	hp0 = u.current_hp
	await get_tree().create_timer(1.6).timeout
	_check("regenera vida", is_instance_valid(u) and u.current_hp >= hp0 + 100, "%d -> %d" % [hp0, u.current_hp if is_instance_valid(u) else -1])

	# 10) cura ao matar
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0), 30)
	u = (await _put_card(_make({"heals_on_kill": true, "heal_on_kill_amount": 300, "hp": 2000}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(1000)
	hp0 = u.current_hp
	await get_tree().create_timer(2.5).timeout
	_check("cura ao matar", is_instance_valid(u) and u.current_hp >= hp0 + 250, "%d -> %d" % [hp0, u.current_hp if is_instance_valid(u) else -1])

	# 11) ressuscita 1x
	await _wipe()
	u = (await _put_card(_make({"can_resurrect": true, "resurrect_hp_percent": 0.5, "hp": 1000}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(99999)
	await get_tree().create_timer(0.3).timeout
	var alive1 = is_instance_valid(u) and u.current_hp > 0
	if alive1:
		u.take_damage(99999)
	await get_tree().create_timer(0.3).timeout
	_check("ressuscita 1x (e só 1x)", alive1 and (!is_instance_valid(u) or u.current_hp <= 0 or u.is_queued_for_deletion()), "voltou=%s" % str(alive1))

	# 12) reflete dano
	await _wipe()
	u = (await _put_card(_make({"reflects_damage": true, "reflect_damage_percent": 0.5, "hp": 9000, "damage": 5}), P, mid + Vector2(0, 40)))[0]
	var foe = (await _put_card(_make({"hp": 5000, "damage": 100}), E, mid + Vector2(0, 0)))[0]
	await get_tree().create_timer(3.5).timeout
	_check("reflete dano", is_instance_valid(foe) and (5000 - foe.current_hp) >= 100, "o agressor perdeu %d" % (5000 - foe.current_hp if is_instance_valid(foe) else -1))

	# 13) e 14) imune a empurrão e a puxão
	await _wipe()
	u = (await _put_card(_make({"immune_to_knockback": true, "immune_to_pull": true, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	var free_u = (await _put_card(_make({"move_speed": 0.0}), P, mid + Vector2(120, 40)))[0]
	await get_tree().create_timer(0.2).timeout
	var p_u = u.global_position
	var p_f = free_u.global_position
	u.apply_knockback(u.global_position + Vector2(0, -30), 70.0)
	free_u.apply_knockback(free_u.global_position + Vector2(0, -30), 70.0)
	await get_tree().create_timer(0.8).timeout
	var kb_ok = u.global_position.distance_to(p_u) < 6.0 and free_u.global_position.distance_to(p_f) > 20.0
	p_u = u.global_position
	u.apply_pull(u.global_position + Vector2(0, -120), 70.0)
	await get_tree().create_timer(0.8).timeout
	_check("imune a empurrão e a puxão", kb_ok and u.global_position.distance_to(p_u) < 6.0, "empurrão ok=%s, puxão moveu %d" % [str(kb_ok), int(u.global_position.distance_to(p_u))])

	# 15) imune enquanto anda
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -160))
	u = (await _put_card(_make({"immune_while_moving": true, "hp": 2000, "detection_range": 400.0}), P, mid + Vector2(0, 170)))[0]
	var moved_at = -1.0
	var t_m = 0.0
	while t_m < 3.0 and moved_at < 0.0:      # espera ela sair do lugar (tem o tempinho de entrada em campo)
		await get_tree().create_timer(0.05).timeout
		t_m += 0.05
		if u.velocity.length() > 20.0 and u._really_moving:
			moved_at = t_m
	hp0 = u.current_hp
	u.take_damage(300)
	_check("imune enquanto anda", moved_at >= 0.0 and u.current_hp == hp0, "começou a andar em %.1fs, perdeu %d andando" % [moved_at, hp0 - u.current_hp])

	# 16) fúria com vida baixa
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"low_hp_rage_threshold": 0.5, "low_hp_rage_damage_mult": 3.0, "hp": 1000}), P, mid + Vector2(0, 40)))[0]
	u.current_hp = 200
	drops = await _hits_on(d, 2.5)
	_check("fúria com vida baixa", !drops.is_empty() and drops[0] >= 170, str(drops.slice(0, 2)))

	# 17) fúria ao entrar
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"entrance_rage_duration": 5.0, "entrance_rage_damage_mult": 3.0, "entrance_rage_speed_mult": 1.0}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(d, 2.5)
	_check("fúria ao entrar", !drops.is_empty() and drops[0] >= 170, str(drops.slice(0, 2)))

	# 18) onda de choque ao entrar e 19) dano ao chegar (acontecem onde a tropa nasce)
	await _wipe()
	d = await _dummy(E, anchor + Vector2(35, -35))
	await _put_card(_make({"entrance_shockwave_damage": 120, "entrance_shockwave_radius": 90.0}), P, mid)
	await get_tree().create_timer(0.4).timeout
	var shock = 99999 - d.current_hp
	d.current_hp = 99999
	await _put_card(_make({"deals_arrival_damage": true, "arrival_damage": 130, "arrival_damage_radius": 90.0}), P, mid)
	await get_tree().create_timer(1.6).timeout
	_check("onda de choque ao entrar e dano ao chegar", shock >= 120 and 99999 - d.current_hp >= 130, "onda %d, chegada %d" % [shock, 99999 - d.current_hp])

	# 20) fica invisível: de longe não é alvo, de perto é
	await _wipe()
	u = (await _put_card(_make({"can_stealth": true, "stealth_reveal_range": 60.0, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	var watcher_far = await _dummy(E, mid + Vector2(0, -200))
	var watcher_near = await _dummy(E, mid + Vector2(30, 40))
	await get_tree().create_timer(0.2).timeout
	_check("invisível de longe, visível de perto", !watcher_far._is_valid_enemy(u) and watcher_near._is_valid_enemy(u))

	# 21) nasce em qualquer lugar e 22) reforço aéreo (pousa: fica um instante sem agir)
	var any_card = _make({"can_spawn_anywhere": true})
	_check("nasce em qualquer lugar", battle._card_allows_spawn_anywhere(any_card) and !battle._card_allows_spawn_anywhere(_make({})))
	await _wipe()
	var lc = _make({"landing_duration": 1.5})
	battle.spawn_unit(lc.unit_scene, P, mid, lc)
	await get_tree().process_frame
	await get_tree().process_frame
	var lander = null
	for x in get_tree().get_nodes_in_group("units"):
		if x.team == P:
			lander = x
	_check("reforço aéreo pousa antes de agir", lander != null and lander._is_incapacitated(), str(lander != null))

	# 23) invoca ao morrer
	await _wipe()
	var sc = _make({"spawns_on_death": true, "death_spawn_count": 2, "hp": 100})
	u = (await _put_card(sc, P, mid + Vector2(0, 40)))[0]
	u.stats.death_spawn_scene = sc.unit_scene
	u.stats.spawns_on_death = true
	var n_before = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion()).size()
	u.take_damage(99999)
	await get_tree().create_timer(0.6).timeout
	var n_after = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and !x.is_queued_for_deletion() and x.current_hp > 0).size()
	_check("invoca ao morrer", n_after >= 2, "antes %d, depois %d" % [n_before, n_after])

	# 24) provoca: o inimigo larga o alvo mais perto e vem nela
	await _wipe()
	var bait = (await _put_card(_make({"hp": 9000, "move_speed": 0.0}), P, mid + Vector2(20, 20)))[0]
	var taunter = (await _put_card(_make({"forces_aggro": true, "taunt_radius": 200.0, "hp": 9000, "move_speed": 0.0}), P, mid + Vector2(-60, 60)))[0]
	foe = (await _put_card(_make({"hp": 5000, "detection_range": 300.0}), E, mid + Vector2(20, -10)))[0]
	foe._reset_aggro()
	await get_tree().create_timer(2.5).timeout
	_check("provoca", is_instance_valid(foe) and foe.target == taunter, "alvo: %s" % ("a provocadora" if (is_instance_valid(foe) and foe.target == taunter) else ("a isca" if (is_instance_valid(foe) and foe.target == bait) else "outro/nenhum")))

	# 25) explode ao morrer
	await _wipe()
	d = await _dummy(E, mid + Vector2(30, 40))
	u = (await _put_card(_make({"explodes_on_death": true, "death_explosion_damage": 200, "death_explosion_radius": 90.0, "hp": 100}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(99999)
	await get_tree().create_timer(0.5).timeout
	_check("explode ao morrer", 99999 - d.current_hp >= 200, str(99999 - d.current_hp))

	# 26) efeito de maestria: só vale com a carta no nível de maestria
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	var mc = _make({"mastery_effect": UnitData.OnHitEffect.SLOW, "mastery_effect_strength": 0.4, "mastery_effect_duration": 3.0})
	u = (await _put_card(mc, P, mid + Vector2(0, 40)))[0]
	u.card_level = 1
	await _hits_on(d, 2.2)
	var slow_low = d.speed_multiplier
	d.speed_multiplier = 1.0
	u.card_level = PlayerProfile.MASTERY_LEVEL
	await _hits_on(d, 2.2)
	_check("efeito de maestria só no nível de maestria", slow_low >= 0.99 and d.speed_multiplier < 0.99, "nível 1: x%.2f, maestria: x%.2f" % [slow_low, d.speed_multiplier])

	# régua do Criador: as habilidades novas aumentam a "Força" (e carta sem habilidade fica igual)
	var plain = UnitData.new()
	plain.hp = 600
	plain.damage = 60
	var fancy: UnitData = plain.duplicate()
	fancy.pulses = true
	fancy.jump_attack = true
	fancy.aura_buff = true
	_check("régua enxerga as habilidades novas", Regua.ability_power(plain) == 0.0 and Regua.compare(fancy, 30)["geral"] > Regua.compare(plain, 30)["geral"] + 20,
		"sem %d%%, com %d%%" % [Regua.compare(plain, 30)["geral"], Regua.compare(fancy, 30)["geral"]])

	# bots armam a base nos 8 pontos, sem repetir ponto, e módulo sozinho nunca fica no meio da frente
	var seen_points := {}
	var lay_bad: Array = []
	for bn in BotSimulator.roster_names.slice(0, 40):
		var bp_prof: AIProfile = BotLearning.get_or_create_profile(bn)
		for ns in [1, 2, 3]:
			var lo: Array = Progresso.bot_module_loadout(bp_prof, ns)
			var pts: Array = lo.map(func(o): return int(o["ponto"]))
			for pt in pts:
				seen_points[pt] = true
				if pt < 0 or pt >= Regras.MODULE_POINTS.size() or pts.count(pt) > 1:
					lay_bad.append("%s %s" % [bn, str(pts)])
	_check("bots usam os pontos novos da base", lay_bad.is_empty() and seen_points.size() >= 6, "pontos usados %s, problemas %s" % [str(seen_points.keys()), str(lay_bad.slice(0, 3))])

	# escudo segura inteiro o golpe que quebra ele: 1 de vida + 1 de escudo sobrevive à bomba
	await _wipe()
	u = (await _put_card(_make({"hp": 1, "has_shield": true, "shield_amount": 1, "shield_recharge_time": 0.0, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(500)
	var alive_after_bomb = is_instance_valid(u) and u.current_hp == 1 and u.current_shield == 0
	if is_instance_valid(u):
		u.take_damage(1)
	await get_tree().create_timer(0.3).timeout
	_check("escudo segura o golpe que quebra ele (e o próximo mata)", alive_after_bomb and (!is_instance_valid(u) or u.current_hp <= 0 or u.is_queued_for_deletion()), "viva depois da bomba? %s" % str(alive_after_bomb))
	# feitiço de 3 golpes seguidos (duração 0,6 / intervalo 0,2) e a conta do resumo
	var arrows = SpellData.new()
	arrows.duration = 0.6
	arrows.tick_interval = 0.2
	_check("resumo do feitiço conta 3 pulsos em 0,6s / 0,2s", Regua.spell_pulses(arrows) == 3, str(Regua.spell_pulses(arrows)))

	# torre inferno: raio contínuo (sem projétil) com o dano crescendo no mesmo alvo até o teto
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -40))
	u = (await _put_card(_make({"is_ranged": true, "beam_attack": true, "attack_range": 160.0, "damage": 15, "attack_speed": 0.3, "move_speed": 0.0,
		"same_target_ramping_damage": true, "same_target_ramping_damage_per_hit": 0.3, "same_target_ramping_damage_max_multiplier": 8.0}), P, mid + Vector2(0, 80)))[0]
	drops = await _hits_on(d, 10.5)
	var projs = 0
	for n in battle.get_children() + (u.get_parent().get_children() if is_instance_valid(u) else []):
		projs += 1 if n is Projectile else 0
	# cor do raio: a escolhida no Criador vale, pra carta e pra módulo
	var beam_field_ok = CustomContent.unit_extra_fields().any(func(f): return f[0] == "beam_tint" and f[2] == "enum" and f[3].size() == SpellData.TINT_NAMES.size())
	var bd_c = BaseData.new()
	bd_c.beam_tint = 6
	bd_c.beam_heats_red = false
	var some_tower = get_tree().get_first_node_in_group("player_base")
	var keep_bd = some_tower.base_data
	some_tower.base_data = bd_c
	var tower_col: Color = some_tower._beam_color(1.0)
	some_tower.base_data = keep_bd
	_check("cor do raio escolhida no Criador", beam_field_ok and tower_col.is_equal_approx(Color(0.3, 0.5, 1.0)), "campo=%s cor=%s" % [str(beam_field_ok), str(tower_col)])
	_check("raio contínuo: começa em 15, chega no teto de 120 e não solta projétil", drops.size() >= 20 and drops[0] == 15 and drops[-1] == 120 and projs == 0,
		"primeiro %d, último %d, %d golpes, projéteis %d" % [drops[0] if !drops.is_empty() else -1, drops[-1] if !drops.is_empty() else -1, drops.size(), projs])

	# cemitério: o feitiço vai soltando tropa aos poucos, não tudo de uma vez
	await _wipe()
	var grave = SpellData.new()
	grave.radius = 100.0
	grave.duration = 3.0
	grave.tick_interval = 1.0
	grave.summon_interval = 0.5
	grave.summon_count = 0
	grave.summon_scene = _make({"hp": 50, "move_speed": 0.0}).unit_scene
	grave.affects_enemies = false
	battle.cast_spell(grave, mid, P)
	await get_tree().create_timer(0.25).timeout
	var early = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and !x.is_queued_for_deletion()).size()
	await get_tree().create_timer(1.3).timeout
	var midway = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and !x.is_queued_for_deletion()).size()
	await get_tree().create_timer(2.2).timeout
	var total_g = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and !x.is_queued_for_deletion()).size()
	_check("cemitério invoca aos poucos", early == 0 and midway >= 2 and midway < total_g and total_g >= 5 and total_g <= 6, "no começo %d, no meio %d, no fim %d" % [early, midway, total_g])

	# SPARKY: carrega o intervalo inteiro antes do 1º tiro, acerta em área, e o atordoamento zera a carga
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -20))
	var d_side = await _dummy(E, mid + Vector2(40, -20))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 150.0, "damage": 900, "attack_speed": 2.0, "is_aoe": true, "aoe_radius": 70.0, "move_speed": 0.0,
		"charged_shot": true, "detection_range": 300.0}), P, mid + Vector2(0, 100)))[0]
	await get_tree().create_timer(1.2).timeout
	var early_hit = d.current_hp < 99999
	var cue_charging = "carregando tiro" in u.ability_cue
	await get_tree().create_timer(2.2).timeout
	var first_shot = 99999 - d.current_hp >= 900 and 99999 - d_side.current_hp >= 900
	d.current_hp = 99999
	await get_tree().create_timer(1.0).timeout          # metade da 2ª carga...
	u.apply_on_hit_effect(UnitData.OnHitEffect.STUN, 0.0, 0.3, 1.0, 0.0, u.global_position)   # ...e leva um choque: zera
	await get_tree().create_timer(1.6).timeout          # sem o choque o 2º tiro já teria saído
	var reset_ok = d.current_hp == 99999
	await get_tree().create_timer(1.6).timeout
	_check("tiro carregado (Sparky): carrega antes, acerta em área e o atordoamento zera a carga", !early_hit and cue_charging and first_shot and reset_ok and d.current_hp < 99999,
		"tiro cedo=%s, mostrou carregando=%s, 1º tiro em área=%s, zerou=%s, atirou depois=%s" % [str(early_hit), str(cue_charging), str(first_shot), str(reset_ok), str(d.current_hp < 99999)])

	# ================= LEVA "MECÂNICAS DO CLASH"
	# choque ao cair (Mago Elétrico)
	await _wipe()
	d = await _dummy(E, anchor + Vector2(30, -30))
	d.stats.move_speed = 40.0
	await _put_card(_make({"entrance_shockwave_damage": 50, "entrance_shockwave_radius": 90.0, "entrance_effect": UnitData.OnHitEffect.STUN, "entrance_effect_duration": 1.0}), P, mid)
	await get_tree().create_timer(0.3).timeout
	_check("choque ao cair atordoa", d._is_incapacitated() and d.current_hp < 99999, "atordoado=%s dano=%d" % [str(d._is_incapacitated()), 99999 - d.current_hp])

	# efeito ao morrer (Golem de Gelo) e fúria ao morrer (Lenhador)
	await _wipe()
	d = await _dummy(E, mid + Vector2(40, 40))
	var mate = (await _put_card(_make({"hp": 5000, "move_speed": 0.0}), P, mid + Vector2(-40, 40)))[0]
	u = (await _put_card(_make({"hp": 100, "move_speed": 0.0, "death_effect": UnitData.OnHitEffect.SLOW, "death_effect_strength": 0.5, "death_effect_duration": 3.0, "death_effect_radius": 120.0,
		"death_rage_duration": 3.0}), P, mid + Vector2(0, 40)))[0]
	u.take_damage(99999)
	await get_tree().create_timer(0.3).timeout
	_check("efeito ao morrer: inimigo lento e aliado com fúria", d.speed_multiplier < 0.99 and is_instance_valid(mate) and mate._rage_until > GameManager.game_time,
		"lento x%.2f, fúria=%s" % [d.speed_multiplier, str(is_instance_valid(mate) and mate._rage_until > GameManager.game_time)])

	# vida útil: construção que se apaga sozinha
	await _wipe()
	u = (await _put_card(_make({"hp": 1000, "move_speed": 0.0, "lifetime": 2.0}), P, mid + Vector2(0, 40)))[0]
	await get_tree().create_timer(1.0).timeout
	var half_life = u.current_hp if is_instance_valid(u) else -1
	await get_tree().create_timer(1.5).timeout
	_check("vida útil: a vida cai sozinha até acabar", half_life > 300 and half_life < 700 and (!is_instance_valid(u) or u.current_hp <= 0 or u.is_queued_for_deletion()), "na metade %d" % half_life)

	# alcance mínimo (Morteiro): não acerta quem está colado, acerta quem está longe
	await _wipe()
	var close_d = await _dummy(E, mid + Vector2(0, 10))
	var far_d = await _dummy(E, mid + Vector2(0, -150))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 220.0, "min_attack_range": 90.0, "move_speed": 0.0, "detection_range": 300.0}), P, mid + Vector2(0, 40)))[0]
	await get_tree().create_timer(3.0).timeout
	_check("alcance mínimo: ignora o colado e acerta o de longe", close_d.current_hp == 99999 and far_d.current_hp < 99999, "colado %d, longe %d" % [99999 - close_d.current_hp, 99999 - far_d.current_hp])

	# bumerangue (Executor): acerta na ida e na volta
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -40))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 120.0, "projectile_returns": true, "damage": 100, "attack_speed": 9.0, "move_speed": 0.0, "detection_range": 200.0}), P, mid + Vector2(0, 60)))[0]
	await get_tree().create_timer(2.5).timeout
	_check("bumerangue acerta na ida e na volta", 99999 - d.current_hp == 200, "dano %d (esperado 200)" % (99999 - d.current_hp))

	# dano em construção (x2) e dano de perto
	await _wipe()
	var hut2 = await _dummy(E, mid + Vector2(0, 0))
	hut2.stats.unit_type = UnitData.UnitType.BUILDING
	u = (await _put_card(_make({"damage": 50, "building_damage_mult": 2.0, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(hut2, 2.0)
	_check("dano em construção x2", !drops.is_empty() and drops[0] == 100, str(drops.slice(0, 2)))
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 200.0, "damage": 100, "close_damage_bonus": 1.0, "move_speed": 0.0}), P, mid + Vector2(0, 30)))[0]
	drops = await _hits_on(d, 2.5)
	_check("mais dano de perto", !drops.is_empty() and drops[0] >= 160, str(drops.slice(0, 2)))

	# choque de volta (Gigante Elétrico)
	await _wipe()
	u = (await _put_card(_make({"hp": 9000, "move_speed": 0.0, "damage": 1, "zaps_attackers": true, "zap_damage": 80, "zap_stun": 0.8}), P, mid + Vector2(0, 40)))[0]
	foe = (await _put_card(_make({"hp": 5000, "damage": 60}), E, mid + Vector2(0, 0)))[0]
	await get_tree().create_timer(2.5).timeout
	_check("choque de volta: quem bate leva dano e fica atordoado", is_instance_valid(foe) and foe.current_hp <= 5000 - 80, "o agressor perdeu %d" % (5000 - foe.current_hp if is_instance_valid(foe) else -1))

	# maldição (Bruxa Mãe): o inimigo que morre amaldiçoado vira tropa minha
	await _wipe()
	var victim3 = (await _put_card(_make({"hp": 120, "move_speed": 0.0, "damage": 1}), E, mid + Vector2(0, 0)))[0]
	u = (await _put_card(_make({"damage": 50, "attack_speed": 0.8, "curses_on_hit": true, "curse_duration": 5.0, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	u.stats.curse_spawn_scene = _make({"hp": 77, "move_speed": 0.0}).unit_scene
	await get_tree().create_timer(4.0).timeout
	var mine = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and x.stats != null and x.stats.hp == 77)
	_check("maldição: quem morre amaldiçoado vira tropa sua", !is_instance_valid(victim3) and mine.size() == 1, "virou %d" % mine.size())

	# coletor: dá recurso pro dono
	await _wipe()
	var money0 = GameManager.player_money
	u = (await _put_card(_make({"hp": 5000, "move_speed": 0.0, "produces_resource": true, "resource_amount": 10, "resource_interval": 1.0}), P, mid + Vector2(0, 40)))[0]
	await get_tree().create_timer(2.3).timeout
	_check("coletor dá recurso pro dono", GameManager.player_money >= money0 + 20, "%d -> %d" % [money0, GameManager.player_money])

	# coice (Fogueteira): pula pra trás depois do tiro
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -60))
	u = (await _put_card(_make({"is_ranged": true, "attack_range": 200.0, "recoil_distance": 40.0, "move_speed": 0.0, "attack_speed": 1.5}), P, mid + Vector2(0, 60)))[0]
	var start_d = u.global_position.distance_to(d.global_position)
	await get_tree().create_timer(2.5).timeout
	_check("coice: pula pra trás ao atirar", is_instance_valid(u) and u.global_position.distance_to(d.global_position) >= start_d + 30.0, "%d -> %d" % [int(start_d), int(u.global_position.distance_to(d.global_position)) if is_instance_valid(u) else -1])

	# feitiços: clone, vazio, terremoto, barril
	await _wipe()
	var orig_u = (await _put_card(_make({"hp": 500, "move_speed": 0.0}), P, mid + Vector2(0, 40)))[0]
	var clone_sp = SpellData.new()
	clone_sp.radius = 80.0
	clone_sp.clones_allies = true
	clone_sp.affects_enemies = false
	battle.cast_spell(clone_sp, mid + Vector2(0, 40), P)
	await get_tree().create_timer(0.3).timeout
	var clones = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.team == P and x.get("_is_clone") and x.current_hp == 1)
	_check("feitiço clone: cópia com 1 de vida", clones.size() == 1, str(clones.size()))
	await _wipe()
	var solo = await _dummy(E, mid + Vector2(0, -200))
	var crowd: Array = []
	for k in 4:
		crowd.append(await _dummy(E, mid + Vector2(-30 + k * 20, 100)))
	var void_sp = SpellData.new()
	void_sp.radius = 60.0
	void_sp.damage = 400
	void_sp.splits_damage = true
	battle.cast_spell(void_sp, solo.global_position, P)
	battle.cast_spell(void_sp, mid + Vector2(0, 100), P)
	await get_tree().create_timer(0.3).timeout
	_check("feitiço vazio: 1 alvo leva tudo, 4 dividem", 99999 - solo.current_hp == 400 and 99999 - crowd[0].current_hp == 100, "sozinho %d, no grupo %d" % [99999 - solo.current_hp, 99999 - crowd[0].current_hp])
	await _wipe()
	var hut3 = await _dummy(E, mid)
	hut3.stats.unit_type = UnitData.UnitType.BUILDING
	var quake = SpellData.new()
	quake.radius = 60.0
	quake.damage = 100
	quake.building_damage_mult = 3.0
	battle.cast_spell(quake, mid, P)
	await get_tree().create_timer(0.3).timeout
	_check("feitiço terremoto: dano x3 em construção", 99999 - hut3.current_hp == 300, str(99999 - hut3.current_hp))
	await _wipe()
	var barrel = SpellData.new()
	barrel.radius = 40.0
	barrel.rolls = true
	barrel.roll_distance = 150.0
	barrel.roll_speed = 300.0
	barrel.summon_at_end = true
	barrel.summon_count = 1
	barrel.summon_scene = _make({"hp": 66, "move_speed": 0.0}).unit_scene
	battle.cast_spell(barrel, mid + Vector2(0, 150), P)
	await get_tree().create_timer(0.15).timeout
	var too_soon = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.stats != null and x.stats.hp == 66).size()
	await get_tree().create_timer(0.9).timeout
	var barb = get_tree().get_nodes_in_group("units").filter(func(x): return is_instance_valid(x) and x.stats != null and x.stats.hp == 66)
	_check("feitiço barril: a tropa sai no fim da rolagem", too_soon == 0 and barb.size() == 1 and barb[0].global_position.distance_to(mid + Vector2(0, 150)) >= 120.0,
		"cedo %d, no fim %d" % [too_soon, barb.size()])

	# --- AS NOVAS
	# vários avanços (bandida): avança mais de uma vez no mesmo alvo
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -180))
	u = (await _put_card(_make({"bandit_dash": true, "dash_speed_multiplier": 3.0, "dash_duration": 0.25, "dash_repeats": true, "dash_cooldown": 0.6, "dash_min_range": 30.0, "dash_damage_mult": 2.0, "move_speed": 30.0, "detection_range": 500.0}), P, mid + Vector2(0, 200)))[0]
	u._reset_aggro()
	var bursts = 0
	var was_fast = false
	var t_d = 0.0
	while t_d < 6.0:
		await get_tree().create_timer(0.05).timeout
		t_d += 0.05
		var fast = is_instance_valid(u) and u.velocity.length() >= 70.0
		if fast and !was_fast:
			bursts += 1
		was_fast = fast
	_check("vários avanços", bursts >= 2, "%d avanços em 6s" % bursts)

	# salto (mega cavaleiro): sai do chão, cai no alvo e dá dano em área
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -80))
	var jump_side = await _dummy(E, mid + Vector2(40, -80))
	u = (await _put_card(_make({"jump_attack": true, "jump_min_range": 60.0, "jump_max_range": 260.0, "jump_damage": 200, "jump_radius": 90.0, "jump_cooldown": 0.5, "move_speed": 20.0, "damage": 1, "detection_range": 400.0}), P, mid + Vector2(0, 90)))[0]
	u._reset_aggro()
	var start_gap = u.global_position.distance_to(d.global_position)
	await get_tree().create_timer(3.5).timeout
	_check("salto cai no alvo com dano em área", is_instance_valid(u) and u.global_position.distance_to(d.global_position) < start_gap * 0.6 and 99999 - d.current_hp >= 200 and 99999 - jump_side.current_hp >= 200,
		"distância %d -> %d, dano %d e %d" % [int(start_gap), int(u.global_position.distance_to(d.global_position)) if is_instance_valid(u) else -1, 99999 - d.current_hp, 99999 - jump_side.current_hp])

	# esquenta: depois de um tempo em campo bate mais forte
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, 0))
	u = (await _put_card(_make({"late_boost_after": 2.5, "late_boost_damage_mult": 3.0}), P, mid + Vector2(0, 40)))[0]
	drops = await _hits_on(d, 5.5)
	_check("esquenta depois de um tempo em campo (e mostra)", drops.size() >= 4 and drops[0] <= 70 and drops[-1] >= 170 and is_instance_valid(u) and "esquentou" in u.ability_cue, "%s, mostrando '%s'" % [str(drops), u.ability_cue if is_instance_valid(u) else "?"])

	# --- PROJÉTIL: pode errar e sai em arco
	await _wipe()
	d = await _dummy(E, mid + Vector2(0, -60))
	var runner = await _dummy(E, mid + Vector2(120, -60))
	for miss in [false, true]:
		var pr = Projectile.new()
		pr.target = runner
		pr.damage = 100
		pr.speed = 300.0
		pr.attacker_team = P
		pr.can_miss = miss
		pr.launch_angle = 45.0
		pr.texture = SpriteForge.projectile("bola_canhao", SpriteForge.DEFAULT_PALETTE)
		battle.add_child(pr)
		pr.global_position = mid + Vector2(120, 140)
		await get_tree().physics_frame
		await get_tree().physics_frame
		runner.global_position += Vector2(90, 0)          # o alvo sai do lugar depois do disparo
		await get_tree().create_timer(1.6).timeout
		if !miss:
			_check("tiro teleguiado acerta mesmo o alvo que andou", 99999 - runner.current_hp == 100, str(99999 - runner.current_hp))
			runner.current_hp = 99999
		else:
			_check("tiro que pode errar erra o alvo que andou", runner.current_hp == 99999 and d.current_hp == 99999, "%d %d" % [99999 - runner.current_hp, 99999 - d.current_hp])

	# --- MÓDULOS: quem acerta, habilidades de tiro e de defesa
	await _wipe()
	var tower = null
	for t in get_tree().get_nodes_in_group("player_base"):
		if t.base_data != null and !(("asleep" in t) and t.asleep) and Regras.tower_shoots(t.base_data):
			tower = t
			break
	if tower == null:
		_check("módulos: achou uma torre pra testar", false, "nenhuma torre que atira")
	else:
		var bd: BaseData = tower.base_data.duplicate()
		tower.base_data = bd
		var walker = await _dummy(E, tower.global_position + Vector2(0, -70))
		var flyer = await _dummy(E, tower.global_position + Vector2(40, -60))
		flyer.stats.unit_type = UnitData.UnitType.AIR
		bd.targets = 1
		var only_ground = tower._find_closest_enemy()
		walker.global_position += Vector2(0, -900)
		var ground_none = tower._find_closest_enemy()
		walker.global_position += Vector2(0, 900)
		bd.targets = 2
		var only_air = tower._find_closest_enemy()
		bd.targets = 0
		_check("módulo acerta só chão / só ar / os dois", only_ground == walker and ground_none == null and only_air == flyer and tower._find_closest_enemy() != null,
			"%s" % str([only_ground == walker, ground_none == null, only_air == flyer]))
		# armadilha armada: a torre não enxerga
		flyer.global_position += Vector2(0, -900)
		walker.stats.is_trap = true
		await get_tree().create_timer(0.2).timeout
		var sees_trap = tower._find_closest_enemy() == walker
		walker.stats.is_trap = false
		walker._trap_sprung = true
		_check("torre não atira em armadilha escondida", !sees_trap)
		# executa alvo fraco
		bd.execute_threshold = 0.5
		bd.execute_damage_mult = 3.0
		walker.current_hp = int(walker.stats.hp * 0.3)
		var ex_low = tower._shot_damage_on(walker, 100)
		walker.current_hp = walker.stats.hp
		_check("módulo executa alvo fraco", ex_low == 300 and tower._shot_damage_on(walker, 100) == 100, "%d / %d" % [ex_low, tower._shot_damage_on(walker, 100)])
		# tiro de verdade: corrente pula pro vizinho, dano cresce no mesmo alvo, vários alvos
		var neighbour = await _dummy(E, walker.global_position + Vector2(50, 0))
		bd.execute_threshold = 0.0
		bd.projectile_chains = true
		bd.projectile_chain_max_targets = 2
		bd.projectile_chain_range = 120.0
		bd.ramp_per_shot = 1.0
		bd.ramp_max_mult = 4.0
		tower._locked_target = walker
		var shot_drops: Array = []
		for k in 3:
			tower._shot_cooldown = 0.0
			var before_hp = walker.current_hp
			tower._process_cannon(0.0)
			await get_tree().create_timer(0.9).timeout
			shot_drops.append(before_hp - walker.current_hp)
		_check("módulo: tiro em corrente e dano que cresce no mesmo alvo", neighbour.current_hp < 99999 and shot_drops.size() == 3 and shot_drops[0] > 0 and shot_drops[2] >= shot_drops[0] * 2,
			"vizinho perdeu %d, tiros %s" % [99999 - neighbour.current_hp, str(shot_drops)])
		bd.projectile_chains = false
		bd.ramp_per_shot = 0.0
		bd.extra_targets = 1
		neighbour.current_hp = 99999
		tower._shot_cooldown = 0.0
		tower._process_cannon(0.0)
		await get_tree().create_timer(0.6).timeout
		_check("módulo atira em mais de um alvo por vez", neighbour.current_hp < 99999, str(99999 - neighbour.current_hp))
		bd.extra_targets = 0
		# GELO na torre: para de atirar pelo tempo todo do efeito e volta depois (bug do João)
		bd.extra_targets = 0
		walker.current_hp = 99999
		tower._locked_target = null
		tower.set_process(true)
		tower.apply_on_hit_effect(UnitData.OnHitEffect.FREEZE, 0.0, 2.0)
		await get_tree().create_timer(1.6).timeout
		var hp_frozen = walker.current_hp
		var frozen_flag = tower.is_frozen()
		await get_tree().create_timer(2.6).timeout
		tower.set_process(false)
		_check("gelo para a torre pelo tempo todo e ela volta a atirar depois", frozen_flag and hp_frozen == 99999 and walker.current_hp < 99999 and !tower.is_frozen(),
			"congelada=%s, dano durante %d, dano depois %d" % [str(frozen_flag), 99999 - hp_frozen, 99999 - walker.current_hp])
		# feitiço de gelo de verdade em cima da torre (módulo E Casa Grande levam o efeito)
		var ice = SpellData.new()
		ice.radius = 120.0
		ice.status_effect = UnitData.OnHitEffect.FREEZE
		ice.status_effect_duration = 3.0
		var main_base = null
		var module_t = null
		for t in get_tree().get_nodes_in_group("player_base"):
			if t.is_main:
				main_base = t
			elif module_t == null and t.base_data != null:
				module_t = t
		for t in [main_base, module_t]:
			if t != null:
				t._frozen_until = -1.0
				battle.cast_spell(ice, t.global_position, E)
		await get_tree().create_timer(0.3).timeout
		_check("feitiço de gelo congela o módulo e a Casa Grande", module_t != null and module_t.is_frozen() and (main_base == null or main_base.is_frozen()),
			"casa grande=%s módulo=%s" % [str(main_base.is_frozen()) if main_base != null else "não achei", str(module_t.is_frozen()) if module_t != null else "não achei"])
		# defesa: redução, regeneração
		tower.max_hp = 10000
		tower.hp = 5000
		bd.damage_reduction_percent = 0.5
		tower.take_damage(200)
		var red_ok = tower.hp == 4900
		bd.damage_reduction_percent = 0.0
		bd.regen_per_second = 400
		tower.set_process(true)
		await get_tree().create_timer(1.0).timeout
		tower.set_process(false)
		_check("módulo: redução de dano e regeneração", red_ok and tower.hp >= 5150, "depois do golpe %s, depois de 1s %d" % [str(red_ok), tower.hp])
		bd.regen_per_second = 0

	# --- BOTS ARMAM A BASE PELO JEITO DELES (e aprendem)
	var bases_all: Array = BotSimulator.available_bases.filter(func(b): return b != null)
	var def_b: BaseData = null
	var of_b: BaseData = null
	var eco_b: BaseData = null
	for b in bases_all:
		if b.category == BaseData.BaseCategory.DEFENSIVO and def_b == null:
			def_b = b
		elif b.category == BaseData.BaseCategory.OFENSIVO and of_b == null:
			of_b = b
		elif b.category == BaseData.BaseCategory.ECONOMICO and eco_b == null:
			eco_b = b
	var pts_ok = Progresso.role_points(BaseData.BaseCategory.DEFENSIVO, 0, true)[0] == 1 \
		and Progresso.role_points(BaseData.BaseCategory.OFENSIVO, 1, true)[0] == 0 \
		and Progresso.role_points(BaseData.BaseCategory.OFENSIVO, 0, true)[0] == 3 \
		and Progresso.role_points(BaseData.BaseCategory.ECONOMICO, 0, true)[0] == 6 \
		and Progresso.role_points(BaseData.BaseCategory.SUPORTE, 0, false)[0] == 4
	_check("cada função tem o seu lugar (parede no caminho, tiro na frente ou perto da base, recurso no fundo)", pts_ok)
	# bots de verdade: defensivo escolhe mais parede, ofensivo mais tiro; e cada módulo vai pro lugar da função
	var cnt := {0: {}, 1: {}}
	var wrong_place: Array = []
	# todos os módulos liberados (no teste o jogador está na arena 0, onde só tem módulo de parede)
	var keep_bases = BotSimulator.available_bases.duplicate()
	var open_bases: Array[BaseData] = []
	for b in keep_bases:
		if b != null:
			var b2: BaseData = b.duplicate()
			b2.unlock_arena = 0
			open_bases.append(b2)
	BotSimulator.available_bases = open_bases
	Regras.set_tune("inova", 0.0)
	for bn in BotSimulator.roster_names:
		var bpf: AIProfile = BotLearning.get_or_create_profile(str(bn))
		var stn = Progresso.bot_stance(bpf)
		if stn == 2:
			continue
		var lo2: Array = Progresso.bot_module_loadout(bpf, 2)
		for o2 in lo2:
			var cat2 = int(o2["base"].category)
			cnt[stn][cat2] = int(cnt[stn].get(cat2, 0)) + 1
			var allowed: Array = Progresso.role_points(cat2, stn, true) + Progresso.role_points(cat2, stn, false)
			if !allowed.has(int(o2["ponto"])):
				wrong_place.append("%s %s@%d" % [bn, o2["base"].base_name, int(o2["ponto"])])
	BotSimulator.available_bases = keep_bases
	Regras.set_tune("inova", 0.0, false)
	var def_share = float(cnt[0].get(BaseData.BaseCategory.DEFENSIVO, 0)) / maxf(1.0, float(cnt[0].values().reduce(func(a, b): return a + b, 0)))
	var of_share = float(cnt[1].get(BaseData.BaseCategory.OFENSIVO, 0)) / maxf(1.0, float(cnt[1].values().reduce(func(a, b): return a + b, 0)))
	var off_wall = float(cnt[1].get(BaseData.BaseCategory.DEFENSIVO, 0)) / maxf(1.0, float(cnt[1].values().reduce(func(a, b): return a + b, 0)))
	var def_gun = float(cnt[0].get(BaseData.BaseCategory.OFENSIVO, 0)) / maxf(1.0, float(cnt[0].values().reduce(func(a, b): return a + b, 0)))
	_check("bot defensivo prefere parede e ofensivo prefere tiro; cada módulo no lugar da função", def_share > off_wall + 0.15 and of_share > def_gun + 0.15 and wrong_place.is_empty(),
		"parede: defensivo %d%% x ofensivo %d%% | tiro: ofensivo %d%% x defensivo %d%% | fora do lugar %s" % [int(def_share * 100), int(off_wall * 100), int(of_share * 100), int(def_gun * 100), str(wrong_place.slice(0, 3))])
	# memória: o ponto que ganha sobe; a vontade de inovar cai com a experiência (menos nos curiosos)
	var learner = str(BotSimulator.roster_names[3])
	var lp: AIProfile = BotLearning.get_or_create_profile(learner)
	var raw_l = BotLearning._load_raw(learner)
	var keep_mem = raw_l.get("mod_memo", null)
	var lstn = Progresso.bot_stance(lp)
	var cat_l = BaseData.BaseCategory.DEFENSIVO
	var home_l = (abs(hash(learner)) / 3) % 2 == 0
	var third = Progresso.role_points(cat_l, 0 if lstn == 2 else lstn, home_l)[2]
	for k in 8:
		BotLearning.record_module_result(learner, ["%d@%d" % [cat_l, third]], true)
	var mem_l = BotLearning.module_memory(learner)
	var learned = int(mem_l.get("round", 0)) >= 8 and int(mem_l["points"]["%d@%d" % [cat_l, third]][1]) >= 8
	var e_new = BotLearning.module_explore_chance(lp, 0)
	var e_old = BotLearning.module_explore_chance(lp, 60)
	var cur = AIProfile.new()
	cur.archetype = AIProfile.Archetype.CURIOSO
	var ana = AIProfile.new()
	ana.archetype = AIProfile.Archetype.ANALITICO
	raw_l = BotLearning._load_raw(learner)
	if keep_mem == null:
		raw_l.erase("mod_memo")
	else:
		raw_l["mod_memo"] = keep_mem
	BotLearning._save_raw(learner, raw_l)
	_check("bot aprende: guarda o que ganhou, fica mais certeiro com o tempo e o curioso continua inovando", learned and e_old < e_new and BotLearning.module_explore_chance(cur, 200) >= 0.2 and BotLearning.module_explore_chance(ana, 200) < 0.05,
		"aprendeu=%s inovar %.2f -> %.2f, curioso %.2f, analítico %.2f" % [str(learned), e_new, e_old, BotLearning.module_explore_chance(cur, 200), BotLearning.module_explore_chance(ana, 200)])

	print("GERAL ok (", _aud_ok.size(), "): ", _aud_ok)
	# EVOLUIR POR IGUAL x FOCAR: com cópias e ouro de sobra, o "por igual" deixa o baralho
	# todo no mesmo nível; o "foca" sobe a carta que já está na frente
	var even_name = ""
	var focus_name = ""
	for k in 200:
		var nm = "TesteEvolui%d" % k
		if BotLearning.evolves_evenly(nm) and even_name == "":
			even_name = nm
		elif !BotLearning.evolves_evenly(nm) and focus_name == "":
			focus_name = nm
	var evo_paths: Array = []
	for c in Catalogo.cards().slice(0, 8):
		evo_paths.append(c.resource_path)
	var evo_res = {}
	for nm in [even_name, focus_name]:
		var lv0 = {}
		for pth in evo_paths:
			lv0[pth] = 1
		lv0[evo_paths[0]] = 3
		var cp = {}
		for pth in evo_paths:
			cp[pth] = 9999
		var dd = {"deck_paths": evo_paths, "card_levels": lv0, "card_copies": cp, "gold": 2600}
		BotLearning._level_cap = 14
		BotLearning._maybe_upgrade_cards(dd, nm)
		evo_res[nm] = dd["card_levels"].values()
	var ev: Array = evo_res[even_name]
	var fc: Array = evo_res[focus_name]
	_check("bot 'por igual' sobe as cartas baixas; o 'foca' sobe a que já está na frente",
		ev.max() == 3 and ev.min() >= 2 and fc.max() > 3, "igual %s | foca %s" % [ev, fc])
	var split = 0
	for k in 400:
		if BotLearning.evolves_evenly("Bot%d" % k):
			split += 1
	_check("uns bots evoluem por igual, outros focam", split > 120 and split < 320, str(split))
	var ap = AIProfile.new()
	_check("nível médio do baralho = soma / quantidade", absf(MatchSetup.avg_level(ap) - 1.0) < 0.01 or ap.deck.is_empty(), str(MatchSetup.avg_level(ap)))
	print("RESULTADO geral COM PROBLEMA (", _aud_bad.size(), "): ", _aud_bad)
