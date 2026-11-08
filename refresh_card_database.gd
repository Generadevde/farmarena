@tool
extends EditorScript

# AJUSTA esse caminho pro lugar de verdade do seu card_database.tscn --
# olha no painel de Arquivos do Godot onde ele está e copia o caminho
# (clica com botão direito nele → "Copiar Caminho")
const CARD_DB_SCENE_PATH = "res://Scenes/card_database.tscn"

const CARDS_FOLDER = "res://Cards/Data/"


# Como rodar: abre esse arquivo no Editor de Script do Godot, e vai em
# Arquivo → Rodar (ou Ctrl+Shift+X). Roda uma vez só, quando quiser
# atualizar o array com o que estiver na pasta AGORA.
func _run():
	var found_cards: Array[CardData] = []
	_scan_folder(CARDS_FOLDER, found_cards)

	if found_cards.is_empty():
		print("Nenhuma carta encontrada em ", CARDS_FOLDER, " -- confere se o caminho está certo")
		return

	var packed_scene: PackedScene = load(CARD_DB_SCENE_PATH)
	if packed_scene == null:
		print("ERRO: não achei a cena em ", CARD_DB_SCENE_PATH)
		print("Ajusta a constante CARD_DB_SCENE_PATH no topo desse script pro caminho certo.")
		return

	var instance = packed_scene.instantiate()
	instance.all_cards = found_cards

	var new_packed_scene = PackedScene.new()
	new_packed_scene.pack(instance)
	var err = ResourceSaver.save(new_packed_scene, CARD_DB_SCENE_PATH)

	if err == OK:
		print("Pronto! %d carta(s) encontrada(s) e salva(s) em all_cards:" % found_cards.size())
		for card in found_cards:
			print("  - ", card.card_name)
	else:
		print("ERRO ao salvar a cena: código ", err)

	instance.queue_free()


func _scan_folder(path: String, found_cards: Array[CardData]):
	var dir = DirAccess.open(path)
	if dir == null:
		print("Não consegui abrir a pasta ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir() and !file_name.begins_with("."):
			_scan_folder(full_path + "/", found_cards)  # entra em subpastas também
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is CardData:
				found_cards.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
