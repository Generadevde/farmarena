extends Control

const MAIN_MENU_SCENE = "res://Scenes/hub.tscn"
const RANKING_SCENE = "res://ranking/leaderboard_menu.tscn"
const CARD_STATS_SCENE = "res://ranking/season_stats_menu.tscn"
const BATTLE_SCENE = "res://Scenes/batlhe_scene.tscn"


func _ready():
	MusicPlayer.play_menu_music()
	theme = ThemeBuilder.game_theme


func _on_ranking_button_pressed():
	get_tree().change_scene_to_file(RANKING_SCENE)


func _on_card_stats_button_pressed():
	get_tree().change_scene_to_file(CARD_STATS_SCENE)


func _on_back_button_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_player_stats_button_pressed():
	_show_player_stats_popup()


func _on_replays_button_pressed():
	_show_replays_popup()


func _show_player_stats_popup():
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
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(260, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📊 Suas Estatísticas"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	vbox.add_child(_stat_line("Batalhas jogadas", str(PlayerProfile.total_battles_played)))
	vbox.add_child(_stat_line("Vitórias", str(PlayerProfile.total_battles_won)))
	vbox.add_child(_stat_line("Taxa de vitória", "%d%%" % round(PlayerProfile.get_win_rate() * 100)))

	var favorite = PlayerProfile.get_favorite_card()
	vbox.add_child(_stat_line("Carta preferida", favorite.card_name if favorite != null else "-- nenhuma ainda --"))

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


func _stat_line(label_text: String, value_text: String) -> Control:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	row.add_child(value)
	return row


func _show_replays_popup():
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
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "🎬 Replays Salvos"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var replays = _load_replays()

	if replays.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nenhum replay salvo ainda."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_label)
	else:
		# do mais recente pro mais antigo
		for i in range(replays.size() - 1, -1, -1):
			vbox.add_child(_build_replay_row(replays[i], i, overlay))

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


func _load_replays() -> Array:
	if !FileAccess.file_exists("user://replays.json"):
		return []
	var file = FileAccess.open("user://replays.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []


func _build_replay_row(replay: Dictionary, index: int, popup_overlay: CanvasLayer) -> Control:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var result_text = "Vitória" if replay.get("player_won", false) else "Derrota"
	var result_color = Color(0.5, 0.85, 0.5) if replay.get("player_won", false) else Color(0.85, 0.45, 0.45)

	var summary_label = Label.new()
	summary_label.text = "vs %s -- %s" % [replay.get("bot_name", "?"), result_text]
	summary_label.add_theme_color_override("font_color", result_color)
	row.add_child(summary_label)

	var date_label = Label.new()
	date_label.text = replay.get("date", "")
	date_label.add_theme_font_size_override("font_size", 11)
	row.add_child(date_label)

	var button_row = HBoxContainer.new()
	row.add_child(button_row)

	var watch_button = Button.new()
	watch_button.text = "Assistir"
	watch_button.pressed.connect(func(): _show_replay_detail(replay))
	button_row.add_child(watch_button)

	var delete_button = Button.new()
	delete_button.text = "Deletar"
	delete_button.pressed.connect(func():
		_delete_replay(index)
		popup_overlay.queue_free()
		_show_replays_popup()  # reabre já sem esse replay
	)
	button_row.add_child(delete_button)

	row.add_child(HSeparator.new())
	return row


func _delete_replay(index: int):
	var replays = _load_replays()
	if index < 0 or index >= replays.size():
		return
	replays.remove_at(index)
	var file = FileAccess.open("user://replays.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(replays))


# versão simples -- mostra o resumo salvo (data, adversário, resultado,
# deck dos dois lados). Não é um "assistir passo a passo" de verdade, já
# que isso exigiria gravar cada ação da partida, o que ainda não fazemos
func _show_replay_detail(replay: Dictionary):
	var overlay = CanvasLayer.new()
	overlay.layer = 110
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(260, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "vs %s" % replay.get("bot_name", "?")
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var result_label = Label.new()
	result_label.text = "Vitória" if replay.get("player_won", false) else "Derrota"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_label)
	vbox.add_child(HSeparator.new())

	var play_button = Button.new()
	play_button.text = "▶ Reproduzir Replay"
	play_button.pressed.connect(func():
		MatchSetup.replay_data = replay
		get_tree().change_scene_to_file(BATTLE_SCENE)
	)
	vbox.add_child(play_button)

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


# botão "voltar" do Android (o jogo não fecha mais sozinho com ele)
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_button_pressed()
