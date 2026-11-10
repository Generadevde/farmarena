extends Control
## HUB 2.0 -- a tela principal do jogo, com 5 abas (toque embaixo ou arraste
## pro lado):   Feira · Cartas · BATALHA · Troféus · Sítio
## Tudo é montado por código em cima do tema rural (ThemeBuilder).

const STATS_HUB_SCENE = "res://ranking/stats_hub.tscn"
const JOURNAL_SCENE = "res://ranking/journal_menu.tscn"
const CREATOR_SCENE = "res://creator/creator_menu.tscn"
const PROFILE_SCENE = "res://Scenes/profile_setup.tscn"

const TABS = [["🛒", "Feira"], ["🃏", "Cartas"], ["⚔", "Batalha"], ["🏆", "Troféus"], ["🏡", "Sítio"]]
const TOP_H = 92.0
const BAR_H = 104.0

static var last_tab := 2

var _tab := 2
var _pages: Array = []
var _pages_root: Control
var _tab_buttons: Array = []
var _dots: Array = []
var _coins_label: Label
var _trophy_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _name_label: Label
var _swipe_start := Vector2.ZERO
var _swiping := false
var _deck_slot := 0
var _pending_card: CardData = null   # carta escolhida, esperando tocar numa posição do baralho
var _pending_index := -1             # posição do baralho escolhida, esperando tocar numa carta
var _filter_turma := ""
var _refresh_queued := false
var _second_timer := 0.0
var _live_labels: Array = []         # [Label, Callable] -- textos de relógio atualizados a cada segundo


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.game_theme
	_tab = last_tab
	_deck_slot = Progresso.active_deck()
	if MusicPlayer.has_method("play_menu_music"):
		MusicPlayer.play_menu_music()
	_build_shell()
	_rebuild_all()
	Progresso.changed.connect(_queue_refresh)
	PlayerProfile.profile_changed.connect(_refresh_top)
	Progresso.rewards_pending.connect(_defer_pending)
	get_viewport().size_changed.connect(_layout_pages)
	_show_pending.call_deferred()


func _defer_pending():
	_show_pending.call_deferred()


