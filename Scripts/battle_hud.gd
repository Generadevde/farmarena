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

	# ---------------- topo: uma barra só, com moldura -- sair | adversário | placar | relógio
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 8
	top_panel.offset_right = -8
	top_panel.offset_top = 6
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_theme_stylebox_override("panel", _plate(Color(0.16, 0.10, 0.06, 0.88), Color("#c89a48"), 12, 3))
	root.add_child(top_panel)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(top)
	# setinha de sair (pergunta antes; sair custa metade dos troféus de uma derrota)
	var back = Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(58, 52)
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_font_override("font", ThemeDB.fallback_font)
	back.pressed.connect(func():
		var battle = get_parent()
		if battle != null and battle.has_method("ask_leave"):
			battle.ask_leave())
	top.add_child(back)
	var opp = Label.new()
	opp.name = "OpponentNameLabel"
	opp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp.add_theme_font_size_override("font_size", 21)
	opp.add_theme_color_override("font_color", Color("#ffb0a0"))
	opp.add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	opp.add_theme_constant_override("outline_size", 5)
	opp.clip_text = true
	top.add_child(opp)
	# placar de torres derrubadas: é ele que decide a partida quando o tempo acaba
	var score_plate = PanelContainer.new()
	score_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_plate.add_theme_stylebox_override("panel", _plate(Color(0.08, 0.06, 0.05, 0.9), Color("#e8c060"), 10, 2))
	score_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(score_plate)
	_score = Label.new()
	_score.name = "PlacarTorres"
	_score.add_theme_font_override("font", ThemeDB.fallback_font)
	_score.add_theme_font_size_override("font_size", 24)
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_plate.add_child(_score)
	var time_plate = PanelContainer.new()
	time_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_plate.add_theme_stylebox_override("panel", _plate(Color(0.08, 0.06, 0.05, 0.9), Color("#8a6a3a"), 10, 2))
	time_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(time_plate)
	var timer = Label.new()
	timer.name = "BattleTimerLabel"
	timer.add_theme_font_size_override("font_size", 26)
	timer.custom_minimum_size.x = 96
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_plate.add_child(timer)

	# ---------------- embaixo
	var bottom = PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_stylebox_override("panel", _plate(Color(0.16, 0.10, 0.06, 0.94), Color("#c89a48"), 14, 3))
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
	# o número do recurso num disco azul (igual à gota de elixir do Clash)
	var drop = PanelContainer.new()
	drop.add_theme_stylebox_override("panel", _plate(Color("#2a78c8"), Color("#bfe6ff"), 26, 3))
	drop.custom_minimum_size = Vector2(62, 52)
	drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	res_row.add_child(drop)
	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override("font_size", 26)
	_money_label.add_theme_color_override("font_color", Color.WHITE)
	_money_label.add_theme_color_override("font_outline_color", Color("#103a66"))
	_money_label.add_theme_constant_override("outline_size", 5)
	drop.add_child(_money_label)
	_bar = ProgressBar.new()
	_bar.name = "ResourceBar"
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 30
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("#4aa8f0")
	fill.border_color = Color("#bfe6ff")
	fill.border_width_top = 4      # faixa clara em cima: dá o brilho de "tubo cheio"
	fill.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", _plate(Color(0.07, 0.05, 0.04, 0.95), Color("#6a4a28"), 8, 2))
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


## moldura arredondada com borda (as placas do topo, o painel das cartas, o disco do recurso)
static func _plate(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _refresh_next():
	_next_view.card = DeckManager.draw_queue[0] if !DeckManager.draw_queue.is_empty() else null
	_next_view.queue_redraw()


func _process(_delta):
	var battle = get_parent()
	if _score != null and battle != null and "towers_destroyed" in battle:
		# torres que VOCÊ derrubou x torres que o bot derrubou
		var mine = int(battle.towers_destroyed[GameManager.Team.ENEMY])
		var bot = int(battle.towers_destroyed[GameManager.Team.PLAYER])
		_score.text = "🏰 %d × %d" % [mine, bot]   # você × bot
		_score.modulate = Color(0.6, 1.0, 0.6) if mine > bot else (Color(1.0, 0.6, 0.55) if bot > mine else Color.WHITE)
	_money_label.text = str(int(GameManager.player_money))
