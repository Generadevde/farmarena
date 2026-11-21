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

enum Kind { BURST, RING, ZONE, NUMBER, PUFF, BOLT, SLASH, SWIRL, RAIN, BUBBLES }

# ESTILOS DE FEITIÇO (aba "Efeitos" do Criador). 0 = automático (o jogo escolhe pelo que o feitiço faz)
const STYLE_NAMES = ["Automático", "Fogo", "Raios", "Gelo", "Nuvem tóxica", "Redemoinho", "Estrelas", "Chuva de pedras", "Onda de choque", "Folhas", "Sombra", "Bolhas"]
const STYLE_COLORS = [Color(1, 1, 0.8), Color(1.0, 0.55, 0.2), Color(1.0, 0.95, 0.5), Color(0.6, 0.85, 1.0), Color(0.55, 0.85, 0.3), Color(0.8, 0.85, 0.9),
	Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 0.4), Color(1.0, 0.9, 0.7), Color(0.45, 0.8, 0.35), Color(0.5, 0.3, 0.7), Color(0.5, 0.8, 1.0)]


## efeito completo de um feitiço num estilo. `duration` 0 = na hora. `power` (0.5..2) = quanto de partícula
static func styled(parent: Node, pos: Vector2, r: float, col: Color, style: int, duration: float, power: float = 1.0):
	var n = int(round(14.0 * clampf(power, 0.3, 2.5)))
	var long = maxf(duration, 0.0)
	match style:
		1:   # FOGO: clarão, labaredas subindo e brasa no chão
			ring(parent, pos, r, col, 0.45)
			burst(parent, pos, col, n + 6, r * 2.4, 5.0)
			burst(parent, pos, Color(1.0, 0.9, 0.4), n, r * 1.4, 3.0)
			_spawn(parent, pos, Kind.BUBBLES, maxf(long, 0.8), r, Color(1.0, 0.45, 0.15), n)
		2:   # RAIOS: vários raios caindo na área
			ring(parent, pos, r, col, 0.3)
			for i in clampi(int(n / 5.0), 2, 6):
				bolt(parent, pos + Vector2.RIGHT.rotated(randf() * TAU) * r * randf_range(0.0, 0.7), col)
			if long > 0.0:
				zone(parent, pos, r, col, long)
		3:   # GELO: cristais estourando e chão congelado
			ring(parent, pos, r, col, 0.5)
			burst(parent, pos, Color(1, 1, 1), n, r * 1.6, 4.0)
			burst(parent, pos, col, n, r * 2.2, 3.0)
			zone(parent, pos, r, col, maxf(long, 0.9))
		4:   # NUVEM TÓXICA: bolhas subindo enquanto dura
			zone(parent, pos, r, col, maxf(long, 0.8))
			_spawn(parent, pos, Kind.BUBBLES, maxf(long, 0.8), r, col, n + 4)
		5:   # REDEMOINHO: espiral girando
			_spawn(parent, pos, Kind.SWIRL, maxf(long, 0.9), r, col, n)
		6:   # ESTRELAS: brilho que espalha
			ring(parent, pos, r, col, 0.5)
			burst(parent, pos, col, n + 8, r * 1.8, 3.0)
			burst(parent, pos, Color(1, 1, 1), n, r * 2.6, 2.0)
			if long > 0.0:
				zone(parent, pos, r, col, long)
		7:   # CHUVA DE PEDRAS: riscos caindo do céu
			_spawn(parent, pos, Kind.RAIN, maxf(long, 0.7), r, col, n + 4)
			zone(parent, pos, r, col, maxf(long, 0.7))
		8:   # ONDA DE CHOQUE: três ondas seguidas
			ring(parent, pos, r, col, 0.35)
			ring(parent, pos, r * 0.7, col, 0.5)
			ring(parent, pos, r * 1.25, Color(1, 1, 1), 0.6)
			burst(parent, pos, col, n, r * 2.8, 3.0)
		9:   # FOLHAS: folhinhas rodando
			_spawn(parent, pos, Kind.SWIRL, maxf(long, 0.9), r, col, int(n / 2.0))
			burst(parent, pos, col, n, r * 1.5, 4.0)
		10:  # SOMBRA: mancha escura e fagulhas roxas
			zone(parent, pos, r, Color(0.12, 0.05, 0.2), maxf(long, 0.9))
			ring(parent, pos, r, col, 0.6)
			burst(parent, pos, col, n, r * 1.4, 3.5)
		11:  # BOLHAS: muitas bolhas, sem mancha no chão
			ring(parent, pos, r, col, 0.4)
			_spawn(parent, pos, Kind.BUBBLES, maxf(long, 1.0), r, col, n + 10)
		_:
			ring(parent, pos, r, col, 0.45)