# ================================================================ casca (topo, páginas, abas)
func _build_shell():
	var top = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = TOP_H
	add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	var lv_box = VBoxContainer.new()
	lv_box.custom_minimum_size.x = 150
	row.add_child(lv_box)
	_level_label = _label("", 20, ThemeBuilder.COLOR_GOLD)
	lv_box.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(140, 14)
	lv_box.add_child(_xp_bar)
	_name_label = _label("", 20)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	row.add_child(_name_label)
	var right = VBoxContainer.new()
	row.add_child(right)
	_coins_label = _label("", 20, ThemeBuilder.COLOR_GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_coins_label)
	_trophy_label = _label("", 20)
	_trophy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_trophy_label)

	var clip = Control.new()
	clip.clip_contents = true
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.offset_top = TOP_H
	clip.offset_bottom = -BAR_H
	add_child(clip)
	_pages_root = Control.new()
	clip.add_child(_pages_root)
	for i in TABS.size():
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_pages_root.add_child(scroll)
		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 12)
		var margin = MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 14)
		margin.add_child(box)
		scroll.add_child(margin)
		_pages.append(box)

	var bar = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR_H
	add_child(bar)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	bar.add_child(tabs)
	for i in TABS.size():
		var b = Button.new()
		b.text = "%s\n%s" % [TABS[i][0], TABS[i][1]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.35 if i == 2 else 1.0
		b.custom_minimum_size.y = BAR_H - 16
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_go_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
		var dot = ColorRect.new()
		dot.color = Color("#f04038")
		dot.size = Vector2(16, 16)
		dot.position = Vector2(8, 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		b.add_child(dot)
		_dots.append(dot)
	_layout_pages.call_deferred()


func _layout_pages():
	var w = size.x
	var h = size.y - TOP_H - BAR_H
	for i in _pages_root.get_child_count():
		var sc: Control = _pages_root.get_child(i)
		sc.position = Vector2(i * w, 0)
		sc.size = Vector2(w, h)
	_pages_root.position.x = -_tab * w
	_style_tabs()


func _go_tab(i: int):
	i = clampi(i, 0, TABS.size() - 1)
	_tab = i
	last_tab = i
	_cancel_placing()
	var tw = create_tween()
	tw.tween_property(_pages_root, "position:x", -i * size.x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_style_tabs()


func _style_tabs():
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == _tab else Color(0.72, 0.68, 0.62)
		_tab_buttons[i].add_theme_font_size_override("font_size", 22 if i == _tab else 18)


# arrastar pro lado troca de aba
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_swipe_start = event.position
			_swiping = event.position.y > TOP_H and event.position.y < size.y - BAR_H and get_tree().get_nodes_in_group("hub_popup").is_empty()
		elif _swiping:
			_swiping = false
			var delta: Vector2 = event.position - _swipe_start
			if absf(delta.x) > 110.0 and absf(delta.x) > absf(delta.y) * 1.8:
				_go_tab(_tab + (-1 if delta.x > 0 else 1))


func _process(delta):
	_second_timer += delta
	if _second_timer >= 0.5:
		_second_timer = 0.0
		for pair in _live_labels:
			if is_instance_valid(pair[0]):
				pair[0].text = pair[1].call()
		_check_chest_ready()


var _ready_state := ""


func _check_chest_ready():
	var state = ""
	for i in Progresso.chests().size():
		state += "1" if Progresso.chest_ready(i) else "0"
	state += "m" if Progresso.mascate_active() else "-"
	if state != _ready_state:
		_ready_state = state
		_queue_refresh()


func _queue_refresh():
	if _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh():
	_refresh_queued = false
	_rebuild_all()


func _rebuild_all():
	_live_labels.clear()
	_refresh_top()
	_build_feira(_clear(_pages[0]))
	_build_cartas(_clear(_pages[1]))
	_build_batalha(_clear(_pages[2]))
	_build_trofeus(_clear(_pages[3]))
	_build_sitio(_clear(_pages[4]))
	_refresh_dots()


func _refresh_top():
	var prog = Progresso.level_progress()
	_level_label.text = "⭐ Nível %d" % Progresso.player_level()
	_xp_bar.max_value = prog[1]
	_xp_bar.value = prog[0]
	_name_label.text = PlayerProfile.player_name
	_coins_label.text = "💰 %d" % PlayerProfile.coins
	_trophy_label.text = "🏆 %d" % ArenaManager.get_trophies(PlayerProfile.player_name)


func _refresh_dots():
	var s = Progresso.shop()
	_dots[0].visible = !s["gratis"] or Progresso.mascate_active()
	var up = false
	for c in Progresso.owned_cards():
		if Progresso.can_upgrade(c) or Progresso.is_new(c):
			up = true
			break
	_dots[1].visible = up
	var chest_ready = false
	for i in Progresso.chests().size():
		if Progresso.chest_ready(i):
			chest_ready = true
	var mission_ready = false
	for m in PlayerProfile.daily_missions:
		if !m["claimed"] and m["progress"] >= m["target"]:
			mission_ready = true
	_dots[2].visible = chest_ready or mission_ready
	_dots[3].visible = Progresso.road_claimable() > 0


# ================================================================ ajudantes de interface
func _clear(box: Node) -> Node:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	return box


func _label(text: String, font_size: int = 18, color: Color = ThemeBuilder.COLOR_CREAM) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _title(text: String) -> Label:
	var l = _label(text, 26, ThemeBuilder.COLOR_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _wrap(text: String, font_size: int = 17, color: Color = ThemeBuilder.COLOR_CREAM) -> Label:
	var l = _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, on_press: Callable, font_size: int = 20) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size.y = 56
	b.pressed.connect(on_press)
	return b


func _panel(parent: Node) -> VBoxContainer:
	var p = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func _grid(parent: Node, cols: int) -> GridContainer:
	var g = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(g)
	return g


static func _clock(seconds: float) -> String:
	var s = int(ceil(seconds))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


func _live(label: Control, fn: Callable):
	label.text = fn.call()
	_live_labels.append([label, fn])


# ================================================================ ABA: BATALHA
func _build_batalha(box: Node):
	var arena_i = ArenaManager.get_player_arena()
	var info = ArenaManager.get_arena_info(arena_i)
	box.add_child(_title("%s %s" % [info.get("emoji", ""), info.get("name", "Arena")]))
	var streak = int(Progresso.d["streak"])
	if streak >= 2:
		var sl = _label("🔥 %d vitórias seguidas%s" % [streak, " -- próximo baú vem melhor!" if streak >= 3 else ""], 18, Color(1, 0.65, 0.3))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sl)

	# baralho ativo
	var deck_panel = _panel(box)
	var head = HBoxContainer.new()
	deck_panel.add_child(head)
	var dl = _label("Baralho %d  ·  custo médio %.0f" % [Progresso.active_deck() + 1, Progresso.deck_average_cost(Progresso.active_deck())], 17)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(dl)
	for i in Progresso.DECK_SLOTS:
		var b = _button(str(i + 1), _pick_active_deck.bind(i), 18)
		b.custom_minimum_size = Vector2(52, 44)
		b.modulate = Color(1, 1, 1) if i == Progresso.active_deck() else Color(0.65, 0.62, 0.58)
		head.add_child(b)
	var g = _grid(deck_panel, 7)
	g.add_theme_constant_override("h_separation", 4)
	for c in Progresso.deck_cards(Progresso.active_deck()):
		var v = CardView.make(c, 88)
		v.tapped.connect(_show_card_popup)
		g.add_child(v)

	var battle = _button("⚔  BATALHAR", _start_battle, 34)
	battle.custom_minimum_size.y = 110
	battle.modulate = Color(1.0, 0.92, 0.6)
	box.add_child(battle)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var b2 = _button("👥 2 contra 2", _start_2v2)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b2)
	var pending = 0
	for m in PlayerProfile.daily_missions:
		if !m["claimed"] and m["progress"] >= m["target"]:
			pending += 1
	var bm = _button("📋 Missões" + (" (%d!)" % pending if pending > 0 else ""), _show_missions)
	bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bm)

	# baús de colheita
	var chest_panel = _panel(box)
	chest_panel.add_child(_label("🎁 Baús de colheita  (vença pra ganhar · cada partida adianta 1 min)", 15, ThemeBuilder.COLOR_STAT_LABEL))
	var crow = HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	chest_panel.add_child(crow)
	for i in Progresso.CHEST_SLOTS:
		crow.add_child(_chest_slot(i))

	# carta do dia
	var cod = Catalogo.find_card(Progresso.card_of_the_day_path())
	if cod != null:
		var cp = _panel(box)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		cp.add_child(h)
		var cv = CardView.make(cod, 84)
		cv.tapped.connect(_show_card_popup)
		h.add_child(cv)
		h.add_child(_wrap("⭐ Carta do dia: %s\nHoje ela ganha MAESTRIA EM DOBRO cada vez que você jogar." % cod.card_name, 17))


