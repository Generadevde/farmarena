extends Node

# guarda qual bot vai ser enfrentado na próxima partida -- setado pelo menu
# antes de trocar pra cena de batalha, e lido por ela assim que começa
var next_ai_profile: AIProfile = null

# guarda os dados de um replay salvo, setado pela tela de estatísticas antes
# de trocar pra cena de batalha -- se isso estiver preenchido, a cena de
# batalha entra em MODO REPRODUÇÃO em vez de partida normal
var replay_data: Dictionary = {}

# modo da próxima partida -- 1v1 normal ou 2v2 (você + bot aliado contra 2 bots)
const MODE_1V1 = 0
const MODE_2V2 = 1
var mode: int = MODE_1V1
var ally_ai_profile: AIProfile = null          # bot do SEU lado no 2v2
var second_enemy_ai_profile: AIProfile = null  # segundo bot inimigo no 2v2


# ================================================================ 2.0: pareamento (antes ficava no menu)
const BATTLE_SCENE = "res://Scenes/batlhe_scene.tscn"
const OPPONENT_TROPHY_RANGE = 150


## bot perto do seu troféu (sem repetir os 2 últimos)
func choose_opponent() -> AIProfile:
	if BotSimulator.roster_names.is_empty():
		return null
	var mine = ArenaManager.get_trophies(PlayerProfile.player_name)
	var near: Array = []
	var closest: Array = []
	var closest_diff = INF
	for bot_name in BotSimulator.roster_names:
		if bot_name in PlayerProfile.recent_opponents:
			continue
		var diff = abs(ArenaManager.get_trophies(bot_name) - mine)
		if diff <= OPPONENT_TROPHY_RANGE:
			near.append(bot_name)
		if diff < closest_diff:
			closest_diff = diff
			closest = [bot_name]
		elif diff == closest_diff:
			closest.append(bot_name)
	var chosen: String
	if !near.is_empty():
		chosen = near[randi() % near.size()]
	elif !closest.is_empty():
		chosen = closest[randi() % closest.size()]
	else:
		chosen = BotSimulator.roster_names[randi() % BotSimulator.roster_names.size()]
	PlayerProfile.record_recent_opponent(chosen)
	return BotLearning.get_or_create_profile(chosen)


func start_1v1(tree: SceneTree):
	mode = MODE_1V1
	next_ai_profile = choose_opponent()
	tree.change_scene_to_file(BATTLE_SCENE)


func start_2v2(tree: SceneTree):
	mode = MODE_2V2
	var main_enemy = choose_opponent()
	next_ai_profile = main_enemy
	var mine = ArenaManager.get_trophies(PlayerProfile.player_name)
	var pool: Array = BotSimulator.roster_names.duplicate()
	pool.sort_custom(func(a, b): return abs(ArenaManager.get_trophies(a) - mine) < abs(ArenaManager.get_trophies(b) - mine))
	var picks: Array = []
	for bot_name in pool.slice(0, 12):
		if main_enemy == null or bot_name != main_enemy.profile_name:
			picks.append(bot_name)
	picks.shuffle()
	ally_ai_profile = BotLearning.get_or_create_profile(picks[0]) if picks.size() > 0 else null
	second_enemy_ai_profile = BotLearning.get_or_create_profile(picks[1]) if picks.size() > 1 else null
	tree.change_scene_to_file(BATTLE_SCENE)
