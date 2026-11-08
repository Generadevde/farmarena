extends Control

const STATS_HUB_SCENE = "res://ranking/stats_hub.tscn"
const LIST_SIZE = 5

const MIN_GAMES_FOR_WIN_RATE = 3
const MIN_GAMES_FOR_PAIR = 2
const MIN_GAMES_FOR_CONTROVERSY = 5

# cada categoria: nome pra mostrar no cabeçalho + os dados já ordenados +
# como montar a legenda de cada carta -- tudo navegável com as setinhas,
# uma categoria por vez, em vez de mostrar as 7 empilhadas de uma só vez
var _categories: Array = []
var _current_category: int = 0
var _display_container: Control  # reaproveita 1 container que já existe na cena
var _category_title_label: Label


func _ready():
	MusicPlayer.play_menu_music()
	theme = ThemeBuilder.game_theme

	_display_container = $ScrollContainer/VBoxContainer/TopWinRate
	_build_category_data()
	_build_toggle_header()
	_show_current_category()


# monta a barra de navegação (◀ nome da categoria ▶) logo acima do container
# que mostra o conteúdo -- mesmo padrão já usado pra trocar de arena/coleção
func _build_toggle_header():
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # sem isso, o alinhamento central não faz efeito -- o cabeçalho ficava "encolhido" no canto em vez de esticar a largura toda
	header.add_theme_constant_override("separation", 16)
	_display_container.get_parent().add_child(header)
	_display_container.get_parent().move_child(header, _display_container.get_index())

	var prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.pressed.connect(func():
		_current_category = (_current_category - 1 + _categories.size()) % _categories.size()
		_show_current_category()
	)
	header.add_child(prev_button)

	_category_title_label = Label.new()
	_category_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_category_title_label)

	var next_button = Button.new()
	next_button.text = "▶"
	next_button.pressed.connect(func():
		_current_category = (_current_category + 1) % _categories.size()
		_show_current_category()
	)
	header.add_child(next_button)


func _build_category_data():
	var all_stats = SeasonStats.get_all_card_stats()
	var with_enough_games = all_stats.filter(func(s): return s["wins"] + s["losses"] >= MIN_GAMES_FOR_WIN_RATE)

	var by_win_rate = with_enough_games.duplicate()
	by_win_rate.sort_custom(func(a, b): return a["win_rate"] > b["win_rate"])

	var by_low_win_rate = with_enough_games.duplicate()
	by_low_win_rate.sort_custom(func(a, b): return a["win_rate"] < b["win_rate"])

	var trending_up = with_enough_games.filter(func(s): return s["trend"] > 0)
	trending_up.sort_custom(func(a, b): return a["trend"] > b["trend"])

	var trending_down = with_enough_games.filter(func(s): return s["trend"] < 0)
	trending_down.sort_custom(func(a, b): return a["trend"] < b["trend"])

	var controversial = _compute_controversial(with_enough_games)

	var pairs = SeasonStats.get_all_pair_stats().filter(func(p): return p["times_played"] >= MIN_GAMES_FOR_PAIR)
	pairs.sort_custom(func(a, b): return a["win_rate"] > b["win_rate"])

	var forgotten = SeasonStats.get_forgotten_cards()

	_categories = [
		{"name": "🏆 Maior Taxa de Vitória", "type": "card", "entries": by_win_rate,
			"caption_fn": func(e): return "%d%%" % round(e["win_rate"] * 100)},
		{"name": "💤 Menor Taxa de Vitória", "type": "card", "entries": by_low_win_rate,
			"caption_fn": func(e): return "%d%%" % round(e["win_rate"] * 100)},
		{"name": "📈 Em Alta", "type": "card", "entries": trending_up,
			"caption_fn": func(e): return "+%d%%" % round(e["trend"] * 100)},
		{"name": "📉 Em Baixa", "type": "card", "entries": trending_down,
			"caption_fn": func(e): return "%d%%" % round(e["trend"] * 100)},
		{"name": "🔥 Cartas Polêmicas", "type": "card", "entries": controversial,
			"caption_fn": func(e): return "%d%% / %dx" % [round(e["win_rate"] * 100), e["times_played"]]},
		{"name": "🤝 Melhores Duplas", "type": "pair", "entries": pairs},
		{"name": "😴 Cartas Esquecidas", "type": "forgotten", "entries": forgotten},
	]


func _show_current_category():
	var category = _categories[_current_category]
	_category_title_label.text = category["name"]

	for child in _display_container.get_children():
		child.queue_free()

	if category["entries"].is_empty():
		var empty_label = Label.new()
		empty_label.text = "Sem dados suficientes ainda."
		_display_container.add_child(empty_label)
		return

	match category["type"]:
		"card":
			_show_card_list(category["entries"], category["caption_fn"])
		"pair":
			_show_pair_list(category["entries"])
		"forgotten":
			_show_forgotten_list(category["entries"])


# lista compacta -- ícone pequeno + nome + legenda numa linha só cada,
# bem mais enxuto que a grade de ícone antiga
func _show_card_list(entries: Array, caption_fn: Callable):
	for i in min(LIST_SIZE, entries.size()):
		var entry = entries[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_display_container.add_child(row)

		row.add_child(_make_icon(entry["card"].icon))

		var name_label = Label.new()
		name_label.text = entry["card"].card_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var caption_label = Label.new()
		caption_label.text = caption_fn.call(entry)
		row.add_child(caption_label)


func _show_pair_list(entries: Array):
	for i in min(LIST_SIZE, entries.size()):
		var entry = entries[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_display_container.add_child(row)

		row.add_child(_make_icon(entry["card_a"].icon))

		var plus_label = Label.new()
		plus_label.text = "+"
		row.add_child(plus_label)

		row.add_child(_make_icon(entry["card_b"].icon))

		var pct_label = Label.new()
		pct_label.text = "%d%%" % round(entry["win_rate"] * 100)
		pct_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct_label)


func _show_forgotten_list(cards: Array):
	for i in min(LIST_SIZE, cards.size()):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_display_container.add_child(row)

		row.add_child(_make_icon(cards[i].icon))

		var name_label = Label.new()
		name_label.text = cards[i].card_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var used_label = Label.new()
		used_label.text = "0 usos"
		row.add_child(used_label)


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon_rect = TextureRect.new()
	icon_rect.texture = texture
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return icon_rect


# "polêmica" = jogada bastante, mas com taxa de vitória baixa (tipo o exemplo
# "vitória 40%, uso 80%") -- combina o quanto é jogada (normalizado contra a
# mais jogada de todas) com o quanto ela DEIXA A DESEJAR na vitória
func _compute_controversial(entries: Array) -> Array:
	var qualified = entries.filter(func(s): return s["wins"] + s["losses"] >= MIN_GAMES_FOR_CONTROVERSY)
	if qualified.is_empty():
		return []

	var max_played = 0
	for e in qualified:
		max_played = max(max_played, e["times_played"])
	if max_played == 0:
		return []

	var scored = []
	for e in qualified:
		var normalized_played = float(e["times_played"]) / max_played
		var controversy = normalized_played - e["win_rate"]
		var copy = e.duplicate()
		copy["controversy"] = controversy
		scored.append(copy)

	scored.sort_custom(func(a, b): return a["controversy"] > b["controversy"])
	return scored


func _on_back_button_pressed():
	get_tree().change_scene_to_file(STATS_HUB_SCENE)
