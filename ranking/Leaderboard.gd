extends Node

const SAVE_DIR = "user://profiles/"

const POINTS_PER_WIN = 10
const POINTS_PER_LOSS = -4

# troféu PERMANENTE -- nunca zera com o fim de temporada (modelo clássico:
# sua arena depende só disso, não de comparação com ninguém)
var scores: Dictionary = {}
# quanto cada um ganhou/perdeu DESDE que a temporada atual começou -- só
# informativo (pra um placar de "melhor da semana"), não mexe em arena
var season_points: Dictionary = {}
var win_streaks: Dictionary = {}  # nome -> vitórias seguidas atuais
var records: Dictionary = {}      # nome -> {"wins": int, "losses": int}


func _get_save_path() -> String:
	return SAVE_DIR + "leaderboard_%d.save" % PlayerProfile.active_profile_id


# chama isso depois de escolher/criar/trocar de perfil -- carrega (ou zera)
# o ranking DESSE perfil especificamente
func load_for_active_profile():
	scores = {}
	season_points = {}
	win_streaks = {}
	records = {}

	var path = _get_save_path()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data != null:
		scores = data.get("scores", {})
		season_points = data.get("season_points", {})
		win_streaks = data.get("win_streaks", {})
		records = data.get("records", {})


func _save():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"scores": scores,
		"season_points": season_points,
		"win_streaks": win_streaks,
		"records": records,
	}))


# registra o resultado de uma partida entre dois nomes quaisquer. Se vier
# ponto customizado (usado pelo ArenaManager, com a faixa variável de
# +25/+50 a -5/-20), usa ele; senão cai no fixo antigo (POINTS_PER_WIN/LOSS)
func record_match(name_a: String, a_won: bool, name_b: String, points_a: float = INF, points_b: float = INF):
	if points_a == INF:
		points_a = POINTS_PER_WIN if a_won else POINTS_PER_LOSS
	if points_b == INF:
		points_b = POINTS_PER_WIN if !a_won else POINTS_PER_LOSS

	_adjust_score(name_a, points_a)
	_adjust_score(name_b, points_b)
	_update_streak(name_a, a_won)
	_update_streak(name_b, !a_won)
	_update_record(name_a, a_won)
	_update_record(name_b, !a_won)
	_save()


func _update_record(participant_name: String, won: bool):
	if !records.has(participant_name):
		records[participant_name] = {"wins": 0, "losses": 0}
	if won:
		records[participant_name]["wins"] += 1
	else:
		records[participant_name]["losses"] += 1


func get_record(participant_name: String) -> Dictionary:
	return records.get(participant_name, {"wins": 0, "losses": 0})


func get_win_rate(participant_name: String) -> float:
	var record = get_record(participant_name)
	var total = record["wins"] + record["losses"]
	return float(record["wins"]) / total if total > 0 else 0.0


func _adjust_score(participant_name: String, delta: float):
	if !scores.has(participant_name):
		scores[participant_name] = 0
	scores[participant_name] += delta
	scores[participant_name] = max(scores[participant_name], 0)  # nunca fica negativo, feio no ranking

	season_points[participant_name] = season_points.get(participant_name, 0) + delta


# usado só pelo ArenaManager, pra dar um troféu inicial variado ao elenco
# de bot (sem isso, todo mundo nasceria com 0, amontoado na Arena 1)
func set_score(participant_name: String, value: float):
	scores[participant_name] = max(value, 0)
	_save()


func _update_streak(participant_name: String, won: bool):
	if won:
		win_streaks[participant_name] = win_streaks.get(participant_name, 0) + 1
	else:
		win_streaks[participant_name] = 0


func get_score(participant_name: String) -> int:
	return scores.get(participant_name, 0)


func get_season_points(participant_name: String) -> int:
	return season_points.get(participant_name, 0)


func get_win_streak(participant_name: String) -> int:
	return win_streaks.get(participant_name, 0)


# chamado quando uma temporada termina e uma nova começa -- NÃO zera mais
# o troféu (scores), que é permanente agora; só zera o que é da temporada
# em si (o placar informativo da semana, sequência e recorde)
func reset():
	season_points = {}
	win_streaks = {}
	records = {}
	_save()


# lista ordenada do maior pro menor, pronta pra exibir na tela de ranking
func get_ranking() -> Array:
	var entries = []
	for participant_name in scores:
		entries.append({"name": participant_name, "score": scores[participant_name]})
	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	return entries
