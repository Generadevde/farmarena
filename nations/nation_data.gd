extends Resource
class_name NationData

## Nome da nação -- precisa bater EXATAMENTE com o texto usado no campo
## "nation" de CardData/BaseData (ex: "Mimosas"), senão não casa com nada
@export var nation_name: String = ""

## Ícone dessa nação, pra aparecer na tela de coleção -- se ficar em
## branco, usa um quadrado colorido genérico no lugar (com a cor abaixo)
@export var icon: Texture2D

## Cor de fallback, usada só enquanto o ícone acima não estiver preenchido
@export var color: Color = Color(0.6, 0.6, 0.6)
