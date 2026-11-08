extends Label

func _process(delta):
	text = str(int(GameManager.player_money))
