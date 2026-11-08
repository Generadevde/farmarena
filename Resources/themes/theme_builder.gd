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


func _build_theme() -> Theme:
	var theme = Theme.new()

	if custom_font != null:
		theme.default_font = custom_font

	_apply_button_styles(theme)
	_apply_panel_styles(theme)
	_apply_label_styles(theme)
	_apply_progress_bar_styles(theme)
	_apply_separator_styles(theme)

	return theme


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
	theme.set_font_size("font_size", "Button", 16)


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
	theme.set_font_size("font_size", "Label", 15)


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
	style.border_width_bottom = 3
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
