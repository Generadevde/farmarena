extends Button

@export var hand_index: int = 0  # 0, 1 ou 2 -- qual posição da mão esse botão representa
var card: CardData
var _view: CardView

var _hold_timer: Timer = null
var _info_popup: CanvasLayer = null
const HOLD_THRESHOLD = 0.4  # segundos segurando parado antes do popup de dados aparecer

var _press_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
const DRAG_MOVE_THRESHOLD = 12.0  # pixels de movimento que já conta como "começou a arrastar", não só segurar parado


func _ready():
	clip_contents = false  # a carta selecionada sobe um pouco pra fora do botão
	theme = ThemeBuilder.game_theme
	add_to_group("hand_card_button")  # pra cena de batalha conseguir juntar todas numa fileira organizada

	# o tema global reserva margem interna pensando em texto de botão normal
	# -- aqui o conteúdo é só o ícone da carta, então zera a margem nos
	# estados do botão, deixando o ícone preencher o espaço inteiro
	var no_margin_style = ThemeBuilder.game_theme.get_stylebox("normal", "Button").duplicate()
	no_margin_style.content_margin_left = 0
	no_margin_style.content_margin_right = 0
	no_margin_style.content_margin_top = 0
	no_margin_style.content_margin_bottom = 0
	add_theme_stylebox_override("normal", no_margin_style)
	add_theme_stylebox_override("hover", no_margin_style)
	add_theme_stylebox_override("pressed", no_margin_style)
	add_theme_stylebox_override("focus", no_margin_style)

	# 2.0: a carta inteira é desenhada pelo CardView (moldura, custo, nível, maestria)
	_view = CardView.make(null, 150)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	$Icon.visible = false
	$Name.visible = false
	$Cost.visible = false

	$Icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$Icon.stretch_mode = TextureRect.STRETCH_SCALE  # estica exato pra caber, sem cortar nem sobrar espaço -- pode distorcer um pouco, mas nunca perde detalhe da arte
	$Icon.set_anchors_preset(Control.PRESET_FULL_RECT)  # preenche o botão inteiro, não importa o tamanho original dele na cena

	DeckManager.hand_changed.connect(_refresh)
	_refresh()


func _refresh():
	card = DeckManager.hand[hand_index]
	if card == null:
		return
	$Name.text = card.card_name
	$Cost.text = str(card.cost)
	$Icon.texture = card.icon
	if _view != null:
		_view.card = card
		_view.queue_redraw()


# cria (na primeira vez) e atualiza o texto de nível em cima do ícone --
# não existe no .tscn original, então monta ele em código se ainda não tiver
func _refresh_level_label():
	var level_label = get_node_or_null("LevelLabel")
	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(level_label)
	level_label.text = "Nv%d" % PlayerProfile.get_card_level(card)


func _process(delta):
	if card == null:
		return
	disabled = GameManager.player_money < card.cost
	var battle = get_tree().get_first_node_in_group("battle_scene")
	var is_selected = battle and battle.selected_card == card
	if _view != null:
		# sem recurso = carta escura; selecionada = sobe e brilha
		_view.modulate = Color(0.45, 0.45, 0.5) if disabled else Color(1, 1, 1)
		_view.position.y = lerpf(_view.position.y, -18.0 if is_selected else 0.0, minf(1.0, delta * 14.0))
		if _view.selected != is_selected:
			_view.set_selected(is_selected)


func _gui_input(event):
	if card == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_start_pos = event.global_position
			_is_dragging = false
			_start_hold_timer()
		else:
			_cancel_hold_timer()
			if _info_popup != null:
				# tava segurando parado e mostrando o popup -- só fecha
				_close_info_popup()
			elif _is_dragging:
				# tava arrastando -- solta o dedo e já tenta confirmar o
				# posicionamento ali mesmo, sem precisar de um segundo toque
				_is_dragging = false
				if disabled:
					return
				var battle = get_tree().get_first_node_in_group("battle_scene")
				if battle:
					battle.try_confirm_placement_at(battle.get_global_mouse_position())
					get_viewport().set_input_as_handled()
			else:
				# toque rápido, sem arrastar -- comportamento clássico:
				# seleciona e espera um toque separado no campo pra confirmar
				if disabled:
					return
				var battle = get_tree().get_first_node_in_group("battle_scene")
				if battle:
					battle.select_card(card, hand_index)
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if !_is_dragging and _press_start_pos.distance_to(event.global_position) >= DRAG_MOVE_THRESHOLD:
			# passou do limiar de movimento -- vira arrasto de verdade a
			# partir de agora, cancela a chance de virar popup de segurar
			_is_dragging = true
			_cancel_hold_timer()
			if !disabled:
				var battle = get_tree().get_first_node_in_group("battle_scene")
				if battle:
					battle.select_card(card, hand_index)


func _start_hold_timer():
	if _hold_timer == null:
		_hold_timer = Timer.new()
		_hold_timer.wait_time = HOLD_THRESHOLD
		_hold_timer.one_shot = true
		_hold_timer.timeout.connect(_show_info_popup)
		add_child(_hold_timer)
	_hold_timer.start()


func _cancel_hold_timer():
	if _hold_timer != null:
		_hold_timer.stop()


func _show_info_popup():
	_info_popup = CanvasLayer.new()
	_info_popup.layer = 120
	get_tree().get_root().add_child(_info_popup)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 140  # sobe o suficiente pra não cobrir a própria mão de cartas
	_info_popup.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var level = PlayerProfile.get_card_level(card)
	var title = Label.new()
	title.text = "%s (Nv %d)" % [card.card_name, level]
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var nation_role_label = Label.new()
	var nation_text = card.get_nation_name() if card.get_nation_name() != "" else "Coringa"
	nation_role_label.text = "%s • %s" % [nation_text, CardData.role_name(card.role)]
	nation_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nation_role_label.add_theme_font_size_override("font_size", 12)
	nation_role_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	vbox.add_child(nation_role_label)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_stat_row("Custo", str(card.cost)))

	var mult = PlayerProfile.compute_stat_multiplier(level)

	if card.is_spell():
		var spell = card.spell_data
		if spell != null:
			if spell.damage > 0:
				vbox.add_child(_stat_row("Dano", str(round(spell.damage * mult))))
			if spell.heal_amount > 0:
				vbox.add_child(_stat_row("Cura", str(round(spell.heal_amount * mult))))
			vbox.add_child(_stat_row("Raio", str(spell.radius)))
	elif card.unit_scene != null:
		var temp = card.unit_scene.instantiate()
		var stats = temp.stats
		temp.queue_free()

		if stats != null:
			vbox.add_child(_stat_row("HP", str(round(stats.hp * mult))))
			vbox.add_child(_stat_row("Dano", str(round(stats.damage * mult))))
			vbox.add_child(_stat_row("Velocidade de Ataque", str(stats.attack_speed)))
			vbox.add_child(_stat_row("Alvos", _target_type_name(stats.target_type)))


func _stat_row(label_text: String, value_text: String) -> Control:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_LABEL)
	row.add_child(label)
	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_VALUE)
	row.add_child(value)
	return row


func _target_type_name(target_type: int) -> String:
	match target_type:
		UnitData.TargetType.GROUND:
			return "Terrestre"
		UnitData.TargetType.AIR:
			return "Aéreo"
		UnitData.TargetType.BUILDING:
			return "Só construção"
		_:
			return "Todos"


func _close_info_popup():
	if _info_popup != null and is_instance_valid(_info_popup):
		_info_popup.queue_free()
	_info_popup = null
