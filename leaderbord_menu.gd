extends Control

const STATS_HUB_SCENE = "res://ranking/stats_hub.tscn"

var _viewing_arena_index: int = 1


func _ready():
	MusicPlayer.play_menu_music()
	theme = ThemeBuilder.game_theme
	$ScrollContainer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_viewing_arena_index = PlayerProfile.arena_index
	_build_list()


func _rank_display(rank: int) -> String:
	match rank:
		1: return "🥇"
		2: return "🥈"
		3: return "🥉"
		_: return "#%d" % rank


func _build_list():
	var container = $ScrollContainer/List
	container.add_theme_constant_override("separation", 10)
	for child in container.get_children():
		child.queue_free()

	var arena_info = ArenaManager.get_arena_info(_viewing_arena_index)

	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	container.add_child(header)

	var prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.disabled = _viewing_arena_index <= 1
	prev_button.pressed.connect(func():
		_viewing_arena_index -= 1
		_build_list()
	)
	header.add_child(prev_button)

	var title = Label.new()
	title.text = "%s %s" % [arena_info["emoji"], arena_info["name"]]
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var next_button = Button.new()
	next_button.text = "▶"
	next_button.disabled = _viewing_arena_index >= ArenaManager.MAX_ARENA
	next_button.pressed.connect(func():
		_viewing_arena_index += 1
		_build_list()
	)
	header.add_child(next_button)

	if _viewing_arena_index == PlayerProfile.arena_index:
		var your_arena_label = Label.new()
		your_arena_label.text = "(sua arena)"
		your_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		your_arena_label.add_theme_font_size_override("font_size", 12)
		container.add_child(your_arena_label)

	var ranking = ArenaManager.get_arena_ranking(_viewing_arena_index)
	var rank = 1

	for entry in ranking:
		var participant_name = entry["name"]
		var is_player = participant_name == PlayerProfile.player_name

		var row = Button.new()
		row.flat = true
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = 36.0  # altura fixa, reforça que toda linha fique do mesmo tamanho
		container.add_child(row)

		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		var rank_label = Label.new()
		rank_label.text = _rank_display(rank)
		rank_label.custom_minimum_size = Vector2(50, 0)
		rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(rank_label)

		var name_label = Label.new()
		name_label.text = participant_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_player:
			name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))  # destaca o jogador
		hbox.add_child(name_label)

		# sempre cria o rótulo de sequência, mesmo vazio -- manter a
		# estrutura da linha idêntica (mesma quantidade de filhos) em todo
		# mundo evita que a altura da linha varie dependendo de quem tem ou
		# não uma sequência, o que bagunçava a área clicável linha a linha
		var streak = Leaderboard.get_win_streak(participant_name)
		var streak_label = Label.new()
		streak_label.text = "🔥%d" % streak if streak >= 2 else ""
		streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(streak_label)

		var score_label = Label.new()
		score_label.text = str(entry["score"])
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(score_label)

		# só bots têm deck pra espiar -- clicar na sua própria linha não faz nada
		if !is_player:
			row.pressed.connect(_show_bot_deck_popup.bind(participant_name))

		rank += 1

	if ranking.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Ninguém jogou nenhuma partida ainda."
		container.add_child(empty_label)


# "raio-x" compacto do bot: personalidade resumida em uma linha, sequência
# atual, e a lista do deck com o nível de cada carta -- sem virar uma tela
# cheia de números, só o essencial pra dar aquele gostinho de "espionagem"
func _show_bot_deck_popup(bot_name: String):
	var profile = BotLearning.get_or_create_profile(bot_name)

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
	panel.custom_minimum_size = Vector2(280, 0)
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title_row = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "%s (🏆 %d)" % [bot_name, ArenaManager.get_trophies(bot_name)]
	title.add_theme_font_size_override("font_size", 22)
	title_row.add_child(title)

	var info_button = Button.new()
	info_button.text = "ⓘ"
	title_row.add_child(info_button)

	var streak = Leaderboard.get_win_streak(bot_name)
	var subtitle = Label.new()
	subtitle.text = _describe_style(profile) + ("  •  🔥%d" % streak if streak >= 2 else "")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.custom_minimum_size.x = 240.0  # largura do painel (280) menos margem
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# painel de estatísticas gerais -- começa escondido, o botão ⓘ revela
	var info_panel = VBoxContainer.new()
	info_panel.visible = false
	vbox.add_child(info_panel)

	var record = Leaderboard.get_record(bot_name)
	var total_battles = record["wins"] + record["losses"]
	var win_rate = Leaderboard.get_win_rate(bot_name)

	var battles_label = Label.new()
	battles_label.text = "Batalhas (nesta temporada): %d" % total_battles
	info_panel.add_child(battles_label)

	var winrate_label = Label.new()
	winrate_label.text = "Vitórias (nesta temporada): %d (%d%%)" % [record["wins"], round(win_rate * 100)]
	info_panel.add_child(winrate_label)

	var losses_label = Label.new()
	losses_label.text = "Derrotas (nesta temporada): %d" % record["losses"]
	info_panel.add_child(losses_label)

	# separado de propósito -- esse número é VITALÍCIO (nunca reseta com a
	# temporada), é ele que realmente explica o nível geral e o nível das
	# cartas do bot. Sem mostrar os dois separados, "1 batalha" ao lado de
	# "nível 7" parece contraditório, mas são janelas de tempo diferentes
	var lifetime_label = Label.new()
	lifetime_label.text = "Vitórias no total (vitalício): %d" % BotLearning.peek_lifetime_wins(bot_name)
	info_panel.add_child(lifetime_label)

	var archetype_label = Label.new()
	archetype_label.text = "Personalidade: %s" % profile.get_archetype_name()
	info_panel.add_child(archetype_label)

	var gold_label = Label.new()
	gold_label.text = "💰 Ouro: %d" % BotLearning.peek_gold(bot_name)
	info_panel.add_child(gold_label)

	var base_level_label = Label.new()
	base_level_label.text = "🏰 Base nível %d" % BotLearning.peek_base_level(bot_name)
	info_panel.add_child(base_level_label)

	if profile.favorite_card != null:
		var favorite_label = Label.new()
		favorite_label.text = "Carta preferida: %s" % profile.favorite_card.card_name
		favorite_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		favorite_label.custom_minimum_size.x = 240.0
		info_panel.add_child(favorite_label)

	var most_played = BotLearning.get_most_played_card(bot_name)
	if most_played != null:
		var most_played_label = Label.new()
		most_played_label.text = "Mais jogada: %s" % most_played.card_name
		most_played_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		most_played_label.custom_minimum_size.x = 240.0
		info_panel.add_child(most_played_label)

	info_button.pressed.connect(func(): info_panel.visible = !info_panel.visible)

	vbox.add_child(HSeparator.new())

	var deck_grid = GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 10)
	deck_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(deck_grid)

	for card in profile.deck:
		if card == null:
			continue
		var level = profile.get_card_level(card)
		deck_grid.add_child(_build_card_icon(card, level))

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


