extends Node2D
class_name Poca
## Poça do RASTRO de uma tropa: fica no chão um tempo e machuca (e pode deixar lento)
## o inimigo do chão que pisa nela. Vive sozinha: não some se a dona morrer.

var team
var damage := 15
var radius := 28.0
var slow := 0.0
var life := 4.0
var color := Color(0.5, 0.85, 0.3)
var _t := 0.0
var _tick := 0.0


static func drop(parent: Node, pos: Vector2, p_team, p_damage: int, p_radius: float, p_life: float, p_slow: float, col: Color) -> Poca:
	var p = Poca.new()
	p.team = p_team
	p.damage = p_damage
	p.radius = p_radius
	p.life = p_life
	p.slow = p_slow
	p.color = col
	p.position = pos
	p.z_index = -4
	parent.add_child(p)
	return p


func _process(delta):
	_t += delta
	if _t >= life:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for u in get_tree().get_nodes_in_group("units"):
			if !is_instance_valid(u) or !("team" in u) or u.team == team or u.stats == null or u.is_queued_for_deletion():
				continue
			if u.stats.unit_type == UnitData.UnitType.AIR or global_position.distance_to(u.global_position) > radius + 8.0:
				continue
			if damage > 0:
				u.take_damage(damage)
			if slow > 0.0 and is_instance_valid(u) and u.has_method("apply_on_hit_effect"):
				u.apply_on_hit_effect(UnitData.OnHitEffect.SLOW, slow, 0.8, 1.0, 0.0, global_position)
	queue_redraw()


func _draw():
	var fade = minf(1.0, (life - _t) / 0.6)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.28 * fade))
	draw_circle(Vector2(radius * 0.25, -radius * 0.2), radius * 0.45, Color(color.r, color.g, color.b, 0.22 * fade))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color(color.r, color.g, color.b, 0.55 * fade), 1.5)
