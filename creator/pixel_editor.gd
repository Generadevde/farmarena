extends Control
class_name PixelEditor

# Editor de PIXEL ART simples, feito pra dedo no celular. Sem animação: um
# quadro só. Usado pra arte de carta (32x32), base (32x64) e fundo de arena
# (36x64). Abre por cima de tudo; quando aperta "Pronto" emite `finished`
# com a Image desenhada.

signal finished(image: Image)
signal cancelled

const PALETTE = [
	Color("000000"), Color("1d2b53"), Color("7e2553"), Color("008751"),
	Color("ab5236"), Color("5f574f"), Color("c2c3c7"), Color("fff1e8"),
	Color("ff004d"), Color("ffa300"), Color("ffec27"), Color("00e436"),
	Color("29adff"), Color("83769c"), Color("ff77a8"), Color("ffccaa"),
	# tons de roça
	Color("3e2731"), Color("6b3e26"), Color("a0663c"), Color("d9a066"),
	Color("2f5f2a"), Color("5a9e3a"), Color("9bd35a"), Color("e8d8a8"),
	Color("ffffff"), Color("7a7a7a"), Color("4b6b8a"), Color("b8e0f0"),
]

enum Tool { PENCIL, ERASER, FILL, PICKER }

var image: Image
var _undo: Array = []
var _redo: Array = []
var _tool: int = Tool.PENCIL
var _color: Color = Color("000000")
var _mirror := false
var _show_grid := true
var _drawing := false
var _last_cell := Vector2i(-1, -1)

var _canvas: Control
var _preview: TextureRect
var _color_swatch: ColorRect
var _tool_buttons: Dictionary = {}
var _mirror_button: Button
var _title: String = "Desenhar"


static func open(parent: Node, img: Image, title: String) -> PixelEditor:
	var layer = CanvasLayer.new()
	layer.layer = 120
	parent.add_child(layer)
	var ed = PixelEditor.new()
	ed._title = title
	ed.image = img.duplicate() as Image
	ed.image.convert(Image.FORMAT_RGBA8)
	layer.add_child(ed)
	ed.tree_exited.connect(layer.queue_free)
	return ed


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.game_theme
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header = HBoxContainer.new()
	root.add_child(header)
	var title = Label.new()
	title.text = "🎨 " + _title + "  (%dx%d)" % [image.get_width(), image.get_height()]
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(image.get_width() * 2, image.get_height() * 2)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.add_child(_preview)

	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 360)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.resized.connect(func(): _canvas.queue_redraw())
	root.add_child(_canvas)

	# ferramentas
	var tools = HFlowContainer.new()  # quebra linha sozinho -- nada fica por cima de nada
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	root.add_child(tools)
	_add_tool(tools, Tool.PENCIL, "✏️ Lápis")
	_add_tool(tools, Tool.ERASER, "🧽 Borracha")
	_add_tool(tools, Tool.FILL, "🪣 Balde")
	_add_tool(tools, Tool.PICKER, "💧 Pegar cor")

	var tools2 = HFlowContainer.new()  # quebra linha sozinho -- nada fica por cima de nada
	tools2.add_theme_constant_override("h_separation", 6)
	tools2.add_theme_constant_override("v_separation", 6)
	root.add_child(tools2)
	_mirror_button = _btn(tools2, "↔ Espelho: não", _toggle_mirror)
	_btn(tools2, "# Grade", _toggle_grid)
	_btn(tools2, "⬛ Contorno", _auto_outline)
	_btn(tools2, "🎲 Gerar", _generate_random)

	# paleta
	var pal_row = HBoxContainer.new()
	pal_row.add_theme_constant_override("separation", 8)
	root.add_child(pal_row)
	_color_swatch = ColorRect.new()
	_color_swatch.custom_minimum_size = Vector2(64, 64)
	_color_swatch.color = _color
	pal_row.add_child(_color_swatch)
	var grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_row.add_child(grid)
	for c in PALETTE:
		var b = Button.new()
		b.custom_minimum_size = Vector2(50, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(4)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var cc = c
		b.pressed.connect(func(): _set_color(cc))
		grid.add_child(b)
	var picker = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(64, 64)
	picker.text = "+"
	picker.color = _color
	picker.color_changed.connect(_set_color)
	pal_row.add_child(picker)

	# ações
	var actions = HFlowContainer.new()  # quebra linha sozinho -- nada fica por cima de nada
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	root.add_child(actions)
	_btn(actions, "↶ Desfazer", _do_undo)
	_btn(actions, "↷ Refazer", _do_redo)
	_btn(actions, "🗑 Limpar", _clear_all)
	_btn(actions, "✖ Cancelar", _cancel)
	var ok = _btn(actions, "✔ Pronto", _confirm)
	ok.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

	_select_tool(Tool.PENCIL)
	_refresh()


func _toggle_mirror():
	_mirror = !_mirror
	_mirror_button.text = "↔ Espelho: " + ("sim" if _mirror else "não")
	_canvas.queue_redraw()


func _toggle_grid():
	_show_grid = !_show_grid
	_canvas.queue_redraw()


func _clear_all():
	_push_undo()
	image.fill(Color(0, 0, 0, 0))
	_refresh()


func _cancel():
	cancelled.emit()
	queue_free()


func _confirm():
	finished.emit(image.duplicate())
	queue_free()


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _add_tool(parent: Node, t: int, text: String):
	var b = _btn(parent, text, func(): _select_tool(t))
	b.toggle_mode = true
	_tool_buttons[t] = b


func _select_tool(t: int):
	_tool = t
	for k in _tool_buttons:
		_tool_buttons[k].button_pressed = (k == t)


func _set_color(c: Color):
	_color = c
	_color_swatch.color = c
	if _tool == Tool.ERASER or _tool == Tool.PICKER:
		_select_tool(Tool.PENCIL)


# ------------------------------------------------------------ desenho

func _cell_size() -> float:
	var s = _canvas.size
	return floor(min(s.x / image.get_width(), s.y / image.get_height()))


func _canvas_origin() -> Vector2:
	var cs = _cell_size()
	var used = Vector2(image.get_width(), image.get_height()) * cs
	return ((_canvas.size - used) / 2.0).floor()


func _draw_canvas():
	var cs = _cell_size()
	if cs <= 0 or _tex == null:
		return
	var o = _canvas_origin()
	var w = image.get_width()
	var h = image.get_height()
	var rect = Rect2(o, Vector2(w, h) * cs)
	_canvas.draw_texture_rect(_checker, rect, false)  # xadrez = transparente
	_canvas.draw_texture_rect(_tex, rect, false)
	if _show_grid and cs >= 6:
		var gc = Color(0, 0, 0, 0.25)
		for x in w + 1:
			_canvas.draw_line(o + Vector2(x * cs, 0), o + Vector2(x * cs, h * cs), gc)
		for y in h + 1:
			_canvas.draw_line(o + Vector2(0, y * cs), o + Vector2(w * cs, y * cs), gc)
	if _mirror:
		_canvas.draw_line(o + Vector2(w * cs / 2.0, 0), o + Vector2(w * cs / 2.0, h * cs), Color(1, 0.3, 0.8, 0.8), 2.0)
	_canvas.draw_rect(rect, Color(1, 1, 1, 0.5), false, 2.0)


func _pos_to_cell(p: Vector2) -> Vector2i:
	var cs = _cell_size()
	var c = ((p - _canvas_origin()) / cs).floor()
	return Vector2i(int(c.x), int(c.y))


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < image.get_width() and c.y < image.get_height()


# só mouse: no celular o Godot já converte toque em mouse (emulate_mouse_from_touch),
# tratar os dois faria desenhar duas vezes
func _canvas_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cell = _pos_to_cell(event.position)
			if !_in_bounds(cell):
				return
			match _tool:
				Tool.FILL:
					_push_undo()
					_flood_fill(cell, _color)
					_refresh()
				Tool.PICKER:
					var picked = image.get_pixelv(cell)
					if picked.a > 0:
						_set_color(picked)
				_:
					_push_undo()
					_drawing = true
					_last_cell = cell
					_paint(cell)
					_refresh()
		else:
			_drawing = false
			_last_cell = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and _drawing:
		var cell = _pos_to_cell(event.position)
		if cell != _last_cell:
			_paint_line(_last_cell, cell)
			_last_cell = cell
			_refresh()


func _paint(cell: Vector2i):
	var c = Color(0, 0, 0, 0) if _tool == Tool.ERASER else _color
	if _in_bounds(cell):
		image.set_pixelv(cell, c)
	if _mirror:
		var m = Vector2i(image.get_width() - 1 - cell.x, cell.y)
		if _in_bounds(m):
			image.set_pixelv(m, c)


func _paint_line(a: Vector2i, b: Vector2i):
	# Bresenham -- traço contínuo mesmo arrastando rápido
	var x0 = a.x
	var y0 = a.y
	var dx = abs(b.x - x0)
	var dy = -abs(b.y - y0)
	var sx = 1 if x0 < b.x else -1
	var sy = 1 if y0 < b.y else -1
	var err = dx + dy
	var guard = 0
	while guard < 500:
		guard += 1
		_paint(Vector2i(x0, y0))
		if x0 == b.x and y0 == b.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _flood_fill(start: Vector2i, new_color: Color):
	var target = image.get_pixelv(start)
	if target.is_equal_approx(new_color):
		return
	var stack: Array[Vector2i] = [start]
	var visited: Dictionary = {}
	while !stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if visited.has(p) or !_in_bounds(p):
			continue
		visited[p] = true
		if !image.get_pixelv(p).is_equal_approx(target):
			continue
		image.set_pixelv(p, new_color)
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))


