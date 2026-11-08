extends Node

const SAVE_DIR = "user://profiles/"

# perguntas sobre UMA carta só
const SINGLE_CARD_QUESTIONS = [
	"Qual carta mais chata de enfrentar?",
	"Qual é a melhor carta?",
	"Qual carta você mais teme?",
	"Qual carta parece mais forte do que realmente é?",
	"Qual carta merece um nerf?",
]

# perguntas sobre uma DUPLA de cartas
const COMBO_QUESTIONS = [
	"Qual a melhor dupla?",
	"Qual combo mais irritante de enfrentar?",
]

const OPTIONS_COUNT = 4
const COMBO_CHANCE = 0.3  # chance de a enquete ser sobre dupla, não carta única
# de quanto em quanto tempo uma enquete se encerra e outra começa
const POLL_INTERVAL_HOURS = 24.0

var current_poll: Dictionary = {}  # {question, options: [[path,...], ...], votes: [int,...], player_voted}
var last_poll_time: float = 0.0
var poll_history: Array = []  # enquetes já encerradas, com resultado final (guarda só as últimas 10)


func _get_save_path() -> String:
	return SAVE_DIR + "polls_%d.save" % PlayerProfile.active_profile_id


# chama isso depois de escolher/criar/trocar de perfil
func load_for_active_profile():
	current_poll = {}
	last_poll_time = 0.0
	poll_history = []

	var path = _get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			current_poll = data.get("current_poll", {})
			last_poll_time = data.get("last_poll_time", 0.0)
			poll_history = data.get("poll_history", [])

	check_for_rotation()


# pública de propósito -- chama isso toda vez que o jogador abre o jornal
# (não só no carregamento do perfil). Sem isso, quem mantém o mesmo perfil
# aberto sem reiniciar o jogo NUNCA via a enquete rodar de novo, mesmo já
# tendo passado as 24h -- ela ficava presa, sem nunca mostrar resultado
func check_for_rotation():
	_maybe_rotate_poll()


func _maybe_rotate_poll():
	var now = Time.get_unix_time_from_system()

	if current_poll.is_empty():
		_start_new_poll()
		last_poll_time = now
		_save()
		return

	var elapsed_hours = (now - last_poll_time) / 3600.0
	if elapsed_hours >= POLL_INTERVAL_HOURS:
		_close_current_poll()
		_start_new_poll()
		last_poll_time = now
		_save()


func _start_new_poll():
	var pool = CardDatabase.all_cards.duplicate()
	pool.shuffle()
	if pool.size() < OPTIONS_COUNT:
		return  # cartas de menos ainda pra montar uma enquete decente

	var is_combo = randf() < COMBO_CHANCE and pool.size() >= OPTIONS_COUNT * 2
	var question: String
	var options = []

	if is_combo:
		question = COMBO_QUESTIONS[randi() % COMBO_QUESTIONS.size()]
		for i in OPTIONS_COUNT:
			options.append([pool[i * 2].resource_path, pool[i * 2 + 1].resource_path])
	else:
		question = SINGLE_CARD_QUESTIONS[randi() % SINGLE_CARD_QUESTIONS.size()]
		for i in OPTIONS_COUNT:
			options.append([pool[i].resource_path])

	current_poll = {
		"question": question,
		"options": options,
		"votes": [0, 0, 0, 0],
		"player_voted": false,
	}

	_collect_bot_votes()


# cada bot vota assim que a enquete nasce -- se a carta favorita dele estiver
# entre as opções, vota nela; senão, vota em qualquer uma ao acaso
func _collect_bot_votes():
	for bot_name in BotSimulator.roster_names:
		var profile = BotLearning.get_or_create_profile(bot_name)
		var vote_index = _bot_choose_vote(profile)
		current_poll["votes"][vote_index] += 1


func _bot_choose_vote(profile: AIProfile) -> int:
	var options = current_poll["options"]

	if profile.favorite_card != null:
		for i in options.size():
			if options[i].has(profile.favorite_card.resource_path):
				return i

	return randi() % options.size()


func _close_current_poll():
	if current_poll.is_empty():
		return
	poll_history.append(current_poll)
	if poll_history.size() > 10:
		poll_history.pop_front()
	current_poll = {}


# devolve a enquete atual só se o jogador AINDA NÃO votou -- {} se não tiver
# nenhuma rolando ou se já votou (nesse caso, espera a próxima)
func get_active_poll_for_player() -> Dictionary:
	if current_poll.is_empty() or current_poll.get("player_voted", false):
		return {}
	return current_poll


func cast_player_vote(option_index: int):
	if current_poll.is_empty() or current_poll.get("player_voted", false):
		return
	current_poll["votes"][option_index] += 1
	current_poll["player_voted"] = true
	_save()


# texto pronto com o resultado da última enquete encerrada, pro jornal usar
func get_last_poll_result_text() -> String:
	if poll_history.is_empty():
		return ""
	return _format_poll_result(poll_history[-1])


func _format_poll_result(poll_data: Dictionary) -> String:
	var options = poll_data["options"]
	var votes = poll_data["votes"]

	var total = 0
	for v in votes:
		total += v
	if total == 0:
		return ""

	var best_index = 0
	for i in votes.size():
		if votes[i] > votes[best_index]:
			best_index = i

	var winner_names = []
	for path in options[best_index]:
		if ResourceLoader.exists(path):
			winner_names.append(load(path).card_name)

	var percent = round(float(votes[best_index]) / total * 100)
	return "Enquete encerrada -- \"%s\": %s venceu com %d%% dos votos!" % [
		poll_data["question"], " + ".join(winner_names), percent
	]


func _save():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_poll": current_poll,
		"last_poll_time": last_poll_time,
		"poll_history": poll_history,
	}))
