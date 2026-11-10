extends Node2D
class_name SpellAreaPreview
## círculo de mira: área do feitiço, ou alcance da defesa/atirador ao posicionar

var radius: float = 80.0
var color := Color(0.4, 0.7, 1.0)
var fill := 0.25


func _draw():
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, fill))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(color.r, color.g, color.b, 0.95), 2.5)
	for i in 24:  # tracejado por fora: destaca o limite em cima de qualquer cenário
		var a = TAU * i / 24.0
		draw_arc(Vector2.ZERO, radius + 3.0, a, a + TAU / 48.0, 4, Color(1, 1, 1, 0.7), 1.5)


func set_radius(new_radius: float):
	if radius != new_radius:
		radius = new_radius
		queue_redraw()
