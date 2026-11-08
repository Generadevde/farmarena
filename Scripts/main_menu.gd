extends Control

# ajusta esses caminhos pro local real das suas cenas
const BATTLE_SCENE = "res://Scenes/batlhe_scene.tscn"
const LIBRARY_SCENE = "res://Scenes/library_menu.tscn"
const STATS_HUB_SCENE = "res://ranking/stats_hub.tscn"
const CREATOR_SCENE = "res://creator/creator_menu.tscn"

# referências cacheadas, encontradas pelo NOME em qualquer lugar da árvore
# (não por caminho fixo) -- assim continua funcionando mesmo se você
# reorganizar a cena depois (envolver em outro container, mover de lugar),
# sem precisar de correção de caminho toda vez que isso acontecer
var _name_label: Label
var _level_label: Label
var _coins_label: Label
var _arena_label: Label
var _xp_bar: ProgressBar
var _top_nation_label: Label  # criado em código -- mostra a nação com mais XP, no lugar da barra de nível antiga


func _ready():
	MusicPlayer.play_menu_music()

	_name_label = find_child("NameLabel", true, false)
	_level_label = find_child("LevelLabel", true, false)
	_coins_label = find_child("CoinsLabel", true, false)
	_arena_label = find_child("ArenaLabel", true, false)
	_xp_bar = find_child("XPBar", true, false)

	if _xp_bar != null:
		_xp_bar.visible = false  # o progresso de nível antigo não faz mais sentido -- congelou desde que o XP passou a ir pra nação
		_top_nation_label = Label.new()
		_top_nation_label.add_theme_font_size_override("font_size", 13)
		_top_nation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_xp_bar.get_parent().add_child(_top_nation_label)
		_xp_bar.get_parent().move_child(_top_nation_label, _xp_bar.get_index())

	add_to_group("main_menu")
	PlayerProfile.profile_changed.connect(_refresh_player_info)
	_refresh_player_info()
	_refresh_season_widget()
	_maybe_show_bot_quote_toast()

	if _name_label != null:
		_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_name_label.gui_input.connect(_on_player_name_gui_input)


func _on_player_name_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_register_dev_tap()


# toque secreto de desenvolvedor -- 7 toques rápidos (dentro de 3s) no
# próprio nome abre o painel de cheat. O popup normal de info NÃO pode
# abrir em todo toque (como era antes) -- ele ficaria por cima do nome e
# bloquearia os toques seguintes da sequência secreta, nunca deixando
# contar até 7. Por isso o popup normal espera um instante antes de abrir,
# só pra ver se mais toques estão chegando -- se chegar toque novo nesse
# meio tempo, o "check_id" muda e invalida a checagem antiga, então só o
# ÚLTIMO toque de uma rajada (ou um toque isolado) realmente abre o popup
const DEV_TAP_COUNT_NEEDED = 7
const DEV_TAP_WINDOW_SECONDS = 3.0
const DEV_TAP_SINGLE_DELAY = 0.35
var _dev_tap_count: int = 0
var _dev_tap_window_start: float = 0.0
var _dev_tap_check_id: int = 0

func _register_dev_tap():
	var now = Time.get_ticks_msec() / 1000.0
	if now - _dev_tap_window_start > DEV_TAP_WINDOW_SECONDS:
		_dev_tap_count = 0
		_dev_tap_window_start = now

	_dev_tap_count += 1
	_dev_tap_check_id += 1
	var my_check_id = _dev_tap_check_id

	if _dev_tap_count >= DEV_TAP_COUNT_NEEDED:
		_dev_tap_count = 0
		_show_dev_cheat_panel()
		return

	await get_tree().create_timer(DEV_TAP_SINGLE_DELAY).timeout
	if my_check_id == _dev_tap_check_id:
		_dev_tap_count = 0
		_show_player_info_popup()


