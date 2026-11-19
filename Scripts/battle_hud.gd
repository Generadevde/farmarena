extends CanvasLayer
class_name BattleHud
## HUD 2.0 da batalha: fica PRESO NA TELA (CanvasLayer), não no mundo.
##   topo: nome do adversário · relógio
##   embaixo: próxima carta · cartas da mão (4, ou 3 na regra antiga) · barra de recurso com número
## Os nós mantêm os nomes antigos (ResourceBar, BattleTimerLabel,
## OpponentNameLabel, Button/Button2/Button3) porque a cena de batalha os
## procura por nome.

const HAND_BUTTON = preload("res://Scenes/button.tscn")


class BarTicks extends Control:
	var bar: ProgressBar
	var _last_max := -1.0

	func _process(_delta):
		if bar != null and bar.max_value != _last_max:
			_last_max = bar.max_value
			queue_redraw()

	func _draw():
		if bar == null or bar.max_value <= 0:
			return
		var v = 10.0
		while v < bar.max_value - 0.5:
			var x = size.x * v / bar.max_value
			draw_line(Vector2(x, 3), Vector2(x, size.y - 3), Color(0.05, 0.12, 0.2, 0.55), 2.0)
			v += 10.0

const CARD_W = 178.0          # carta da mão com 3 na mão
const CARD_W_4 = 142.0        # com 4 na mão (cabe na tela de 720 junto com a "próxima")

var _money_label: Label
var _bar: ProgressBar
var _next_view: CardView
var _score: Label


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

	# placar de torres derrubadas, logo abaixo do relógio: é ele que decide
	# a partida quando o tempo acaba (quem derrubou mais, ganha)
	_score = Label.new()
	_score.name = "PlacarTorres"
	_score.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_score.offset_right = -14
	_score.offset_top = 56
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.add_theme_font_override("font", ThemeDB.fallback_font)
	_score.add_theme_font_size_override("font_size", 22)
	_score.add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	_score.add_theme_constant_override("outline_size", 6)
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_score)

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
	var hand_n = Regras.hand_size()
	var card_w = CARD_W if hand_n <= 3 else CARD_W_4
	row.add_theme_constant_override("separation", 10 if hand_n <= 3 else 7)
	v.add_child(row)

	var next_box = VBoxContainer.new()
	next_box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(next_box)
	var nl = Label.new()
	nl.text = "próxima"
	nl.add_theme_font_size_override("font_size", 14)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_box.add_child(nl)
	_next_view = CardView.make(null, 100 if hand_n <= 3 else 84)
	_next_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_view.show_level = false
	next_box.add_child(_next_view)

	for i in hand_n:
		var b = HAND_BUTTON.instantiate()
		b.name = "Button" if i == 0 else "Button%d" % (i + 1)
		b.hand_index = i
		b.card_w = card_w
		b.custom_minimum_size = Vector2(card_w, card_w * 1.34 + CardView.FOOT * card_w / 132.0)
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
	if Regras.on("visual"):
		# gomos de 10 em 10: dá pra ler de relance quantas cartas cabem
		var ticks = BarTicks.new()
		ticks.bar = _bar
		ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
		ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_child(ticks)

	DeckManager.hand_changed.connect(_refresh_next)
	_refresh_next()


func _refresh_next():
	_next_view.card = DeckManager.draw_queue[0] if !DeckManager.draw_queue.is_empty() else null
	_next_view.queue_redraw()


func _process(_delta):
	var battle = get_parent()
	if _score != null and battle != null and "towers_destroyed" in battle:
		# torres que VOCÊ derrubou x torres que o bot derrubou
		var mine = int(battle.towers_destroyed[GameManager.Team.ENEMY])
		var bot = int(battle.towers_destroyed[GameManager.Team.PLAYER])
		_score.text = "🏰 %d × %d" % [mine, bot]
		_score.modulate = Color(0.6, 1.0, 0.6) if mine > bot else (Color(1.0, 0.6, 0.55) if bot > mine else Color.WHITE)
	_money_label.text = str(int(GameManager.player_money))
