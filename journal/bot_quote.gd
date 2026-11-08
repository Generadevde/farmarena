extends Resource
class_name BotQuote

@export var bot_name: String = ""

# frases prontas, escritas à mão (se preenchido, entra no sorteio junto com
# as semi-automáticas abaixo)
@export var phrases: Array[String] = []

# frase semi-automática: sorteia um pedaço de cada lista e junta -- "início"
# + "meio", e opcionalmente emenda uma carta no final (nome + taxa de
# vitória dela, se já tiver dado suficiente)
@export var pre_phrase_1: Array[String] = []
@export var pre_phrase_2: Array[String] = []
@export var mention_card: bool = false