static func _spawn(parent: Node, pos: Vector2, k: int, lifetime: float, r: float, col: Color, count: int):
	var fx = _make(parent, pos, k, lifetime)
	if fx == null:
		return
	fx.color = col
	fx.radius = r
	fx.z_index = 6
	for i in clampi(count, 3, 40):
		# [posição no chão, fase 0..1, tamanho]
		fx._bits.append([Vector2.RIGHT.rotated(randf() * TAU) * r * sqrt(randf()), randf(), randf_range(2.0, 5.0)])

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
		Kind.SWIRL:
			var fade_s = minf(1.0, minf(t / 0.2, (life - t) / 0.3))
			for arm in 3:
				var a0 = t * 5.0 + arm * TAU / 3.0
				for seg in 5:
					var rr = radius * (0.2 + 0.16 * seg)
					draw_arc(Vector2.ZERO, rr, a0 + seg * 0.5, a0 + seg * 0.5 + 0.9, 8, Color(color.r, color.g, color.b, (0.75 - 0.1 * seg) * fade_s), 3.0)
			for b in _bits:
				var ang = t * 4.0 + b[1] * TAU
				var rr2 = radius * (0.3 + 0.7 * fposmod(b[1] + t * 0.4, 1.0))
				draw_rect(Rect2(Vector2(cos(ang), sin(ang) * 0.7) * rr2 - Vector2(b[2], b[2]) * 0.5, Vector2(b[2], b[2])), Color(color.r, color.g, color.b, 0.9 * fade_s))
		Kind.RAIN:
			var fade_r = minf(1.0, (life - t) / 0.25)
			for b in _bits:
				var ph = fposmod(b[1] + t * 1.8, 1.0)       # cada pedra cai, bate e recomeça
				var ground: Vector2 = b[0]
				if ph < 0.75:
					var hgt = (1.0 - ph / 0.75) * 260.0
					var p0 = ground + Vector2(hgt * 0.25, -hgt)
					draw_line(p0, p0 + Vector2(6, -22), Color(color.r, color.g, color.b, 0.9 * fade_r), 3.0)
					draw_rect(Rect2(p0 - Vector2(3, 3), Vector2(6, 6)), Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, fade_r))
				else:
					var kk = (ph - 0.75) / 0.25
					draw_arc(ground, 5.0 + 12.0 * kk, 0, TAU, 12, Color(1, 0.95, 0.8, (1.0 - kk) * fade_r), 2.0)
		Kind.BUBBLES:
			var fade_b = minf(1.0, minf(t / 0.15, (life - t) / 0.3))
			for b in _bits:
				var ph2 = fposmod(b[1] + t * 0.9, 1.0)
				var p1: Vector2 = b[0] + Vector2(sin((t + b[1] * 9.0) * 5.0) * 3.0, -ph2 * 34.0)
				draw_circle(p1, b[2] * (0.6 + 0.6 * ph2), Color(color.r, color.g, color.b, 0.75 * (1.0 - ph2) * fade_b))
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
