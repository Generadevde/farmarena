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
	await get_tree().create_timer(75.0).timeout  # ~75s de jogo (time_scale acelera)
	_report()
	get_tree().quit()


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
