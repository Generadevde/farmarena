extends Node
# LAB: monta situações controladas na batalha de verdade (bot parado) e registra o que acontece.
# LAB_PLAN = JSON [[t, "P"|"E", "nome da carta", x, y], ...]   (x,y relativos ao centro do campo; y>0 = lado do jogador)
var battle
var t := 0.0
var plan: Array = []
var end_t := 30.0
var sample := 0.0
var quiet := false
var _init_hp := {}
var _falls: Array = []
var _lead := 0
var _lead_changes := 0
var _lives: Array = []
var _born := {}
var _seen_towers := {}
var _done := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("LAB_SEED") != "":
		seed(int(OS.get_environment("LAB_SEED")))
	get_window().size = Vector2i(720, 1600)
	plan = JSON.parse_string(OS.get_environment("LAB_PLAN")) if OS.get_environment("LAB_PLAN") != "" else []
	if OS.get_environment("LAB_END") != "":
		end_t = float(OS.get_environment("LAB_END"))
	quiet = OS.get_environment("LAB_QUIET") != ""
	PlayerProfile.create_new_profile("João")
	PlayerBehaviorProfiler.load_for_active_profile()
	Leaderboard.load_for_active_profile()
	SeasonStats.load_for_active_profile()
	SeasonManager.load_for_active_profile()
	PollManager.load_for_active_profile()
	ArenaManager.load_for_active_profile()
	CustomContent.load_all()
	for n in get_tree().root.get_children():
		if n.name.to_lower().contains("hub"):
			n.queue_free()
	await get_tree().process_frame
	MatchSetup.mode = MatchSetup.MODE_1V1
	MatchSetup.tournament = OS.get_environment("LAB_FAIR") != "" or OS.get_environment("LAB_TORNEIO") != ""
	MatchSetup.rule = 0
	MatchSetup.arena_override = 1
	var si = int(OS.get_environment("LAB_SEED")) if OS.get_environment("LAB_SEED") != "" else 0
	MatchSetup.next_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[(3 + si * 2) % BotSimulator.roster_names.size()])
	battle = load("res://Scenes/batlhe_scene.tscn").instantiate()
	get_tree().root.add_child(battle)
	await get_tree().create_timer(0.6).timeout
	battle._close_intro()
	if OS.get_environment("LAB_BOT") == "":
		battle.ai_profile = null  # bot parado: só acontece o que está no plano
	if OS.get_environment("LAB_FAIR") != "":
		# partida JUSTA pra medir as regras: o mesmo tipo de robô dos dois lados,
		# cartas e torres no mesmo nível, x2 pros dois
		var names = BotSimulator.roster_names
		var sf = int(OS.get_environment("LAB_SEED")) if OS.get_environment("LAB_SEED") != "" else 0
		var pa: AIProfile = BotLearning.get_or_create_profile(names[(7 + sf * 3) % names.size()])
		var pb: AIProfile = battle.ai_profile if battle.ai_profile != null else BotLearning.get_or_create_profile(names[(3 + sf * 2) % names.size()])
		battle.ai_profile = null
		var specs = [[pa, GameManager.Team.PLAYER, battle.spawn_player_area, "RoboP"], [pb, GameManager.Team.ENEMY, battle.spawn_enemy_area, "RoboE"]]
		for sp in specs:
			var c = BotController.new()
			c.name = sp[3]
			c.setup(battle, sp[0], sp[1], sp[2], [0.22, 0.78][randi() % 2])
			battle.add_child(c)
			battle._extra_ai_controllers.append(c)
		print("LAB justo P=", pa.deck.map(func(x): return x.card_name), " | E=", pb.deck.map(func(x): return x.card_name))
	elif OS.get_environment("LAB_ALLY") != "":
		var si2 = int(OS.get_environment("LAB_SEED")) if OS.get_environment("LAB_SEED") != "" else 0
		var prof: AIProfile = BotLearning.get_or_create_profile(BotSimulator.roster_names[(7 + si2 * 3) % BotSimulator.roster_names.size()])
		var c = BotController.new()
		c.name = "RoboJogador"
		c.setup(battle, prof, GameManager.Team.PLAYER, battle.spawn_player_area, 0.22)
		battle.add_child(c)
		battle._extra_ai_controllers.append(c)
		print("LAB robo jogador deck=", prof.deck.map(func(x): return x.card_name), " | bot deck=", battle.ai_profile.deck.map(func(x): return x.card_name) if battle.ai_profile else [])
	t = 0.0
	print("LAB inicio plano=", plan.size())
	if OS.get_environment("LAB_DUELOS") != "":
		_duels()


# ---------------------------------------------------------------- duelos (LAB_DUELOS=arquivo.json)
# Solta a carta A de um lado e a B do outro, no meio do campo (longe das
# torres), e anota quem sobra, com quanta vida e em quanto tempo. Roda a
# lista inteira numa partida só. Entrada: [["A","B"], ...]  Saída: LAB_DUELOS_OUT
var _dueling := false


func _side_state(team) -> Array:
	var n := 0
	var hp := 0.0
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and !u.is_queued_for_deletion() and u.team == team and u.current_hp > 0:
			n += 1
			hp += float(u.current_hp)
	return [n, hp]


