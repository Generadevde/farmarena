extends Button
class_name BaseSelectButton

var base_data: BaseData
var _hold_timer: Timer = null
var _info_popup: CanvasLayer = null
var _equipped_via_hold: bool = false

const HOLD_THRESHOLD := 0.4


func _ready():
	custom_minimum_size = Vector2(90, 132)
	clip_contents = true

	# Garante que o botão receba os eventos do mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS  # deixa a lista rolar arrastando por cima

	if base_data == null:
		push_warning("BaseSelectButton: base_data não foi definido.")
		return

	var is_unlocked = PlayerProfile.is_base_unlocked(base_data)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# =========================
	# ÍCONE
	# =========================

	var icon_rect = TextureRect.new()
	icon_rect.texture = base_data.icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_unlocked:
		icon_rect.modulate = Color(1, 1, 1)
	else:
		icon_rect.modulate = Color(0.4, 0.4, 0.4)

	vbox.add_child(icon_rect)

	# =========================
	# NOME
	# =========================

	var name_label = Label.new()
	name_label.text = base_data.base_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# =========================
	# TIER
	# =========================

	var tier_badge = Label.new()
	tier_badge.text = "Tier %d" % base_data.tier
	tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_badge.add_theme_font_size_override("font_size", 9)
	tier_badge.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	tier_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tier_badge)

	# =========================
	# NÍVEL / BLOQUEIO
	# =========================

	if is_unlocked:
		var level_label = Label.new()
		level_label.text = "Nível %d" % PlayerProfile.get_base_level(base_data)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(level_label)

	else:
		var lock_label = Label.new()

		if !base_data.predecessor_bases.is_empty() and !PlayerProfile.can_unlock_base(base_data):
			var pending: Array[String] = []

			for predecessor in base_data.predecessor_bases:
				if predecessor != null and !PlayerProfile.is_base_unlocked(predecessor):
					pending.append(predecessor.base_name)

			if !pending.is_empty():
				lock_label.text = "🔒 %s" % ", ".join(pending)
			else:
				lock_label.text = "🔒 %d XP" % base_data.nation_xp_cost
		else:
			lock_label.text = "🔒 %d XP" % base_data.nation_xp_cost

		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 11)
		lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		vbox.add_child(lock_label)


# ============================================================
# MOUSE
# ============================================================

var _press_pos: Vector2 = Vector2.ZERO


func _gui_input(event):
	# arrastando = rolando a lista, cancela o "segurar pra equipar"
	if event is InputEventMouseMotion and event.button_mask != 0 and event.global_position.distance_to(_press_pos) > 12.0:
		_cancel_hold_timer()

	if base_data == null or disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			# Começou a segurar
			_equipped_via_hold = false
			_press_pos = event.global_position
			_start_hold_timer()

		else:
			# Soltou o botão
			_cancel_hold_timer()

			# arrastou o dedo (rolando a lista) -- não é toque, ignora
			if event.global_position.distance_to(_press_pos) > 12.0:
				return

			# Se já equipou através do hold,
			# não abre o popup.
			if _equipped_via_hold:
				get_viewport().set_input_as_handled()
				return

			# Clique rápido
			if _info_popup != null:
				_close_info_popup()
			else:
				_show_info_popup()

			get_viewport().set_input_as_handled()


# ============================================================
# HOLD
# ============================================================

func _start_hold_timer():
	if _hold_timer == null:
		_hold_timer = Timer.new()
		_hold_timer.name = "HoldTimer"
		_hold_timer.wait_time = HOLD_THRESHOLD
		_hold_timer.one_shot = true

		_hold_timer.timeout.connect(_equip_on_hold)

		add_child(_hold_timer)

	_hold_timer.start()


func _cancel_hold_timer():
	if _hold_timer != null:
		_hold_timer.stop()


func _equip_on_hold():
	if base_data == null:
		return

	# Base bloqueada não pode ser equipada.
	if !PlayerProfile.is_base_unlocked(base_data):
		return

	# Marca que o equipamento aconteceu pelo hold.
	_equipped_via_hold = true

	print("Segurar detectado: equipando ", base_data.base_name)

	var menu = get_tree().get_first_node_in_group("library_menu")

	if menu == null:
		push_warning("BaseSelectButton: nenhum node no grupo 'library_menu'.")
		return

	if menu.has_method("equip_base"):
		menu.equip_base(base_data)
	else:
		push_warning("BaseSelectButton: library_menu não possui equip_base().")


# ============================================================
# POPUP DE INFORMAÇÕES
# ============================================================

