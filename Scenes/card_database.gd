extends Node
## Banco de cartas JOGÁVEIS (oficiais do Catalogo + criadas no Criador + Safra).
## As oficiais são montadas na memória pelo Catalogo -- ver Scripts/catalogo.gd

var all_cards: Array[CardData] = []


func _init():
	all_cards.assign(Catalogo.cards())


## acha a carta pelo caminho salvo (baralho, estatística, bot...)
func get_card(path: String) -> CardData:
	return Catalogo.find_card(path)
