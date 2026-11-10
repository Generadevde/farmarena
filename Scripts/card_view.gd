extends Control
class_name CardView
## Carta desenhada por código: moldura na cor da raridade, faixa da turma,
## arte 48x48, custo, nível e a borda de MAESTRIA (quanto mais você usa a
## carta, mais ela brilha: bronze -> prata -> ouro -> diamante).

signal tapped(card)

var card: CardData
var locked := false          # ainda não encontrada
var show_level := true
var badge := ""              # texto pequeno no rodapé ("x12", "NOVA!", "Arena 3")
var badge_color := Color(1, 0.9, 0.5)
var selected := false
var mastery_override := -1   # -1 = usa a do jogador
var level_override := -1
var _t := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false


static func make(c: CardData, w: float = 132.0) -> CardView:
	var v = CardView.new()
	v.card = c
	v.custom_minimum_size = Vector2(w, w * 1.34)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	return v


func _ready():
	set_process(false)
	_update_anim()


func _update_anim():
	set_process(is_inside_tree() and (selected or _mastery() >= 3))


func set_selected(v: bool):
	selected = v
	_update_anim()
	queue_redraw()


func _mastery() -> int:
	if mastery_override >= 0:
		return mastery_override
	return Progresso.mastery(card) if card != null and !locked else 0


func _process(delta):
	_t += delta
	queue_redraw()


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.global_position
		elif _pressing:
			_pressing = false
			if event.global_position.distance_to(_press_pos) < 18.0:
				tapped.emit(card)


func _draw():
	if card == null:
		return
	var w = size.x
	var h = size.y
	var u = w / 132.0
	var rarity_col: Color = Catalogo.rarity_color(card)
	var turma_col: Color = card.nation_data.color if card.nation_data != null else Color(0.55, 0.55, 0.55)
	var mastery = _mastery()
	var frame_col = rarity_col
	if locked:
		frame_col = Color(0.35, 0.33, 0.3)
		turma_col = Color(0.3, 0.29, 0.27)

	# sombra + moldura
	draw_rect(Rect2(3 * u, 5 * u, w - 3 * u, h - 5 * u), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, 0, w - 3 * u, h - 5 * u), Color("#2a1a22"))
	var inner = Rect2(3 * u, 3 * u, w - 9 * u, h - 11 * u)
	draw_rect(inner, frame_col)
	# fundo da arte (cor da turma, com faixa clara em cima)
	var art_box = Rect2(inner.position + Vector2(4, 4) * u, Vector2(inner.size.x - 8 * u, inner.size.x - 8 * u))
	draw_rect(art_box, turma_col.darkened(0.25))
	draw_rect(Rect2(art_box.position, Vector2(art_box.size.x, art_box.size.y * 0.5)), turma_col.darkened(0.08))
	if card.icon != null:
		var art_rect = Rect2(art_box.position, art_box.size)
		draw_texture_rect(card.icon, art_rect, false, Color(0.12, 0.12, 0.12, 0.9) if locked else Color.WHITE)
	# nome
	var font = ThemeDB.fallback_font
	var name_rect = Rect2(inner.position.x + 2 * u, art_box.end.y + 2 * u, inner.size.x - 4 * u, inner.end.y - art_box.end.y - 4 * u)
	draw_rect(name_rect, Color("#f3e6c8") if !locked else Color(0.6, 0.58, 0.54))
	var fs = int(15 * u)
	var label = card.card_name if !locked else "???"
	while fs > 9 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_rect.size.x - 4:
		fs -= 1
	if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_rect.size.x - 4:
		draw_multiline_string(font, name_rect.position + Vector2(2, fs), label, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x - 4, fs, 2, Color("#3a2414"))
	else:
		draw_string(font, name_rect.position + Vector2(0, name_rect.size.y * 0.5 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, fs, Color("#3a2414"))
	# custo (gota no canto)
	var cc = Vector2(15, 15) * u
	draw_circle(cc, 17 * u, Color("#2a1a22"))
	draw_circle(cc, 15 * u, Color("#58b8f0") if !locked else Color(0.45, 0.45, 0.45))
	var cost = str(card.cost)
	var cfs = int(18 * u)
	var cw = font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	draw_string_outline(font, cc + Vector2(-cw * 0.5, cfs * 0.36), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, 3, Color("#12324a"))
	draw_string(font, cc + Vector2(-cw * 0.5, cfs * 0.36), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color.WHITE)
	# nível
	if show_level and !locked:
		var lv = level_override if level_override > 0 else PlayerProfile.get_card_level(card)
		var txt = "Nv %d" % lv
		var lfs = int(13 * u)
		var lw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 8 * u
		var lr = Rect2(w - 6 * u - lw, 5 * u, lw, 18 * u)
		draw_rect(lr, Color("#2a1a22"))
		draw_string(font, lr.position + Vector2(4 * u, 13.5 * u), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color("#ffe08a"))
	# selo
	if badge != "":
		var bfs = int(13 * u)
		var bw = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x + 10 * u
		var br = Rect2((w - 3 * u - bw) * 0.5, art_box.end.y - 18 * u, bw, 18 * u)
		draw_rect(br, Color(0.1, 0.06, 0.05, 0.88))
		draw_string(font, br.position + Vector2(5 * u, 13.5 * u), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, badge_color)
	# MAESTRIA: borda extra + cantoneiras + brilho andando (ouro/diamante)
	if mastery > 0:
		var mc: Color = Progresso.MASTERY_COLORS[mastery]
		var r = Rect2(1 * u, 1 * u, w - 5 * u, h - 7 * u)
		draw_rect(r, mc, false, (2.0 + mastery * 0.6) * u)
		var k = (6 + mastery * 2) * u
		for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			draw_rect(Rect2(corner - Vector2(k, k) * 0.5, Vector2(k, k)), mc)
			draw_rect(Rect2(corner - Vector2(k, k) * 0.25, Vector2(k, k) * 0.5), mc.lightened(0.5))
		if mastery >= 3:
			var per = 2.0 * (r.size.x + r.size.y)
			for j in (2 if mastery >= 4 else 1):
				var dist = fposmod(_t * 90.0 + j * per * 0.5, per)
				draw_circle(_perimeter_point(r, dist), 4.5 * u, Color(1, 1, 1, 0.95))
				draw_circle(_perimeter_point(r, dist - 8.0), 3.0 * u, Color(mc.r, mc.g, mc.b, 0.8))
	if selected:
		var pulse = 0.6 + 0.4 * sin(_t * 7.0)
		draw_rect(Rect2(-2, -2, w + 1 - 3 * u, h + 1 - 5 * u), Color(1, 1, 1, pulse), false, 4.0)


static func _perimeter_point(r: Rect2, dist: float) -> Vector2:
	var per = 2.0 * (r.size.x + r.size.y)
	dist = fposmod(dist, per)
	if dist < r.size.x:
		return r.position + Vector2(dist, 0)
	dist -= r.size.x
	if dist < r.size.y:
		return Vector2(r.end.x, r.position.y + dist)
	dist -= r.size.y
	if dist < r.size.x:
		return Vector2(r.end.x - dist, r.end.y)
	dist -= r.size.x
	return Vector2(r.position.x, r.end.y - dist)
