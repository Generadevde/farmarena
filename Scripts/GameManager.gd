extends Node

enum Team {
	PLAYER,
	ENEMY
} 

var player_money = 100
var enemy_money = 100


# relógio do JOGO (segue pausa e velocidade do jogo) -- usado pelos efeitos
# de unidade (atordoar, congelar, invulnerável...). Antes usavam o relógio
# do aparelho, que continua andando com a partida pausada/travada
var game_time: float = 0.0


func _physics_process(delta):
	game_time += delta