func _show_info_popup(page: int = 1):
	if base_data == null:
		return

	# Evita criar dois popups.
	if _info_popup != null and is_instance_valid(_info_popup):
		_close_info_popup()

	_info_popup = CanvasLayer.new()
	_info_popup.layer = 120

	# pendura na cena atual (não na raiz) -- assim some junto quando troca de
	# tela, em vez de ficar uma camada invisível bloqueando toque
	get_tree().current_scene.add_child(_info_popup)

	# =========================
	# FUNDO
	# =========================

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	_info_popup.add_child(bg)

	# =========================
	# CENTRO
	# =========================

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_info_popup.add_child(center)

	# =========================
	# PAINEL
	# =========================

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.theme = ThemeBuilder.game_theme

	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	panel.add_child(vbox)

	# =========================
	# TÍTULO
	# =========================

	var level = PlayerProfile.get_base_level(base_data)
	var is_unlocked = PlayerProfile.is_base_unlocked(base_data)

	var title = Label.new()

	if is_unlocked:
		title.text = "%s (Nível %d)" % [base_data.base_name, level]
	else:
		title.text = base_data.base_name

	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# ========================================================
	# BASE BLOQUEADA
	# ========================================================

	if !is_unlocked:
		var pending: Array[String] = []

		for predecessor in base_data.predecessor_bases:
			if predecessor != null and !PlayerProfile.is_base_unlocked(predecessor):
				pending.append(predecessor.base_name)

		var unlock_button = Button.new()

		if !pending.is_empty():

			unlock_button.text = "🔒 Desbloqueie %s primeiro" % ", ".join(pending)
			unlock_button.disabled = true

		else:

			var breakdown = PlayerProfile.get_unlock_cost_breakdown_base(base_data)

			var cost_text = ""

			if breakdown["nation"] > 0 and breakdown["free"] > 0:

				cost_text = "🏆 %d + ⭐ %d" % [
					breakdown["nation"],
					breakdown["free"]
				]

			elif breakdown["nation"] > 0:

				cost_text = "🏆 %d XP de %s" % [
					breakdown["nation"],
					base_data.get_nation_name()
				]

			else:

				cost_text = "⭐ %d XP livre" % breakdown["free"]

			if PlayerProfile.can_unlock_base(base_data):

				unlock_button.text = "Desbloquear (%s)" % cost_text

			else:

				unlock_button.text = "Precisa de: %s" % cost_text
				unlock_button.disabled = true

			unlock_button.pressed.connect(func():

				if PlayerProfile.unlock_base(base_data):

					_close_info_popup()

					_show_info_popup(1)
			)

		vbox.add_child(unlock_button)

		var close_button_locked = Button.new()
		close_button_locked.text = "Fechar"
		close_button_locked.pressed.connect(_close_info_popup)

		vbox.add_child(close_button_locked)

		return

	# ========================================================
	# PÁGINA 2
	# ========================================================

	if page == 2:

		_build_description_page(vbox)

		var nav_row = HBoxContainer.new()
		nav_row.alignment = BoxContainer.ALIGNMENT_CENTER

		vbox.add_child(nav_row)

		var back_arrow = Button.new()
		back_arrow.text = "◀ Estatísticas"

		back_arrow.pressed.connect(func():

			_close_info_popup()
			_show_info_popup(1)
		)

		nav_row.add_child(back_arrow)

		var close_button2 = Button.new()
		close_button2.text = "Fechar"
		close_button2.pressed.connect(_close_info_popup)

		vbox.add_child(close_button2)

		return

	# ========================================================
	# PÁGINA 1: ESTATÍSTICAS
	# ========================================================

	var mult = PlayerProfile.compute_base_stat_multiplier(level)

	vbox.add_child(
		_stat_row(
			"HP",
			str(round(base_data.base_hp * mult))
		)
	)

	match base_data.base_type:

		BaseData.BaseType.CANNON:

			vbox.add_child(
				_stat_row(
					"Dano",
					str(round(base_data.attack_damage * mult))
				)
			)

			vbox.add_child(
				_stat_row(
					"Velocidade de Ataque",
					str(base_data.attack_speed)
				)
			)

			vbox.add_child(
				_stat_row(
					"Alcance",
					str(base_data.attack_range)
				)
			)

		BaseData.BaseType.HEAL:

			vbox.add_child(
				_stat_row(
					"Cura",
					str(round(base_data.heal_amount * mult))
				)
			)

			vbox.add_child(
				_stat_row(
					"Raio",
					str(base_data.heal_radius)
				)
			)

		BaseData.BaseType.PRODUCTION:

			vbox.add_child(
				_stat_row(
					"Produção extra",
					"%d%%" % round(
						base_data.production_speed_boost * 100
					)
				)
			)

		BaseData.BaseType.CAPACITY:

			vbox.add_child(
				_stat_row(
					"Capacidade extra",
					str(base_data.capacity_bonus)
				)
			)

		BaseData.BaseType.AURA:

			vbox.add_child(
				_stat_row(
					"Raio da aura",
					str(base_data.aura_radius)
				)
			)

	# ========================================================
	# BOTÃO PÁGINA 2
	# ========================================================

	var next_arrow = Button.new()
	next_arrow.text = "Como usar ▶"

	next_arrow.pressed.connect(func():

		_close_info_popup()
		_show_info_popup(2)
	)

	vbox.add_child(next_arrow)

	vbox.add_child(HSeparator.new())

	# ========================================================
	# UPGRADE
	# ========================================================

	if PlayerProfile.is_max_level_base(base_data):

		var max_label = Label.new()
		max_label.text = "Nível máximo!"
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		vbox.add_child(max_label)

	else:

		var uses_needed = PlayerProfile.get_upgrade_cost_base(base_data)
		var uses_have = PlayerProfile.get_base_usage(base_data)
		var coin_cost = PlayerProfile.get_upgrade_coin_cost_base(base_data)

		var progress_label = Label.new()

		progress_label.text = (
			"Uso: %d / %d -- Custo: %d moedas"
			% [
				min(uses_have, uses_needed),
				uses_needed,
				coin_cost
			]
		)

		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD

		vbox.add_child(progress_label)

		var upgrade_button = Button.new()
		upgrade_button.text = "Upar"

		upgrade_button.disabled = (
			uses_have < uses_needed
			or PlayerProfile.coins < coin_cost
		)

		upgrade_button.pressed.connect(func():

			if PlayerProfile.upgrade_base(base_data):

				_close_info_popup()

				_show_info_popup(1)
		)

		vbox.add_child(upgrade_button)

	# ========================================================
	# FECHAR
	# ========================================================

	var close_button = Button.new()
	close_button.text = "Fechar"

	close_button.pressed.connect(_close_info_popup)

	vbox.add_child(close_button)