func _chest_slot(i: int) -> Control:
	var b = Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 150
	b.add_theme_font_size_override("font_size", 16)
	var list = Progresso.chests()
	if i >= list.size():
		b.text = "vazio"
		b.disabled = true
		return b
	var def = Progresso.CHESTS[int(list[i]["tipo"])]
	var col = Color.html(def["cor"])
	var art = ChestArt.new()
	art.color = col
	art.anchor_left = 0.5
	art.anchor_right = 0.5
	art.offset_left = -36
	art.offset_right = 36
	art.offset_top = 10
	art.offset_bottom = 74
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var name_text = "\n\n\n%s\n" % def["nome"]
	if Progresso.chest_ready(i):
		b.text = name_text + "ABRIR!"
		b.modulate = Color(1.0, 1.0, 0.7)
		art.bouncing = true
		b.pressed.connect(_open_chest.bind(i))
	elif Progresso.unlocking_index() == i:
		_live(b, func(): return name_text + "⏳ " + _clock(Progresso.chest_remaining(i)))
		b.pressed.connect(_toast.bind("Abrindo... cada partida jogada adianta 1 minuto."))
	else:
		b.text = name_text + "tocar pra abrir (%s)" % _clock(def["tempo"])
		if Progresso.unlocking_index() == -1:
			b.pressed.connect(_start_chest.bind(i))
		else:
			b.pressed.connect(_toast.bind("Só um baú abre por vez."))
	return b


func _start_chest(i: int):
	Progresso.start_chest(i)


func _open_chest(i: int):
	var def = Progresso.CHESTS[int(Progresso.chests()[i]["tipo"])]
	var loot = Progresso.open_chest(i)
	if !loot.is_empty():
		_show_loot(def["nome"], loot, Color.html(def["cor"]))


func _pick_active_deck(i: int):
	_deck_slot = i
	Progresso.set_active_deck(i)


func _start_battle():
	MatchSetup.start_1v1(get_tree())


func _start_2v2():
	MatchSetup.start_2v2(get_tree())