func _show_dev_cheat_panel():
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "🛠️ Painel de Desenvolvedor"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var coins_button = Button.new()
	coins_button.text = "+1000 💰 moedas"
	coins_button.pressed.connect(func():
		PlayerProfile.add_coins(1000)
		_refresh_player_info()
	)
	vbox.add_child(coins_button)

	var xp_button = Button.new()
	xp_button.text = "+500 ⭐ XP livre"
	xp_button.pressed.connect(func():
		PlayerProfile.free_xp += 500
		PlayerProfile.save_profile()
		PlayerProfile.profile_changed.emit()
		_refresh_player_info()
	)
	vbox.add_child(xp_button)

	var big_xp_button = Button.new()
	big_xp_button.text = "+5000 ⭐ XP livre"
	big_xp_button.pressed.connect(func():
		PlayerProfile.free_xp += 5000
		PlayerProfile.save_profile()
		PlayerProfile.profile_changed.emit()
		_refresh_player_info()
	)
	vbox.add_child(big_xp_button)

	vbox.add_child(HSeparator.new())

	var upgrade_all_button = Button.new()
	upgrade_all_button.text = "⬆️ +1 nível em TODAS as cartas"
	upgrade_all_button.pressed.connect(func():
		for path in PlayerProfile.unlocked_cards:
			if ResourceLoader.exists(path):
				PlayerProfile.dev_force_upgrade_card(load(path))
	)
	vbox.add_child(upgrade_all_button)

	var max_all_button = Button.new()
	max_all_button.text = "🌟 Maximiza TODAS as cartas"
	max_all_button.pressed.connect(func():
		for path in PlayerProfile.unlocked_cards:
			if ResourceLoader.exists(path):
				var card = load(path)
				while !PlayerProfile.is_max_level(card):
					PlayerProfile.dev_force_upgrade_card(card)
	)
	vbox.add_child(max_all_button)

	vbox.add_child(HSeparator.new())

	var per_card_label = Label.new()
	per_card_label.text = "Subir carta específica:"
	per_card_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(per_card_label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 4)
	scroll.add_child(card_list)

	for path in PlayerProfile.unlocked_cards:
		if !ResourceLoader.exists(path):
			continue
		var card = load(path)
		if card == null:
			continue

		var row = HBoxContainer.new()
		card_list.add_child(row)

		var name_level_label = Label.new()
		name_level_label.text = "%s (Nv %d)" % [card.card_name, PlayerProfile.get_card_level(card)]
		name_level_label.custom_minimum_size = Vector2(170, 0)
		name_level_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_level_label)

		var plus_button = Button.new()
		plus_button.text = "+1"
		plus_button.pressed.connect(func():
			PlayerProfile.dev_force_upgrade_card(card)
			name_level_label.text = "%s (Nv %d)" % [card.card_name, PlayerProfile.get_card_level(card)]
		)
		row.add_child(plus_button)

	vbox.add_child(HSeparator.new())

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(overlay.queue_free)
	vbox.add_child(close_button)


# chance de mostrar uma fala de bot sozinha, sem precisar abrir o jornal --
# some sozinha depois de um tempo, ou se apertar o X
const BOT_QUOTE_TOAST_CHANCE = 0.35
const BOT_QUOTE_TOAST_SECONDS = 6.0


func _maybe_show_bot_quote_toast():
	if randf() > BOT_QUOTE_TOAST_CHANCE:
		return

	var quote = Journal.get_random_bot_quote()
	if quote == "":
		return

	var overlay = CanvasLayer.new()
	overlay.layer = 90
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH  # cresce pros 2 lados, centralizado (antes ia pra direita e cobria o botão Atualizações)
	panel.position.y = 90
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = ThemeBuilder.game_theme
	overlay.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var label = Label.new()
	label.text = "💬 " + quote
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size.x = 220.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.pressed.connect(func(): overlay.queue_free())
	hbox.add_child(close_button)

	await get_tree().create_timer(BOT_QUOTE_TOAST_SECONDS).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()


# mesmo tipo de "raio-x" que já existe pro bot no ranking, só que pro
# próprio jogador -- batalhas, taxa de vitória, carta mais usada
func _show_player_info_popup():
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

	var title = Label.new()
	title.text = "%s (🏆 %d)" % [PlayerProfile.player_name, ArenaManager.get_trophies(PlayerProfile.player_name)]
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var record = Leaderboard.get_record(PlayerProfile.player_name)
	var total_battles = record["wins"] + record["losses"]
	var win_rate = Leaderboard.get_win_rate(PlayerProfile.player_name)

	var battles_label = Label.new()
	battles_label.text = "Batalhas: %d" % total_battles
	vbox.add_child(battles_label)

	var winrate_label = Label.new()
	winrate_label.text = "Vitórias: %d (%d%%)" % [record["wins"], round(win_rate * 100)]
	vbox.add_child(winrate_label)

	var losses_label = Label.new()
	losses_label.text = "Derrotas: %d" % record["losses"]
	vbox.add_child(losses_label)

	var most_used = _get_player_most_used_card()
	if most_used != null:
		var most_used_label = Label.new()
		most_used_label.text = "Mais usada: %s" % most_used.card_name
		most_used_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		most_used_label.custom_minimum_size.x = 240.0
		vbox.add_child(most_used_label)

	var streak = Leaderboard.get_win_streak(PlayerProfile.player_name)
	if streak >= 2:
		var streak_label = Label.new()
		streak_label.text = "🔥 Sequência atual: %d vitória(s)" % streak
		vbox.add_child(streak_label)

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


