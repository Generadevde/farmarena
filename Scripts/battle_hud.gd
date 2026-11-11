extends CanvasLayer
class_name BattleHud
## HUD 2.0 da batalha: fica PRESO NA TELA (CanvasLayer), não no mundo.
##   topo: nome do adversário · relógio
##   embaixo: próxima carta · 3 cartas da mão · barra de recurso com número
## Os nós mantêm os nomes antigos (ResourceBar, BattleTimerLabel,
## OpponentNameLabel, Button/Button2/Button3) porque a cena de batalha os
## procura por nome.

const HAND_BUTTON = preload("res://Scenes/button.tscn")
const CARD_W = 178.0

var _money_label: Label
var _bar: ProgressBar
var _next_view: CardView


static func install(battle: Node) -> BattleHud:
	# tira o HUD antigo (que ficava posicionado no mundo)
	for old_name in ["HBoxContainer", "VBoxContainer", "Label", "ResourceBar", "BattleTimerLabel", "OpponentNameLabel"]:
		var old = battle.get_node_or_null(old_name)
		if old != null:
			battle.remove_child(old)
			old.free()
	var hud = BattleHud.new()
	hud.layer = 10
	hud.name = "Hud2"
	battle.add_child(hud)
	return hud


func _ready():
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeBuilder.game_theme
	add_child(root)

	# ---------------- topo
	var top = HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	# setinha de sair (pergunta antes; sair custa metade dos troféus de uma derrota)
	var back = Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(64, 56)
	back.add_theme_font_size_override("font_size", 30)
	back.add_theme_font_override("font", ThemeDB.fallback_font)
	back.modulate = Color(1, 1, 1, 0.85)
	back.pressed.connect(func():
		var battle = get_parent()
		if battle != null and battle.has_method("ask_leave"):
			battle.ask_leave())
	top.add_child(back)
	var opp = Label.new()
	opp.name = "OpponentNameLabel"
	opp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp.add_theme_font_size_override("font_size", 24)
	opp.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	opp.add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	opp.add_theme_constant_override("outline_size", 6)
	opp.clip_text = true
	top.add_child(opp)
	var timer = Label.new()
	timer.name = "BattleTimerLabel"
	timer.add_theme_font_size_override("font_size", 30)
	timer.add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	timer.add_theme_constant_override("outline_size", 8)
	top.add_child(timer)

	# ---------------- embaixo
	var bottom = PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	bottom.add_child(v)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	var next_box = VBoxContainer.new()
	next_box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(next_box)
	var nl = Label.new()
	nl.text = "próxima"
	nl.add_theme_font_size_override("font_size", 14)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_box.add_child(nl)
	_next_view = CardView.make(null, 100)
	_next_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_view.show_level = false
	next_box.add_child(_next_view)

	var names = ["Button", "Button2", "Button3"]
	for i in 3:
		var b = HAND_BUTTON.instantiate()
		b.name = names[i]
		b.hand_index = i
		b.custom_minimum_size = Vector2(CARD_W, CARD_W * 1.34 + CardView.FOOT * CARD_W / 132.0)
		row.add_child(b)

	var res_row = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	v.add_child(res_row)
	_money_label = Label.new()
	_money_label.custom_minimum_size.x = 64
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override("font_size", 28)
	_money_label.add_theme_color_override("font_color", Color("#7fd0ff"))
	res_row.add_child(_money_label)
	_bar = ProgressBar.new()
	_bar.name = "ResourceBar"
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 30
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("#58b8f0")
	fill.border_color = Color("#2a78b0")
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill)
	res_row.add_child(_bar)

	DeckManager.hand_changed.connect(_refresh_next)
	_refresh_next()


func _refresh_next():
	_next_view.card = DeckManager.draw_queue[0] if !DeckManager.draw_queue.is_empty() else null
	_next_view.queue_redraw()


func _process(_delta):
	_money_label.text = str(int(GameManager.player_money))
