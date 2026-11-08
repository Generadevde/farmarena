extends Node

const SAVE_DIR = "user://profiles/"

# duração de uma temporada, em dias
const SEASON_DURATION_DAYS = 7.0

var season_start_time: float = 0.0  # timestamp unix de quando a temporada atual começou
var season_number: int = 1


func _get_save_path() -> String:
	return SAVE_DIR + "season_%d.save" % PlayerProfile.active_profile_id


# chama isso depois de escolher/criar/trocar de perfil -- carrega (ou começa)
# a temporada DESSE perfil especificamente, e já verifica se ela venceu
func load_for_active_profile():
	season_start_time = 0.0
	season_number = 1

	var path = _get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			season_start_time = data.get("season_start_time", 0.0)
			season_number = data.get("season_number", 1)

	if season_start_time <= 0.0:
		# primeiro contato desse perfil com o sistema de temporada -- só
		# marca o começo, não tem nada pra resetar ainda
		season_start_time = Time.get_unix_time_from_system()
		_save()
	else:
		_check_and_reset_if_needed()


func _check_and_reset_if_needed():
	if _elapsed_days() >= SEASON_DURATION_DAYS:
		_start_new_season()


func _start_new_season():
	# não mexe mais em arena aqui -- ela sobe/desce sozinha, em tempo real,
	# junto com cada partida (ver ArenaManager). A temporada agora só reseta
	# o placar informativo da semana (Leaderboard.season_points)
	Leaderboard.reset()
	SeasonStats.reset()
	season_number += 1
	season_start_time = Time.get_unix_time_from_system()
	_save()


# só pra testar manualmente sem precisar esperar os dias de verdade passarem
func force_new_season():
	_start_new_season()


func get_days_remaining() -> float:
	return max(SEASON_DURATION_DAYS - _elapsed_days(), 0.0)


func _elapsed_days() -> float:
	var now = Time.get_unix_time_from_system()
	return (now - season_start_time) / 86400.0


func _save():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"season_start_time": season_start_time,
		"season_number": season_number,
	}))