func _get_player_most_used_card() -> CardData:
	var best_path = ""
	var best_count = 0
	for path in PlayerProfile.card_usage:
		if PlayerProfile.card_usage[path] > best_count:
			best_count = PlayerProfile.card_usage[path]
			best_path = path
	if best_path != "" and ResourceLoader.exists(best_path):
		return load(best_path)
	return null


func _refresh_player_info():
	if _name_label == null:
		return  # ainda não achou os nós (cena com estrutura diferente do esperado)

	_name_label.text = PlayerProfile.player_name
	_level_label.text = "⭐ %d XP livre" % PlayerProfile.free_xp
	_coins_label.text = "💰 %d" % PlayerProfile.coins
	var arena_info = ArenaManager.get_arena_info(PlayerProfile.arena_index)
	_arena_label.text = "%s %s" % [arena_info["emoji"], arena_info["name"]]

	if _top_nation_label != null:
		_top_nation_label.text = _get_top_nation_text()


# monta o texto de destaque da nação com mais XP acumulado -- "🏆 Mimosas: 240 XP",
# ou uma mensagem convidativa se o jogador ainda não tem XP de nação nenhuma
func _get_top_nation_text() -> String:
	if PlayerProfile.nation_xp.is_empty():
		return "Jogue pra ganhar XP de nação!"

	var top_nation = ""
	var top_amount = -1
	for nation_name in PlayerProfile.nation_xp:
		if PlayerProfile.nation_xp[nation_name] > top_amount:
			top_amount = PlayerProfile.nation_xp[nation_name]
			top_nation = nation_name

	return "🏆 %s: %d XP" % [top_nation, top_amount]


# a temporada é tratada como uma "safra" (tema de fazenda) -- a barra enche
# conforme os dias passam, e o texto muda de tom quando a colheita se aproxima
func _refresh_season_widget():
	var days_remaining = SeasonManager.get_days_remaining()
	var total_days = SeasonManager.SEASON_DURATION_DAYS

	$SeasonWidget/SeasonLabel.text = "🌾 Safra #%d" % SeasonManager.season_number

	$SeasonWidget/SeasonBar.max_value = total_days
	$SeasonWidget/SeasonBar.value = total_days - days_remaining

	var days_left = ceili(days_remaining)
	if days_remaining <= 0.5:
		$SeasonWidget/SeasonSubLabel.text = "🌾 A colheita é hoje!"
	elif days_left <= 1:
		$SeasonWidget/SeasonSubLabel.text = "Último dia da safra!"
	elif days_left <= 2:
		$SeasonWidget/SeasonSubLabel.text = "A colheita está chegando -- só mais %d dias!" % days_left
	else:
		$SeasonWidget/SeasonSubLabel.text = "Faltam %d dias para a colheita" % days_left


func _on_battle_button_pressed():
	MatchSetup.mode = MatchSetup.MODE_1V1
	MatchSetup.next_ai_profile = _choose_opponent()
	get_tree().change_scene_to_file(BATTLE_SCENE)


