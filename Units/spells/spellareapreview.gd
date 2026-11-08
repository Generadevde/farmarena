extends Node2D
class_name SpellAreaPreview

var radius: float = 80.0


func _draw():
	# preenchimento translúcido + contorno mais forte, pra dar noção clara
	# de até onde o feitiço alcança antes de você confirmar o clique
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.7, 1.0, 0.25))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.4, 0.7, 1.0, 0.9), 2.0)


func set_radius(new_radius: float):
	if radius != new_radius:
		radius = new_radius
		queue_redraw()