# torre sempre inteira: num duelo sem briga (um não alcança o outro) as tropas
# vão pra torre, e a partida não pode acabar no meio da lista
func _heal_towers():
	for g in ["player_base", "enemy_base"]:
		for tw in get_tree().get_nodes_in_group(g):
			if is_instance_valid(tw) and "max_hp" in tw:
				tw.hp = tw.max_hp


func _duels():
	_dueling = true
	var pairs: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LAB_DUELOS")))
	var gap = float(OS.get_environment("LAB_DUELO_GAP")) if OS.get_environment("LAB_DUELO_GAP") != "" else 95.0
	var out: Array = []
	for pr in pairs:
		var a = _card(str(pr[0]))
		var b = _card(str(pr[1]))
		if a == null or b == null:
			continue
		for u in get_tree().get_nodes_in_group("units"):
			u.queue_free()
		for pj in get_tree().get_nodes_in_group("projectiles"):
			pj.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
		battle._battle_time_remaining = 9999.0  # o relógio da partida não pode acabar no meio da lista
		_heal_towers()
		battle.spawn_unit(a.unit_scene, GameManager.Team.PLAYER, ArenaBuilder.CENTER + Vector2(0, gap), a)
		battle.spawn_unit(b.unit_scene, GameManager.Team.ENEMY, ArenaBuilder.CENTER + Vector2(0, -gap), b)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var p0 = _side_state(GameManager.Team.PLAYER)
		var e0 = _side_state(GameManager.Team.ENEMY)
		var t0 = GameManager.game_time
		var res = "empate"
		var frac = 0.0
		while GameManager.game_time - t0 < 45.0 and !get_tree().paused:
			await get_tree().physics_frame
			_heal_towers()
			var ps = _side_state(GameManager.Team.PLAYER)
			var es = _side_state(GameManager.Team.ENEMY)
			if ps[0] == 0 or es[0] == 0:
				# espera um instante: filhote que nasce na morte ainda conta
				for i in 12:
					await get_tree().physics_frame
				ps = _side_state(GameManager.Team.PLAYER)
				es = _side_state(GameManager.Team.ENEMY)
				if ps[0] == 0 and es[0] == 0:
					res = "empate"
					break
				if es[0] == 0:
					res = "A"
					frac = ps[1] / maxf(p0[1], 1.0)
					break
				if ps[0] == 0:
					res = "B"
					frac = es[1] / maxf(e0[1], 1.0)
					break
		var ps2 = _side_state(GameManager.Team.PLAYER)
		var es2 = _side_state(GameManager.Team.ENEMY)
		out.append({"a": a.card_name, "b": b.card_name, "res": res, "sobra": snappedf(minf(frac, 1.0), 0.01), "t": snappedf(GameManager.game_time - t0, 0.1),
			"fa": snappedf(ps2[1] / maxf(p0[1], 1.0), 0.01), "fb": snappedf(es2[1] / maxf(e0[1], 1.0), 0.01)})
	var f = FileAccess.open(OS.get_environment("LAB_DUELOS_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("DUELOS ", out.size())
	_done = true
	get_tree().quit()


func _card(card_name: String) -> CardData:
	for c in CardDatabase.all_cards:
		if c != null and c.card_name == card_name:
			return c
	return null


# ---------------------------------------------------------------- "jogador" de mentira (LAB_HUMANO=1)
# Joga pelo MESMO caminho do jogador de verdade: escolhe carta da mão, mostra
# a prévia por um instante e confirma no campo. Serve pra ver a partida real
# (mão, prévia, zona vermelha) contra o bot principal.
var _h_pending: Dictionary = {}
var _h_think := 2.0
var _h_lane := -150.0


func _human(delta):
	var money = int(GameManager.player_money)
	if !_h_pending.is_empty():
		_h_pending["t"] -= delta
		var ev = InputEventMouseMotion.new()
		var screen = battle.get_viewport().get_canvas_transform() * _h_pending["pos"]
		ev.position = screen
		ev.global_position = screen
		Input.parse_input_event(ev)
		if _h_pending["t"] <= 0.0:
			battle.try_confirm_placement_at(_h_pending["pos"])
			_h_pending = {}
		return
	_h_think -= delta
	if _h_think > 0.0:
		return
	_h_think = randf_range(0.7, 1.6)
	var hand: Array = DeckManager.hand
	var affordable: Array = []
	for c in hand:
		if c != null and money >= c.cost:
			affordable.append(c)
	if affordable.is_empty():
		return
	var d = BattleBrain.choose_defense(get_tree(), GameManager.Team.PLAYER, affordable, hand, money, battle.player_max_money, battle.spawn_player_area, battle, 0.05)
	var card: CardData = null
	var pos = Vector2.INF
	if d.has("card"):
		card = d["card"]
		pos = d["pos"]
	elif !d.get("wait", false) and money >= 55:
		var troops = affordable.filter(func(c): return !c.is_spell())
		if troops.is_empty():
			return
		card = troops[randi() % troops.size()]
		if randf() < 0.2:
			_h_lane = -_h_lane
		pos = BattleBrain.offensive_position(card, DeckBuilder.get_unit_stats(card), GameManager.Team.PLAYER, get_tree(), battle.spawn_player_area, battle, ArenaBuilder.CENTER.x + _h_lane)
	if card == null or pos == Vector2.INF:
		return
	var idx = hand.find(card)
	battle.select_card(card, idx)
	_h_pending = {"pos": pos, "t": 0.45}
	print("LAB t=%.1f jogador joga %s" % [t, card.card_name])


func _frac(group: String) -> float:
	var total := 0.0
	var now := 0.0
	for k in _init_hp:
		if k.begins_with(group):
			total += _init_hp[k]
	for b in get_tree().get_nodes_in_group(group):
		if is_instance_valid(b) and "hp" in b and !b.is_queued_for_deletion():
			now += b.hp
	return now / total if total > 0 else 0.0


func _finish(reason: String):
	if _done:
		return
	_done = true
	var plays_p := 0
	var plays_e := 0
	for a in battle.match_action_log:
		if str(a.get("side", "")) == "player":
			plays_p += 1
		else:
			plays_e += 1
	var avg := 0.0
	for l in _lives:
		avg += l
	avg = avg / _lives.size() if !_lives.is_empty() else 0.0
	var hp0: Array = []
	for k in _init_hp:
		hp0.append("%s%d" % ["P" if k.begins_with("player") else "E", int(_init_hp[k])])
	print("LABFIM %s dur=%.1f vidaP=%.2f vidaE=%.2f quedas=%s viradas=%d jogadasBot=%d unidades_mortas=%d vida_media_tropa=%.1fs torres0=%s" % [reason, t, _frac("player_base"), _frac("enemy_base"), str(_falls), _lead_changes, plays_e + plays_p, _lives.size(), avg, str(hp0)])
	get_tree().quit()


func _track():
	for g in ["player_base", "enemy_base"]:
		var i := 0
		for b in get_tree().get_nodes_in_group(g):
			var key = "%s#%d" % [g, b.get_instance_id()]
			if !_init_hp.has(key) and "max_hp" in b and t > 0.3:
				_init_hp[key] = float(b.max_hp)
				_seen_towers[key] = b
			i += 1
	for key in _seen_towers.keys():
		var b = _seen_towers[key]
		if !is_instance_valid(b) or b.is_queued_for_deletion():
			_falls.append("%s@%d" % ["P" if key.begins_with("player") else "E", int(t)])
			_seen_towers.erase(key)
	for u in get_tree().get_nodes_in_group("units"):
		var id = u.get_instance_id()
		if !_born.has(id):
			_born[id] = t
			var born_t = t
			u.died.connect(func(_a, _b): _lives.append(t - born_t))
	var d = _frac("player_base") - _frac("enemy_base")
	var now_lead = 0 if absf(d) < 0.03 else (1 if d > 0 else -1)
	if now_lead != 0 and _lead != 0 and now_lead != _lead:
		_lead_changes += 1
	if now_lead != 0:
		_lead = now_lead


func _physics_process(delta):
	if battle == null or !is_instance_valid(battle) or !battle.is_inside_tree():
		return
	if _done or _dueling:
		return
	if battle.match_over:
		_finish("acabou")
		return
	if get_tree().paused:
		return
	t += delta
	_track()
	if OS.get_environment("LAB_HUMANO") != "":
		_human(delta)
	while !plan.is_empty() and float(plan[0][0]) <= t:
		var p = plan.pop_front()
		var card = _card(str(p[2]))
		if card == null:
			print("LAB carta não achada: ", p[2])
			continue
		var team = GameManager.Team.PLAYER if str(p[1]) == "P" else GameManager.Team.ENEMY
		var pos = ArenaBuilder.CENTER + Vector2(float(p[3]), float(p[4]))
		if card.is_spell():
			battle.cast_spell(card.spell_data, pos, team)
		else:
			battle.spawn_unit(card.unit_scene, team, pos, card)
		print("LAB t=%.1f %s solta %s em (%d,%d)" % [t, p[1], card.card_name, int(p[3]), int(p[4])])
	sample -= delta
	if sample <= 0.0 and !quiet:
		sample = 0.5
		var parts: Array = []
		for u in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(u) and "current_hp" in u and u.current_hp != null:
				var nm = u.card_data.card_name.substr(0, 10) if u.card_data != null else "?"
				parts.append("%s%s:%d@%d,%d" % ["P" if u.team == GameManager.Team.PLAYER else "E", nm, int(u.current_hp), int(u.global_position.x - ArenaBuilder.CENTER.x), int(u.global_position.y - ArenaBuilder.CENTER.y)])
		var tw: Array = []
		for g in ["player_base", "enemy_base"]:
			for b in get_tree().get_nodes_in_group(g):
				if is_instance_valid(b) and "hp" in b:
					tw.append("%s%d" % ["TP" if g == "player_base" else "TE", int(b.hp)])
		print("LABS t=%.1f torres[%s] %s" % [t, " ".join(tw), " | ".join(parts)])
	if t > end_t:
		_finish("tempo_do_lab")
