extends Control

const MAIN_MENU_SCENE = "res://Scenes/main_menu.tscn"


func _ready():
	theme = ThemeBuilder.game_theme
	MusicPlayer.play_menu_music()
	$ScrollContainer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_list()
	Journal.mark_all_as_read()


func _build_list():
	var container = $ScrollContainer/List
	for child in container.get_children():
		child.queue_free()

	if Journal.entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nenhuma novidade por enquanto."
		container.add_child(empty_label)
		return

	for entry in Journal.entries:
		var panel = PanelContainer.new()
		container.add_child(panel)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		var title_label = Label.new()
		title_label.text = entry.title
		title_label.add_theme_font_size_override("font_size", 20)
		vbox.add_child(title_label)

		var date_label = Label.new()
		date_label.text = entry.date
		date_label.add_theme_font_size_override("font_size", 12)
		date_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(date_label)

		var desc_label = Label.new()
		desc_label.text = entry.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = 300.0
		vbox.add_child(desc_label)


func _on_back_button_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