# monta um ícone de carta clicável, com o nível embaixo -- clicar mostra os
# atributos dela NAQUELE nível específico
func _build_card_icon(card: CardData, level: int) -> Control:
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(60, 70)

	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var icon_rect = TextureRect.new()
	icon_rect.texture = card.icon
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon_rect)

	var level_label = Label.new()
	level_label.text = "Nv %d" % level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 11)
	box.add_child(level_label)

	button.pressed.connect(_show_card_stats_popup.bind(card, level))

	return button


# mostra os atributos reais da carta NAQUELE nível específico -- usa a
# mesma curva de multiplicador que já vale pro jogador e pro bot (a carta
# não precisa "ser" de ninguém, só recebe o nível que você mandar)
func _show_card_stats_popup(card: CardData, level: int):
	var overlay = CanvasLayer.new()
	overlay.layer = 110
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
	panel.custom_minimum_size = Vector2(240, 0)
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "%s (Nv %d)" % [card.card_name, level]
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var mult = PlayerProfile.compute_stat_multiplier(level)

	if card.is_spell():
		var spell = card.spell_data
		if spell != null:
			if spell.damage > 0:
				vbox.add_child(_stat_line("Dano", str(round(spell.damage * mult))))
			if spell.heal_amount > 0:
				vbox.add_child(_stat_line("Cura", str(round(spell.heal_amount * mult))))
			vbox.add_child(_stat_line("Raio", str(spell.radius)))
	elif card.unit_scene != null:
		var temp = card.unit_scene.instantiate()
		var stats = temp.stats
		temp.queue_free()

		if stats != null:
			vbox.add_child(_stat_line("HP", str(round(stats.hp * mult))))
			vbox.add_child(_stat_line("Dano", str(round(stats.damage * mult))))
			vbox.add_child(_stat_line("Velocidade de Ataque", str(stats.attack_speed)))
			vbox.add_child(_stat_line("Alcance", str(stats.attack_range)))
			vbox.add_child(_stat_line("Velocidade", str(stats.move_speed)))

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
	row.add_child(value)

	return row


# resume a personalidade do bot numa frase só, sem listar número nenhum
const ROLE_NAMES = {
	CardData.CardRole.ENXAME: "enxame",
	CardData.CardRole.TANQUE: "tanque",
	CardData.CardRole.PUNICAO: "punição",
	CardData.CardRole.CONTROLE: "controle",
	CardData.CardRole.CONTRA_ATAQUE: "contra-ataque",
	CardData.CardRole.SUPORTE: "suporte",
	CardData.CardRole.FINALIZADOR: "finalizador",
	CardData.CardRole.CONSTRUCAO: "construção",
	CardData.CardRole.AEREO: "aéreo",
	CardData.CardRole.VERSATIL: "versátil",
	CardData.CardRole.INVOCADOR: "invocador",
	CardData.CardRole.CERCO: "cerco",
}


func _describe_style(profile: AIProfile) -> String:
	var bits: Array[String] = []
	if profile.prefer_expensive:
		bits.append("gosta de carta cara")
	if profile.reacts_to_threats:
		bits.append("defensivo")
	if profile.revenge_mode:
		bits.append("perigoso quando leva dano")
	if profile.prefer_units_over_spells:
		bits.append("evita feitiço")
	if profile.decision_interval <= 1.8:
		bits.append("ataca rápido")
	if profile.preferred_role != CardData.CardRole.VERSATIL:
		bits.append("gosta de " + ROLE_NAMES.get(profile.preferred_role, "?"))
	if bits.is_empty():
		return "estilo equilibrado"
	return ", ".join(bits)


func _on_back_button_pressed():
	get_tree().change_scene_to_file(STATS_HUB_SCENE)
