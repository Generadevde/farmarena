extends Node

# fonte de TODAS as nações cadastradas -- arrasta aqui, direto no Inspector
# desse autoload, todo arquivo .tres de NationData que você criar. Mesmo
# padrão do CardDatabase.all_cards (preenchimento manual sobrevive à
# exportação pro Android; escaneamento de pasta em tempo de execução não)
var all_nations: Array[NationData] = []


func _init():
	all_nations.assign(Catalogo.nations())


func get_nation_data(nation_name: String) -> NationData:
	for n in all_nations:
		if n != null and n.nation_name == nation_name:
			return n
	return null