# contorno escuro em volta de tudo que está desenhado -- deixa a arte com
# cara de pixel art "de jogo" com 1 toque
func _auto_outline():
	_push_undo()
	var src = image.duplicate()
	var outline = Color("1a1018")
	for y in image.get_height():
		for x in image.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n = Vector2i(x, y) + d
				if _in_bounds(n) and src.get_pixelv(n).a > 0.0 and !src.get_pixelv(n).is_equal_approx(outline):
					image.set_pixel(x, y, outline)
					break
	_refresh()


func _generate_random():
	_push_undo()
	var gen = CardGenerator.generate_sprite(image.get_width(), image.get_height(), randi())
	image.blit_rect(gen, Rect2i(Vector2i.ZERO, gen.get_size()), Vector2i.ZERO)
	_refresh()


func _push_undo():
	_undo.append(image.duplicate())
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()


func _do_undo():
	if _undo.is_empty():
		return
	_redo.append(image.duplicate())
	image = _undo.pop_back()
	_refresh()


func _do_redo():
	if _redo.is_empty():
		return
	_undo.append(image.duplicate())
	image = _redo.pop_back()
	_refresh()


var _tex: ImageTexture
var _checker: ImageTexture


func _refresh():
	if _checker == null:
		var ck = Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				ck.set_pixel(x, y, Color(0.32, 0.32, 0.32) if (x + y) % 2 == 0 else Color(0.24, 0.24, 0.24))
		_checker = ImageTexture.create_from_image(ck)
	if _tex == null or _tex.get_size() != Vector2(image.get_size()):
		_tex = ImageTexture.create_from_image(image)
	else:
		_tex.update(image)
	_preview.texture = _tex
	_canvas.queue_redraw()
