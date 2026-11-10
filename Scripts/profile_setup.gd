extends Control
## Tela de entrada 2.0: logo, "continuar como", lista de perfis, criar/excluir.
## Montada por código no mesmo estilo do menu novo.

const MAIN_MENU_SCENE = "res://Scenes/hub.tscn"

var _box: VBoxContainer


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.game_theme
	MusicPlayer.play_menu_music()
	for c in get_children():
		c.queue_free()  # tira os nós da tela antiga
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size.x = 600
	center.add_child(col)

	var title = Label.new()
	title.text = "FARM ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	title.add_theme_constant_override("outline_size", 14)
	col.add_child(title)
	var parade = HBoxContainer.new()
	parade.alignment = BoxContainer.ALIGNMENT_CENTER
	parade.add_theme_constant_override("separation", 6)
	col.add_child(parade)
	for id in ["vaca_brava", "galo_rei", "sapo_rei", "espantalho", "peao_forcado", "et_abdutor"]:
		var c = Catalogo.card(id)
		if c == null:
			continue
		var tr = TextureRect.new()
		tr.texture = c.icon
		tr.custom_minimum_size = Vector2(92, 92)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		parade.add_child(tr)

	var panel = PanelContainer.new()
	col.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)

	var profiles = PlayerProfile.list_profiles()
	if profiles.is_empty():
		_show_creation_form()
		return
	var last_id = PlayerProfile.get_last_active_profile_id()
	for p in profiles:
		if p["id"] == last_id:
			_show_continue_screen(p)
			return
	_show_profile_list()


func _clear():
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _label(text: String, font_size: int = 22) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	_box.add_child(l)
	return l


func _button(text: String, cb: Callable, font_size: int = 24, parent: Node = null) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 72
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	(parent if parent != null else _box).add_child(b)
	return b


func _show_continue_screen(profile: Dictionary):
	_clear()
	_label("Bem-vindo de volta,", 20)
	_label(str(profile["name"]), 40).add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	var go = _button("▶  JOGAR", _enter.bind(int(profile["id"])), 34)
	go.custom_minimum_size.y = 110
	go.modulate = Color(1.0, 0.92, 0.6)
	_button("👤 Trocar de perfil", _show_profile_list, 20)


func _show_profile_list():
	var profiles = PlayerProfile.list_profiles()
	if profiles.is_empty():
		_show_creation_form()
		return
	_clear()
	_label("Quem vai jogar?", 26)
	for profile in profiles:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_box.add_child(row)
		var b = _button(str(profile["name"]), _enter.bind(int(profile["id"])), 24, row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var del = _button("🗑", _confirm_delete.bind(profile), 22, row)
		del.custom_minimum_size.x = 80
	_button("➕ Criar novo perfil", _show_creation_form, 20)


func _confirm_delete(profile: Dictionary):
	_clear()
	_label("Excluir o perfil de %s?" % str(profile["name"]), 26)
	_label("Some tudo: cartas, troféus, baús. Não dá pra desfazer.", 18)
	_button("Sim, excluir", _delete.bind(int(profile["id"])), 22).modulate = Color(1.0, 0.6, 0.55)
	_button("Cancelar", _show_profile_list, 22)


func _delete(id: int):
	PlayerProfile.delete_profile(id)
	_show_profile_list()


func _show_creation_form():
	_clear()
	_label("Bem-vindo ao Farm Arena!", 28)
	_label("Como você quer ser chamado na roça?", 19)
	var input = LineEdit.new()
	input.placeholder_text = "Digite seu nome"
	input.max_length = 16
	input.custom_minimum_size.y = 72
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 28)
	_box.add_child(input)
	var create = _button("Criar e jogar", _create.bind(input), 28)
	create.custom_minimum_size.y = 90
	input.text_submitted.connect(func(_t): _create(input))
	if !PlayerProfile.list_profiles().is_empty():
		_button("Voltar", _show_profile_list, 20)


var _creating := false


func _create(input: LineEdit):
	var typed = input.text.strip_edges()
	if typed == "" or _creating:
		return
	_creating = true
	PlayerProfile.create_new_profile(typed)
	_finish_entering_profile()


func _enter(id: int):
	PlayerProfile.load_profile_by_id(id)
	_finish_entering_profile()


# carrega TUDO que depende do perfil ativo, na ordem certa, e só DEPOIS roda
# a simulação de "tempo que o jogo ficou fechado" dos bots
func _finish_entering_profile():
	PlayerBehaviorProfiler.load_for_active_profile()
	Leaderboard.load_for_active_profile()
	SeasonStats.load_for_active_profile()
	SeasonManager.load_for_active_profile()
	PollManager.load_for_active_profile()
	ArenaManager.load_for_active_profile()
	CustomContent.load_all()
	BotSimulator.on_profile_loaded()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
