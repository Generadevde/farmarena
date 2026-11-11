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
	BotSimulator.ensure_rivals()  # nunca falta adversário na sua faixa
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


# ---- torneio / regras especiais
const RULE_NAMES = ["Clássico", "Recurso em dobro", "Torres de palha", "Chuva de vaca"]
const RULE_TEXT = ["Regras normais. Que vença o melhor.", "O recurso enche em dobro desde o primeiro segundo. Correria!",
	"As torres têm só 60% da vida. Qualquer vacilo custa caro.", "De tempos em tempos cai uma vaca do céu num lugar aleatório. Em todo mundo."]
const TOURNAMENT_LEVEL = 5   # no torneio todas as cartas (suas e do bot) jogam no mesmo nível
var tournament := false
var skip_intro := false  # testes automáticos pulam a tela de "versus"
var friendly := false   # amistoso de clã: não vale troféu nem baú
var rule := 0
var arena_override := 0
var daily := false      # Desafio do Dia: baralho pronto, cartas niveladas, não vale troféu


func clear_special():
	daily = false
	friendly = false
	tournament = false
	rule = 0
	arena_override = 0


## partida de torneio contra um bot específico
func start_tournament_match(tree: SceneTree, bot_name: String, rule_id: int, arena_i: int):
	mode = MODE_1V1
	tournament = true
	rule = rule_id
	arena_override = arena_i
	next_ai_profile = BotLearning.get_or_create_profile(bot_name)
	tree.change_scene_to_file(BATTLE_SCENE)


## Desafio do Dia: você joga com o baralho do dia (emprestado), tudo no nível
## de torneio, contra alguém da sua faixa. Não vale troféu.
func start_daily_match(tree: SceneTree, deck: Array):
	clear_special()
	mode = MODE_1V1
	tournament = true
	daily = true
	arena_override = randi_range(1, 7)
	DeckManager.full_deck.assign(deck)   # só nesta partida; o menu devolve o seu baralho
	next_ai_profile = choose_opponent()
	tree.change_scene_to_file(BATTLE_SCENE)


func start_1v1(tree: SceneTree):
	clear_special()
	# "clima maluco": de vez em quando a partida normal vem com uma regra doida
	if randf() < 0.15:
		rule = 1 + randi() % (RULE_NAMES.size() - 1)
	mode = MODE_1V1
	next_ai_profile = choose_opponent()
	tree.change_scene_to_file(BATTLE_SCENE)


func start_2v2(tree: SceneTree):
	clear_special()
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
