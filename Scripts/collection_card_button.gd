extends Button
class_name CollectionCardButton

var card: CardData


func _ready():
	custom_minimum_size = Vector2(90, 138)
	mouse_filter = Control.MOUSE_FILTER_PASS  # arrastar em cima rola a coleção
	clip_contents = true  # corta qualquer coisa que ultrapasse os limites do botão

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var icon_rect = TextureRect.new()
	icon_rect.texture = card.icon
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítido
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(icon_rect)

	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# mostra sempre -- agora é um número que você mesmo define pra toda
	# carta, não faz mais sentido esconder só porque não tem cadeia
	var tier_badge = Label.new()
	tier_badge.text = "Tier %d" % card.tier
	tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_badge.add_theme_font_size_override("font_size", 9)
	tier_badge.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	vbox.add_child(tier_badge)

	var level_label = Label.new()
	level_label.text = "Nível %d" % PlayerProfile.get_card_level(card)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(level_label)

	_apply_lock_state()


# três estados visuais: bloqueada de vez (nível baixo demais, escurecida),
# elegível esperando o toque (mais clara que o normal) e desbloqueada (normal)
func _apply_lock_state():
	if PlayerProfile.is_card_unlocked(card):
		modulate = Color(1, 1, 1)
	elif PlayerProfile.can_unlock_card(card):
		modulate = Color(1.3, 1.3, 0.9)  # mais clara -- "pronta pra desbloquear"
	else:
		modulate = Color(0.35, 0.35, 0.35)  # escurecida -- ainda não chegou o nível


func _pressed():
	var menu = get_tree().get_first_node_in_group("library_menu")
	if menu != null and menu.has_method("show_card_details"):
		menu.show_card_details(card)
