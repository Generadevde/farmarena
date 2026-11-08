extends Node

# arrasta seus arquivos de música aqui no Inspector (autoload não abre no
# editor de cena normal -- acessa via Project Settings > Autoload > clica
# no ícone ao lado do MusicPlayer pra abrir o Inspector dele)
@export var menu_tracks: Array[AudioStream] = []
@export var battle_tracks: Array[AudioStream] = []
## faixas pros 2 minutos finais da partida (recurso x2) -- mais aceleradas
@export var final_tracks: Array[AudioStream] = []

enum Category { NONE, MENU, BATTLE, FINAL }

const FADE_TIME = 0.8
const MUSIC_DB = -4.0

var _player: AudioStreamPlayer
var _current_category: Category = Category.NONE
var _last_track: AudioStream = null
var _fade: Tween


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua tocando com a partida pausada no fim
	_player = AudioStreamPlayer.new()
	_player.volume_db = MUSIC_DB
	add_child(_player)
	_player.finished.connect(_on_track_finished)


func play_menu_music():
	_play_category(Category.MENU, menu_tracks)


func play_battle_music():
	_play_category(Category.BATTLE, battle_tracks)


# chamado pela batalha quando entra nos 2 minutos finais (x2)
func play_final_music():
	if final_tracks.is_empty():
		return
	_play_category(Category.FINAL, final_tracks)


func stop_music():
	_current_category = Category.NONE
	_fade_out_then(func(): _player.stop())


func _tracks_for(category: Category) -> Array[AudioStream]:
	match category:
		Category.MENU:
			return menu_tracks
		Category.BATTLE:
			return battle_tracks
		Category.FINAL:
			return final_tracks
	return []


func _play_category(category: Category, tracks: Array[AudioStream]):
	# já está tocando essa categoria? deixa a faixa atual em paz, não reinicia
	if _current_category == category and _player.playing:
		return
	_current_category = category
	if _player.playing:
		# troca suave: abaixa a atual e entra a nova
		_fade_out_then(func(): _play_random_track(tracks))
	else:
		_play_random_track(tracks)


func _fade_out_then(cb: Callable):
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -40.0, FADE_TIME)
	_fade.tween_callback(cb)


func _play_random_track(tracks: Array[AudioStream]):
	if tracks.is_empty():
		return

	var track = tracks[randi() % tracks.size()]
	# evita repetir a mesma faixa duas vezes seguidas, se tiver outra opção
	if tracks.size() > 1:
		while track == _last_track:
			track = tracks[randi() % tracks.size()]

	_last_track = track
	_player.stream = track
	_player.volume_db = -30.0
	_player.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", MUSIC_DB, FADE_TIME)


# quando uma faixa termina sozinha (chegou ao fim), sorteia a próxima da
# MESMA categoria que estava tocando -- é isso que cria a "playlist" aleatória
func _on_track_finished():
	if _current_category != Category.NONE:
		_play_random_track(_tracks_for(_current_category))
