extends Node
## Efeitos sonoros (autoload "Sfx"). Uso: Sfx.play("golpe")
## Os sons são sintetizados por ci/tools/gerar_sons.py (Sounds/sfx/*.wav).
## Cada som tem um intervalo mínimo entre repetições -- 12 pintinhos batendo
## juntos tocam um "golpe" só, não doze.

const NAMES = ["golpe", "golpe2", "tiro", "explosao", "raio", "cura", "gelo", "furia", "lama", "morte", "nasce", "torre_dano", "torre_cai",
	"clique", "moeda", "bau", "carta", "nivel", "vitoria", "derrota", "erro", "vaca"]
const MIN_GAP = {"golpe": 0.07, "golpe2": 0.07, "tiro": 0.08, "morte": 0.1, "explosao": 0.12, "torre_dano": 0.15, "nasce": 0.08, "cura": 0.4}
const VOLUME_DB = -7.0
const VOICES = 10

var enabled := true
var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last: Dictionary = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path = "res://Sounds/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	Config.setup()
	if "_player" in MusicPlayer and MusicPlayer._player != null:
		MusicPlayer._player.bus = Config.BUS_MUSIC
	for i in VOICES:
		var p = AudioStreamPlayer.new()
		p.bus = Config.BUS_SFX
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


func play(sound: String, pitch_spread: float = 0.08, volume_offset: float = 0.0):
	if !enabled or !_streams.has(sound):
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -9.0)) < float(MIN_GAP.get(sound, 0.03)):
		return
	_last[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.volume_db = VOLUME_DB + volume_offset
	p.play()


# todo botão do jogo ganha o clique sozinho
func _on_node_added(node: Node):
	if node is Button:
		node.pressed.connect(_click)


func _click():
	play("clique", 0.03)