# ================================================================ ABA: CARTAS
func _build_cartas(box: Node):
	# baralhos
	var deck_panel = _panel(box)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	deck_panel.add_child(head)
	for i in Progresso.DECK_SLOTS:
		var b = _button("Baralho %d" % (i + 1), _view_deck.bind(i), 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color(1, 1, 1) if i == _deck_slot else Color(0.62, 0.6, 0.56)
		head.add_child(b)
	var is_active = _deck_slot == Progresso.active_deck()
	var info = HBoxContainer.new()
	deck_panel.add_child(info)
	var il = _label("Custo médio %.0f%s" % [Progresso.deck_average_cost(_deck_slot), "  ·  EM USO" if is_active else ""], 16, ThemeBuilder.COLOR_STAT_LABEL)
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(il)
	if !is_active:
		info.add_child(_button("Usar este", _pick_active_deck.bind(_deck_slot), 16))
	var g = _grid(deck_panel, 7)
	g.add_theme_constant_override("h_separation", 4)
	var deck = Progresso.deck_cards(_deck_slot)
	for i in deck.size():
		var v = CardView.make(deck[i], 88)
		v.set_selected(_pending_card != null or _pending_index == i)
		v.tapped.connect(_on_deck_slot_tapped.bind(i))
		g.add_child(v)
	var hint = "Toque numa carta do baralho pra trocar, ou numa carta da coleção pra ver/usar."
	if _pending_card != null:
		hint = "👉 Toque na posição do baralho onde %s vai entrar." % _pending_card.card_name
	elif _pending_index != -1:
		hint = "👉 Agora toque na carta da coleção que vai entrar no lugar."
	deck_panel.add_child(_wrap(hint, 15, Color(1, 0.9, 0.6) if (_pending_card != null or _pending_index != -1) else ThemeBuilder.COLOR_STAT_LABEL))
	if _pending_card != null or _pending_index != -1:
		deck_panel.add_child(_button("Cancelar troca", _cancel_placing_and_refresh, 16))

	# filtro por turma
	var chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	box.add_child(chips)
	var all_b = _button("Todas", _set_filter.bind(""), 15)
	all_b.custom_minimum_size.y = 44
	all_b.modulate = Color(1, 1, 1) if _filter_turma == "" else Color(0.62, 0.6, 0.56)
	chips.add_child(all_b)
	for n in CustomContent.all_nations():
		if n == null:
			continue
		var cb = _button(n.nation_name, _set_filter.bind(n.nation_name), 15)
		cb.custom_minimum_size.y = 44
		cb.modulate = n.color.lightened(0.35) if _filter_turma == n.nation_name else Color(0.62, 0.6, 0.56)
		chips.add_child(cb)

	var owned: Array = []
	var missing: Array = []
	for c in CardDatabase.all_cards:
		if c == null or CustomContent.is_spawn_only(c):
			continue
		if _filter_turma != "" and c.get_nation_name() != _filter_turma:
			continue
		if Progresso.is_owned(c):
			owned.append(c)
		else:
			missing.append(c)
	owned.sort_custom(func(a, b): return a.cost < b.cost if a.cost != b.cost else a.card_name < b.card_name)
	missing.sort_custom(func(a, b): return a.unlock_arena < b.unlock_arena if a.unlock_arena != b.unlock_arena else a.cost < b.cost)

	box.add_child(_title("Coleção  %d/%d" % [owned.size(), owned.size() + missing.size()]))
	var og = _grid(box, 5)
	for c in owned:
		var v = CardView.make(c, 128)
		if Progresso.is_new(c):
			v.badge = "NOVA!"
			v.badge_color = Color(0.5, 1, 0.6)
		elif Progresso.can_upgrade(c):
			v.badge = "⬆ SUBIR"
			v.badge_color = Color(0.5, 1, 0.6)
		elif Progresso.copies_needed(c) > 0:
			v.badge = "%d/%d" % [Progresso.copies(c), Progresso.copies_needed(c)]
		else:
			v.badge = "MÁX"
		v.tapped.connect(_on_collection_tapped)
		og.add_child(v)
	if !missing.is_empty():
		box.add_child(_title("Ainda não encontradas"))
		var mg = _grid(box, 5)
		var arena_now = ArenaManager.get_player_arena()
		for c in missing:
			var v = CardView.make(c, 128)
			v.locked = c.unlock_arena > arena_now - 1
			v.show_level = false
			v.badge = "Arena %d" % (c.unlock_arena + 1) if v.locked else "nos baús"
			v.tapped.connect(_show_card_popup)
			mg.add_child(v)

	# torres
	box.add_child(_title("Sua torre"))
	var tg = _grid(box, 4)
	var equipped = PlayerProfile.get_equipped_base()
	for b in BotSimulator.available_bases:
		if b == null:
			continue
		var unlocked = PlayerProfile.is_base_unlocked(b)
		var tb = Button.new()
		tb.custom_minimum_size = Vector2(160, 190)
		tb.icon = b.icon
		tb.expand_icon = true
		tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tb.text = b.base_name + ("\n✔ em uso" if b == equipped else ("" if unlocked else "\n🔒 Arena %d" % (b.unlock_arena + 1)))
		tb.add_theme_font_size_override("font_size", 14)
		tb.modulate = Color(1, 1, 1) if unlocked else Color(0.5, 0.5, 0.5)
		tb.pressed.connect(_show_base_popup.bind(b))
		tg.add_child(tb)


func _view_deck(i: int):
	_deck_slot = i
	_cancel_placing()
	_queue_refresh()


func _set_filter(turma: String):
	_filter_turma = turma
	_queue_refresh()


func _cancel_placing():
	_pending_card = null
	_pending_index = -1


func _cancel_placing_and_refresh():
	_cancel_placing()
	_queue_refresh()


func _on_deck_slot_tapped(_card, index: int):
	if _pending_card != null:
		Progresso.set_deck_card(_deck_slot, index, _pending_card)
		_cancel_placing()
		_queue_refresh()
		return
	_pending_index = -1 if _pending_index == index else index
	_queue_refresh()


func _on_collection_tapped(card: CardData):
	if _pending_index != -1:
		Progresso.set_deck_card(_deck_slot, _pending_index, card)
		_cancel_placing()
		_queue_refresh()
		return
	_show_card_popup(card)


# ---------------------------------------------------------------- popup de carta
func _popup(min_width: float = 600.0) -> VBoxContainer:
	var overlay = CanvasLayer.new()
	overlay.layer = 50
	overlay.add_to_group("hub_popup")
	add_child(overlay)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = ThemeBuilder.game_theme
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.set_meta("overlay", overlay)
	return v


func _close(v: Node):
	var overlay = v.get_meta("overlay")
	if is_instance_valid(overlay):
		overlay.queue_free()


func _show_card_popup(card: CardData):
	if card == null:
		return
	var owned = Progresso.is_owned(card)
	Progresso.clear_new(card)
	var v = _popup()
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var cv = CardView.make(card, 200)
	cv.locked = false
	cv.show_level = owned
	head.add_child(cv)
	var side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(side)
	side.add_child(_wrap(card.card_name, 26, ThemeBuilder.COLOR_GOLD))
	var rarity = Catalogo.rarity_of(card)
	side.add_child(_label("%s  ·  %s" % [Catalogo.RARITY_NAMES[rarity], card.get_nation_name() if card.get_nation_name() != "" else "Coringa"], 17, Catalogo.RARITY_COLORS[rarity]))
	side.add_child(_label("%s  ·  custo %d" % [CardData.role_name(card.role), card.cost], 17))
	if card.description != "":
		side.add_child(_wrap("“%s”" % card.description, 16, Color(0.95, 0.9, 0.78)))

	# números
	var lv = Progresso.level(card)
	var mult = PlayerProfile.compute_stat_multiplier(lv)
	var stats_text = _stats_text(card, mult)
	if stats_text != "":
		v.add_child(_wrap(stats_text, 17))
	for p in card.pros:
		v.add_child(_wrap("✔ " + p, 16, Color(0.6, 1.0, 0.6)))
	for p in card.cons:
		v.add_child(_wrap("✖ " + p, 16, Color(1.0, 0.62, 0.55)))

	if owned:
		# nível
		var need = Progresso.copies_needed(card)
		if need > 0:
			var bar = ProgressBar.new()
			bar.max_value = need
			bar.value = mini(Progresso.copies(card), need)
			bar.show_percentage = false
			bar.custom_minimum_size.y = 22
			v.add_child(bar)
			var up = _button("⬆ Subir pro nível %d   (%d/%d cópias · 💰 %d)" % [lv + 1, Progresso.copies(card), need, Progresso.upgrade_cost(card)], _upgrade.bind(card, v), 18)
			up.disabled = !Progresso.can_upgrade(card)
			v.add_child(up)
		else:
			v.add_child(_label("Nível máximo!", 18, ThemeBuilder.COLOR_GOLD))
		# maestria
		var mp = Progresso.mastery_progress(card)
		var m = Progresso.mastery(card)
		var mtext = "Maestria: %s" % (Progresso.MASTERY_NAMES[m] if m > 0 else "nenhuma ainda")
		mtext += "  ·  usada %d vezes" % mp[0]
		if mp[1] > 0:
			mtext += "  (próxima borda com %d)" % mp[1]
		v.add_child(_wrap(mtext, 15, Progresso.MASTERY_COLORS[m] if m > 0 else ThemeBuilder.COLOR_STAT_LABEL))
		if !Progresso.deck_paths(_deck_slot).has(card.resource_path):
			v.add_child(_button("Colocar no Baralho %d" % (_deck_slot + 1), _begin_place.bind(card, v)))
	else:
		v.add_child(_wrap("Você ainda não tem esta carta. Ela aparece nos baús e na Feira a partir da Arena %d." % (card.unlock_arena + 1), 16, Color(1, 0.85, 0.5)))
	v.add_child(_button("Fechar", _close.bind(v)))


func _stats_text(card: CardData, mult: float) -> String:
	if card.is_spell():
		var sp = card.spell_data
		var parts: Array = ["Área %d" % int(sp.radius)]
		if sp.damage > 0:
			parts.append("Dano %d" % int(round(sp.damage * mult)))
		if sp.heal_amount > 0:
			parts.append("Cura %d" % int(sp.heal_amount))
		if sp.duration > 0:
			parts.append("Dura %.0fs" % sp.duration)
		if sp.shield_amount > 0:
			parts.append("Escudo %d" % sp.shield_amount)
		if sp.summon_count > 0:
			parts.append("Invoca %d" % sp.summon_count)
		return "  ·  ".join(parts)
	var st = DeckBuilder.get_unit_stats(card)
	if st == null:
		return ""
	var parts2: Array = ["❤ %d" % int(round(st.hp * mult))]
	if st.damage > 0:
		parts2.append("⚔ %d" % int(round(st.damage * mult)))
		if st.attack_speed > 0:
			parts2.append("a cada %.1fs" % st.attack_speed)
	if st.move_speed > 0:
		parts2.append("👟 %d" % int(st.move_speed))
	if st.is_ranged:
		parts2.append("🎯 %d" % int(st.attack_range))
	if st.unit_count > 1:
		parts2.append("x%d" % st.unit_count)
	for comp in card.companions:
		parts2.append("+%d acompanhante(s)" % int(comp["count"]))
	if st.unit_type == UnitData.UnitType.AIR:
		parts2.append("voa")
	if st.unit_type == UnitData.UnitType.BUILDING:
		parts2.append("construção")
	return "  ·  ".join(parts2)


func _upgrade(card: CardData, popup_box: Node):
	if Progresso.upgrade(card):
		_close(popup_box)
		_toast("%s subiu pro nível %d!" % [card.card_name, Progresso.level(card)])
		_show_card_popup.call_deferred(card)


func _begin_place(card: CardData, popup_box: Node):
	_close(popup_box)
	_pending_card = card
	_pending_index = -1
	if _tab != 1:
		_go_tab(1)
		_pending_card = card
	_queue_refresh()
	_pages_root.get_child(1).scroll_vertical = 0


func _show_base_popup(b: BaseData):
	var v = _popup()
	var tr = TextureRect.new()
	tr.texture = b.icon
	tr.custom_minimum_size = Vector2(192, 192)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(tr)
	v.add_child(_title(b.base_name))
	if b.description != "":
		v.add_child(_wrap("“%s”" % b.description, 16))
	v.add_child(_label("❤ %d por torre (são 2)" % int(round(b.base_hp * ArenaBuilder.TOWER_HP_FRACTION)), 17))
	for p in b.pros:
		v.add_child(_wrap("✔ " + p, 16, Color(0.6, 1.0, 0.6)))
	for p in b.cons:
		v.add_child(_wrap("✖ " + p, 16, Color(1.0, 0.62, 0.55)))
	if PlayerProfile.is_base_unlocked(b):
		if PlayerProfile.get_equipped_base() != b:
			v.add_child(_button("Usar esta torre", _equip_base.bind(b, v)))
	else:
		v.add_child(_wrap("🔒 Libera quando você chegar na Arena %d." % (b.unlock_arena + 1), 16, Color(1, 0.85, 0.5)))
	v.add_child(_button("Fechar", _close.bind(v)))


func _equip_base(b: BaseData, popup_box: Node):
	PlayerProfile.set_equipped_base(b)
	_close(popup_box)
	_queue_refresh()


# ================================================================ ABA: FEIRA
func _build_feira(box: Node):
	var s = Progresso.shop()
	box.add_child(_title("🛒 Feira da Roça"))
	var gift = _button("🎁 Presente do dia -- PEGAR!" if !s["gratis"] else "🎁 Presente de hoje já foi. Volta amanhã!", _claim_gift, 20)
	gift.disabled = s["gratis"]
	if !s["gratis"]:
		gift.modulate = Color(1, 1, 0.7)
	box.add_child(gift)

	if Progresso.mascate_active():
		var mp = _panel(box)
		var t = _label("", 20, Color(0.9, 0.72, 1.0))
		_live(t, func(): return "🧳 O MASCATE está na cidade!  vai embora em " + _clock(Progresso.mascate_seconds_left()))
		mp.add_child(t)
		mp.add_child(_wrap("“Tudo original, confia. Caiu do caminhão ontem.”", 15, Color(0.95, 0.9, 0.78)))
		var mg = _grid(mp, 3)
		for offer in Progresso.mascate_offers():
			mg.add_child(_offer_widget(offer, true))
		var left = Progresso.mascate_surprises_left()
		var sb = _button("📦 Caixa Surpresa  💰 %d   (restam %d)" % [Progresso.SURPRISE_PRICE, left], _buy_surprise, 18)
		sb.disabled = left <= 0 or PlayerProfile.coins < Progresso.SURPRISE_PRICE
		mp.add_child(sb)

	var op = _panel(box)
	op.add_child(_label("Ofertas de hoje (mudam todo dia)", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(op, 3)
	for offer in s["ofertas"]:
		g.add_child(_offer_widget(offer, false))

	var cp = _panel(box)
	cp.add_child(_label("Baús à venda (1 de cada por dia)", 17, ThemeBuilder.COLOR_STAT_LABEL))
	for i in Progresso.SHOP_CHESTS.size():
		var def = Progresso.CHESTS[Progresso.SHOP_CHESTS[i][0]]
		var price = Progresso.SHOP_CHESTS[i][1]
		var b = _button("%s  ·  %d cartas  ·  💰 %d" % [def["nome"], def["cartas"], price] if !s["baus"][i] else "%s -- vendido" % def["nome"], _buy_chest.bind(i), 19)
		b.disabled = s["baus"][i] or PlayerProfile.coins < price
		cp.add_child(b)


func _offer_widget(offer: Dictionary, special: bool) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var c = Catalogo.find_card(str(offer["path"]))
	if c == null:
		return box
	var v = CardView.make(c, 190)
	v.show_level = Progresso.is_owned(c)
	if offer["vendido"]:
		v.badge = "comprado"
	elif !Progresso.is_owned(c):
		v.badge = "CARTA NOVA"
		v.badge_color = Color(0.5, 1, 0.6)
	else:
		v.badge = "x%d" % int(offer["qtd"])
	v.tapped.connect(_show_card_popup)
	box.add_child(v)
	var b = _button(("-50%%  💰 %d" if special else "💰 %d") % int(offer["preco"]), _buy_offer.bind(offer), 18)
	b.disabled = offer["vendido"] or PlayerProfile.coins < int(offer["preco"])
	box.add_child(b)
	return box


func _buy_offer(offer: Dictionary):
	var result = Progresso.buy_offer(offer)
	if !result.is_empty():
		_show_loot("Compra feita!", [result], ThemeBuilder.COLOR_GOLD)


func _claim_gift():
	var loot = Progresso.claim_daily_gift()
	if !loot.is_empty():
		_show_loot("Presente do dia", loot, Color("#d8b060"))


func _buy_chest(i: int):
	var def = Progresso.CHESTS[Progresso.SHOP_CHESTS[i][0]]
	var loot = Progresso.buy_shop_chest(i)
	if !loot.is_empty():
		_show_loot(def["nome"], loot, Color.html(def["cor"]))


func _buy_surprise():
	var result = Progresso.buy_surprise()
	if !result.is_empty():
		_show_loot("📦 " + str(result.get("fala", "Caixa Surpresa")), [result], Color(0.9, 0.72, 1.0))


# ================================================================ ABA: TROFÉUS
func _build_trofeus(box: Node):
	var mine = ArenaManager.get_trophies(PlayerProfile.player_name)
	box.add_child(_title("🏆 Caminho dos Troféus"))
	var arena_i = ArenaManager.get_player_arena()
	var next_text = "Você chegou no topo!"
	if arena_i < ArenaManager.max_arena:
		var next_info = ArenaManager.get_arena_info(arena_i + 1)
		next_text = "Faltam %d troféus pra %s %s" % [int(next_info["trophy_threshold"]) - mine, next_info.get("emoji", ""), next_info.get("name", "")]
	var nl = _label(next_text, 17, ThemeBuilder.COLOR_STAT_LABEL)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nl)
	box.add_child(_button("📊 Ranking e estatísticas", _goto.bind(STATS_HUB_SCENE), 18))

	var last_arena = 1
	var shown_locked = 0
	for m in Progresso.road_milestones():
		var a = ArenaManager.get_arena_for_trophies(int(m["trofeus"]))
		if a != last_arena:
			last_arena = a
			_arena_divider(box, a)
		if !m["liberado"]:
			shown_locked += 1
			if shown_locked > 6:
				continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var tl = _label("🏆 %d" % int(m["trofeus"]), 19, ThemeBuilder.COLOR_GOLD if m["liberado"] else Color(0.6, 0.58, 0.55))
		tl.custom_minimum_size.x = 120
		row.add_child(tl)
		var reward: Dictionary = m["premio"]
		var rtext = "💰 %d de ouro" % int(reward["ouro"]) if reward["tipo"] == "ouro" else "🎁 " + Progresso.CHESTS[int(reward["bau"])]["nome"]
		var rl = _label(rtext, 18)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		if m["pego"]:
			row.add_child(_label("✔", 20, Color(0.6, 1, 0.6)))
		elif m["liberado"]:
			var b = _button("PEGAR", _claim_road.bind(int(m["trofeus"])), 18)
			b.modulate = Color(1, 1, 0.7)
			row.add_child(b)
		else:
			row.add_child(_label("🔒", 20))
	if arena_i == 1 and last_arena == 1:
		_arena_divider(box, 2)


func _arena_divider(box: Node, arena_i: int):
	var info = ArenaManager.get_arena_info(arena_i)
	var p = _panel(box)
	p.add_child(_title("%s %s  ·  %d troféus" % [info.get("emoji", ""), info.get("name", ""), int(info.get("trophy_threshold", 0))]))
	var unlocks: Array = []
	for c in CardDatabase.all_cards:
		if c != null and c.unlock_arena == arena_i - 1 and !CustomContent.is_spawn_only(c):
			unlocks.append(c)
	if unlocks.is_empty():
		return
	p.add_child(_label("Cartas que começam a aparecer aqui:", 15, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(p, 7)
	g.add_theme_constant_override("h_separation", 4)
	var reached = ArenaManager.get_player_arena() >= arena_i
	for c in unlocks:
		var v = CardView.make(c, 86)
		v.locked = !reached and !Progresso.is_owned(c)
		v.show_level = false
		v.tapped.connect(_show_card_popup)
		g.add_child(v)
	for b in BotSimulator.available_bases:
		if b != null and b.unlock_arena == arena_i - 1 and arena_i > 1:
			p.add_child(_label("🏰 Torre nova: %s" % b.base_name, 16, Color(0.7, 0.9, 1.0)))


func _claim_road(trophies: int):
	var loot = Progresso.claim_road(trophies)
	if !loot.is_empty():
		_show_loot("Prêmio dos %d troféus" % trophies, loot, ThemeBuilder.COLOR_GOLD)


# ================================================================ ABA: SÍTIO
func _build_sitio(box: Node):
	box.add_child(_title("🏡 Seu Sítio"))
	var p = _panel(box)
	var rate = PlayerProfile.get_win_rate() if PlayerProfile.has_method("get_win_rate") else 0.0
	p.add_child(_label("%s  ·  Nível %d" % [PlayerProfile.player_name, Progresso.player_level()], 20, ThemeBuilder.COLOR_GOLD))
	p.add_child(_label("Partidas: %d  ·  Vitórias: %d  (%.0f%%)" % [PlayerProfile.total_battles_played, PlayerProfile.total_battles_won, rate * (100.0 if rate <= 1.0 else 1.0)], 17))
	p.add_child(_label("Maior sequência de vitórias: %d" % int(Progresso.d["best_streak"]), 17))
	p.add_child(_label("Temporada %d  ·  faltam %.0f dias" % [SeasonManager.season_number, SeasonManager.get_days_remaining()], 17))

	# mais e menos jogadas da temporada
	var ranking = Progresso.season_ranking()
	var played = ranking.filter(func(e): return e[1] > 0)
	var sp = _panel(box)
	sp.add_child(_label("📈 Suas cartas MAIS jogadas na temporada", 17, ThemeBuilder.COLOR_STAT_LABEL))
	if played.is_empty():
		sp.add_child(_label("Jogue uma partida pra começar a contar.", 16))
	else:
		var g = _grid(sp, 5)
		for e in played.slice(0, 5):
			var v = CardView.make(e[0], 120)
			v.badge = "%dx" % e[1]
			v.tapped.connect(_show_card_popup)
			g.add_child(v)
	var lp = _panel(box)
	lp.add_child(_label("📉 As MENOS jogadas (que tal dar uma chance?)", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var g2 = _grid(lp, 5)
	var least: Array = ranking.duplicate()
	least.reverse()
	for e in least.slice(0, 5):
		var v2 = CardView.make(e[0], 120)
		v2.badge = "%dx" % e[1]
		v2.badge_color = Color(0.8, 0.8, 0.8)
		v2.tapped.connect(_show_card_popup)
		g2.add_child(v2)

	box.add_child(_button("📊 Ranking, temporada e estatísticas", _goto.bind(STATS_HUB_SCENE)))
	box.add_child(_button("📰 Jornal da Roça", _goto.bind(JOURNAL_SCENE)))
	box.add_child(_button("🎨 Criador (cartas, torres, arenas)", _goto.bind(CREATOR_SCENE)))
	box.add_child(_button("🌱 Safra (cartas novas automáticas)", _show_safra))
	box.add_child(_button("👤 Trocar de perfil", _goto.bind(PROFILE_SCENE)))
	box.add_child(_button("Sair do jogo", get_tree().quit))


func _goto(scene: String):
	if ResourceLoader.exists(scene):
		get_tree().change_scene_to_file(scene)
	else:
		_toast("Tela não encontrada.")


func _show_safra():
	var v = _popup()
	v.add_child(_title("🌱 Safra"))
	if get_node_or_null("/root/Safra") != null:
		var safra = get_node("/root/Safra")
		v.add_child(_wrap(safra.status_text(), 17))
		for c in safra.current_cards():
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			v.add_child(row)
			var cv = CardView.make(c, 110)
			cv.show_level = Progresso.is_owned(c)
			cv.tapped.connect(_show_card_popup)
			row.add_child(cv)
			row.add_child(_wrap("%s\n%s · custo %d" % [c.card_name, CardData.role_name(c.role), c.cost], 16))
	else:
		v.add_child(_wrap("A cada 3 dias o sítio colhe 2 cartas novas e 1 missão especial. Em breve!", 17))
	v.add_child(_button("Fechar", _close.bind(v)))


# ================================================================ missões
func _show_missions():
	PlayerProfile._check_and_reset_daily_missions()
	var v = _popup()
	v.add_child(_title("📋 Missões do dia"))
	for m in PlayerProfile.daily_missions:
		var p = _panel(v)
		p.add_child(_wrap(str(m["description"]), 17))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		p.add_child(row)
		var bar = ProgressBar.new()
		bar.max_value = m["target"]
		bar.value = mini(int(m["progress"]), int(m["target"]))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 20)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		row.add_child(_label("%d/%d" % [mini(int(m["progress"]), int(m["target"])), int(m["target"])], 16))
		var is_coins = int(m["reward_type"]) == MissionData.RewardType.COINS
		var reward_text = ("💰 %d" if is_coins else "⭐ %d XP") % int(m["reward_amount"])
		if m["claimed"]:
			row.add_child(_label("✔ " + reward_text, 16, Color(0.6, 1, 0.6)))
		elif m["progress"] >= m["target"]:
			var b = _button("PEGAR " + reward_text, _claim_mission.bind(str(m["id"]), v), 16)
			b.modulate = Color(1, 1, 0.7)
			row.add_child(b)
		else:
			row.add_child(_label(reward_text, 16, ThemeBuilder.COLOR_GOLD))
	v.add_child(_button("Fechar", _close.bind(v)))


func _claim_mission(id: String, popup_box: Node):
	if PlayerProfile.claim_mission_reward(id):
		_close(popup_box)
		_queue_refresh()
		_show_missions.call_deferred()


# ================================================================ prêmios
func _show_pending():
	if !get_tree().get_nodes_in_group("hub_popup").is_empty():
		return
	var list = Progresso.pop_pending()
	for r in list:
		match str(r.get("tipo", "")):
			"nivel":
				_show_loot("⬆ NÍVEL %d!" % int(r["nivel"]), [{"tipo": "ouro", "ouro": int(r["ouro"])}], Color(0.5, 1, 0.6))
			"bau":
				_show_loot("🎁 " + Progresso.CHESTS[int(r["bau"])]["nome"], r["itens"], Color.html(Progresso.CHESTS[int(r["bau"])]["cor"]))
			"maestria":
				var c = Catalogo.find_card(str(r["path"]))
				if c != null:
					_show_loot("✨ Maestria %s!" % Progresso.MASTERY_NAMES[int(r["nivel"])], [{"tipo": "carta", "path": c.resource_path, "qtd": 0, "nova": false, "ouro": 0}], Progresso.MASTERY_COLORS[int(r["nivel"])])


func _show_loot(title_text: String, loot: Array, color: Color):
	var v = _popup(640)
	var t = _title(title_text)
	t.add_theme_color_override("font_color", color.lightened(0.2))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var art = ChestArt.new()
	art.color = color
	art.bouncing = true
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var g = _grid(v, 4)
	var delay = 0.15
	for item in loot:
		var w: Control
		if str(item.get("tipo", "")) == "ouro":
			var b = VBoxContainer.new()
			b.custom_minimum_size = Vector2(140, 150)
			b.alignment = BoxContainer.ALIGNMENT_CENTER
			var coin = _label("💰", 54)
			coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_child(coin)
			var amt = _label("+%d" % int(item["ouro"]), 24, ThemeBuilder.COLOR_GOLD)
			amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_child(amt)
			w = b
		else:
			var c = Catalogo.find_card(str(item["path"]))
			if c == null:
				continue
			var cv = CardView.make(c, 140)
			if item.get("nova", false):
				cv.badge = "NOVA!"
				cv.badge_color = Color(0.5, 1, 0.6)
			elif int(item.get("ouro", 0)) > 0:
				cv.badge = "máx: +💰%d" % int(item["ouro"])
			elif int(item.get("qtd", 0)) > 0:
				cv.badge = "x%d" % int(item["qtd"])
			w = cv
		w.modulate.a = 0.0
		g.add_child(w)
		var tw = w.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(w, "modulate:a", 1.0, 0.18)
		delay += 0.14
	v.add_child(_button("Boa!", _close_loot.bind(v), 22))


func _close_loot(v: Node):
	_close(v)
	_queue_refresh()
	_show_pending.call_deferred()


func _toast(text: String):
	var l = _label(text, 19, Color(1, 0.95, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var p = PanelContainer.new()
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.custom_minimum_size.x = 560
	p.position = Vector2(size.x * 0.5 - 280, size.y - BAR_H - 110)
	p.z_index = 100
	add_child(p)
	var tw = p.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ================================================================ desenho do baú
class ChestArt extends Control:
	var color := Color("#b87840")
	var bouncing := false
	var _t := 0.0

	func _init():
		custom_minimum_size = Vector2(72, 64)

	func _process(delta):
		if bouncing:
			_t += delta
			queue_redraw()

	func _draw():
		var off = Vector2(0, -absf(sin(_t * 5.0)) * 6.0) if bouncing else Vector2.ZERO
		var dark = color.darkened(0.35)
		var out = Color("#2a1a22")
		draw_rect(Rect2(off + Vector2(4, 22), Vector2(64, 40)), out)
		draw_rect(Rect2(off + Vector2(7, 25), Vector2(58, 34)), color)
		draw_rect(Rect2(off + Vector2(7, 45), Vector2(58, 14)), dark)
		draw_rect(Rect2(off + Vector2(2, 8), Vector2(68, 20)), out)
		draw_rect(Rect2(off + Vector2(5, 11), Vector2(62, 14)), color.lightened(0.18))
		draw_rect(Rect2(off + Vector2(5, 11), Vector2(62, 4)), color.lightened(0.4))
		for x in [16.0, 52.0]:
			draw_rect(Rect2(off + Vector2(x, 11), Vector2(5, 48)), dark)
		draw_rect(Rect2(off + Vector2(29, 20), Vector2(14, 16)), out)
		draw_rect(Rect2(off + Vector2(31, 22), Vector2(10, 12)), Color("#ffd23c"))
		draw_rect(Rect2(off + Vector2(34, 26), Vector2(4, 5)), out)