# ============================================================
# PÁGINA DE DESCRIÇÃO
# ============================================================

func _build_description_page(vbox: VBoxContainer):

	const PAGE_WIDTH := 220.0

	# =========================
	# DESCRIÇÃO
	# =========================

	if base_data.description != "":

		var desc_label = Label.new()

		desc_label.text = base_data.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = PAGE_WIDTH

		vbox.add_child(desc_label)
		vbox.add_child(HSeparator.new())

	# =========================
	# PRÓS
	# =========================

	if !base_data.pros.is_empty():

		var pros_title = Label.new()

		pros_title.text = "Pontos fortes"

		pros_title.add_theme_color_override(
			"font_color",
			Color(0.4, 0.8, 0.4)
		)

		pros_title.add_theme_font_size_override(
			"font_size",
			14
		)

		vbox.add_child(pros_title)

		for pro in base_data.pros:

			var pro_label = Label.new()

			pro_label.text = "+ " + pro
			pro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			pro_label.custom_minimum_size.x = PAGE_WIDTH

			vbox.add_child(pro_label)

	# =========================
	# CONTRAS
	# =========================

	if !base_data.cons.is_empty():

		var cons_title = Label.new()

		cons_title.text = "Cuidados"

		cons_title.add_theme_color_override(
			"font_color",
			Color(0.85, 0.45, 0.45)
		)

		cons_title.add_theme_font_size_override(
			"font_size",
			14
		)

		vbox.add_child(cons_title)

		for con in base_data.cons:

			var con_label = Label.new()

			con_label.text = "- " + con
			con_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			con_label.custom_minimum_size.x = PAGE_WIDTH

			vbox.add_child(con_label)

	# =========================
	# VAZIO
	# =========================

	if (
		base_data.description == ""
		and base_data.pros.is_empty()
		and base_data.cons.is_empty()
	):

		var empty_label = Label.new()

		empty_label.text = (
			"(essa base ainda não tem "
			+ "descrição/prós/contras cadastrados)"
		)

		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.custom_minimum_size.x = PAGE_WIDTH

		vbox.add_child(empty_label)

	vbox.add_child(HSeparator.new())


# ============================================================
# LINHA DE ESTATÍSTICA
# ============================================================

func _stat_row(label_text: String, value_text: String) -> Control:

	var row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	label.add_theme_color_override(
		"font_color",
		ThemeBuilder.COLOR_STAT_LABEL
	)

	row.add_child(label)

	var value = Label.new()
	value.text = value_text

	value.add_theme_color_override(
		"font_color",
		ThemeBuilder.COLOR_STAT_VALUE
	)

	row.add_child(value)

	return row


# ============================================================
# FECHAR POPUP
# ============================================================

func _close_info_popup():

	if _info_popup != null and is_instance_valid(_info_popup):

		_info_popup.queue_free()
		_info_popup = null
