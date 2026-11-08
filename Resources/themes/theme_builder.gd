extends Node

# --- Tema visual "Farm Arena" -- rústico, madeira e capim ---
# Autoload: aplica isso na RAIZ de qualquer cena (Control) com
# `theme = ThemeBuilder.game_theme` no _ready() dela -- botão, painel,
# label e barra de progresso de toda a árvore abaixo herdam o estilo de
# uma vez só, sem precisar configurar nó por nó

var game_theme: Theme

# fonte customizada -- se você adicionar um arquivo de fonte (.ttf/.otf)
# nesse caminho, ela é usada em tudo automaticamente. Se o arquivo ainda
# não existir, não dá erro nenhum -- só continua com a fonte padrão do
# Godot (mesmo princípio do cenário de arena que não quebra se não existir)
const CUSTOM_FONT_PATH = "res://fonts/rustic_font.ttf"

# --- paleta ---
const COLOR_WOOD_LIGHT = Color("#a9713f")     # madeira clara -- botão normal
const COLOR_WOOD_DARK = Color("#6b4226")      # madeira escura -- botão pressionado / borda
const COLOR_WOOD_HOVER = Color("#bf8752")     # madeira mais clara -- hover
const COLOR_WOOD_DISABLED = Color("#8a7f76")  # cinza-amarronzado -- desabilitado
const COLOR_PANEL_BG = Color("#4a3320")       # madeira bem escura -- fundo de painel/popup
const COLOR_GRASS = Color("#5f8b3f")          # verde capim -- barra de progresso / destaque
const COLOR_GRASS_DARK = Color("#3f6329")     # verde escuro -- borda da barra
const COLOR_CREAM = Color("#f3e6c8")          # creme -- texto sobre fundo escuro
const COLOR_GOLD = Color("#d9a441")           # dourado -- destaque/seleção

# cores específicas pra linha de atributo (tipo "HP  50") -- rótulo e valor
# em cores BEM diferentes de propósito (as duas primeiras tentativas eram
# tons parecidos demais, difícil de notar a diferença de relance)
const COLOR_STAT_LABEL = Color("#c9a86a")   # dourado opaco -- o nome do atributo ("HP", "Dano"...)
const COLOR_STAT_VALUE = Color("#ffffff")   # branco puro -- o número em si, contraste máximo com o rótulo

var custom_font: FontFile = null


func _ready():
	if ResourceLoader.exists(CUSTOM_FONT_PATH):
		custom_font = load(CUSTOM_FONT_PATH)

	game_theme = _build_theme()
	# tema na JANELA inteira -- toda tela do jogo herda, mesmo as que nunca
	# setaram `theme = ThemeBuilder.game_theme`
	get_tree().root.theme = game_theme
	RenderingServer.set_default_clear_color(COLOR_GRASS_DARK)
	_build_menu_background()


# ------------------------------------------------------------ fundo dos menus
# fazendinha em pixel art (céu, morros, pasto, cerca de madeira) atrás de
# TODOS os menus. Fica numa camada bem no fundo e some sozinha na batalha
var _bg_layer: CanvasLayer
var _last_scene: Node = null


func _build_menu_background():
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -100
	add_child(_bg_layer)
	var rect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(_make_farm_background(90, 200))
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(rect)


func _process(_delta):
	var scene = get_tree().current_scene
	if scene == _last_scene:
		return
	_last_scene = scene
	var in_battle = scene != null and scene.scene_file_path.contains("batlhe_scene")
	_bg_layer.visible = !in_battle


func _make_farm_background(w: int, h: int) -> Image:
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2026
	var sky_top = Color("#7ec8e3")
	var sky_bottom = Color("#cfeaf0")
	var horizon = int(h * 0.22)
	for y in h:
		for x in w:
			var c: Color
			if y < horizon:
				c = sky_top.lerp(sky_bottom, float(y) / horizon)
			else:
				var t = float(y - horizon) / (h - horizon)
				c = Color("#7fb04a").lerp(Color("#4f7f2f"), t)
				if rng.randf() < 0.12:
					c = c.darkened(0.12)
				elif rng.randf() < 0.05:
					c = c.lightened(0.12)
			img.set_pixel(x, y, c)
	# morros ao longe
	for x in w:
		var hill = horizon - int(4 + 3 * sin(x * 0.12) + 2 * sin(x * 0.31 + 1.0))
		for y in range(hill, horizon + 2):
			img.set_pixel(x, clamp(y, 0, h - 1), Color("#5e9a3c"))
	# nuvens
	for cx in [14, 52, 76]:
		var cy = rng.randi_range(5, horizon - 14)
		for dx in range(-6, 7):
			for dy in range(-2, 3):
				if abs(dx) + abs(dy) * 2 < 8 and cx + dx >= 0 and cx + dx < w:
					img.set_pixel(cx + dx, cy + dy, Color("#ffffff"))
	# florzinhas no pasto
	for i in 120:
		var x = rng.randi() % w
		var y = rng.randi_range(horizon + 4, h - 1)
		img.set_pixel(x, y, [Color("#ffec27"), Color("#ff9ec4"), Color("#ffffff")][rng.randi() % 3])
	# cercas de madeira (uma no horizonte e uma lá embaixo)
	for fence_y in [horizon + 6, h - 14]:
		for x in w:
			for rail in [fence_y, fence_y + 4]:
				img.set_pixel(x, rail, Color("#8b5a2b"))
				img.set_pixel(x, rail + 1, Color("#5c3a1e"))
			if x % 8 == 0:
				for y in range(fence_y - 3, fence_y + 8):
					if y >= 0 and y < h:
						img.set_pixel(x, y, Color("#a0703c"))
						if x + 1 < w:
							img.set_pixel(x + 1, y, Color("#5c3a1e"))
	return img


