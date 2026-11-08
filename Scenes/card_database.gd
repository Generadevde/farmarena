extends Node

# ajusta esse caminho pra pasta onde ficam os .tres de CardData -- só usado
# como REFORÇO, se o array abaixo estiver vazio (ver comentário dele)
const CARDS_FOLDER = "res://Cards/Data/"

# fonte PRINCIPAL e confiável dos dados de carta -- arrasta TODOS os .tres
# de CardData aqui, direto no Inspector desse autoload. Isso é necessário
# porque o escaneamento de pasta em tempo de execução (o jeito antigo) não
# sobrevive à exportação pro Android -- os arquivos somem do pacote final
# mesmo funcionando perfeito no editor. Esse array, por ser preenchido
# manualmente no Inspector (igual o Roster Names do BotSimulator), já foi
# confirmado que sobrevive à exportação (os 21 bots chegaram certinho).
@export var all_cards: Array[CardData] = []


func _ready():
	# se esqueceu de preencher o array (ou é a primeira vez rodando no
	# editor, antes de arrastar os arquivos), cai pro escaneamento antigo
	# como reforço -- mas isso é só conveniência de desenvolvimento, NÃO
	# confia nisso pra build exportada
	if all_cards.is_empty():
		_scan_folder(CARDS_FOLDER)


func _scan_folder(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("CardDatabase: não consegui abrir a pasta " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			_scan_folder(full_path + "/")  # entra em subpastas também
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is CardData:
				all_cards.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
