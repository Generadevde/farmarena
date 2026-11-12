extends Node

const SAVE_DIR = "user://profiles/"

# limiar de troféu pra cada arena -- modelo clássico: sua arena depende só
# do seu PRÓPRIO troféu acumulado, nunca de comparação com quem mais tá
# jogando. Isso resolve de vez o problema de bot rodando de fundo "roubar
# vaga" de quem joga pouco -- não existe vaga, existe só o seu progresso
const DEFAULT_ARENAS = [
	{},  # índice 0 não existe, só de preenchimento
	{"name": "Pasto Verde", "emoji": "🌱", "trophy_threshold": 0},
	{"name": "Curral Velho", "emoji": "🐄", "trophy_threshold": 600},
	{"name": "Milharal", "emoji": "🌽", "trophy_threshold": 1300},
	{"name": "Brejo", "emoji": "🐸", "trophy_threshold": 2100},
	{"name": "Vila da Feira", "emoji": "🎪", "trophy_threshold": 3000},
	{"name": "Noite Estranha", "emoji": "🛸", "trophy_threshold": 4000},
	{"name": "Arena do Rodeio", "emoji": "🏆", "trophy_threshold": 5000},
]
const DEFAULT_MAX_ARENA = 7

# versão EDITÁVEL das arenas (o Criador de Arenas mexe aqui) -- começa igual
# às padrões e o CustomContent aplica nome/emoji/troféu/recompensa/fundo
# personalizados por cima, e pode adicionar arenas novas no fim
var arenas: Array = DEFAULT_ARENAS.duplicate(true)
var max_arena: int = DEFAULT_MAX_ARENA

# faixa de troféu ganho/perdido por partida -- continua variando conforme a
# diferença de troféu entre os dois lados, igual já tínhamos
const WIN_MIN = 25.0
const WIN_MAX = 50.0
const LOSS_MIN = 5.0
const LOSS_MAX = 20.0
const REFERENCE_POINT_GAP = 200.0

var trophies: Dictionary = {}  # nome (bot ou jogador) -> troféu acumulado -- NUNCA reseta por temporada


func _get_save_path() -> String:
	return SAVE_DIR + "arenas_%d.save" % PlayerProfile.active_profile_id


func load_for_active_profile():
	trophies = {}

	var path = _get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			trophies = data.get("trophies", {})

	_sync_player_arena_cache()


func _save():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"trophies": trophies}))


func get_trophies(participant_name: String) -> int:
	return trophies.get(participant_name, 0)


func get_arena_info(index: int) -> Dictionary:
	return arenas[clamp(index, 1, max_arena)]


# calcula a arena a partir do troféu -- nunca é "guardada e movida", é
# sempre derivada na hora, então nunca fica dessincronizada de nada
func get_arena_for_trophies(trophy_count: int) -> int:
	var result = 1
	for i in range(2, max_arena + 1):
		if trophy_count >= arenas[i]["trophy_threshold"]:
			result = i
	return result


func get_participant_arena(participant_name: String) -> int:
	return get_arena_for_trophies(get_trophies(participant_name))


# ouro por vitória escalando por arena -- Arena 1 = 40, sobe 30 a cada arena
# seguinte (Arena 2 = 70, Arena 3 = 100, ..., Arena 7 = 220). Vale tanto pro
# jogador quanto pro bot, usando a arena de CADA UM na hora (get_participant_arena)
# tabela de recompensa por arena -- cada faixa é [mínimo, máximo], sorteado
# na hora. Só Arena 1 preenchida por enquanto -- arena sem entrada própria
# cai no fallback da Arena 1 (get() com default), até você definir as outras
const REWARD_TABLE = {
	1: {
		"win_gold": [50, 100], "win_xp": [25, 75],
		"loss_gold": [25, 40], "loss_xp": [20, 40],
	},
}


# recompensa padrão de uma arena -- a Arena 1 é a da tabela acima; as outras
# escalam ~+30% de ouro e +25% de XP por arena (antes caíam todas na Arena 1)
func default_rewards_for(arena_index: int) -> Dictionary:
	var base = REWARD_TABLE[1]
	var g = pow(1.3, arena_index - 1)
	var x = pow(1.25, arena_index - 1)
	return {
		"win_gold": [int(base["win_gold"][0] * g), int(base["win_gold"][1] * g)],
		"win_xp": [int(base["win_xp"][0] * x), int(base["win_xp"][1] * x)],
		"loss_gold": [int(base["loss_gold"][0] * g), int(base["loss_gold"][1] * g)],
		"loss_xp": [int(base["loss_xp"][0] * x), int(base["loss_xp"][1] * x)],
	}