# 2v2: você + 1 bot aliado contra 2 bots. Escolhe 3 bots diferentes perto do
# seu troféu (o adversário principal usa a mesma regra da partida normal)
func _on_battle_2v2_button_pressed():
	MatchSetup.mode = MatchSetup.MODE_2V2
	var main_enemy = _choose_opponent()
	MatchSetup.next_ai_profile = main_enemy
	var used: Array = []
	if main_enemy != null:
		used.append(main_enemy.profile_name)
	var pool: Array = BotSimulator.roster_names.duplicate()
	var my_trophies = ArenaManager.get_trophies(PlayerProfile.player_name)
	pool.sort_custom(func(a, b): return abs(ArenaManager.get_trophies(a) - my_trophies) < abs(ArenaManager.get_trophies(b) - my_trophies))
	var picks: Array = []
	for bot_name in pool.slice(0, 12):
		if !used.has(bot_name):
			picks.append(bot_name)
	picks.shuffle()
	MatchSetup.ally_ai_profile = BotLearning.get_or_create_profile(picks[0]) if picks.size() > 0 else null
	MatchSetup.second_enemy_ai_profile = BotLearning.get_or_create_profile(picks[1]) if picks.size() > 1 else null
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _on_creator_button_pressed():
	get_tree().change_scene_to_file(CREATOR_SCENE)


# sorteia um nome do elenco compartilhado (BotSimulator.roster_names) e busca
# (ou cria, se for a 1ª vez) a personalidade atual daquele bot -- dá pra
# evoluir depois pra escolher com base na arena/nível do jogador
# bots com nível geral dentro dessa distância do seu contam como "perto" e
# entram no sorteio; ajusta esse número pra deixar o pareamento mais apertado
# ou mais solto
const OPPONENT_TROPHY_RANGE = 150


# sorteia um adversário priorizando quem estiver perto do seu troféu -- se
# ninguém estiver na faixa (ex: começo de jogo, elenco ainda não evoluiu),
# cai pro bot mais próximo que existir, em vez de sortear qualquer um às cegas
func _choose_opponent() -> AIProfile:
	if BotSimulator.roster_names.is_empty():
		return null

	var candidates: Array[String] = []
	var closest_candidates: Array[String] = []
	var closest_diff = INF
	var player_trophies = ArenaManager.get_trophies(PlayerProfile.player_name)

	for bot_name in BotSimulator.roster_names:
		# bot enfrentado nas últimas 2 partidas não pode ser sorteado de novo
		if bot_name in PlayerProfile.recent_opponents:
			continue

		var bot_trophies = ArenaManager.get_trophies(bot_name)
		var diff = abs(bot_trophies - player_trophies)

		if diff <= OPPONENT_TROPHY_RANGE:
			candidates.append(bot_name)

		if diff < closest_diff:
			closest_diff = diff
			closest_candidates = [bot_name]
		elif diff == closest_diff:
			# empate no "mais próximo" -- sorteia entre todos os empatados,
			# em vez de sempre ficar com o primeiro da lista (isso fazia
			# cair sempre no mesmo bot quando ninguém estava no alcance normal)
			closest_candidates.append(bot_name)

	var chosen_name: String
	if !candidates.is_empty():
		chosen_name = candidates[randi() % candidates.size()]
	elif !closest_candidates.is_empty():
		chosen_name = closest_candidates[randi() % closest_candidates.size()]
	else:
		# só cai aqui se TODO o elenco tiver sido excluído pelos "recentes"
		# (elenco bem pequeno) -- melhor repetir um bot do que não ter
		# oponente nenhum pra jogar
		chosen_name = BotSimulator.roster_names[randi() % BotSimulator.roster_names.size()]

	PlayerProfile.record_recent_opponent(chosen_name)
	return BotLearning.get_or_create_profile(chosen_name)


# monta o bot na hora, com base em tudo que o observador já viu você jogar
# até agora -- fica mais parecido com você conforme você joga mais partidas
func _on_reflection_battle_button_pressed():
	MatchSetup.next_ai_profile = PlayerBehaviorProfiler.build_ai_profile()
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _on_library_button_pressed():
	get_tree().change_scene_to_file(LIBRARY_SCENE)


func _on_stats_button_pressed():
	get_tree().change_scene_to_file(STATS_HUB_SCENE)


func _on_journal_button_pressed():
	_show_journal_popup()


func _on_missions_button_pressed():
	_show_missions_popup()


func _on_updates_button_pressed():
	_show_updates_popup()


