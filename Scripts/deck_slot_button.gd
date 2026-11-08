extends Button
@export var deck_index: int = 0  # posição fixa no deck (0 a 6)

func _ready():
	clip_contents = true  # corta qualquer coisa que ultrapasse os limites do botão
	$Icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$Icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	DeckManager.deck_changed.connect(_refresh)
	_refresh()

func _refresh():
	var card: CardData = DeckManager.full_deck[deck_index]
	if card == null:
		return
	$Name.text = card.card_name
	$Name.clip_text = true  # corte elegante com reticências, em vez do corte brusco que já tinha antes
	$Name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$Name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Icon.texture = card.icon
	_refresh_level_label(card)

# cria (na primeira vez) e atualiza o texto de nível em cima do ícone --
# não existe no .tscn original, então monta ele em código se ainda não tiver
func _refresh_level_label(card: CardData):
	var level_label = get_node_or_null("LevelLabel")
	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(level_label)
	level_label.text = "Nv%d" % PlayerProfile.get_card_level(card)

func _pressed():
	var card: CardData = DeckManager.full_deck[deck_index]
	if card == null:
		return
	var menu = get_tree().get_first_node_in_group("library_menu")
	if menu != null and menu.has_method("show_card_details"):
		menu.show_card_details(card)
