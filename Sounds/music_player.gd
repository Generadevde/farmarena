extends Node

# arrasta seus arquivos de música aqui no Inspector (autoload não abre no
# editor de cena normal -- acessa via Project Settings > Autoload > clica
# no ícone ao lado do MusicPlayer pra abrir o Inspector dele)
@export var menu_tracks: Array[AudioStream] = []
@export var battle_tracks: Array[AudioStream] = []

enum Category { NONE, MENU, BATTLE }

var _player: AudioStreamPlayer
var _current_category: Category = Category.NONE
var _last_track: AudioStream = null


func _ready():
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_track_finished)


func play_menu_music():
	_play_category(Category.MENU, menu_tracks)


func play_battle_music():
	_play_category(Category.BATTLE, battle_tracks)


func stop_music():
	_current_category = Category.NONE
	_player.stop()


func _play_category(category: Category, tracks: Array[AudioStream]):
	# já está tocando essa categoria? deixa a faixa atual em paz, não reinicia
	if _current_category == category and _player.playing:
		return
	_current_category = category
	_play_random_track(tracks)


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
	_player.play()


# quando uma faixa termina sozinha (chegou ao fim), sorteia a próxima da
# MESMA categoria que estava tocando -- é isso que cria a "playlist" aleatória
func _on_track_finished():
	match _current_category:
		Category.MENU:
			_play_random_track(menu_tracks)
		Category.BATTLE:
			_play_random_track(battle_tracks)
