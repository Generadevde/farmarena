extends Control

# 0 = próxima carta que vai entrar na mão
# 1 = a carta que vem depois dessa
@export var queue_index: int = 0


func _ready():
	DeckManager.hand_changed.connect(_refresh)
	_refresh()


func _refresh():
	if queue_index >= DeckManager.draw_queue.size():
		$Icon.texture = null
		return

	var card: CardData = DeckManager.draw_queue[queue_index]
	if card == null:
		$Icon.texture = null
		return

	$Icon.texture = card.icon