func _show_journal_popup():
	Journal.mark_all_as_read()

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
	panel.custom_minimum_size = Vector2(320, 420)
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)

	const LABEL_WIDTH = 280.0  # largura do painel menos margem, pra quebra de linha funcionar de verdade

	# cores do "jornal" -- fala ambiente de bot em verde, fala dirigida a
	# você (pós-batalha) em verde escuro, detalhe (entrada manual) em
	# branco, notícia automática em cinza
	const COLOR_BOT_AMBIENT = Color(0.45, 0.85, 0.45)
	const COLOR_BOT_DIRECTED = Color(0.15, 0.5, 0.2)
	const COLOR_DETAIL = Color(1, 1, 1)
	const COLOR_NEWS = Color(0.65, 0.65, 0.65)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(outer_vbox)

	# cabeçalho com título + X no canto, pra fechar tudo de uma vez
	var header = HBoxContainer.new()
	outer_vbox.add_child(header)

	var title = Label.new()
	title.text = "Jornal"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close_x = Button.new()
	close_x.text = "X"
	close_x.pressed.connect(func(): overlay.queue_free())
	header.add_child(close_x)

	var quote = Journal.get_random_bot_quote()
	if quote != "":
		var quote_label = Label.new()
		quote_label.text = "💬 " + quote
		quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		quote_label.custom_minimum_size.x = LABEL_WIDTH
		quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quote_label.add_theme_color_override("font_color", COLOR_BOT_AMBIENT)
		outer_vbox.add_child(quote_label)
		outer_vbox.add_child(HSeparator.new())

	PollManager.check_for_rotation()
	var active_poll = PollManager.get_active_poll_for_player()
	if !active_poll.is_empty():
		_build_poll_ui(outer_vbox, active_poll, LABEL_WIDTH, overlay)
		outer_vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	# falas de bot dirigidas a VOCÊ, depois de partida real -- verde escuro.
	# X remove de verdade (não volta mais)
	for i in Journal.player_directed_quotes.size():
		var directed_label = Label.new()
		directed_label.text = "🎯 " + Journal.player_directed_quotes[i]
		directed_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		directed_label.custom_minimum_size.x = LABEL_WIDTH - 30.0
		directed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		directed_label.add_theme_color_override("font_color", COLOR_BOT_DIRECTED)
		var row = _build_dismissible_row(directed_label, func(r):
			r.queue_free()
		)
		list.add_child(row)

	if !Journal.player_directed_quotes.is_empty():
		list.add_child(HSeparator.new())

	# notícias automáticas -- cinza. X só esconde nessa visualização (ela é
	# recalculada na hora toda vez que o jornal abre, não tem "removida de
	# vez" pra um fato tipo "fulano lidera o ranking")
	for line in Journal.generate_auto_news():
		var auto_label = Label.new()
		auto_label.text = "• " + line
		auto_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		auto_label.custom_minimum_size.x = LABEL_WIDTH - 30.0
		auto_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_label.add_theme_color_override("font_color", COLOR_NEWS)
		var row = _build_dismissible_row(auto_label, func(r): r.queue_free())
		list.add_child(row)

	if !Journal.entries.is_empty():
		list.add_child(HSeparator.new())

	# depois as notícias fixas que você escreveu à mão -- branco (detalhe).
	# X remove de verdade (não volta mais)
	for entry in Journal.entries:
		var entry_box = VBoxContainer.new()
		entry_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var entry_title = Label.new()
		entry_title.text = entry.title
		entry_title.add_theme_font_size_override("font_size", 16)
		entry_title.add_theme_color_override("font_color", COLOR_DETAIL)
		entry_box.add_child(entry_title)

		var entry_date = Label.new()
		entry_date.text = entry.date
		entry_date.add_theme_font_size_override("font_size", 11)
		entry_date.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		entry_box.add_child(entry_date)

		var entry_desc = Label.new()
		entry_desc.text = entry.description
		entry_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		entry_desc.custom_minimum_size.x = LABEL_WIDTH - 30.0
		entry_desc.add_theme_color_override("font_color", COLOR_DETAIL)
		entry_box.add_child(entry_desc)

		var entry_row = _build_dismissible_row(entry_box, func(r):
			r.queue_free()
		)
		list.add_child(entry_row)


