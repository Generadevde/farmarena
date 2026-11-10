extends Node2D
class_name Fx
## Efeitos visuais leves, desenhados por código (sem textura, sem partícula
## de GPU -- barato pro celular). Uso:
##   Fx.burst(pai, pos, cor)          estilhaços de pixel (acerto, morte)
##   Fx.ring(pai, pos, raio, cor)     onda que abre (área, onda de choque)
##   Fx.zone(pai, pos, raio, cor, t)  área no chão que fica por t segundos
##   Fx.number(pai, pos, valor, cor)  número de dano/cura subindo
##   Fx.puff(pai, pos, escala)        fumacinha de morte
##   Fx.bolt(pai, pos, cor)           raio caindo do céu
##   Fx.text(pai, pos, texto, cor)    palavra curta ("CONGELADO!", "+1 torre")

enum Kind { BURST, RING, ZONE, NUMBER, PUFF, BOLT, SLASH }

const MAX_ALIVE = 70  # teto de efeitos simultâneos -- acima disso, os novos são ignorados
static var alive := 0
static var enabled := true

var kind: int = Kind.BURST
var life := 0.4
var t := 0.0
var color := Color.WHITE
var radius := 20.0
var label := ""
var _bits: Array = []  # BURST/PUFF: [pos, vel, tamanho]
var _font: Font
var _angle := 0.0
var _arc := 0.0


static func _make(parent: Node, pos: Vector2, k: int, lifetime: float) -> Fx:
	if !enabled or parent == null or !is_instance_valid(parent) or alive >= MAX_ALIVE:
		return null
	var fx = Fx.new()
	fx.kind = k
	fx.life = lifetime
	fx.z_index = 30
	fx.position = pos
	parent.add_child(fx)
	return fx


static func burst(parent: Node, pos: Vector2, col: Color, count: int = 8, speed: float = 90.0, size: float = 3.0):
	var fx = _make(parent, pos, Kind.BURST, 0.35)
	if fx == null:
		return
	fx.color = col
	for i in count:
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		fx._bits.append([Vector2.ZERO, dir * speed * randf_range(0.5, 1.2), size * randf_range(0.7, 1.3)])


static func puff(parent: Node, pos: Vector2, scale_mult: float = 1.0):
	var fx = _make(parent, pos, Kind.PUFF, 0.45)
	if fx == null:
		return
	fx.color = Color(0.95, 0.93, 0.88)
	for i in 7:
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		fx._bits.append([dir * 4.0 * scale_mult, dir * 34.0 * scale_mult * randf_range(0.5, 1.1) + Vector2(0, -18), 6.0 * scale_mult * randf_range(0.7, 1.2)])


static func ring(parent: Node, pos: Vector2, r: float, col: Color, lifetime: float = 0.35):
	var fx = _make(parent, pos, Kind.RING, lifetime)
	if fx == null:
		return
	fx.color = col
	fx.radius = r
	fx.z_index = 5


static func zone(parent: Node, pos: Vector2, r: float, col: Color, lifetime: float):
	var fx = _make(parent, pos, Kind.ZONE, maxf(lifetime, 0.3))
	if fx == null:
		return
	fx.color = col
	fx.radius = r
	fx.z_index = -5


static func bolt(parent: Node, pos: Vector2, col: Color):
	var fx = _make(parent, pos, Kind.BOLT, 0.28)
	if fx == null:
		return
	fx.color = col
	var p = Vector2(randf_range(-30, 30), -420)
	while p.y < 0:
		fx._bits.append(p)
		p += Vector2(randf_range(-22, 22), randf_range(40, 70))
	fx._bits.append(Vector2.ZERO)


static func slash(parent: Node, pos: Vector2, forward: Vector2, reach: float, arc_deg: float, col: Color = Color(1, 1, 0.85)):
	var fx = _make(parent, pos, Kind.SLASH, 0.22)
	if fx == null:
		return
	fx.color = col
	fx.radius = reach
	fx._angle = forward.angle()
	fx._arc = deg_to_rad(arc_deg)