func get_rewards(arena_index: int) -> Dictionary:
	var info = get_arena_info(arena_index)
	if info.has("rewards"):
		return info["rewards"]
	return default_rewards_for(clamp(arena_index, 1, max_arena))


# textura de fundo (pixel art) da arena, ou null se não tiver
func get_background(arena_index: int) -> Texture2D:
	var info = get_arena_info(arena_index)
	return info.get("background_texture", null)


func get_match_reward(arena_index: int, won: bool) -> Dictionary:
	var table = get_rewards(arena_index)
	var gold_range = table["win_gold"] if won else table["loss_gold"]
	var xp_range = table["win_xp"] if won else table["loss_xp"]
	return {
		"gold": randi_range(gold_range[0], gold_range[1]),
		"xp": randi_range(xp_range[0], xp_range[1]),
	}


func get_player_arena() -> int:
	return get_participant_arena(PlayerProfile.player_name)


# lista todo mundo que está NA MESMA arena que esse índice agora mesmo,
# ordenado por troféu -- calculado na hora, sempre em dia
func get_arena_ranking(arena_index: int) -> Array:
	var entries = []

	if get_player_arena() == arena_index:
		entries.append({
			"name": PlayerProfile.player_name,
			"score": get_trophies(PlayerProfile.player_name),
			"is_player": true,
		})

	for bot_name in BotSimulator.roster_names:
		if get_participant_arena(bot_name) == arena_index:
			entries.append({
				"name": bot_name,
				"score": get_trophies(bot_name),
				"is_player": false,
			})

	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	return entries


# calcula o troféu ganho/perdido (variável, pela diferença de troféu entre
# os dois) e já aplica nos dois lados -- chama isso em vez de
# Leaderboard.record_match() direto, toda vez que o resultado for de arena
## simulated = partida de bot contra bot (simulação). Nela o perdedor perde
## quase o mesmo que o vencedor ganha -- senão o elenco inteiro subia ~12
## troféus a cada 2 minutos e disparava na frente do jogador.
const SIMULATED_LOSS_RATIO = 1.0   # partida simulada é soma zero: o que um ganha o outro perde (0.85 inflava o topo)


## quantos troféus o perdedor perderia nessa partida (sem aplicar nada)
func loss_points_for(winner_name: String, loser_name: String) -> int:
	var diff = get_trophies(loser_name) - get_trophies(winner_name)
	var t = (clamp(diff / REFERENCE_POINT_GAP, -1.0, 1.0) + 1.0) / 2.0
	return int(round(lerp(LOSS_MIN, LOSS_MAX, t)))


## multa (ex.: sair no meio da partida): só tira troféu de um nome
func apply_penalty(participant_name: String, points: int):
	trophies[participant_name] = max(get_trophies(participant_name) - points, 0)
	_sync_player_arena_cache()
	_save()


func record_match_points(winner_name: String, loser_name: String, simulated: bool = false):
	var winner_trophies = get_trophies(winner_name)
	var loser_trophies = get_trophies(loser_name)

	# positivo = o perdedor tinha MAIS troféu que o vencedor (vitória de zebra)
	var diff = loser_trophies - winner_trophies
	var t = (clamp(diff / REFERENCE_POINT_GAP, -1.0, 1.0) + 1.0) / 2.0  # 0.0 a 1.0

	var win_points = lerp(WIN_MIN, WIN_MAX, t)
	var loss_points = lerp(LOSS_MIN, LOSS_MAX, t)
	if simulated:
		loss_points = win_points * SIMULATED_LOSS_RATIO

	trophies[winner_name] = get_trophies(winner_name) + int(round(win_points))
	trophies[loser_name] = max(get_trophies(loser_name) - int(round(loss_points)), 0)


	# o Leaderboard/temporada continuam existindo, só que agora são um
	# placar PURAMENTE informativo (como foi essa semana) -- não afetam
	# mais a arena de ninguém, essa parte agora é só o troféu acima
	Leaderboard.record_match(winner_name, true, loser_name, win_points, -loss_points)

	_sync_player_arena_cache()
	_save()


# mantém PlayerProfile.arena_index/arena_name em dia, em TEMPO REAL, a cada
# partida -- é só um cache de conveniência pra quem já lê esses campos
# direto (menu, tela de ranking); a fonte da verdade é sempre o troféu
func _sync_player_arena_cache():
	var new_arena = get_player_arena()
	if PlayerProfile.arena_index != new_arena:
		PlayerProfile.arena_index = new_arena
		PlayerProfile.arena_name = get_arena_info(new_arena)["name"]
		PlayerProfile.save_profile()