# embrulha qualquer conteúdo (label ou vbox) numa linha com um X pequeno do
# lado, pra dispensar aquele item individual -- on_dismiss recebe a LINHA
# inteira (a HBoxContainer), já pronta pra remover da tela
func _build_dismissible_row(content: Control, on_dismiss: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(content)

	var dismiss_button = Button.new()
	dismiss_button.text = "x"
	dismiss_button.add_theme_font_size_override("font_size", 11)
	dismiss_button.custom_minimum_size = Vector2(24, 24)
	dismiss_button.pressed.connect(func(): on_dismiss.call(row))
	row.add_child(dismiss_button)

	return row


# monta a pergunta + os 4 botões de opção (cada um com o nome da carta, ou
# das duas cartas se for pergunta de dupla) -- votar fecha e reabre o
# popup, já sem a enquete (porque _get_active_poll_for_player só devolve
# enquete que ainda não foi votada)
func _build_poll_ui(parent: VBoxContainer, poll: Dictionary, label_width: float, overlay: CanvasLayer):
	var question_label = Label.new()
	question_label.text = "🗳️ " + poll["question"]
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	question_label.custom_minimum_size.x = label_width
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(question_label)

	var options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 6)
	parent.add_child(options_box)

	var options = poll["options"]
	for i in options.size():
		var option_paths = options[i]
		var names: Array[String] = []
		for path in option_paths:
			if ResourceLoader.exists(path):
				names.append(load(path).card_name)
		if names.is_empty():
			continue

		var option_button = Button.new()
		option_button.text = " + ".join(names)
		var captured_index = i
		option_button.pressed.connect(func():
			PollManager.cast_player_vote(captured_index)
			overlay.queue_free()
			_show_journal_popup()
		)
		options_box.add_child(option_button)


# botão de sair do jogo -- conecta o "pressed" desse botão nessa função
func _show_missions_popup():
	PlayerProfile._check_and_reset_daily_missions()

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

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📋 Missões Diárias"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for mission in PlayerProfile.daily_missions:
		vbox.add_child(_build_mission_row(mission, overlay))

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


func _build_mission_row(mission: Dictionary, overlay: Node = null) -> Control:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var desc_label = Label.new()
	desc_label.text = mission["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(desc_label)

	var progress_row = HBoxContainer.new()
	row.add_child(progress_row)

	var progress_bar = ProgressBar.new()
	progress_bar.max_value = mission["target"]
	progress_bar.value = mission["progress"]
	progress_bar.custom_minimum_size = Vector2(140, 16)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "%d/%d" % [mission["progress"], mission["target"]]
	progress_row.add_child(progress_label)

	var reward_label = Label.new()
	var reward_text = ""
	match mission["reward_type"]:
		MissionData.RewardType.COINS:
			reward_text = "💰 %d ouro" % mission["reward_amount"]
		MissionData.RewardType.FREE_XP:
			reward_text = "⭐ %d XP livre" % mission["reward_amount"]
		MissionData.RewardType.NATION_XP:
			reward_text = "⭐ %d XP de %s" % [mission["reward_amount"], mission["reward_nation"]]
	reward_label.text = "Recompensa: " + reward_text
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	row.add_child(reward_label)

	if mission["claimed"]:
		var claimed_label = Label.new()
		claimed_label.text = "✅ Resgatada"
		claimed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(claimed_label)
	elif mission["progress"] >= mission["target"]:
		var claim_button = Button.new()
		claim_button.text = "Resgatar!"
		claim_button.pressed.connect(func():
			PlayerProfile.claim_mission_reward(mission["id"])
			if overlay != null:
				overlay.queue_free()  # fecha o antigo antes -- antes empilhava um popup em cima do outro
			_show_missions_popup()  # reabre já atualizado
		)
		row.add_child(claim_button)

	row.add_child(HSeparator.new())
	return row


func _show_updates_popup():
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
	scroll.custom_minimum_size = Vector2(0, 380)
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "📰 Atualizações"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	if UpdateDatabase.all_updates.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nenhuma atualização cadastrada ainda."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_label)
	else:
		for update in UpdateDatabase.all_updates:
			if update == null:
				continue
			vbox.add_child(_build_update_row(update))

	var close_button = Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_button)


func _build_update_row(update: UpdateData) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var header = HBoxContainer.new()
	box.add_child(header)

	var title_label = Label.new()
	title_label.text = "%s -- v%s" % [update.title, update.version] if update.version != "" else update.title
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	if update.date != "":
		var date_label = Label.new()
		date_label.text = update.date
		date_label.add_theme_font_size_override("font_size", 11)
		header.add_child(date_label)

	var desc_label = Label.new()
	desc_label.text = update.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc_label)

	box.add_child(HSeparator.new())
	return box


# botão de sair do jogo -- conecta o "pressed" desse botão nessa função
func _on_exit_button_pressed():
	get_tree().quit()