static func number(parent: Node, pos: Vector2, value: float, col: Color = Color.WHITE):
	if absf(value) < 1.0:
		return
	text(parent, pos + Vector2(randf_range(-8, 8), -14), str(int(round(absf(value)))), col, 0.6)


static func text(parent: Node, pos: Vector2, txt: String, col: Color = Color.WHITE, lifetime: float = 0.9):
	var fx = _make(parent, pos, Kind.NUMBER, lifetime)
	if fx == null:
		return
	fx.color = col
	fx.label = txt
	fx._font = ThemeDB.fallback_font
	fx.z_index = 40


func _enter_tree():
	alive += 1


func _exit_tree():
	alive -= 1


func _process(delta):
	t += delta
	if t >= life:
		queue_free()
		return
	if kind == Kind.BURST or kind == Kind.PUFF:
		for b in _bits:
			b[0] += b[1] * delta
			b[1] *= 0.9
	elif kind == Kind.NUMBER:
		position.y -= 38.0 * delta
	queue_redraw()


func _draw():
	var k = clampf(t / life, 0.0, 1.0)
	match kind:
		Kind.BURST:
			var c = Color(color.r, color.g, color.b, 1.0 - k * k)
			for b in _bits:
				var s = b[2] * (1.0 - k * 0.5)
				draw_rect(Rect2(b[0] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
		Kind.PUFF:
			var c2 = Color(color.r, color.g, color.b, 0.85 * (1.0 - k))
			for b in _bits:
				draw_circle(b[0], b[2] * (0.6 + k * 0.8), c2)
		Kind.RING:
			var r = radius * (0.25 + 0.75 * ease(k, 0.4))
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.22 * (1.0 - k)))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(color.r, color.g, color.b, 1.0 - k), 3.0)
		Kind.ZONE:
			var fade = minf(1.0, minf(t / 0.2, (life - t) / 0.3))
			var pulse = 0.5 + 0.5 * sin(t * 6.0)
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, (0.16 + 0.06 * pulse) * fade))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.75 * fade), 2.0)
			draw_arc(Vector2.ZERO, radius * (0.35 + 0.6 * fposmod(t * 0.9, 1.0)), 0, TAU, 32, Color(color.r, color.g, color.b, 0.3 * fade * (1.0 - fposmod(t * 0.9, 1.0))), 2.0)
		Kind.BOLT:
			var a = 1.0 - k
			for i in range(_bits.size() - 1):
				draw_line(_bits[i], _bits[i + 1], Color(color.r, color.g, color.b, a), 5.0)
				draw_line(_bits[i], _bits[i + 1], Color(1, 1, 1, a), 2.0)
			draw_circle(Vector2.ZERO, 14.0 * (1.0 + k), Color(1, 1, 1, 0.6 * a))
		Kind.SLASH:
			var sweep = _arc * ease(k, 0.3)
			draw_arc(Vector2.ZERO, radius, _angle - _arc * 0.5, _angle - _arc * 0.5 + sweep, 16, Color(color.r, color.g, color.b, 0.9 * (1.0 - k)), 4.0)
			draw_arc(Vector2.ZERO, radius * 0.8, _angle - _arc * 0.5, _angle - _arc * 0.5 + sweep, 16, Color(color.r, color.g, color.b, 0.4 * (1.0 - k)), 3.0)
		Kind.NUMBER:
			var sz = 15 if label.length() <= 4 else 13
			var w = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var pos = Vector2(-w * 0.5, 0)
			var a2 = 1.0 - k * k
			var pop = 1.0 + 0.5 * maxf(0.0, 1.0 - t / 0.12)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
			draw_string_outline(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0.12, 0.07, 0.05, a2))
			draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(color.r, color.g, color.b, a2))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
