extends Control

# ajusta esse caminho pro local real da sua cena de menu principal
const MAIN_MENU_SCENE = "res://Scenes/main_menu.tscn"

# guarda o perfil da tela de "continuar", pra o botão Voltar saber pra onde ir
var _last_profile_for_back: Dictionary = {}


func _ready():
	theme = ThemeBuilder.game_theme
	MusicPlayer.play_menu_music()

	var profiles = PlayerProfile.list_profiles()

	if profiles.is_empty():
		# ninguém nunca jogou nesse aparelho -- pula direto pra criação
		_show_creation_form()
		return

	var last_id = PlayerProfile.get_last_active_profile_id()
	var last_profile = null
	for p in profiles:
		if p["id"] == last_id:
			last_profile = p

	if last_profile != null:
		_show_continue_screen(last_profile)
	else:
		_show_profile_list(profiles)


# tela rápida: "Continuar como Fulano?" -- caminho mais comum, sem fricção
func _show_continue_screen(profile: Dictionary):
	_last_profile_for_back = profile
	_hide_everything()
	$ContinueLabel.text = "Continuar como %s?" % profile["name"]
	$ContinueLabel.visible = true
	$VBoxContainer/ContinueButton.visible = true
	$VBoxContainer/SwitchProfileButton.visible = true

	# desconecta a conexão anterior -- antes, cada vez que voltava pra essa
	# tela (botão Voltar) o pressed ganhava MAIS uma conexão, e um toque
	# carregava o perfil 2, 3 vezes seguidas
	for c in $VBoxContainer/ContinueButton.pressed.get_connections():
		$VBoxContainer/ContinueButton.pressed.disconnect(c["callable"])
	$VBoxContainer/ContinueButton.pressed.connect(func():
		PlayerProfile.load_profile_by_id(profile["id"])
		_finish_entering_profile()
	)


# lista de todos os perfis -- pra escolher outro, criar mais um, ou excluir
func _show_profile_list(profiles: Array):
	if profiles.is_empty():
		# excluiu o último que restava -- volta pro formulário de criação
		_show_creation_form()
		return

	_hide_everything()
	$ProfileList.visible = true
	$NewProfileButton.visible = true
	$VBoxContainer/BackButton.visible = !_last_profile_for_back.is_empty()

	for child in $ProfileList.get_children():
		child.queue_free()

	for profile in profiles:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		$ProfileList.add_child(row)

		var captured_profile = profile  # cópia local, elimina qualquer dúvida de qual perfil o botão aponta

		var select_button = Button.new()
		select_button.text = captured_profile["name"]
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.pressed.connect(func():
			PlayerProfile.load_profile_by_id(captured_profile["id"])
			_finish_entering_profile()
		)
		row.add_child(select_button)

		var delete_button = Button.new()
		delete_button.text = "Excluir"
		delete_button.pressed.connect(func():
			print("DEBUG Excluir clicado: id=", captured_profile["id"], " nome=", captured_profile["name"])
			_confirm_delete_profile(captured_profile)
		)
		row.add_child(delete_button)


# popup de confirmação -- só exclui de verdade se a pessoa apertar "Excluir"
# na segunda tela, nunca direto no primeiro toque
func _confirm_delete_profile(profile: Dictionary):
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "Excluir o perfil de %s?\nIsso não pode ser desfeito." % profile["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(func(): overlay.queue_free())
	button_row.add_child(cancel_button)

	var confirm_button = Button.new()
	confirm_button.text = "Excluir"
	confirm_button.pressed.connect(func():
		print("DEBUG confirmando exclusão: id=", profile["id"], " nome=", profile["name"])
		PlayerProfile.delete_profile(profile["id"])
		print("DEBUG lista após excluir tem ", PlayerProfile.list_profiles().size(), " perfil(is)")
		# se era o perfil pro qual o botão "Voltar" levaria, esquece --
		# senão o Voltar tentaria continuar num perfil que não existe mais
		if _last_profile_for_back.get("id", -1) == profile["id"]:
			_last_profile_for_back = {}
		overlay.queue_free()
		_show_profile_list(PlayerProfile.list_profiles())
	)
	button_row.add_child(confirm_button)


# formulário de nome, pra criar um perfil novo (o primeiro, ou mais um extra)
func _show_creation_form():
	_hide_everything()
	$NameInput.visible = true
	$NameInput.text = ""
	$CreateButton.visible = true
	$CreateButton.disabled = false


func _hide_everything():
	$ContinueLabel.visible = false
	$VBoxContainer/ContinueButton.visible = false
	$VBoxContainer/SwitchProfileButton.visible = false
	$ProfileList.visible = false
	$NewProfileButton.visible = false
	$VBoxContainer/BackButton.visible = false
	$NameInput.visible = false
	$CreateButton.visible = false


func _on_switch_profile_button_pressed():
	_show_profile_list(PlayerProfile.list_profiles())


func _on_back_button_pressed():
	if _last_profile_for_back.is_empty():
		return
	_show_continue_screen(_last_profile_for_back)


func _on_new_profile_button_pressed():
	_show_creation_form()


func _on_create_button_pressed():
	if $CreateButton.disabled:
		return  # já processando esse clique, ignora repetição/duplo toque
	var typed_name = $NameInput.text.strip_edges()
	if typed_name == "":
		return  # não deixa criar com nome vazio
	$CreateButton.disabled = true
	PlayerProfile.create_new_profile(typed_name)
	_finish_entering_profile()


# carrega TUDO que depende do perfil ativo, na ordem certa, e só DEPOIS roda
# a simulação de "tempo que o jogo ficou fechado" dos bots -- antes ela rodava
# no _ready do BotSimulator, ANTES de qualquer perfil existir, gravando no
# perfil errado (e o load logo depois apagava). Era por isso que no celular
# (app fecha/abre toda hora) o ranking parecia parado
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