func _build_theme() -> Theme:
	var theme = Theme.new()

	if custom_font != null:
		theme.default_font = custom_font

	_apply_button_styles(theme)
	_apply_panel_styles(theme)
	_apply_label_styles(theme)
	_apply_progress_bar_styles(theme)
	_apply_separator_styles(theme)
	_apply_input_styles(theme)
	theme.default_font_size = 18

	return theme


# campos de texto, listas suspensas, rolagem, popups -- tudo no estilo fazenda
func _apply_input_styles(theme: Theme):
	var field = _make_wood_stylebox(COLOR_CREAM, COLOR_WOOD_DARK)
	field.content_margin_left = 12
	var field_focus = _make_wood_stylebox(COLOR_CREAM, COLOR_GOLD)
	field_focus.content_margin_left = 12
	for t in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", t, field)
		theme.set_stylebox("focus", t, field_focus)
		theme.set_stylebox("read_only", t, field)
		theme.set_color("font_color", t, Color("#3b2614"))
		theme.set_color("caret_color", t, Color("#3b2614"))
		theme.set_color("font_placeholder_color", t, Color("#8a6a48"))
		theme.set_font_size("font_size", t, 20)

	var popup = _make_wood_stylebox(COLOR_PANEL_BG, COLOR_GOLD)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("hover", "PopupMenu", _make_wood_stylebox(COLOR_GRASS, COLOR_GRASS_DARK))
	theme.set_color("font_color", "PopupMenu", COLOR_CREAM)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font_size("font_size", "PopupMenu", 22)
	theme.set_constant("v_separation", "PopupMenu", 14)

	# barra de rolagem grossa e fácil de pegar com o dedo
	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0, 0, 0, 0.18)
	scroll_bg.set_corner_radius_all(6)
	scroll_bg.content_margin_left = 6
	scroll_bg.content_margin_right = 6
	var grab = _make_wood_stylebox(COLOR_WOOD_LIGHT, COLOR_WOOD_DARK)
	for t in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", t, scroll_bg)
		theme.set_stylebox("grabber", t, grab)
		theme.set_stylebox("grabber_highlight", t, grab)
		theme.set_stylebox("grabber_pressed", t, _make_wood_stylebox(COLOR_GOLD, COLOR_WOOD_DARK))

	# CheckButton / CheckBox: só o texto creme, sem a tábua de fundo
	var empty = StyleBoxEmpty.new()
	for t in ["CheckButton", "CheckBox"]:
		theme.set_stylebox("normal", t, empty)
		theme.set_stylebox("hover", t, empty)
		theme.set_stylebox("pressed", t, empty)
		theme.set_stylebox("focus", t, empty)
		theme.set_color("font_color", t, COLOR_CREAM)
		theme.set_color("font_pressed_color", t, COLOR_GOLD)

	# painel "cerca" -- usado em listas (tábua clara com sombra embaixo)
	var tab = _make_wood_stylebox(COLOR_GRASS_DARK, COLOR_WOOD_DARK)
	theme.set_stylebox("panel", "TabContainer", tab)


func _apply_button_styles(theme: Theme):
	var normal = _make_wood_stylebox(COLOR_WOOD_LIGHT, COLOR_WOOD_DARK)
	var hover = _make_wood_stylebox(COLOR_WOOD_HOVER, COLOR_WOOD_DARK)
	var pressed = _make_wood_stylebox(COLOR_WOOD_DARK, COLOR_GOLD)
	var disabled = _make_wood_stylebox(COLOR_WOOD_DISABLED, COLOR_WOOD_DISABLED)
	var focus = _make_wood_stylebox(COLOR_WOOD_LIGHT, COLOR_GOLD)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", COLOR_CREAM)
	theme.set_color("font_hover_color", "Button", COLOR_CREAM)
	theme.set_color("font_pressed_color", "Button", COLOR_GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6))
	theme.set_font_size("font_size", "Button", 20)  # celular: texto maior


func _apply_panel_styles(theme: Theme):
	var panel_style = _make_wood_stylebox(COLOR_PANEL_BG, COLOR_WOOD_DARK)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12

	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "Panel", panel_style)


func _apply_label_styles(theme: Theme):
	theme.set_color("font_color", "Label", COLOR_CREAM)
	theme.set_font_size("font_size", "Label", 18)


func _apply_progress_bar_styles(theme: Theme):
	var bg = _make_wood_stylebox(COLOR_WOOD_DARK, COLOR_WOOD_DARK)
	bg.set_corner_radius_all(6)

	var fill = _make_wood_stylebox(COLOR_GRASS, COLOR_GRASS_DARK)
	fill.set_corner_radius_all(6)

	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", COLOR_CREAM)


func _apply_separator_styles(theme: Theme):
	var sep = StyleBoxLine.new()
	sep.color = COLOR_WOOD_DARK
	sep.thickness = 2
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_stylebox("separator", "VSeparator", sep)


# painel/botão "de madeira" -- cor de fundo + borda mais escura, cantos
# arredondados, pra parecer uma tábua ao invés do retângulo cinza padrão
func _make_wood_stylebox(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 6  # "sombra" embaixo, cara de tábua de cerca
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


# aplica a fonte customizada (se existir) num Label/Button específico --
# útil pra um título ou destaque que precise da fonte MESMO sem passar
# pela herança normal de tema (ex: um node fixo na cena que já tem outro
# tema/override próprio)
func apply_custom_font_to(control: Control, size: int = 16):
	if custom_font != null:
		control.add_theme_font_override("font", custom_font)
	control.add_theme_font_size_override("font_size", size)
