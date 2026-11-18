extends Node
# FILME (só GitHub Actions): grava uma partida normal com um "jogador robô"
# do nosso lado, pra olhar o ritmo da batalha quadro a quadro.
# Também imprime um registro (FILMELOG) de cada morte e de cada torre.

var battle
var t := 0.0
var next_play := 2.0
var rng := RandomNumberGenerator.new()


func _ready():
	rng.seed = 7
	get_window().size = Vector2i(720, 1600)
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
	MatchSetup.tournament = false
	MatchSetup.rule = 0
	MatchSetup.arena_override = 1
	MatchSetup.next_ai_profile = BotLearning.get_or_create_profile(BotSimulator.roster_names[3])
	battle = load("res://Scenes/batlhe_scene.tscn").instantiate()
	get_tree().root.add_child(battle)
	await get_tree().create_timer(0.6).timeout
	battle._close_intro()
	print("FILMELOG inicio deck=", DeckManager.full_deck.map(func(c): return c.card_name))


func _physics_process(delta):
	if battle == null or !is_instance_valid(battle):
		return
	t += delta
	if t >= next_play:
		next_play = t + rng.randf_range(1.5, 4.0)
		_play()
	if t > 75.0:
		print("FILMELOG fim t=", snapped(t, 0.1))
		get_tree().quit()


func _play():
	var deck = DeckManager.full_deck
	var card: CardData = deck[rng.randi() % deck.size()]
	if GameManager.player_money < card.cost:
		return
	var mid = ArenaBuilder.CENTER
	if card.spell_data != null:
		var best = null
		for u in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(u) and u.team == GameManager.Team.ENEMY:
				best = u
				break
		if best == null:
			return
		GameManager.player_money -= card.cost
		battle.cast_spell(card.spell_data, best.global_position, GameManager.Team.PLAYER)
		print("FILMELOG t=", snapped(t, 0.1), " jogador feitiço ", card.card_name)
		return
	if card.unit_scene == null:
		return
	var x = (-150.0 if rng.randf() < 0.5 else 150.0) + rng.randf_range(-30, 30)
	var pos = mid + Vector2(x, rng.randf_range(80, 260))
	GameManager.player_money -= card.cost
	battle.spawn_unit(card.unit_scene, GameManager.Team.PLAYER, pos, card)
	print("FILMELOG t=", snapped(t, 0.1), " jogador solta ", card.card_name, " em ", pos.round())
