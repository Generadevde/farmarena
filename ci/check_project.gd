extends Node

# Só pro GitHub Actions: roda o jogo sem tela, com todos os autoloads
# carregados, e tenta carregar CADA script e CADA cena do projeto. Qualquer
# erro de GDScript aparece no log do build ("CHECK FALHOU").

var _failed: Array = []


func _ready():
	var files: Array = []
	_collect("res://", files)
	for path in files:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			_failed.append(path)
			print("CHECK FALHOU: ", path)
		elif res is GDScript and !res.can_instantiate() and !_is_abstract_ok(res):
			_failed.append(path)
			print("CHECK FALHOU (não compila): ", path)
	print("CHECK RESULTADO: %d arquivo(s) verificados, %d com problema" % [files.size(), _failed.size()])
	# abre as telas principais de verdade, uma por uma
	for scene in ["res://creator/creator_menu.tscn", "res://Scenes/hub.tscn", "res://Scenes/profile_setup.tscn"]:
		var packed: PackedScene = load(scene)
		if packed == null:
			print("CHECK FALHOU (cena): ", scene)
			continue
		var inst = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame
		print("CHECK cena aberta ok: ", scene)
	get_tree().quit(1 if !_failed.is_empty() else 0)


func _is_abstract_ok(_s) -> bool:
	return false


func _collect(dir_path: String, out: Array):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.begins_with("."):
			f = dir.get_next()
			continue
		var full = dir_path.path_join(f)
		if dir.current_is_dir():
			if f != "android" and f != "build" and f != "ci":
				_collect(full, out)
		elif f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(full)
		f = dir.get_next()
	dir.list_dir_end()
