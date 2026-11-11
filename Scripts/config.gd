extends RefCounted
class_name Config
## CONFIGURAÇÕES do jogo (valem pra todos os perfis): volume da música e dos
## efeitos. Guardado em user://config.json.

const PATH = "user://config.json"
const BUS_MUSIC = "Musica"
const BUS_SFX = "Efeitos"

static var data: Dictionary = {"musica": 0.8, "efeitos": 0.9}
static var _ready_done := false


static func setup():
	if _ready_done:
		return
	_ready_done = true
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for k in parsed:
				data[k] = parsed[k]
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	apply()


static func apply():
	for pair in [[BUS_MUSIC, "musica"], [BUS_SFX, "efeitos"]]:
		var idx = AudioServer.get_bus_index(pair[0])
		if idx == -1:
			continue
		var v = clampf(float(data.get(pair[1], 1.0)), 0.0, 1.0)
		AudioServer.set_bus_mute(idx, v <= 0.01)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.01)))


static func set_volume(key: String, value: float):
	data[key] = clampf(value, 0.0, 1.0)
	apply()


static func save():
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
