extends Control
## HUB 2.0 -- a tela principal do jogo, com 5 abas (toque embaixo ou arraste
## pro lado):   Feira · Cartas · BATALHA · Troféus · Sítio
## Tudo é montado por código em cima do tema rural (ThemeBuilder).

const JOURNAL_SCENE = "res://ranking/journal_menu.tscn"
const CREATOR_SCENE = "res://creator/creator_menu.tscn"
const PROFILE_SCENE = "res://Scenes/profile_setup.tscn"

const TABS = [["🛒", "Feira"], ["🃏", "Cartas"], ["⚔", "Batalha"], ["🏆", "Troféus"], ["🛡", "Clã"], ["🏡", "Sítio"]]
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
	MatchSetup.clear_special()
	Progresso._apply_active_deck()   # devolve o seu baralho (o Desafio do Dia empresta outro)
	Safra.sync_profile()
	Assembleia.sync()
	if int(Progresso.d.get("bots_arena_v", 0)) < 2:
		Progresso.d["bots_arena_v"] = 2
		BotLearning.enforce_arena_everywhere()
		Progresso.save()
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
	var gear = _button("⚙", _show_settings, 24)
	gear.add_theme_font_override("font", ThemeDB.fallback_font)
	gear.custom_minimum_size = Vector2(60, 54)
	row.add_child(gear)
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
		scroll.add_child(ScrollGlide.new())
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

	# doca do baralho: fica PRESA no topo da aba Cartas (não rola junto)
	_deck_dock = PanelContainer.new()
	var dsb = StyleBoxFlat.new()
	dsb.bg_color = Color("#3a2618")
	dsb.border_color = Color("#1e120a")
	dsb.border_width_bottom = 4
	dsb.content_margin_left = 10
	dsb.content_margin_right = 10
	dsb.content_margin_top = 8
	dsb.content_margin_bottom = 8
	_deck_dock.add_theme_stylebox_override("panel", dsb)
	_deck_dock.theme = ThemeBuilder.game_theme
	_pages_root.add_child(_deck_dock)

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
		b.add_theme_font_size_override("font_size", 17)
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


func _w() -> float:
	return get_viewport_rect().size.x


func _layout_pages():
	size = get_viewport_rect().size
	var w = _w()
	var h = size.y - TOP_H - BAR_H
	if is_instance_valid(_deck_dock):
		_deck_dock.position = Vector2(w, 0)
		_deck_dock.size = Vector2(w, _deck_dock.get_combined_minimum_size().y)
	for i in _pages.size():
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
	_build_page(i)
	var tw = create_tween()
	tw.tween_property(_pages_root, "position:x", -i * _w(), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_style_tabs()


func _style_tabs():
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == _tab else Color(0.72, 0.68, 0.62)
		_tab_buttons[i].add_theme_font_size_override("font_size", 20 if i == _tab else 16)


# arrastar pro lado troca de aba
func _input(event):
	if _drag_card != null:
		if event is InputEventMouseMotion:
			_move_ghost(event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
			_end_drag(event.position)
			get_viewport().set_input_as_handled()
		return
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
	_lazy_timer += delta
	if _lazy_timer >= 0.25:
		_lazy_timer = 0.0
		if _drag_card == null:
			_build_one_lazy_page()
	_second_timer += delta
	if _second_timer >= 0.5:
		_second_timer = 0.0
		for pair in _live_labels:
			if is_instance_valid(pair[0]):
				pair[0].text = pair[1].call()
		_check_chest_ready()
		if !Progresso.d["pending"].is_empty():
			_show_pending()
	_clan_timer += delta
	if _clan_timer >= 5.0:
		_clan_timer = 0.0
		if Cla.tick():
			_dirty[4] = true
			if _tab == 4:
				_build_page(4)
			_refresh_dots()


var _ready_state := ""
var _clan_timer := 0.0


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


## DESEMPENHO: antes, qualquer mudança refazia as 6 abas inteiras de uma vez
## (centenas de cartas desenhadas de novo) e a coleção engasgava. Agora só a
## aba que está na tela é refeita na hora; as outras ficam marcadas como
## "sujas" e são refeitas uma por vez, com calma, ou quando você entra nelas.
var _dirty: Array = [true, true, true, true, true, true]
var _lazy_timer := 0.0


func _rebuild_all():
	_refresh_top()
	for i in _dirty.size():
		_dirty[i] = true
	_build_page(_tab)
	_refresh_dots()


func _build_page(i: int):
	if i < 0 or i >= _pages.size() or !_dirty[i]:
		return
	_dirty[i] = false
	var scroll = _pages_root.get_child(i)
	var keep_scroll = scroll.scroll_vertical if scroll is ScrollContainer else 0
	var box = _clear(_pages[i])
	_live_labels = _live_labels.filter(func(pair): return is_instance_valid(pair[0]) and pair[0].is_inside_tree())
	match i:
		0:
			_build_feira(box)
		1:
			_build_cartas(box)
		2:
			_build_batalha(box)
		3:
			_build_trofeus(box)
		4:
			_build_cla(box)
		5:
			_build_sitio(box)
	if scroll is ScrollContainer and keep_scroll > 0:
		_restore_scroll.call_deferred(scroll, keep_scroll)


func _restore_scroll(scroll: ScrollContainer, value: int):
	if is_instance_valid(scroll):
		await get_tree().process_frame
		if is_instance_valid(scroll):
			scroll.scroll_vertical = value


func _build_one_lazy_page():
	for i in _dirty.size():
		if _dirty[i]:
			_build_page(i)
			return


func _refresh_top():
	var prog = Progresso.level_progress()
	_level_label.text = "⭐ Nível %d" % Progresso.player_level()
	for l in [_level_label, _coins_label, _trophy_label]:
		l.add_theme_font_override("font", ThemeDB.fallback_font)
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
	var clan_alert = false
	if Cla.mine() != "":
		for tier in 3:
			if Cla.harvest_claimable(tier):
				clan_alert = true
	_dots[4].visible = clan_alert
	_dots[5].visible = Safra.mission_ready() or Gazeta.unread() > 0


# ================================================================ ajudantes de interface
func _clear(box: Node) -> Node:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	return box


static var _digit_re: RegEx


## a fonte rústica do tema tem "1" parecido com "I" e "0" com "O" -- qualquer
## texto com número usa a fonte padrão, que é bem mais legível
func _readable(control: Control, text: String):
	if _digit_re == null:
		_digit_re = RegEx.new()
		_digit_re.compile("[0-9]")
	if _digit_re.search(text) != null:
		control.add_theme_font_override("font", ThemeDB.fallback_font)


func _label(text: String, font_size: int = 18, color: Color = ThemeBuilder.COLOR_CREAM) -> Label:
	var l = Label.new()
	l.text = text
	_readable(l, text)
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
	_readable(b, text)
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
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	_live_labels.append([label, fn])


# ================================================================ ABA: BATALHA
## quadradinho de opção: ícone grande em cima, nome embaixo
func _tile(grid: Node, icon: String, text: String, action: Callable, highlight: bool = false, note: String = "") -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	if highlight:
		b.modulate = Color(1.0, 0.95, 0.6)
	grid.add_child(b)
	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var il = _label(icon, 38)
	il.add_theme_font_override("font", ThemeDB.fallback_font)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	il.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(il)
	var tl = _label(text, 15)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.clip_text = true
	col.add_child(tl)
	if note != "":
		var nl = _label(note, 12, Color(1, 0.9, 0.5))
		nl.add_theme_font_override("font", ThemeDB.fallback_font)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.clip_text = true
		col.add_child(nl)
	return b


func _build_batalha(box: Node):
	var arena_i = ArenaManager.get_player_arena()
	var info = ArenaManager.get_arena_info(arena_i)
	var my_tr = ArenaManager.get_trophies(PlayerProfile.player_name)

	# ---------------- cartaz da arena: a arena no meio, você por cima
	var banner = Control.new()
	banner.custom_minimum_size = Vector2(0, 400)
	banner.clip_contents = true
	box.add_child(banner)
	var tex_path = "res://Resources/arena/arena_bg_%d.png" % clampi(arena_i, 1, 7)
	if ResourceLoader.exists(tex_path):
		var pic = TextureRect.new()
		pic.texture = load(tex_path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(pic)
	for shade in [[0.0, 0.0, 1.0, 0.0, 0.0, 96.0, 0.62], [0.0, 1.0, 1.0, 1.0, -150.0, 0.0, 0.55]]:
		var sh = ColorRect.new()
		sh.color = Color(0.08, 0.04, 0.02, shade[6])
		sh.anchor_left = shade[0]
		sh.anchor_top = shade[1]
		sh.anchor_right = shade[2]
		sh.anchor_bottom = shade[3]
		sh.offset_top = shade[4]
		sh.offset_bottom = shade[5]
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(sh)
	var frame = ReferenceRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.border_color = Color("#2a1608")
	frame.border_width = 5.0
	frame.editor_only = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(frame)
	# faixa de cima: arena + troféus
	var top = HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(top)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -2)
	top.add_child(left)
	left.add_child(_label("Arena %d" % arena_i, 14, Color(1, 0.9, 0.7)))
	left.add_child(_label("%s %s" % [info.get("emoji", ""), info.get("name", "Arena")], 28, ThemeBuilder.COLOR_GOLD))
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", -2)
	top.add_child(right)
	var tl = _label("🏆 %d" % my_tr, 30, Color(1, 1, 1))
	tl.add_theme_font_override("font", ThemeDB.fallback_font)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(tl)
	var next_text = "arena máxima!"
	if arena_i < ArenaManager.max_arena:
		next_text = "faltam %d pra %s" % [maxi(0, int(ArenaManager.get_arena_info(arena_i + 1).get("trophy_threshold", 0)) - my_tr), ArenaManager.get_arena_info(arena_i + 1).get("name", "")]
	var nl = _label(next_text, 13, Color(1, 0.9, 0.7))
	nl.add_theme_font_override("font", ThemeDB.fallback_font)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(nl)
	# meio: quem é você
	var who = VBoxContainer.new()
	who.set_anchors_preset(Control.PRESET_CENTER)
	who.grow_horizontal = Control.GROW_DIRECTION_BOTH
	who.grow_vertical = Control.GROW_DIRECTION_BOTH
	who.offset_top = -40
	who.add_theme_constant_override("separation", 0)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(who)
	var pn = _label(PlayerProfile.player_name, 34, Color(1, 1, 1))
	pn.add_theme_color_override("font_outline_color", Color("#2a1608"))
	pn.add_theme_constant_override("outline_size", 10)
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(pn)
	var clan_text = "🛡 " + Cla.mine() if Cla.mine() != "" else "sem clã"
	var streak = int(Progresso.d["streak"])
	var sub = _label("%s   ·   nível %d%s" % [clan_text, Progresso.player_level(), "   ·   🔥 %d seguidas" % streak if streak >= 2 else ""], 16, Color(1, 0.95, 0.8))
	sub.add_theme_font_override("font", ThemeDB.fallback_font)
	sub.add_theme_color_override("font_outline_color", Color("#2a1608"))
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(sub)
	# embaixo: BATALHAR
	var battle = _button("⚔  BATALHAR", _start_battle, 36)
	battle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	battle.offset_left = 60
	battle.offset_right = -60
	battle.offset_top = -124
	battle.offset_bottom = -22
	battle.modulate = Color(1.0, 0.92, 0.6)
	banner.add_child(battle)

	# ---------------- opções em quadradinhos
	var pending = 0
	for m in PlayerProfile.daily_missions:
		if !m["claimed"] and m["progress"] >= m["target"]:
			pending += 1
	var tiles = _grid(box, 4)
	var t_note = "em andamento" if Progresso.tournament_active() else ("grátis hoje" if Progresso.tournament_free_today() else "")
	_tile(tiles, "🏟", "Torneios", _show_tournament, Progresso.tournament_active() or Progresso.tournament_free_today(), t_note)
	_tile(tiles, "📅", "Desafio do dia", _show_daily, !Progresso.daily_done(), "feito ✔" if Progresso.daily_done() else "%d de %d" % [Progresso.daily_wins(), Progresso.DAILY_WINS])
	_tile(tiles, "👥", "2 contra 2", _start_2v2)
	_tile(tiles, "🏆", "Ranking", _show_ranking)

	# ---------------- baús
	var chest_panel = _panel(box)
	chest_panel.add_child(_label("🎁 Baús de colheita  (vença pra ganhar · cada partida adianta 1 min)", 14, ThemeBuilder.COLOR_STAT_LABEL))
	var crow = HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	chest_panel.add_child(crow)
	for i in Progresso.CHEST_SLOTS:
		crow.add_child(_chest_slot(i))

	# ---------------- baralho em uso, embaixo
	var deck_panel = _panel(box)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	deck_panel.add_child(head)
	var dl = _label("🃏 Baralho %d  ·  custo médio %.0f" % [Progresso.active_deck() + 1, Progresso.deck_average_cost(Progresso.active_deck())], 16)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.clip_text = true
	head.add_child(dl)
	for i in Progresso.DECK_SLOTS:
		var b = _button(str(i + 1), _pick_active_deck.bind(i), 17)
		b.custom_minimum_size = Vector2(50, 40)
		b.modulate = Color(1, 1, 1) if i == Progresso.active_deck() else Color(0.65, 0.62, 0.58)
		head.add_child(b)
	var drow = HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 3)
	deck_panel.add_child(drow)
	for c in Progresso.deck_cards(Progresso.active_deck()):
		var v = CardView.make(c, 92)
		if Progresso.can_upgrade(c):
			v.badge = "SUBIR"
			v.badge_color = Color(0.5, 1, 0.6)
		v.tapped.connect(_show_card_popup)
		drow.add_child(v)
	var check = DeckDoctor.analyze(Progresso.deck_cards(Progresso.active_deck()))
	var drow2 = HBoxContainer.new()
	drow2.add_theme_constant_override("separation", 8)
	deck_panel.add_child(drow2)
	var cb = _button("🔍 Analisar  (%s · %d)" % [check["veredito"], int(check["nota"])], _show_deck_check, 16)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.custom_minimum_size.y = 50
	drow2.add_child(cb)
	var sb = _button("💡 Sugerir baralho", _show_deck_suggest, 16)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.custom_minimum_size.y = 50
	drow2.add_child(sb)

	_build_powers(box)

	# missões do dia (direto na tela)
	PlayerProfile._check_and_reset_daily_missions()
	var mission_panel = _panel(box)
	mission_panel.add_child(_label("📋 Missões do dia" + ("  --  %d pronta(s)!" % pending if pending > 0 else ""), 17, ThemeBuilder.COLOR_STAT_LABEL))
	for m in PlayerProfile.daily_missions:
		_mission_row(mission_panel, m, null)

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


# ================================================================ DESAFIO DO DIA
func _show_daily():
	var v = _popup(660)
	v.add_child(_title("📅 Desafio do Dia"))
	var deck = Progresso.daily_deck()
	v.add_child(_wrap("Hoje o baralho é emprestado: turma %s. Vença %d partidas com ele. Cartas e torres no nível %d pros dois lados, não vale troféu, e pode tentar quantas vezes quiser. Amanhã o baralho muda." % [Progresso.daily_theme(), Progresso.DAILY_WINS, MatchSetup.TOURNAMENT_LEVEL], 15, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(v, 4)
	for c in deck:
		var cv = CardView.make(c, 150, true)
		cv.locked = false
		cv.level_override = MatchSetup.TOURNAMENT_LEVEL
		cv.mastery_override = 0
		cv.tapped.connect(_show_card_popup.bind(-1, MatchSetup.TOURNAMENT_LEVEL, "o Desafio"))
		g.add_child(cv)
	var check = DeckDoctor.analyze(deck)
	v.add_child(_label("Nota do baralho: %s (%d)" % [check["veredito"], int(check["nota"])], 15, check["cor"]))
	var ladder = LadderView.new()
	ladder.setup(Progresso.daily_wins(), Progresso.DAILY_WINS, 0, 0, {Progresso.DAILY_WINS: Progresso.DAILY_CHEST})
	ladder.custom_minimum_size.y = 96
	v.add_child(ladder)
	v.add_child(_label("Prêmio: 💰 %d por vitória  ·  com %d vitórias: %s + XP (e às vezes um poder)" % [Progresso.DAILY_GOLD_PER_WIN, Progresso.DAILY_WINS, Progresso.CHESTS[Progresso.DAILY_CHEST]["nome"]], 14, Color(0.8, 0.95, 1.0)))
	if Progresso.daily_done():
		v.add_child(_label("✔ Feito hoje! Dá pra continuar jogando por diversão.", 17, Color(0.6, 1, 0.6)))
	var pb = _button("⚔ JOGAR com o baralho do dia", _play_daily, 24)
	pb.custom_minimum_size.y = 80
	pb.modulate = Color(1.0, 0.92, 0.6)
	v.add_child(pb)
	v.add_child(_button("Voltar", _close.bind(v)))


func _play_daily():
	Progresso.start_daily_match(get_tree())


# ================================================================ DOUTOR DO BARALHO
func _deck_report(v: Node, cards: Array):
	var r = DeckDoctor.analyze(cards)
	var head = _label("%s  ·  nota %d de 100" % [r["veredito"], int(r["nota"])], 28, r["cor"])
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.value = int(r["nota"])
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	v.add_child(bar)
	for block in [["✔ Pontos fortes", r["fortes"], Color(0.6, 1.0, 0.6)], ["✖ Pontos fracos", r["fracos"], Color(1.0, 0.65, 0.55)], ["⚠ Quem ganha desse baralho", r["counters"], Color(1.0, 0.85, 0.5)]]:
		if block[1].is_empty():
			continue
		var p = _panel(v)
		p.add_child(_label(str(block[0]), 17, block[2]))
		for line in block[1]:
			var l = _wrap("• " + str(line), 15)
			l.add_theme_font_override("font", ThemeDB.fallback_font)
			p.add_child(l)


func _show_deck_check():
	var v = _popup(660, true)
	v.add_child(_title("🔍 Análise do Baralho %d" % (_deck_slot + 1)))
	var cards = Progresso.deck_cards(_deck_slot)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	for c in cards:
		var cv = CardView.make(c, 88)
		cv.tapped.connect(_show_card_popup)
		row.add_child(cv)
	_deck_report(v, cards)
	v.add_child(_button("💡 Me sugere um baralho melhor", _swap_popup.bind(v, _show_deck_suggest)))
	v.add_child(_button("Voltar", _close.bind(v)))


func _swap_popup(popup_box: Node, next: Callable):
	_close(popup_box)
	next.call_deferred()


var _suggest_scope := 0   # 0 = só as minhas cartas; 1 = todas as cartas da minha arena


func _show_deck_suggest():
	var v = _popup(660, true)
	v.add_child(_title("💡 Sugestão de baralho"))
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var scope_names = ["Com as minhas cartas", "Com tudo da Arena %d" % ArenaManager.get_player_arena()]
	for i in 2:
		var tb = _button(scope_names[i], _set_suggest_scope.bind(v, i), 16)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = 52
		tb.modulate = Color(1, 1, 0.75) if i == _suggest_scope else Color(0.62, 0.6, 0.56)
		tabs.add_child(tb)
	var pool: Array = Progresso.owned_cards() if _suggest_scope == 0 else Progresso.pool()
	var deck = DeckDoctor.suggest(pool, Progresso.DECK_SIZE)
	if deck.size() < Progresso.DECK_SIZE:
		v.add_child(_wrap("Ainda não tem carta suficiente pra montar uma sugestão.", 16))
	else:
		var g = _grid(v, 4)
		var have = 0
		for c in deck:
			var cv = CardView.make(c, 150, true)
			cv.locked = false
			cv.show_level = Progresso.is_owned(c)
			if Progresso.is_owned(c):
				have += 1
			else:
				cv.badge = "não tem"
				cv.badge_color = Color(1, 0.6, 0.5)
			cv.tapped.connect(_show_card_popup)
			g.add_child(cv)
		_deck_report(v, deck)
		var cb = _button("Copiar pro Baralho %d" % (_deck_slot + 1), _copy_meta.bind(deck, v), 19)
		cb.disabled = have < Progresso.DECK_SIZE
		if cb.disabled:
			cb.text = "Não dá pra copiar: faltam %d cartas na sua coleção" % (Progresso.DECK_SIZE - have)
		else:
			cb.modulate = Color(1.0, 0.92, 0.6)
		v.add_child(cb)
	v.add_child(_button("🎲 Outra sugestão", _swap_popup.bind(v, _show_deck_suggest)))
	v.add_child(_button("Voltar", _close.bind(v)))


func _set_suggest_scope(popup_box: Node, scope: int):
	_suggest_scope = scope
	_swap_popup(popup_box, _show_deck_suggest)


# ================================================================ CONFIGURAÇÕES
func _show_settings():
	var v = _popup(620)
	v.add_child(_title("⚙ Configurações"))
	for spec in [["🎵 Música", "musica"], ["🔊 Efeitos (golpes, cartas, botões)", "efeitos"]]:
		var p = _panel(v)
		var value_label = _label("", 17, ThemeBuilder.COLOR_GOLD)
		var head = HBoxContainer.new()
		p.add_child(head)
		var name_l = _label(str(spec[0]), 18)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		head.add_child(value_label)
		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Config.data.get(spec[1], 1.0))
		slider.custom_minimum_size.y = 56
		p.add_child(slider)
		value_label.text = "%d%%" % int(round(slider.value * 100)) if slider.value > 0.01 else "mudo"
		slider.value_changed.connect(_on_volume.bind(str(spec[1]), value_label))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var prof = _button("👤 Trocar de perfil", _goto.bind(PROFILE_SCENE), 17)
	prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prof)
	var quit_b = _button("Sair do jogo", get_tree().quit, 17)
	quit_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quit_b)
	v.add_child(_button("Voltar", _close_settings.bind(v), 20))


func _on_volume(value: float, key: String, value_label: Label):
	Config.set_volume(key, value)
	value_label.text = "%d%%" % int(round(value * 100)) if value > 0.01 else "mudo"
	if key == "efeitos":
		Sfx.play("carta")


func _close_settings(popup_box: Node):
	Config.save()
	_close(popup_box)


func _show_my_cards():
	var v = _popup(660)
	v.add_child(_title("📈 Minhas cartas na temporada"))
	var ranking = Progresso.season_ranking()
	var played = ranking.filter(func(e): return e[1] > 0)
	v.add_child(_label("As que você MAIS jogou", 17, ThemeBuilder.COLOR_STAT_LABEL))
	if played.is_empty():
		v.add_child(_label("Jogue uma partida pra começar a contar.", 16))
	else:
		var g = _grid(v, 5)
		for e in played.slice(0, 5):
			var cv = CardView.make(e[0], 120)
			cv.badge = "%dx" % e[1]
			cv.tapped.connect(_show_card_popup)
			g.add_child(cv)
	v.add_child(_label("As que você MENOS jogou (que tal dar uma chance?)", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var g2 = _grid(v, 5)
	var least: Array = ranking.duplicate()
	least.reverse()
	for e in least.slice(0, 5):
		var cv2 = CardView.make(e[0], 120)
		cv2.badge = "%dx" % e[1]
		cv2.badge_color = Color(0.8, 0.8, 0.8)
		cv2.tapped.connect(_show_card_popup)
		g2.add_child(cv2)
	v.add_child(_button("Voltar", _close.bind(v)))


func _chest_slot(i: int) -> Control:
	var b = Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 178
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", ThemeDB.fallback_font)
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
	var name_text = "\n\n\n\n%s\n" % def["nome"]
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


func _show_tournament():
	var v = _popup(660, true)
	v.add_child(_title("🏟 Torneios e Desafios"))
	var t = Progresso.tournament()
	v.add_child(_label("Taças conquistadas: 🏆 %d" % Progresso.tournament_cups(), 18, ThemeBuilder.COLOR_GOLD))
	if !Progresso.tournament_active():
		v.add_child(_wrap("Em todos: cartas e torres no nível %d pros dois lados -- ganha quem joga melhor. Não vale troféu. A 1ª entrada do dia é grátis (em qualquer um)." % MatchSetup.TOURNAMENT_LEVEL, 15, ThemeBuilder.COLOR_STAT_LABEL))
		if str(t.get("ultimo", "")) != "":
			v.add_child(_wrap("Último: %s" % str(t["ultimo"]), 15, Color(0.85, 0.8, 0.7)))
		var free = Progresso.tournament_free_today()
		for mode in Progresso.TOURNEY_ORDER:
			var def = Progresso.TOURNEYS[mode]
			var p = _panel(v)
			p.add_child(_label("%s %s" % [def["icone"], def["nome"]], 21, ThemeBuilder.COLOR_GOLD))
			p.add_child(_wrap(def["desc"], 15))
			p.add_child(_wrap("Prêmios: " + def["premio"], 14, Color(0.8, 0.95, 1.0)))
			if mode != "mata" and Progresso.tournament_record(mode) > 0:
				p.add_child(_label("Seu recorde: %d vitória(s)" % Progresso.tournament_record(mode), 15, Color(1, 0.85, 0.5)))
			var eb = _button("ENTRAR -- grátis hoje!" if free else "ENTRAR  💰 %d" % int(def["fee"]), _enter_tournament.bind(v, mode), 20)
			eb.disabled = !Progresso.can_enter_tournament(mode)
			p.add_child(eb)
	else:
		var mode_now = Progresso.tournament_mode()
		var def_now = Progresso.TOURNEYS[mode_now]
		var rule = int(t.get("regra", 0))
		v.add_child(_label("%s %s" % [def_now["icone"], def_now["nome"]], 22, ThemeBuilder.COLOR_GOLD))
		var p2 = _panel(v)
		p2.add_child(_label("Regra da partida: %s" % MatchSetup.RULE_NAMES[rule], 19, Color(1, 0.8, 1)))
		p2.add_child(_wrap(MatchSetup.RULE_TEXT[rule], 15))
		p2.add_child(_label("Cenário: %s" % ArenaManager.get_arena_info(int(t.get("arena", 1))).get("name", ""), 15, ThemeBuilder.COLOR_STAT_LABEL))
		var play_text = "⚔ JOGAR"
		if mode_now == "mata":
			var r = int(t.get("rodada", 0))
			var ops: Array = t.get("oponentes", [])
			var figs: Array = t.get("figurantes", [])
			var bracket = BracketView.new()
			bracket.setup(PlayerProfile.player_name, ops, figs, r)
			v.add_child(bracket)
			if r < ops.size():
				v.add_child(_label("👉 %s: você x %s  (🏆 %d)" % [Progresso.TOURNAMENT_ROUNDS[r], str(ops[r]), ArenaManager.get_trophies(str(ops[r]))], 18, Color(1, 1, 0.7)))
			play_text = "⚔ JOGAR: %s" % Progresso.TOURNAMENT_ROUNDS[r]
		else:
			var wins = Progresso.tournament_wins()
			var losses = Progresso.tournament_losses()
			var goal = int(def_now["vit"])
			var max_l = int(def_now["der"])
			var ladder = LadderView.new()
			ladder.setup(wins, goal, losses, max_l, def_now["marcos"])
			v.add_child(ladder)
			v.add_child(_label("Vitórias: %s   ·   Derrotas: %d de %d" % ["%d de %d" % [wins, goal] if goal > 0 else str(wins), losses, max_l], 18, Color(0.6, 1, 0.6)))
			# próximo prêmio
			var marks: Dictionary = def_now["marcos"]
			var next_mark = -1
			for k in marks:
				if int(k) > wins and (next_mark == -1 or int(k) < next_mark):
					next_mark = int(k)
			if next_mark != -1:
				v.add_child(_label("Próximo baú: com %d vitórias (%s)" % [next_mark, Progresso.CHESTS[int(marks[next_mark])]["nome"]], 16, Color(0.8, 0.95, 1.0)))
			elif mode_now == "sobrev":
				v.add_child(_label("Próximo baú: com %d vitórias  ·  recorde: %d" % [(int(wins / 3.0) + 1) * 3, Progresso.tournament_record(mode_now)], 16, Color(0.8, 0.95, 1.0)))
			var opp = Progresso.tournament_opponent()
			v.add_child(_label("👉 Próximo adversário: %s  (🏆 %d)" % [opp, ArenaManager.get_trophies(opp)], 18, Color(1, 1, 0.7)))
			play_text = "⚔ JOGAR a partida %d" % (wins + losses + 1)
		var gb = _button(play_text, _play_tournament, 24)
		gb.custom_minimum_size.y = 80
		gb.modulate = Color(1.0, 0.92, 0.6)
		v.add_child(gb)
		v.add_child(_button("Desistir (o que já ganhou, fica)", _abandon_tournament.bind(v), 15))
	v.add_child(_button("Fechar", _close.bind(v)))


func _enter_tournament(popup_box: Node, mode: String = "mata"):
	if Progresso.enter_tournament(mode):
		_close(popup_box)
		_show_tournament.call_deferred()


func _abandon_tournament(popup_box: Node):
	Progresso.abandon_tournament()
	_close(popup_box)
	_queue_refresh()
	_show_tournament.call_deferred()


func _play_tournament():
	Progresso.start_tournament_match(get_tree())


func _pick_active_deck(i: int):
	_deck_slot = i
	Progresso.set_active_deck(i)


func _start_battle():
	MatchSetup.start_1v1(get_tree())


func _start_2v2():
	MatchSetup.start_2v2(get_tree())


# ================================================================ ABA: CARTAS
var _cards_view := 0  # 0 = cartas, 1 = torres


func _set_cards_view(v: int):
	_cards_view = v
	_cancel_placing()
	_queue_refresh()


func _build_torres(box: Node):
	var equipped = PlayerProfile.get_equipped_base()
	var tlv = Progresso.tower_level()
	var tp = _panel(box)
	tp.add_child(_label("🏰 Nível das torres: %d" % tlv, 22, ThemeBuilder.COLOR_GOLD))
	var why = "Sobe sozinho junto com o seu nível de jogador (hoje nível %d), sem passar de 1 acima da carta mais forte do baralho. Cada nível dá +15%% de vida e de dano." % Progresso.player_level()
	if tlv >= PlayerProfile.MAX_CARD_LEVEL:
		why = "Nível máximo! Cada nível deu +15% de vida e de dano."
	elif tlv < Progresso.player_level():
		why += " Agora quem segura é o baralho: melhore suas cartas pra torre subir."
	else:
		why += " Agora falta subir o seu nível de jogador."
	tp.add_child(_wrap(why, 15, ThemeBuilder.COLOR_STAT_LABEL))
	box.add_child(_wrap("Sua torre vale pras DUAS torres do seu lado. Cada tipo muda o jeito de jogar. As novas liberam conforme você sobe de arena.", 15, ThemeBuilder.COLOR_STAT_LABEL))
	var list: Array = BotSimulator.available_bases.filter(func(b): return b != null)
	list.sort_custom(func(a, b): return a.unlock_arena < b.unlock_arena)
	for b in list:
		var unlocked = PlayerProfile.is_base_unlocked(b)
		var p = _panel(box)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		p.add_child(row)
		var tr = TextureRect.new()
		tr.texture = b.icon
		tr.custom_minimum_size = Vector2(144, 144)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.modulate = Color(1, 1, 1) if unlocked else Color(0.25, 0.25, 0.25)
		row.add_child(tr)
		var side = VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(side)
		if b.has_meta("safra"):
			side.add_child(_label("🆕 NOVIDADE da safra" if b == Safra.current_tower() else "🌱 Torre de safra", 14, Color(0.5, 1, 0.6)))
		side.add_child(_label(b.base_name + ("   ✔ EM USO" if b == equipped else ""), 21, ThemeBuilder.COLOR_GOLD if unlocked else Color(0.6, 0.58, 0.55)))
		var brar = Catalogo.base_rarity(b)
		var bab = Catalogo.base_ability(b)
		side.add_child(_label("%s  ·  %s" % [Catalogo.RARITY_NAMES[brar], "Habilidade: " + str(bab[0]) if !bab.is_empty() else "sem habilidade"], 15, Catalogo.RARITY_COLORS[brar]))
		side.add_child(_label(_base_summary(b), 15, Color(0.8, 0.95, 1.0)))
		for t in b.pros:
			side.add_child(_wrap("✔ " + t, 15, Color(0.6, 1.0, 0.6)))
		for t in b.cons:
			side.add_child(_wrap("✖ " + t, 15, Color(1.0, 0.62, 0.55)))
		if b.description != "":
			p.add_child(_wrap("“%s”" % b.description, 15, Color(0.95, 0.9, 0.78)))
		if !unlocked:
			p.add_child(_label("🔒 Libera na Arena %d (%s)" % [b.unlock_arena, ArenaManager.get_arena_info(b.unlock_arena).get("name", "")], 16, Color(1, 0.85, 0.5)))
		elif b != equipped:
			p.add_child(_button("Usar esta torre", _equip_base_direct.bind(b), 19))
	box.add_child(_button("🎨 Criar minha própria torre (Criador)", _goto.bind(CREATOR_SCENE), 18))


func _base_summary(b: BaseData) -> String:
	var tmult = PlayerProfile.compute_base_stat_multiplier(Progresso.tower_level())
	var hp = int(round(b.base_hp * tmult * ArenaBuilder.TOWER_HP_FRACTION))
	var txt = "❤ %d cada" % hp
	match b.base_type:
		BaseData.BaseType.CANNON:
			txt += "  ·  ⚔ %d a cada %.1fs  ·  alcance %d%s" % [int(round(b.attack_damage * tmult)), b.attack_speed, int(b.attack_range), "  ·  em área" if b.is_aoe else ""]
		BaseData.BaseType.PRODUCTION:
			txt += "  ·  recurso +%d%% mais rápido" % int(round(b.production_speed_boost * 100))
		BaseData.BaseType.HEAL:
			txt += "  ·  cura %d por segundo em volta" % int(b.heal_amount / maxf(b.heal_interval, 0.1))
		BaseData.BaseType.CAPACITY:
			txt += "  ·  guarda +%d de recurso" % b.capacity_bonus
		BaseData.BaseType.AURA:
			txt += "  ·  aura: %s (raio %d)" % [CustomContent.EFFECT_NAMES[b.effect], int(b.aura_radius)]
		_:
			txt += "  ·  só resistência"
	return txt


func _equip_base_direct(b: BaseData):
	PlayerProfile.set_equipped_base(b)
	Sfx.play("carta")
	_queue_refresh()


var _deck_dock: PanelContainer
var _col_views: Dictionary = {}   # carta -> CardView da coleção (pra marcar a escolhida sem refazer a tela)


## monta a doca fixa: troca Cartas/Torres, os 4 baralhos e as 7 cartas do
## baralho sempre à vista. É nela que você toca pra pôr a carta escolhida.
func _build_dock():
	if !is_instance_valid(_deck_dock):
		return
	for c in _deck_dock.get_children():
		_deck_dock.remove_child(c)
		c.queue_free()
	_drop_targets.clear()
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_deck_dock.add_child(col)
	var switch = HBoxContainer.new()
	switch.add_theme_constant_override("separation", 8)
	col.add_child(switch)
	var names = ["🃏 Cartas", "🏰 Torres"]
	for i in 2:
		var sb = _button(names[i], _set_cards_view.bind(i), 19)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size.y = 48
		sb.modulate = Color(1, 1, 1) if i == _cards_view else Color(0.6, 0.58, 0.54)
		switch.add_child(sb)
	if _cards_view == 0:
		var head = HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		col.add_child(head)
		for i in Progresso.DECK_SLOTS:
			var b = _button(str(i + 1), _view_deck.bind(i), 18)
			b.custom_minimum_size = Vector2(54, 42)
			b.modulate = Color(1, 1, 0.75) if i == _deck_slot else Color(0.62, 0.6, 0.56)
			head.add_child(b)
		var is_active = _deck_slot == Progresso.active_deck()
		var il = _label("Baralho %d · custo médio %.0f%s" % [_deck_slot + 1, Progresso.deck_average_cost(_deck_slot), " · EM USO" if is_active else ""], 15, ThemeBuilder.COLOR_STAT_LABEL)
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il.clip_text = true
		head.add_child(il)
		if !is_active:
			var ub = _button("Usar este", _pick_active_deck.bind(_deck_slot), 15)
			ub.custom_minimum_size.y = 42
			head.add_child(ub)
		var deck = Progresso.deck_cards(_deck_slot)
		var row: HBoxContainer = null
		for i in deck.size():
			if i % 4 == 0:
				row = HBoxContainer.new()
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				row.add_theme_constant_override("separation", 8)
				col.add_child(row)
			var cv = CardView.make(deck[i], 138)
			if Progresso.can_upgrade(deck[i]):
				cv.badge = "SUBIR"
				cv.badge_color = Color(0.5, 1, 0.6)
			cv.set_selected(_pending_card != null or _pending_index == i)
			cv.tapped.connect(_on_deck_slot_tapped.bind(i))
			cv.held.connect(_on_card_held.bind(i))
			row.add_child(cv)
			_drop_targets.append([cv, i])
		var hint_row = HBoxContainer.new()
		col.add_child(hint_row)
		var hint = "Toque: baralho mostra a carta, coleção escolhe  ·  Segure: informações"
		var active = false
		if _pending_card != null:
			hint = "👉 Toque no lugar de %s  ·  segure outra pra comparar" % _pending_card.card_name
			active = true
		elif _pending_index != -1 and _pending_index < deck.size():
			hint = "👉 Toque na carta da coleção que entra no lugar de %s" % deck[_pending_index].card_name
			active = true
		var hl = _label(hint, 15, Color(1, 0.9, 0.6) if active else ThemeBuilder.COLOR_STAT_LABEL)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.clip_text = true
		hl.custom_minimum_size.y = 40
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_row.add_child(hl)
		if active:
			var xb = _button("✖", _clear_selection, 17)
			xb.custom_minimum_size = Vector2(56, 40)
			hint_row.add_child(xb)
	_deck_dock.size = Vector2(_w(), _deck_dock.get_combined_minimum_size().y)


## marca/desmarca a carta escolhida SEM refazer a tela (a rolagem não pula)
func _refresh_selection():
	_build_dock()
	for c in _col_views:
		if is_instance_valid(_col_views[c]):
			_col_views[c].set_selected(_pending_card == c)


func _clear_selection():
	_cancel_placing()
	_refresh_selection()


func _build_cartas(box: Node):
	_col_views.clear()
	_build_dock()
	# espaço do tamanho da doca, pra primeira linha não ficar escondida atrás dela
	var spacer = Control.new()
	spacer.custom_minimum_size.y = (_deck_dock.get_combined_minimum_size().y if is_instance_valid(_deck_dock) else 0.0) - 4.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	if _cards_view == 1:
		_build_torres(box)
		return

	# filtros: 3 botões numa linha só (cada toque passa pro próximo)
	var frow = HBoxContainer.new()
	frow.add_theme_constant_override("separation", 6)
	box.add_child(frow)
	var turma_names: Array = [""]
	for n in CustomContent.all_nations():
		if n != null:
			turma_names.append(n.nation_name)
	for spec in [["Ordem: " + SORT_NAMES[_sort_mode], _set_sort.bind((_sort_mode + 1) % SORT_NAMES.size()), _sort_mode != 0],
			["Tipo: " + KIND_NAMES[_filter_kind], _set_kind.bind((_filter_kind + 1) % KIND_NAMES.size()), _filter_kind != 0],
			["Turma: " + (_filter_turma if _filter_turma != "" else "Todas"), _set_filter.bind(str(turma_names[(turma_names.find(_filter_turma) + 1) % turma_names.size()])), _filter_turma != ""]]:
		var fb = _button(str(spec[0]), spec[1], 15)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.custom_minimum_size.y = 46
		fb.clip_text = true
		fb.modulate = Color(1, 1, 0.75) if spec[2] else Color(0.8, 0.77, 0.72)
		frow.add_child(fb)

	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	box.add_child(tools)
	var chk = DeckDoctor.analyze(Progresso.deck_cards(_deck_slot))
	var ab = _button("🔍 Analisar (%s · %d)" % [chk["veredito"], int(chk["nota"])], _show_deck_check, 15)
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.custom_minimum_size.y = 46
	tools.add_child(ab)
	var sgb = _button("💡 Sugerir baralho", _show_deck_suggest, 15)
	sgb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sgb.custom_minimum_size.y = 46
	tools.add_child(sgb)

	var in_deck: Array = Progresso.deck_paths(_deck_slot)
	var owned: Array = []
	var missing: Array = []
	for c in CardDatabase.all_cards:
		if c == null or CustomContent.is_spawn_only(c):
			continue
		if _filter_turma != "" and c.get_nation_name() != _filter_turma:
			continue
		if _filter_kind != 0 and _card_kind(c) != _filter_kind:
			continue
		if Progresso.is_owned(c):
			if !in_deck.has(c.resource_path):
				owned.append(c)
		else:
			missing.append(c)
	owned.sort_custom(_sort_cards)
	missing.sort_custom(_sort_cards if _sort_mode != 0 else func(a, b): return a.unlock_arena < b.unlock_arena if a.unlock_arena != b.unlock_arena else a.cost < b.cost)

	var news: Array = Safra.current_cards()
	if !news.is_empty() and _filter_turma == "" and _filter_kind == 0:
		var np = _panel(box)
		np.add_child(_label("🆕 Novidades desta safra", 19, Color(0.5, 1, 0.6)))
		np.add_child(_wrap("Liberada só no dia do lançamento. Depois, aparece nos baús e na Feira de quem já chegou na arena dela.", 13, ThemeBuilder.COLOR_STAT_LABEL))
		var ng = _grid(np, 4)
		for c in news:
			var nv = CardView.make(c, 150, true)
			nv.show_level = Progresso.is_owned(c)
			nv.badge = "NOVIDADE" if Progresso.is_owned(c) else "🔒 Arena %d" % maxi(1, c.unlock_arena)
			nv.badge_color = Color(0.5, 1, 0.6) if Progresso.is_owned(c) else Color(1, 0.85, 0.5)
			nv.tapped.connect(_show_card_popup)
			ng.add_child(nv)
	box.add_child(_label("Fora do baralho: %d carta(s)   ·   coleção %d/%d" % [owned.size(), owned.size() + in_deck.size(), owned.size() + in_deck.size() + missing.size()], 16, ThemeBuilder.COLOR_GOLD))
	var og = _grid(box, 4)
	for c in owned:
		var badge = ""
		var badge_col = Color(1, 0.9, 0.5)
		if Progresso.is_new(c):
			badge = "NOVA!"
			badge_col = Color(0.5, 1, 0.6)
		elif Progresso.can_upgrade(c):
			badge = "⬆ SUBIR"
			badge_col = Color(0.5, 1, 0.6)
		elif Safra.is_novelty(c):
			badge = "NOVIDADE"
			badge_col = Color(0.5, 1, 0.6)
		og.add_child(_collection_entry(c, false, badge, badge_col))
	if !missing.is_empty():
		box.add_child(_title("Ainda não encontradas"))
		var mg = _grid(box, 4)
		var arena_now = ArenaManager.get_player_arena()
		for c in missing:
			var is_locked = c.unlock_arena > arena_now
			mg.add_child(_collection_entry(c, true, "Arena %d" % c.unlock_arena if is_locked else "nos baús", Color(1, 0.9, 0.5), is_locked))
	_build_place_bar()



const SORT_NAMES = ["Mais barata", "Mais cara", "Raridade", "Nível", "Nome", "Novas"]
const KIND_NAMES = ["Tudo", "Tropa", "Voador", "Construção", "Feitiço"]
var _sort_mode := 0
var _filter_kind := 0


func _set_sort(i: int):
	_sort_mode = i
	_queue_refresh()


func _set_kind(i: int):
	_filter_kind = i
	_queue_refresh()


## 1 tropa do chão, 2 voador, 3 construção, 4 feitiço
func _card_kind(c: CardData) -> int:
	if c.is_spell():
		return 4
	var st = DeckBuilder.get_unit_stats(c)
	if st == null:
		return 1
	if st.unit_type == UnitData.UnitType.AIR:
		return 2
	if st.unit_type == UnitData.UnitType.BUILDING:
		return 3
	return 1


func _sort_cards(a: CardData, b: CardData) -> bool:
	match _sort_mode:
		1:
			if a.cost != b.cost:
				return a.cost > b.cost
		2:
			var ra = Catalogo.rarity_of(a)
			var rb = Catalogo.rarity_of(b)
			if ra != rb:
				return ra > rb
		3:
			var la = Progresso.level(a)
			var lb = Progresso.level(b)
			if la != lb:
				return la > lb
		4:
			return a.card_name < b.card_name
		5:
			var na = int(a.get_meta("safra", -1))
			var nb = int(b.get_meta("safra", -1))
			if na != nb:
				return na > nb
	if a.cost != b.cost:
		return a.cost < b.cost
	return a.card_name < b.card_name


## uma carta da coleção: grande, com os dados dentro dela
func _collection_entry(c: CardData, missing: bool, badge: String, badge_col: Color, hide_art: bool = false) -> Control:
	var v = CardView.make(c, 162, true)
	v.locked = hide_art
	v.show_level = !missing
	if badge == "" and !missing:
		var need = Progresso.copies_needed(c)
		badge = "%d/%d" % [Progresso.copies(c), need] if need > 0 else "MÁX"
	v.badge = badge
	v.badge_color = badge_col
	v.set_selected(_pending_card == c)
	if missing:
		v.tapped.connect(_show_card_popup)
	else:
		# toque = escolhe pra trocar (o baralho está sempre em cima); segurar = informações
		v.tapped.connect(_on_collection_tapped)
		v.held.connect(_on_card_held)
		_col_views[c] = v
	return v


# ---------------------------------------------------------------- arrastar: segura o dedo na carta e leva até o baralho
var _drag_card: CardData = null
var _drag_ghost: CardView
var _drop_targets: Array = []  # [Control, posição no baralho]


func _begin_drag(card: CardData):
	if card == null or Progresso.deck_paths(_deck_slot).has(card.resource_path):
		return
	Sfx.play("carta")
	Input.vibrate_handheld(25)
	_drag_card = card
	_swiping = false
	_pending_card = card
	_pending_index = -1
	_drag_ghost = CardView.make(card, 150, true)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 200
	_drag_ghost.modulate = Color(1, 1, 1, 0.9)
	_drag_ghost.size = _drag_ghost.custom_minimum_size
	add_child(_drag_ghost)
	_move_ghost(get_viewport().get_mouse_position())
	_queue_refresh()  # mostra a faixa do baralho embaixo pra soltar


func _move_ghost(pos: Vector2):
	if is_instance_valid(_drag_ghost):
		_drag_ghost.position = pos - Vector2(_drag_ghost.size.x * 0.5, _drag_ghost.size.y + 30.0)
	for t in _drop_targets:
		if is_instance_valid(t[0]):
			t[0].modulate = Color(1.3, 1.3, 0.8) if t[0].get_global_rect().has_point(pos) else Color(1, 1, 1)


func _end_drag(pos: Vector2):
	var card = _drag_card
	_drag_card = null
	if is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	for t in _drop_targets:
		if is_instance_valid(t[0]) and t[0].get_global_rect().has_point(pos):
			if Progresso.set_deck_card(_deck_slot, int(t[1]), card):
				Sfx.play("moeda")
			_cancel_placing()
			_queue_refresh()
			return
	# soltou fora: a carta continua escolhida, dá pra tocar no lugar


var _place_bar: Control


## faixa que aparece embaixo quando uma carta está escolhida: mostra o
## baralho ali mesmo, pra tocar no lugar sem precisar rolar a tela pra cima
func _build_place_bar():
	if is_instance_valid(_place_bar):
		_place_bar.queue_free()
	_place_bar = null


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
	if is_instance_valid(_place_bar):
		_place_bar.queue_free()
	_place_bar = null


func _cancel_placing_and_refresh():
	_cancel_placing()
	_queue_refresh()


func _on_deck_slot_tapped(_card, index: int):
	if _pending_card != null:
		Progresso.set_deck_card(_deck_slot, index, _pending_card)
		_cancel_placing()
		_queue_refresh()
		return
	if _pending_index != -1:
		_clear_selection()
		return
	# toque numa carta do baralho = informações na hora (lá tem Evoluir e Trocar)
	_show_card_popup(_card, index)


func _on_collection_tapped(card: CardData):
	if _pending_index != -1:
		Progresso.set_deck_card(_deck_slot, _pending_index, card)
		_cancel_placing()
		_queue_refresh()
		return
	# toque = escolhe a carta; agora é só tocar no lugar dela no baralho lá em cima
	_pending_card = null if _pending_card == card else card
	_pending_index = -1
	Sfx.play("carta")
	_refresh_selection()


# ---------------------------------------------------------------- popup de carta
func _popup(min_width: float = 600.0, tall: bool = false) -> VBoxContainer:
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
	if tall:
		var sc = ScrollContainer.new()
		sc.add_child(ScrollGlide.new())
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(min_width - 20, minf(1150.0, get_viewport_rect().size.y - 260.0))
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
		panel.add_child(sc)
	else:
		panel.add_child(v)
	v.set_meta("overlay", overlay)
	return v


func _close(v: Node):
	var overlay = v.get_meta("overlay")
	if is_instance_valid(overlay):
		overlay.remove_from_group("hub_popup")
		overlay.queue_free()
	# fechou uma janela: se ficou prêmio esperando (ex.: subiu de nível ao
	# evoluir uma carta), mostra agora -- antes só aparecia depois da próxima partida
	_show_pending.call_deferred()


const ABILITY_HELP = {
	"Dano em área": "acerta todo mundo que estiver perto do alvo.",
	"Investida": "corre e o primeiro golpe bate mais forte e empurra.",
	"Furtivo": "inimigo só enxerga de perto; aparece depois de atacar.",
	"1º golpe em dobro": "o primeiro ataque causa o dobro de dano.",
	"Entra em fúria": "chega mais rápido e mais forte por alguns segundos.",
	"Onda de choque": "causa dano em volta quando entra em campo.",
	"Roubo de vida": "recupera vida a cada golpe.",
	"Provoca": "os inimigos por perto são obrigados a bater nele.",
	"Casca dura": "leva menos dano (ou tem escudo extra).",
	"Regenera": "recupera vida sozinho com o tempo.",
	"Divide o dano": "o grupo reparte o dano que cada um leva.",
	"Filhotes ao morrer": "quando morre, solta unidades menores.",
	"Explode": "causa dano em área quando morre ou encosta.",
	"Tiro especial": "o tiro se divide, atravessa ou pula entre alvos.",
	"Cura aliados": "cura as tropas amigas em volta.",
	"Cura": "recupera vida dos aliados na área.",
	"Purifica": "tira efeitos ruins dos aliados.",
	"Fúria": "aliados na área batem e andam mais rápido.",
	"Escudo": "dá um escudo temporário aos aliados.",
	"Fica no chão": "o efeito continua na área por um tempo.",
	"Invoca tropas": "faz nascer outras unidades.",
	"Intocável andando": "não leva dano enquanto anda; só parado ou atacando.",
	"Vai ficando mais forte": "bate cada vez mais rápido ou mais forte.",
	"Fúria na beira da morte": "com pouca vida, fica mais perigoso.",
	"Executa": "finaliza na hora inimigo com pouca vida.",
	"Gera recurso": "produz recurso extra enquanto estiver vivo.",
	"Devolve dano": "quem bate nele leva parte do dano de volta.",
	"Cura ao matar": "recupera vida a cada inimigo derrotado.",
	"Levanta de novo": "volta à vida uma vez depois de morrer.",
	"Inabalável": "não é empurrado nem puxado.",
	"Nasce em qualquer lugar": "você pode jogar em qualquer ponto do campo, até do lado da torre inimiga.",
	"Invoca sem parar": "fica brotando tropa na área enquanto durar.",
	"Tiro em corrente": "o tiro pula de um inimigo pro outro.",
	"Clone ao morrer": "deixa uma cópia mais fraca quando morre.",
	"Revida": "às vezes devolve o golpe quando apanha.",
	"Recurso ao matar": "ganha recurso a cada inimigo derrotado.",
	"Rouba recurso": "tira recurso do rival quando bate na torre.",
	"Golpe duplo": "cada golpe acerta mais um inimigo ao lado.",
	"Bote": "dá um salto rápido no primeiro alvo.",
	"Mais dano de longe": "quanto mais longe o alvo, mais forte o tiro.",
	"Acompanhantes": "vem com outras unidades diferentes junto.",
}


func _ability_help(skill: String) -> String:
	if ABILITY_HELP.has(skill):
		return ABILITY_HELP[skill]
	if skill.begins_with("Golpe: "):
		return "cada golpe aplica esse efeito no alvo."
	if skill.begins_with("Efeito: "):
		return "aplica esse efeito em quem estiver na área."
	return ""


## um quadradinho de número: rótulo pequeno, valor grande e, em verde, o
## quanto sobe no próximo nível
func _stat_tile(grid: Node, label_text: String, value: String, plus: String = ""):
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(198, 0)
	grid.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var name_l = _label(label_text, 12, ThemeBuilder.COLOR_STAT_LABEL)
	name_l.add_theme_font_override("font", ThemeDB.fallback_font)
	name_l.clip_text = true
	v.add_child(name_l)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var val_l = _label(value, 18)
	val_l.add_theme_font_override("font", ThemeDB.fallback_font)
	h.add_child(val_l)
	if plus != "":
		var plus_l = _label(plus, 15, Color(0.5, 1.0, 0.55))
		plus_l.add_theme_font_override("font", ThemeDB.fallback_font)
		h.add_child(plus_l)


static func _speed_name(sp: float) -> String:
	if sp <= 0:
		return "Parado"
	if sp < 32:
		return "Muito lenta"
	if sp < 48:
		return "Lenta"
	if sp < 66:
		return "Média"
	if sp < 90:
		return "Rápida"
	return "Muito rápida"


func _fill_stat_tiles(g: Node, card: CardData, mult: float, next_mult: float):
	var up = next_mult > mult
	if card.is_spell():
		var sp: SpellData = card.spell_data
		if sp.damage > 0:
			var d0 = int(round(sp.damage * mult))
			_stat_tile(g, "💥 Dano", str(d0), "+%d" % (int(round(sp.damage * next_mult)) - d0) if up else "")
			var t0 = int(round(sp.damage * mult * sp.base_damage_multiplier))
			_stat_tile(g, "🏰 Dano em torre", str(t0), "+%d" % (int(round(sp.damage * next_mult * sp.base_damage_multiplier)) - t0) if up else "")
		if sp.heal_amount > 0:
			var h0 = int(round(sp.heal_amount * mult))
			_stat_tile(g, "✚ Cura", str(h0), "+%d" % (int(round(sp.heal_amount * next_mult)) - h0) if up else "")
		if sp.shield_amount > 0:
			var s0 = int(round(sp.shield_amount * mult))
			_stat_tile(g, "🛡 Escudo", str(s0), "+%d" % (int(round(sp.shield_amount * next_mult)) - s0) if up else "")
		_stat_tile(g, "⭕ Raio", str(int(sp.radius)))
		if sp.duration > 0:
			_stat_tile(g, "⏱ Duração", "%.1fs" % sp.duration)
		if sp.summon_count > 0:
			_stat_tile(g, "👥 Invoca", "x%d" % sp.summon_count)
		_stat_tile(g, "🎯 Afeta", "Aliados" if (sp.affects_allies or !sp.affects_enemies) else "Inimigos")
		_stat_tile(g, "💧 Custo", str(card.cost))
		return
	var st: UnitData = DeckBuilder.get_unit_stats(card)
	if st == null:
		return
	var hp0 = int(round(st.hp * mult))
	_stat_tile(g, "❤ Vida", str(hp0), "+%d" % (int(round(st.hp * next_mult)) - hp0) if up else "")
	if st.damage > 0:
		var d1 = int(round(st.damage * mult))
		_stat_tile(g, "⚔ Dano", str(d1), "+%d" % (int(round(st.damage * next_mult)) - d1) if up else "")
		if st.attack_speed > 0:
			var dps0 = int(round(st.damage * mult / st.attack_speed))
			_stat_tile(g, "🔥 Dano por segundo", str(dps0), "+%d" % (int(round(st.damage * next_mult / st.attack_speed)) - dps0) if up else "")
			_stat_tile(g, "⏱ Vel. de ataque", "%.1fs" % st.attack_speed)
		_stat_tile(g, "📏 Alcance", str(int(st.attack_range)) if st.is_ranged else "Corpo a corpo")
	else:
		_stat_tile(g, "⚔ Dano", "não ataca")
	_stat_tile(g, "👟 Velocidade", "%s (%d)" % [_speed_name(st.move_speed), int(st.move_speed)] if st.move_speed > 0 else "Parado")
	var targets = "Chão"
	match st.target_type:
		UnitData.TargetType.BUILDING:
			targets = "Só torres"
		UnitData.TargetType.ALL:
			targets = "Chão e ar"
		UnitData.TargetType.AIR:
			targets = "Só ar"
	_stat_tile(g, "🎯 Alvos", targets if st.damage > 0 else "-")
	var kind = "Terrestre"
	if st.unit_type == UnitData.UnitType.AIR:
		kind = "Voador"
	elif st.unit_type == UnitData.UnitType.BUILDING:
		kind = "Construção"
	_stat_tile(g, "🐾 Tipo", kind)
	var count_text = "x%d" % st.unit_count
	for comp in card.companions:
		count_text += " +%d" % int(comp["count"])
	if st.unit_count > 1 or !card.companions.is_empty():
		_stat_tile(g, "👥 Quantidade", count_text)
	if st.is_aoe:
		_stat_tile(g, "⭕ Área do golpe", str(int(st.aoe_radius)))
	_stat_tile(g, "💧 Custo", str(card.cost))


## level_view > 0: só olhar a carta no nível de OUTRA pessoa (ex.: carta de um bot)
func _show_card_popup(card: CardData, deck_index: int = -1, level_view: int = 0, whose: String = ""):
	if card == null:
		return
	var owned = Progresso.is_owned(card) and level_view <= 0
	if level_view <= 0:
		Progresso.clear_new(card)
	var outer = _popup(660)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	outer.add_child(head)
	# miolo com rolagem curta + rodapé FIXO com os botões (não precisa descer pra fechar)
	var mid_scroll = ScrollContainer.new()
	mid_scroll.add_child(ScrollGlide.new())
	mid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid_scroll.custom_minimum_size = Vector2(640, clampf(get_viewport_rect().size.y - 880.0, 380.0, 700.0))
	outer.add_child(mid_scroll)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	v.set_meta("overlay", outer.get_meta("overlay"))
	mid_scroll.add_child(v)
	var foot = VBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	outer.add_child(foot)
	var cv = CardView.make(card, 190, true)
	cv.locked = false
	cv.show_level = owned or level_view > 0
	if level_view > 0:
		cv.level_override = level_view
		cv.mastery_override = 0
	head.add_child(cv)
	var side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(side)
	side.add_child(_wrap(card.card_name, 26, ThemeBuilder.COLOR_GOLD))
	var rarity = Catalogo.rarity_of(card)
	var lv = level_view if level_view > 0 else Progresso.level(card)
	if Safra.is_novelty(card):
		side.add_child(_label("🆕 NOVIDADE desta safra", 16, Color(0.5, 1, 0.6)))
	var adj_text = Assembleia.adjust_text(card)
	if adj_text != "":
		side.add_child(_wrap("⚖ Ajustada pela Assembleia: " + adj_text, 15, Color(0.8, 0.95, 1.0)))
	side.add_child(_label("%s  ·  %s" % [Catalogo.RARITY_NAMES[rarity], card.get_nation_name() if card.get_nation_name() != "" else "Coringa"], 17, Catalogo.RARITY_COLORS[rarity]))
	side.add_child(_label("%s  ·  %s" % [CardData.role_name(card.role), ("Nível %d de %s" % [lv, whose] if level_view > 0 else "Nível %d" % lv) if (owned or level_view > 0) else "não liberada"], 17))
	if card.description != "":
		side.add_child(_wrap("“%s”" % card.description, 16, Color(0.95, 0.9, 0.78)))

	# melhoria primeiro: é o que mais se usa
	var can_level = owned and Progresso.copies_needed(card) > 0
	if owned:
		var need = Progresso.copies_needed(card)
		if need > 0:
			var bar = ProgressBar.new()
			bar.max_value = need
			bar.value = mini(Progresso.copies(card), need)
			bar.show_percentage = false
			bar.custom_minimum_size.y = 18
			foot.add_child(bar)
			var missing: Array = []
			if Progresso.copies(card) < need:
				missing.append("faltam %d cópia(s)" % (need - Progresso.copies(card)))
			if PlayerProfile.coins < Progresso.upgrade_cost(card):
				missing.append("faltam 💰 %d" % (Progresso.upgrade_cost(card) - PlayerProfile.coins))
			var up = _button("⬆ EVOLUIR pro nível %d   (%d/%d cópias · 💰 %d)" % [lv + 1, Progresso.copies(card), need, Progresso.upgrade_cost(card)], _upgrade.bind(card, v, deck_index), 19)
			up.disabled = !Progresso.can_upgrade(card)
			if !up.disabled:
				up.modulate = Color(0.7, 1.0, 0.7)
			elif !missing.is_empty():
				up.text = "⬆ Evoluir pro nível %d: %s" % [lv + 1, " e ".join(missing)]
			foot.add_child(up)
		else:
			foot.add_child(_label("⭐ Nível máximo!", 18, ThemeBuilder.COLOR_GOLD))

	# números em quadradinhos (em verde, o ganho do próximo nível)
	var mult = PlayerProfile.compute_stat_multiplier(lv)
	var next_mult = PlayerProfile.compute_stat_multiplier(lv + 1) if can_level else mult
	if can_level:
		v.add_child(_label("Números no nível %d   (em verde: o que ganha no nível %d)" % [lv, lv + 1], 14, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(v, 3)
	_fill_stat_tiles(g, card, mult, next_mult)
	var target_line = _target_text(card)
	if target_line != "":
		v.add_child(_wrap(target_line, 16, Color(1.0, 0.85, 0.55)))

	# habilidades, uma por linha, explicadas
	var skills = Catalogo.abilities_detail(card)
	var sk_panel = _panel(v)
	sk_panel.add_child(_label("Carta %s" % Catalogo.RARITY_NAMES[rarity], 17, Catalogo.RARITY_COLORS[rarity].lightened(0.2)))
	if skills.is_empty():
		sk_panel.add_child(_wrap("Sem habilidade: é só vida e pancada. (Normal e Rara nunca têm habilidade; Épica, Lendária e Mística têm, cada vez mais forte.)", 15))
	for pair in skills:
		var help_text = _ability_help(str(pair[0]))
		sk_panel.add_child(_wrap("%s %s%s" % ["★".repeat(int(pair[1])), pair[0], ": " + help_text if help_text != "" else ""], 15))

	if !card.pros.is_empty() or !card.cons.is_empty():
		var pc = _panel(v)
		for p in card.pros:
			pc.add_child(_wrap("✔ " + p, 15, Color(0.6, 1.0, 0.6)))
		for p in card.cons:
			pc.add_child(_wrap("✖ " + p, 15, Color(1.0, 0.62, 0.55)))

	# histórico
	var hist = _panel(v)
	if owned:
		var mp = Progresso.mastery_progress(card)
		var m = Progresso.mastery(card)
		var mtext = "Maestria: %s  ·  você usou %d vez(es)" % [Progresso.MASTERY_NAMES[m] if m > 0 else "nenhuma ainda", mp[0]]
		if mp[1] > 0:
			mtext += "  (próxima borda com %d)" % mp[1]
		hist.add_child(_wrap(mtext, 15, Progresso.MASTERY_COLORS[m] if m > 0 else ThemeBuilder.COLOR_STAT_LABEL))
	var season: Dictionary = SeasonStats.stats.get(card.resource_path, {})
	var played = int(season.get("wins", 0)) + int(season.get("losses", 0))
	if played > 0:
		hist.add_child(_wrap("Na temporada (todo mundo): jogada em %d partidas, vence %d%%" % [played, int(round(100.0 * int(season.get("wins", 0)) / played))], 15, ThemeBuilder.COLOR_STAT_LABEL))
	else:
		hist.add_child(_wrap("Na temporada: ainda sem partidas registradas.", 15, ThemeBuilder.COLOR_STAT_LABEL))
	hist.add_child(_wrap("Libera na Arena %d (%s)" % [maxi(1, card.unlock_arena), ArenaManager.get_arena_info(maxi(1, card.unlock_arena)).get("name", "")], 15, ThemeBuilder.COLOR_STAT_LABEL))

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	foot.add_child(btn_row)
	if owned:
		if deck_index >= 0:
			var sw = _button("🔁 Trocar", _begin_swap.bind(deck_index, v), 20)
			sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sw.modulate = Color(1.0, 0.92, 0.6)
			btn_row.add_child(sw)
		elif !Progresso.deck_paths(_deck_slot).has(card.resource_path):
			var use_b = _button("➕ Usar no baralho", _begin_place.bind(card, v), 20)
			use_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			use_b.modulate = Color(1.0, 0.92, 0.6)
			btn_row.add_child(use_b)
	elif level_view > 0:
		var mine_text = "Você tem esta carta no nível %d." % Progresso.level(card) if Progresso.is_owned(card) else "Você ainda não tem esta carta."
		v.add_child(_wrap("Números no nível %d, como %s usa.  %s" % [lv, whose, mine_text], 15, Color(1, 0.85, 0.5)))
	else:
		v.add_child(_wrap("Você ainda não tem esta carta. Ela aparece nos baús e na Feira a partir da Arena %d." % maxi(1, card.unlock_arena), 15, Color(1, 0.85, 0.5)))
	var back_b = _button("Voltar", _close.bind(v), 20)
	back_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(back_b)


## segurar uma carta: informações. Se já tem OUTRA carta escolhida, compara as duas.
func _on_card_held(card: CardData, deck_index: int = -1):
	var other: CardData = _pending_card
	if other == null and _pending_index != -1:
		var deck = Progresso.deck_cards(_deck_slot)
		if _pending_index < deck.size():
			other = deck[_pending_index]
	if other != null and other != card:
		_show_compare(other, card)
	else:
		_show_card_popup(card, deck_index)


## números de uma carta pra comparação: nome -> [texto, valor (ou null), maior é melhor?]
func _compare_values(c: CardData) -> Dictionary:
	var lv = Progresso.level(c)
	var mult = PlayerProfile.compute_stat_multiplier(lv)
	var out: Dictionary = {}
	out["Custo"] = [str(c.cost), float(c.cost), false]
	out["Nível"] = [str(lv) if Progresso.is_owned(c) else "não tem", float(lv), true]
	out["Raridade"] = [Catalogo.RARITY_NAMES[Catalogo.rarity_of(c)], float(Catalogo.rarity_of(c)), true]
	if c.is_spell():
		var sp: SpellData = c.spell_data
		out["Tipo"] = ["Feitiço", null, true]
		if sp.damage > 0:
			out["Dano"] = [str(int(round(sp.damage * mult))), sp.damage * mult, true]
		if sp.heal_amount > 0:
			out["Cura"] = [str(int(round(sp.heal_amount * mult))), sp.heal_amount * mult, true]
		if sp.shield_amount > 0:
			out["Escudo"] = [str(int(round(sp.shield_amount * mult))), sp.shield_amount * mult, true]
		out["Raio"] = [str(int(sp.radius)), sp.radius, true]
		if sp.duration > 0:
			out["Duração"] = ["%.1fs" % sp.duration, sp.duration, true]
	else:
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st != null:
			var kind = "Terrestre"
			if st.unit_type == UnitData.UnitType.AIR:
				kind = "Voador"
			elif st.unit_type == UnitData.UnitType.BUILDING:
				kind = "Construção"
			out["Tipo"] = [kind, null, true]
			out["Vida"] = [str(int(round(st.hp * mult))) + (" x%d" % st.unit_count if st.unit_count > 1 else ""), st.hp * mult * st.unit_count, true]
			if st.damage > 0:
				out["Dano"] = [str(int(round(st.damage * mult))), st.damage * mult, true]
				if st.attack_speed > 0:
					var dps = st.damage * mult / st.attack_speed * st.unit_count
					out["Dano por segundo"] = [str(int(round(dps))), dps, true]
					out["Vel. de ataque"] = ["%.1fs" % st.attack_speed, st.attack_speed, false]
				out["Alcance"] = [str(int(st.attack_range)) if st.is_ranged else "Corpo a corpo", st.attack_range if st.is_ranged else 0.0, true]
			if st.move_speed > 0:
				out["Velocidade"] = ["%s (%d)" % [_speed_name(st.move_speed), int(st.move_speed)], st.move_speed, true]
			var targets = "Chão"
			match st.target_type:
				UnitData.TargetType.BUILDING:
					targets = "Só torres"
				UnitData.TargetType.ALL:
					targets = "Chão e ar"
				UnitData.TargetType.AIR:
					targets = "Só ar"
			out["Alvos"] = [targets if st.damage > 0 else "-", null, true]
	var skills = Catalogo.abilities(c)
	out["Habilidades"] = [", ".join(skills) if !skills.is_empty() else "nenhuma", null, true]
	return out


func _show_compare(a: CardData, b: CardData):
	var v = _popup(680)
	v.add_child(_title("⚖ Comparar"))
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 40)
	v.add_child(top)
	for c in [a, b]:
		var cv = CardView.make(c, 210, true)
		cv.locked = false
		cv.show_level = Progresso.is_owned(c)
		cv.tapped.connect(_show_card_popup)
		top.add_child(cv)
	var va = _compare_values(a)
	var vb = _compare_values(b)
	var order = ["Custo", "Nível", "Raridade", "Tipo", "Vida", "Dano", "Dano por segundo", "Vel. de ataque", "Alcance", "Velocidade", "Alvos", "Cura", "Escudo", "Raio", "Duração", "Habilidades"]
	var table = GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 8)
	table.add_theme_constant_override("v_separation", 4)
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(table)
	var green = Color(0.5, 1.0, 0.55)
	for key in order:
		if !va.has(key) and !vb.has(key):
			continue
		var ea: Array = va.get(key, ["-", null, true])
		var eb: Array = vb.get(key, ["-", null, true])
		var col_a = ThemeBuilder.COLOR_CREAM
		var col_b = ThemeBuilder.COLOR_CREAM
		if ea[1] != null and eb[1] != null and !is_equal_approx(float(ea[1]), float(eb[1])) and key != "Nível" and key != "Raridade":
			var a_better = (float(ea[1]) > float(eb[1])) == bool(ea[2])
			if a_better:
				col_a = green
			else:
				col_b = green
		var la = _wrap(str(ea[0]), 17, col_a)
		la.custom_minimum_size.x = 230
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		la.add_theme_font_override("font", ThemeDB.fallback_font)
		table.add_child(la)
		var lk = _label(key, 13, ThemeBuilder.COLOR_STAT_LABEL)
		lk.custom_minimum_size.x = 150
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lk.add_theme_font_override("font", ThemeDB.fallback_font)
		table.add_child(lk)
		var lb = _wrap(str(eb[0]), 17, col_b)
		lb.custom_minimum_size.x = 230
		lb.add_theme_font_override("font", ThemeDB.fallback_font)
		table.add_child(lb)
	v.add_child(_label("Em verde: o melhor número de cada linha.", 13, ThemeBuilder.COLOR_STAT_LABEL))
	v.add_child(_button("Voltar", _close.bind(v), 20))


func _begin_swap(index: int, popup_box: Node):
	_close(popup_box)
	if _tab != 1:
		_go_tab(1)
	_cards_view = 0
	_pending_card = null
	_pending_index = index
	_queue_refresh()


## frase clara de QUEM a carta ataca
func _target_text(card: CardData) -> String:
	if card.is_spell():
		var sp = card.spell_data
		return "🎯 Afeta: seus aliados" if (sp.affects_allies or !sp.affects_enemies) else "🎯 Afeta: inimigos na área (tropas, construções e torres)"
	var st = DeckBuilder.get_unit_stats(card)
	if st == null:
		return ""
	if st.damage <= 0:
		return "🎯 Não ataca ninguém"
	match st.target_type:
		UnitData.TargetType.BUILDING:
			return "🎯 Ataca: SÓ torres e construções. Ignora as tropas e vai direto."
		UnitData.TargetType.ALL:
			return "🎯 Ataca: tudo — tropas no chão, voadores, construções e torres. Briga com quem aparecer na frente."
		UnitData.TargetType.AIR:
			return "🎯 Ataca: só voadores"
	return "🎯 Ataca: tropas no chão, construções e torres. Briga com quem aparecer na frente. Não acerta voador."


func _stats_text(card: CardData, mult: float) -> String:
	if card.is_spell():
		var sp = card.spell_data
		var parts: Array = ["Área %d" % int(sp.radius)]
		if sp.damage > 0:
			parts.append("Dano %d" % int(round(sp.damage * mult)))
		if sp.heal_amount > 0:
			parts.append("Cura %d" % int(round(sp.heal_amount * mult)))
		if sp.duration > 0:
			parts.append("Dura %.0fs" % sp.duration)
		if sp.shield_amount > 0:
			parts.append("Escudo %d" % int(round(sp.shield_amount * mult)))
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


func _upgrade(card: CardData, popup_box: Node, deck_index: int = -1):
	if Progresso.upgrade(card):
		_close(popup_box)
		_queue_refresh()
		await _celebrate(card, "NÍVEL %d!" % Progresso.level(card), "+15% de vida e de dano", Color(0.5, 1.0, 0.6))
		_show_card_popup(card, deck_index)


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
		v.add_child(_wrap("🔒 Libera quando você chegar na Arena %d." % b.unlock_arena, 16, Color(1, 0.85, 0.5)))
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
	box.add_child(_button("📊 Ranking de jogadores", _show_ranking, 18))

	var last_arena = 1
	var shown_locked = 0
	_arena_divider(box, 1)
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


func _arena_divider(box: Node, arena_i: int):
	var info = ArenaManager.get_arena_info(arena_i)
	var p = _panel(box)
	p.add_child(_title("%s %s  ·  %d troféus" % [info.get("emoji", ""), info.get("name", ""), int(info.get("trophy_threshold", 0))]))
	var unlocks: Array = []
	for c in CardDatabase.all_cards:
		if c != null and c.unlock_arena == arena_i and !CustomContent.is_spawn_only(c):
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
		if b != null and b.unlock_arena == arena_i:
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
	p.add_child(_label("%s  ·  Nível %d  ·  🏆 %d" % [PlayerProfile.player_name, Progresso.player_level(), ArenaManager.get_trophies(PlayerProfile.player_name)], 20, ThemeBuilder.COLOR_GOLD))
	var facts = _grid(p, 2)
	for fact in ["Partidas: %d" % PlayerProfile.total_battles_played, "Vitórias: %d (%.0f%%)" % [PlayerProfile.total_battles_won, rate * (100.0 if rate <= 1.0 else 1.0)],
			"Maior sequência: %d" % int(Progresso.d["best_streak"]), "Temporada %d · faltam %.0f dias" % [SeasonManager.season_number, SeasonManager.get_days_remaining()]]:
		var fl = _label(fact, 15)
		fl.custom_minimum_size.x = 300
		fl.add_theme_font_override("font", ThemeDB.fallback_font)
		facts.add_child(fl)

	box.add_child(_label("Competição", 16, ThemeBuilder.COLOR_STAT_LABEL))
	var g1 = _grid(box, 3)
	_tile(g1, "🏆", "Ranking", _show_ranking)
	_tile(g1, "🔥", "Meta e cartas", _show_card_stats)
	_tile(g1, "⚖", "Assembleia", _show_assembleia, !Assembleia.pautas().is_empty(), "votação aberta" if !Assembleia.pautas().is_empty() else "")
	_tile(g1, "📰", "Gazeta", _show_jornal, Gazeta.unread() > 0, "%d novidade(s)" % Gazeta.unread() if Gazeta.unread() > 0 else "")
	_tile(g1, "📜", "Temporadas", _show_registro)
	_tile(g1, "🎬", "Replays", _show_replays)

	box.add_child(_label("Cartas e baralho", 16, ThemeBuilder.COLOR_STAT_LABEL))
	var g2 = _grid(box, 3)
	_tile(g2, "🌱", "Safra", _show_safra, Safra.mission_ready(), "PRÊMIO!" if Safra.mission_ready() else "")
	_tile(g2, "📈", "Minhas cartas", _show_my_cards)
	_tile(g2, "🔍", "Analisar baralho", _show_deck_check)
	_tile(g2, "💡", "Sugerir baralho", _show_deck_suggest)
	_tile(g2, "📅", "Desafio do dia", _show_daily, !Progresso.daily_done())
	_tile(g2, "🎨", "Criador", _goto.bind(CREATOR_SCENE))

	box.add_child(_label("Jogo", 16, ThemeBuilder.COLOR_STAT_LABEL))
	var g3 = _grid(box, 3)
	_tile(g3, "⚙", "Configurações", _show_settings)
	_tile(g3, "👤", "Trocar perfil", _goto.bind(PROFILE_SCENE))
	_tile(g3, "🚪", "Sair do jogo", get_tree().quit)


# ================================================================ poderes
func _build_powers(box: Node):
	var owned: Array = []
	for id in Progresso.POWERS:
		if Progresso.power_count(id) > 0:
			owned.append(id)
	var active: Array = []
	if Progresso.clock_boost_left() > 0:
		active.append("relogio")
	for id in ["ouro2", "xp2", "sorte"]:
		if Progresso.power_battles(id) > 0:
			active.append(id)
	if owned.is_empty() and active.is_empty():
		return
	var p = _panel(box)
	p.add_child(_label("⚡ Poderes (raros: vêm do torneio e da colheita do clã)", 15, ThemeBuilder.COLOR_STAT_LABEL))
	for id in active:
		var l = _label("", 16, Color(0.6, 1, 0.7))
		if id == "relogio":
			_live(l, func(): return "● Baús %dx mais rápidos por mais %s" % [Progresso.clock_boost_mult(), _clock(Progresso.clock_boost_left())])
		else:
			l.text = "● %s: restam %d %s" % [Progresso.POWERS[id]["nome"], Progresso.power_battles(id), "vitórias" if id == "sorte" else "partidas"]
		p.add_child(l)
	for id in owned:
		var def = Progresso.POWERS[id]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		p.add_child(row)
		var txt = _wrap("%s x%d\n%s" % [def["nome"], Progresso.power_count(id), def["desc"]], 15, Color.html(def["cor"]).lightened(0.3))
		row.add_child(txt)
		var b = _button("USAR", _use_power.bind(id), 18)
		b.custom_minimum_size.x = 120
		row.add_child(b)


func _use_power(id: String):
	var problem = Progresso.use_power(id)
	if problem != "":
		_toast(problem)
	else:
		Sfx.play("nivel")
		_toast("%s usado!" % Progresso.POWERS[id]["nome"])


# ================================================================ ABA: CLÃ
func _build_cla(box: Node):
	if Cla.mine() == "":
		box.add_child(_title("🛡 Clãs"))
		box.add_child(_wrap("Entre num clã pra pedir e doar cartas, jogar amistosos com os colegas e encher a colheita do clã (baús e um poder raro no topo). Dá pra sair e trocar quando quiser.", 16))
		var pos = 1
		for e in Cla.ranking():
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var l = _label("%dº  %s\n🏆 %d  ·  %d membros" % [pos, e[0], e[1], e[2]], 17)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(_button("Entrar", _join_clan.bind(str(e[0])), 18))
			pos += 1
		return
	Cla.tick()
	var clan = Cla.mine()
	var rank = Cla.ranking()
	var place = 1
	for i in rank.size():
		if rank[i][0] == clan:
			place = i + 1
	box.add_child(_title("🛡 %s" % clan))
	var sub = _label("%dº no ranking de clãs  ·  🏆 %d  ·  suas doações: %d" % [place, Cla.score(clan), int(Cla._d()["doacoes"])], 16, ThemeBuilder.COLOR_STAT_LABEL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	# colheita do clã
	var hp = _panel(box)
	var pts = Cla.harvest_points()
	hp.add_child(_label("🌾 Colheita do clã  ·  %d pontos  ·  zera em %.1f dia(s)" % [pts, Safra.days_to_next()], 16, ThemeBuilder.COLOR_STAT_LABEL))
	var bar = ProgressBar.new()
	bar.max_value = Cla.HARVEST_TIERS[2]
	bar.value = mini(pts, Cla.HARVEST_TIERS[2])
	bar.show_percentage = false
	bar.custom_minimum_size.y = 22
	hp.add_child(bar)
	var trow = HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	hp.add_child(trow)
	var prize_names = ["Saco de Milho", "Caixote da Feira", "Baú + PODER"]
	for tier in 3:
		var tb = _button("%d pts\n%s" % [Cla.HARVEST_TIERS[tier], prize_names[tier]], _claim_harvest.bind(tier), 15)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if Cla.harvest_claimed(tier):
			tb.text = "✔ pego"
			tb.disabled = true
		elif Cla.harvest_claimable(tier):
			tb.modulate = Color(1, 1, 0.6)
		else:
			tb.disabled = true
		trow.add_child(tb)
	hp.add_child(_wrap("Vitória dá 15 pontos, partida 5, doação 2. Os colegas também pontuam.", 14, ThemeBuilder.COLOR_STAT_LABEL))

	# pedir cartas
	var rp = _panel(box)
	rp.add_child(_label("🙏 Pedir cartas", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var req = Cla.current_request()
	if !req.is_empty():
		var rc = Catalogo.find_card(str(req["path"]))
		if rc != null:
			var rrow = HBoxContainer.new()
			rrow.add_theme_constant_override("separation", 12)
			rp.add_child(rrow)
			var rv = CardView.make(rc, 96)
			rv.tapped.connect(_show_card_popup)
			rrow.add_child(rv)
			var done = int(req["got"]) >= int(req["cap"])
			rrow.add_child(_wrap("%s\nRecebidas: %d de %d%s" % [rc.card_name, int(req["got"]), int(req["cap"]), "  ✔ completo" if done else "\nOs colegas doam aos poucos, e mais rápido se você jogar."], 16))
	if Cla.can_request():
		rp.add_child(_button("Escolher carta pra pedir", _show_request_picker, 18))
	else:
		var wl = _label("", 15)
		_live(wl, func(): return "Novo pedido em " + _clock(Cla.request_wait()))
		rp.add_child(wl)

	# doar
	var dp = _panel(box)
	dp.add_child(_label("🎁 Pedidos dos colegas (doar dá ouro, XP e pontos)", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var reqs = Cla.bot_requests()
	if reqs.is_empty():
		dp.add_child(_label("Ninguém pedindo nada agora. Já já aparece.", 15))
	for i in reqs.size():
		var r = reqs[i]
		var dc = Catalogo.find_card(str(r["path"]))
		if dc == null:
			continue
		var drow = HBoxContainer.new()
		drow.add_theme_constant_override("separation", 10)
		dp.add_child(drow)
		var dv = CardView.make(dc, 84)
		dv.show_level = false
		dv.tapped.connect(_show_card_popup)
		drow.add_child(dv)
		drow.add_child(_wrap("%s pede %s\nfaltam %d  ·  você tem %d sobrando" % [str(r["quem"]), dc.card_name, int(r["falta"]), Progresso.copies(dc)], 15))
		var rar = Catalogo.rarity_of(dc)
		var db = _button("Doar 1\n+💰%d" % Cla.DONATE_GOLD[rar], _donate.bind(i), 15)
		db.custom_minimum_size.x = 120
		db.disabled = Progresso.copies(dc) < 1
		drow.add_child(db)

	# mural
	var cp = _panel(box)
	cp.add_child(_label("💬 Mural do clã", 17, ThemeBuilder.COLOR_STAT_LABEL))
	var chat: Array = Cla._d()["chat"]
	for line in chat.slice(maxi(0, chat.size() - 7)):
		cp.add_child(_wrap(str(line), 15))

	# membros
	var mp = _panel(box)
	var list = Cla.members(clan)
	mp.add_child(_label("👥 Membros (%d)  ·  toque num colega pra ver o baralho ou jogar amistoso" % list.size(), 15, ThemeBuilder.COLOR_STAT_LABEL))
	for i in list.size():
		var who = str(list[i])
		var is_me = who == PlayerProfile.player_name
		var mb = _button("%s%s   ·   🏆 %d   ·   doou %d" % ["👑 " if i == 0 else "", who, ArenaManager.get_trophies(who), int(Cla._d()["doacoes"]) if is_me else Cla.fake_donations(who)], _show_bot.bind(who), 15)
		mb.custom_minimum_size.y = 46
		mb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if is_me:
			mb.modulate = Color(1, 1, 0.6)
			mb.disabled = true
		mp.add_child(mb)
	box.add_child(_button("🏅 Ranking de clãs", _show_clan_ranking, 18))
	box.add_child(_button("Sair do clã", _leave_clan, 16))


func _join_clan(clan: String):
	Cla.join(clan)
	Sfx.play("nivel")


func _leave_clan():
	Cla.leave()


func _claim_harvest(tier: int):
	var loot = Cla.claim_harvest(tier)
	if !loot.is_empty():
		_show_loot("🌾 Colheita do clã", loot, Color(0.9, 0.8, 0.4))


func _donate(i: int):
	var result = Cla.donate(i)
	if !result.is_empty():
		Sfx.play("moeda")
		_toast("Doado! +💰%d  +%d XP  +2 pontos pro clã" % [int(result["ouro"]), int(result["xp"])])


func _show_request_picker():
	var v = _popup(660, true)
	v.add_child(_title("Pedir qual carta?"))
	v.add_child(_wrap("Normal: até 12 cópias · Rara: até 4 · Épica: 1. Lendária e Mística não dá pra pedir.", 15, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(v, 4)
	var cards = Progresso.owned_cards().filter(func(c): return Cla.REQUEST_CAP[Catalogo.rarity_of(c)] > 0 and Progresso.copies_needed(c) > 0)
	cards.sort_custom(func(a, b): return Catalogo.rarity_of(a) < Catalogo.rarity_of(b) if Catalogo.rarity_of(a) != Catalogo.rarity_of(b) else a.cost < b.cost)
	for c in cards:
		var cv = CardView.make(c, 146)
		cv.badge = "%d/%d" % [Progresso.copies(c), Progresso.copies_needed(c)]
		cv.tapped.connect(_request_card.bind(v))
		g.add_child(cv)
	v.add_child(_button("Cancelar", _close.bind(v)))


func _request_card(card: CardData, popup_box: Node):
	if Cla.request(card):
		_close(popup_box)
		_toast("Pedido feito! Os colegas vão doando aos poucos.")


func _show_clan_ranking():
	var v = _popup(620, true)
	v.add_child(_title("🏅 Ranking de clãs"))
	var pos = 1
	for e in Cla.ranking():
		v.add_child(_label("%dº  %s   ·   🏆 %d   ·   %d membros" % [pos, e[0], e[1], e[2]], 17, Color(1, 1, 0.6) if e[0] == Cla.mine() else ThemeBuilder.COLOR_CREAM))
		pos += 1
	v.add_child(_button("Fechar", _close.bind(v)))


# ================================================================ ranking, perfil de bot, estatísticas, replays
const RANK_VIEWS = ["Perto de mim", "Top 20", "Clãs", "Temporada"]


func _ranked_names() -> Array:
	var names: Array = []
	for n in BotSimulator.roster_names:
		if !names.has(n):
			names.append(n)
	if !names.has(PlayerProfile.player_name):
		names.append(PlayerProfile.player_name)
	names.sort_custom(func(a, b): return ArenaManager.get_trophies(a) > ArenaManager.get_trophies(b))
	return names


func _rank_row(parent: Node, pos: int, who: String):
	var medals = ["🥇", "🥈", "🥉"]
	var arena = ArenaManager.get_arena_info(ArenaManager.get_participant_arena(who))
	var is_me = who == PlayerProfile.player_name
	var b = _button("%s  %s%s" % [medals[pos] if pos < 3 else "%dº" % (pos + 1), who, "  (você)" if is_me else ""], _show_bot.bind(who), 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 58
	if is_me:
		b.modulate = Color(1, 1, 0.6)
	var right = _label("%s 🏆 %d " % [arena.get("emoji", ""), ArenaManager.get_trophies(who)], 18, ThemeBuilder.COLOR_GOLD)
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(right)
	parent.add_child(b)


func _show_ranking(view: int = 0):
	var v = _popup(660, true)
	v.add_child(_title("🏆 Ranking"))
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for i in RANK_VIEWS.size():
		var tb = _button(RANK_VIEWS[i], _switch_ranking.bind(v, i), 16)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = 56
		tb.modulate = Color(1, 1, 0.75) if i == view else Color(0.62, 0.6, 0.56)
		tabs.add_child(tb)
	var names = _ranked_names()
	var my_pos = names.find(PlayerProfile.player_name)
	var my_tr = ArenaManager.get_trophies(PlayerProfile.player_name)
	match view:
		0, 1:
			# cartão "onde eu estou"
			var p = _panel(v)
			p.add_child(_label("Você está em %dº de %d" % [my_pos + 1, names.size()], 24, Color(1, 1, 0.6)))
			var info = "🏆 %d troféus" % my_tr
			if my_pos > 0:
				var above = str(names[my_pos - 1])
				info += "  ·  faltam %d pra passar %s" % [maxi(1, ArenaManager.get_trophies(above) - my_tr + 1), above]
			else:
				info += "  ·  você é o líder!"
			p.add_child(_wrap(info, 16))
			var from = 0
			var to = mini(20, names.size())
			if view == 0:
				from = maxi(0, my_pos - 5)
				to = mini(names.size(), my_pos + 6)
			v.add_child(_label("Toque num nome pra ver o baralho dele.", 14, ThemeBuilder.COLOR_STAT_LABEL))
			for i in range(from, to):
				_rank_row(v, i, str(names[i]))
		2:
			var clans = Cla.ranking()
			for i in clans.size():
				var c = clans[i]
				var mine = str(c[0]) == Cla.mine()
				var l = _label("%dº  🛡 %s%s   ·   %d pontos   ·   %d membros" % [i + 1, str(c[0]), "  (seu clã)" if mine else "", int(c[1]), int(c[2])], 17, Color(1, 1, 0.6) if mine else ThemeBuilder.COLOR_CREAM)
				_panel(v).add_child(l)
		3:
			var now = Registro.snapshot()
			var sp = _panel(v)
			sp.add_child(_label("Temporada %d" % SeasonManager.season_number, 24, ThemeBuilder.COLOR_GOLD))
			sp.add_child(_label("Faltam %.0f dia(s) pra acabar" % SeasonManager.get_days_remaining(), 17))
			_registro_summary(sp, now)
			var fame = Registro.hall_of_fame()
			if !fame.is_empty():
				var fp = _panel(v)
				fp.add_child(_label("🏅 Quem mais ganhou temporada", 17, ThemeBuilder.COLOR_STAT_LABEL))
				for e in fame.slice(0, 5):
					fp.add_child(_label("%s  ·  %d título(s)" % [e[0], e[1]], 17, Color(1, 1, 0.7) if e[0] == PlayerProfile.player_name else ThemeBuilder.COLOR_CREAM))
			var history: Array = Registro.entries().duplicate()
			history.reverse()
			if history.is_empty():
				v.add_child(_wrap("Quando esta temporada terminar, o resultado fica guardado aqui: campeão, sua colocação e suas cartas mais usadas.", 15, ThemeBuilder.COLOR_STAT_LABEL))
			for e in history.slice(0, 6):
				var hp = _panel(v)
				hp.add_child(_label("Temporada %d  ·  terminou em %s" % [int(e["temporada"]), str(e["fim"])], 17, ThemeBuilder.COLOR_GOLD))
				_registro_summary(hp, e)
				hp.add_child(_button("Ver tabela completa", _show_registro_table.bind(e), 15))
	v.add_child(_button("Fechar", _close.bind(v)))


func _switch_ranking(popup_box: Node, view: int):
	_close(popup_box)
	_show_ranking.call_deferred(view)


func _show_bot(who: String):
	if who == PlayerProfile.player_name:
		return
	var prof: AIProfile = BotLearning.get_or_create_profile(who)
	var v = _popup(640)
	v.add_child(_title(who))
	var arena = ArenaManager.get_arena_info(ArenaManager.get_participant_arena(who))
	var rec = Leaderboard.get_record(who)
	v.add_child(_label("🏆 %d  ·  %s %s  ·  %s" % [ArenaManager.get_trophies(who), arena.get("emoji", ""), arena.get("name", ""), Cla.clan_of(who)], 16))
	v.add_child(_label("Estilo: %s  ·  nesta temporada: %dV %dD" % [prof.get_archetype_name(), int(rec.get("wins", 0)), int(rec.get("losses", 0))], 16, ThemeBuilder.COLOR_STAT_LABEL))
	var g = _grid(v, 4)
	for c in prof.deck:
		if c == null:
			continue
		var cv = CardView.make(c, 140, true)
		cv.level_override = prof.get_card_level(c)
		cv.mastery_override = 0
		cv.tapped.connect(_show_card_popup.bind(-1, prof.get_card_level(c), who))
		g.add_child(cv)
	v.add_child(_label("Toque numa carta pra ver os números no nível dele.", 14, ThemeBuilder.COLOR_STAT_LABEL))
	if prof.equipped_base != null:
		v.add_child(_label("🏰 Torre: %s  ·  nível %d" % [prof.equipped_base.base_name, Progresso.bot_tower_level(prof)], 16, ThemeBuilder.COLOR_STAT_LABEL))
	var history = Registro.history_of(who)
	if !history.is_empty():
		v.add_child(_label("Última temporada: %dº lugar" % int(history[0][1]), 15, ThemeBuilder.COLOR_STAT_LABEL))
	if Cla.mine() != "" and Cla.clan_of(who) == Cla.mine():
		var fb = _button("🤝 Jogar amistoso", _friendly.bind(who), 22)
		fb.modulate = Color(1.0, 0.92, 0.6)
		v.add_child(fb)
	v.add_child(_button("Fechar", _close.bind(v)))


func _friendly(who: String):
	Cla.start_friendly(get_tree(), who)


func _show_card_stats():
	var v = _popup(680, true)
	v.add_child(_title("📈 Meta e cartas da temporada"))
	v.add_child(_wrap("Contando todas as partidas (suas e dos bots): quantas vezes cada carta foi jogada e quanto ela vence.", 15, ThemeBuilder.COLOR_STAT_LABEL))
	_build_meta(v)
	var all = SeasonStats.get_all_card_stats().filter(func(e): return e["card"] != null)
	if all.is_empty():
		v.add_child(_label("Ainda sem partidas nesta temporada.", 16))
	for section in [["🔥 Mais vitoriosas", func(a, b): return a["win_rate"] > b["win_rate"]], ["🧊 Menos vitoriosas", func(a, b): return a["win_rate"] < b["win_rate"]], ["📣 Mais jogadas", func(a, b): return a["times_played"] > b["times_played"]]]:
		var list = all.filter(func(e): return e["wins"] + e["losses"] >= 3) if section[0] != "📣 Mais jogadas" else all.duplicate()
		if list.is_empty():
			continue
		list.sort_custom(section[1])
		v.add_child(_label(section[0], 18, ThemeBuilder.COLOR_GOLD))
		var g = _grid(v, 4)
		for e in list.slice(0, 4):
			var cv = CardView.make(e["card"], 150)
			cv.show_level = false
			cv.mastery_override = 0
			cv.badge = "%d%% · %dx" % [int(round(e["win_rate"] * 100)), int(e["times_played"])]
			cv.tapped.connect(_show_card_popup)
			g.add_child(cv)
	v.add_child(_button("Fechar", _close.bind(v)))


## META: os 3 baralhos mais jogados (bots + você) e as cartas mais usadas.
## Como quase ninguém tem o baralho idêntico, cada "baralho do meta" é montado
## em volta de uma carta-chave: as 7 cartas que mais aparecem junto com ela.
func _meta_decks() -> Dictionary:
	var decks: Array = []
	for n in BotSimulator.roster_names:
		var raw: Dictionary = BotLearning._load_raw(str(n))
		var paths: Array = raw.get("deck_paths", [])
		if paths.size() >= 5:
			decks.append(paths)
	var mine: Array = Progresso.deck_paths(Progresso.active_deck())
	if mine.size() >= 5:
		decks.append(mine)
	var usage: Dictionary = {}
	for dk in decks:
		for path in dk:
			usage[path] = int(usage.get(path, 0)) + 1
	var order: Array = usage.keys()
	order.sort_custom(func(a, b): return usage[a] > usage[b] if usage[a] != usage[b] else str(a) < str(b))
	var metas: Array = []
	for anchor in order:
		if metas.size() >= 3:
			break
		var together: Dictionary = {}
		var users = 0
		for dk in decks:
			if dk.has(anchor):
				users += 1
				for path in dk:
					together[path] = int(together.get(path, 0)) + 1
		var picks: Array = together.keys()
		picks.sort_custom(func(a, b): return together[a] > together[b] if together[a] != together[b] else str(a) < str(b))
		picks = picks.slice(0, Progresso.DECK_SIZE)
		var repeated = false
		for m in metas:
			if picks.filter(func(x): return m["cartas"].has(x)).size() >= 5:
				repeated = true
		if repeated or picks.size() < 5:
			continue
		metas.append({"ancora": anchor, "cartas": picks, "usam": users})
	return {"total": decks.size(), "metas": metas, "top": order.slice(0, 8), "uso": usage}


func _build_meta(v: Node):
	var meta = _meta_decks()
	var total = int(meta["total"])
	if total <= 0:
		return
	v.add_child(_label("🔥 Cartas do meta (as mais usadas nos baralhos)", 18, ThemeBuilder.COLOR_GOLD))
	var tg = _grid(v, 4)
	for path in meta["top"]:
		var c = Catalogo.find_card(str(path))
		if c == null:
			continue
		var cv = CardView.make(c, 150)
		cv.show_level = false
		cv.mastery_override = 0
		cv.badge = "%d%% usam" % int(round(100.0 * int(meta["uso"][path]) / total))
		cv.tapped.connect(_show_card_popup)
		tg.add_child(cv)
	var metas: Array = meta["metas"]
	for i in metas.size():
		var m = metas[i]
		var anchor_card = Catalogo.find_card(str(m["ancora"]))
		var p = _panel(v)
		p.add_child(_label("Baralho do meta nº %d  ·  %s" % [i + 1, anchor_card.card_name if anchor_card != null else "?"], 18, ThemeBuilder.COLOR_GOLD))
		var cards: Array = []
		for path in m["cartas"]:
			var c = Catalogo.find_card(str(path))
			if c != null:
				cards.append(c)
		var have = cards.filter(func(c): return Progresso.is_owned(c)).size()
		var cost = 0.0
		for c in cards:
			cost += c.cost
		p.add_child(_label("Usado por %d de %d jogadores (%d%%)  ·  custo médio %.0f  ·  você tem %d/%d" % [int(m["usam"]), total, int(round(100.0 * int(m["usam"]) / total)), cost / maxf(1.0, cards.size()), have, cards.size()], 14, ThemeBuilder.COLOR_STAT_LABEL))
		var g = _grid(p, 4)
		for c in cards:
			var cv = CardView.make(c, 140)
			cv.show_level = false
			cv.mastery_override = 0
			cv.locked = false
			if !Progresso.is_owned(c):
				cv.badge = "não tem"
				cv.badge_color = Color(1, 0.6, 0.5)
			cv.tapped.connect(_show_card_popup)
			g.add_child(cv)
		var cb = _button("Copiar pro Baralho %d" % (_deck_slot + 1), _copy_meta.bind(cards, v), 17)
		cb.disabled = have < Progresso.DECK_SIZE
		if cb.disabled:
			cb.text = "Copiar (faltam %d cartas)" % (Progresso.DECK_SIZE - have)
		p.add_child(cb)


func _copy_meta(cards: Array, popup_box: Node):
	for i in mini(cards.size(), Progresso.DECK_SIZE):
		Progresso.set_deck_card(_deck_slot, i, cards[i])
	# segunda passada: a troca pode ter empurrado carta de lugar
	for i in mini(cards.size(), Progresso.DECK_SIZE):
		Progresso.set_deck_card(_deck_slot, i, cards[i])
	_close(popup_box)
	_toast("Baralho do meta copiado pro Baralho %d!" % (_deck_slot + 1))
	_queue_refresh()


# ================================================================ comemoração (carta nova / subiu de nível)
var _celebrating := false


## animação rápida e bonita: raios girando, carta "pula" pra tela, título.
## Dura ~1,3 s; tocar fecha na hora. Se já tem uma rodando, espera a vez.
func _celebrate(card: CardData, title_text: String, sub_text: String, color: Color):
	while _celebrating:
		await get_tree().process_frame
	_celebrating = true
	Sfx.play("nivel", 0.05, 2.0)
	var layer = CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var size_now = get_viewport_rect().size
	var mid = size_now * 0.5 + Vector2(0, -40)
	var burst = BurstView.new()
	burst.color = color
	burst.position = mid
	layer.add_child(burst)
	var cv = CardView.make(card, 300, true)
	cv.locked = false
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cv)
	cv.size = cv.custom_minimum_size
	cv.pivot_offset = cv.custom_minimum_size * 0.5
	cv.position = mid - cv.custom_minimum_size * 0.5
	cv.scale = Vector2(0.2, 0.2)
	cv.rotation = -0.5
	var title = _label(title_text, 54, color.lightened(0.25))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size_now.x, 70)
	title.position = Vector2(0, mid.y - cv.custom_minimum_size.y * 0.5 - 110)
	title.modulate.a = 0.0
	layer.add_child(title)
	var sub = _label("%s\n%s" % [card.card_name, sub_text], 22, Color(1, 0.95, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size_now.x, 70)
	sub.position = Vector2(0, mid.y + cv.custom_minimum_size.y * 0.5 + 24)
	sub.modulate.a = 0.0
	layer.add_child(sub)
	var tw = layer.create_tween().set_parallel(true)
	tw.tween_property(bg, "color:a", 0.82, 0.15)
	tw.tween_property(cv, "scale", Vector2(1.12, 1.12), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.2).set_delay(0.15)
	tw.tween_property(sub, "modulate:a", 1.0, 0.2).set_delay(0.25)
	tw.chain().tween_property(cv, "scale", Vector2(1.0, 1.0), 0.12)
	var state = {"done": false}
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: state["done"] = true)
	var waited = 0.0
	while waited < 1.1 and !state["done"]:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_instance_valid(layer):
		var out = layer.create_tween().set_parallel(true)
		for node in [bg, cv, title, sub, burst]:
			out.tween_property(node, "modulate:a", 0.0, 0.12)
		await out.finished
		layer.queue_free()
	_celebrating = false
	_show_pending.call_deferred()


# ================================================================ GAZETA DA ROÇA (jornal)
func _news_card(parent: Node, item: Dictionary, big: bool):
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#f3e6c8") if !big else Color("#fff3d0")
	sb.border_color = Color("#3a2414")
	sb.set_border_width_all(2)
	sb.border_width_left = 10
	sb.border_color = Color.html(str(item.get("cor", "#3a2414")))
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var tag_text = str(item.get("tag", ""))
	if str(item.get("dia", "")) != "":
		tag_text += "  ·  " + str(item["dia"])
	var tag = _label(tag_text, 13, Color.html(str(item.get("cor", "#3a2414"))).darkened(0.25))
	tag.add_theme_font_override("font", ThemeDB.fallback_font)
	col.add_child(tag)
	var head = _wrap(str(item.get("titulo", "")), 25 if big else 19, Color("#2a1608"))
	col.add_child(head)
	var body = _wrap(str(item.get("texto", "")), 15, Color("#4a3420"))
	body.add_theme_font_override("font", ThemeDB.fallback_font)
	col.add_child(body)
	var c = Catalogo.find_card(str(item.get("carta", "")))
	if c != null:
		var cv = CardView.make(c, 96)
		cv.show_level = false
		cv.mastery_override = 0
		cv.locked = false
		cv.tapped.connect(_show_card_popup)
		row.add_child(cv)


func _show_jornal():
	var v = _popup(670, true)
	# cabeçalho de jornal
	var mast = PanelContainer.new()
	var msb = StyleBoxFlat.new()
	msb.bg_color = Color("#f3e6c8")
	msb.border_color = Color("#2a1608")
	msb.border_width_top = 4
	msb.border_width_bottom = 4
	msb.content_margin_top = 8
	msb.content_margin_bottom = 8
	mast.add_theme_stylebox_override("panel", msb)
	v.add_child(mast)
	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 0)
	mast.add_child(mv)
	var name_l = _label("A GAZETA DA ROÇA", 40, Color("#2a1608"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(name_l)
	var edition = _label("Edição de %s  ·  Temporada %d  ·  \"Se aconteceu no pasto, saiu aqui\"" % [Time.get_date_string_from_system(), SeasonManager.season_number], 13, Color("#5a4028"))
	edition.add_theme_font_override("font", ThemeDB.fallback_font)
	edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(edition)

	var heads = Gazeta.headlines()
	var bigs = heads.filter(func(h): return h.get("grande", false))
	var smalls = heads.filter(func(h): return !h.get("grande", false))
	var events = Gazeta.events()
	if !bigs.is_empty():
		v.add_child(_label("MANCHETES", 16, ThemeBuilder.COLOR_GOLD))
		for h in bigs:
			_news_card(v, h, true)
	if !events.is_empty():
		v.add_child(_label("ACONTECEU", 16, ThemeBuilder.COLOR_GOLD))
		for e in events.slice(0, 6):
			_news_card(v, e, false)
	if !smalls.is_empty():
		v.add_child(_label("NO PASTO HOJE", 16, ThemeBuilder.COLOR_GOLD))
		for h in smalls:
			_news_card(v, h, false)
	var quote = Journal.get_random_bot_quote() if Journal.has_method("get_random_bot_quote") else ""
	if quote != "":
		v.add_child(_label("DISSE ME DISSE", 16, ThemeBuilder.COLOR_GOLD))
		_news_card(v, {"tag": "FOFOCA", "cor": "#8a6ad8", "titulo": quote, "texto": ""}, false)
	if heads.is_empty() and events.is_empty():
		v.add_child(_wrap("Dia parado no pasto. Jogue umas partidas que a notícia aparece.", 16))
	Gazeta.mark_read()
	v.add_child(_button("Fechar", _close_loot.bind(v)))


# ================================================================ ASSEMBLEIA DAS CARTAS (buff e nerf por votação)
func _show_assembly_result(r: Dictionary):
	var v = _popup(620)
	v.add_child(_title("⚖ Resultado da Assembleia"))
	var c = Catalogo.find_card(str(r.get("carta", "")))
	if c != null:
		var cv = CardView.make(c, 200, true)
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.tapped.connect(_show_card_popup)
		v.add_child(cv)
	var l = _wrap(str(r.get("texto", "")), 20, Color(1, 0.95, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(_button("Entendi", _close_loot.bind(v), 20))


func _show_assembleia():
	Assembleia.sync()
	var v = _popup(660, true)
	v.add_child(_title("⚖ Assembleia das cartas"))
	v.add_child(_wrap("A cada 3 dias os bots abrem uma pauta (pelos números da temporada) e você pode abrir UMA sua. Todo mundo vota: os bots pesam o quanto a carta vence, o quanto é usada e se ELES usam -- quem não tem opinião forte fica neutro, e você também pode. Seu voto vale por %d. Pauta aprovada muda a carta só um pouco (2%% a 4%%, conforme o tipo)." % Assembleia.PLAYER_WEIGHT, 15, ThemeBuilder.COLOR_STAT_LABEL))
	var left = _label("", 16, Color(1, 0.9, 0.6))
	_live(left, func(): return "⏳ A votação fecha em " + _clock(Assembleia.seconds_left()))
	v.add_child(left)
	var list = Assembleia.pautas()
	if list.is_empty():
		v.add_child(_label("Nenhuma pauta aberta agora.", 16))
	for i in list.size():
		var pa: Dictionary = list[i]
		var c = Catalogo.find_card(str(pa["path"]))
		if c == null:
			continue
		var is_buff = str(pa["tipo"]) == "buff"
		var p = _panel(v)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var cv = CardView.make(c, 150, true)
		cv.show_level = false
		cv.mastery_override = 0
		cv.tapped.connect(_show_card_popup)
		row.add_child(cv)
		var side = VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(side)
		side.add_child(_wrap("%s em %s" % ["⬆ BUFF" if is_buff else "⬇ NERF", c.card_name], 21, Color(0.5, 1, 0.6) if is_buff else Color(1, 0.6, 0.5)))
		side.add_child(_wrap("Se passar: %s" % Assembleia.effect_text(c, str(pa["tipo"])), 15))
		side.add_child(_wrap("Pedido de %s" % str(pa["autor"]), 14, ThemeBuilder.COLOR_STAT_LABEL))
		side.add_child(_wrap("Vence %d%% das partidas  ·  está em %d%% dos baralhos" % [int(round(Assembleia.card_win_rate(c.resource_path) * 100)), int(round(Assembleia.usage_share(c.resource_path) * 100))], 14, ThemeBuilder.COLOR_STAT_LABEL))
		var vt = Assembleia.votes(pa)
		var bar = ProgressBar.new()
		bar.max_value = maxi(1, vt[0] + vt[1])
		bar.value = vt[0]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 22
		p.add_child(bar)
		p.add_child(_label("👍 %d a favor  ·  👎 %d contra  ·  😐 %d neutros  ·  %s" % [vt[0], vt[1], vt[2], "passando" if vt[0] > vt[1] else "sendo recusada"], 15, Color(0.6, 1, 0.6) if vt[0] > vt[1] else Color(1, 0.7, 0.6)))
		var mine = int(pa.get("voto", 0))
		var vr = HBoxContainer.new()
		vr.add_theme_constant_override("separation", 8)
		p.add_child(vr)
		var yb = _button("👍 A favor" + ("  ✔" if mine > 0 else ""), _vote_assembly.bind(v, i, 1), 18)
		yb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yb.modulate = Color(0.7, 1, 0.7) if mine > 0 else Color(1, 1, 1)
		vr.add_child(yb)
		var nb = _button("👎 Contra" + ("  ✔" if mine < 0 else ""), _vote_assembly.bind(v, i, -1), 18)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.modulate = Color(1, 0.7, 0.65) if mine < 0 else Color(1, 1, 1)
		vr.add_child(nb)
		var ub = _button("😐 Neutro" + ("  ✔" if mine == 0 else ""), _vote_assembly.bind(v, i, 0), 18)
		ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ub.modulate = Color(1, 1, 0.75) if mine == 0 else Color(1, 1, 1)
		vr.add_child(ub)
	var pb = _button("📣 Abrir minha pauta (1 a cada 3 dias)" if Assembleia.can_propose() else "Você já abriu sua pauta nestes 3 dias", _pick_assembly_card.bind(v), 19)
	pb.disabled = !Assembleia.can_propose()
	if !pb.disabled:
		pb.modulate = Color(1.0, 0.92, 0.6)
	v.add_child(pb)
	# cartas já mexidas
	var adjusted: Array = []
	for c in CardDatabase.all_cards:
		if c != null and Assembleia.adjust_text(c) != "":
			adjusted.append("%s: %s" % [c.card_name, Assembleia.adjust_text(c)])
	if !adjusted.is_empty():
		var ap = _panel(v)
		ap.add_child(_label("Cartas já ajustadas", 17, ThemeBuilder.COLOR_GOLD))
		for t in adjusted:
			ap.add_child(_wrap("• " + t, 15))
	var hist = Assembleia.history()
	if !hist.is_empty():
		var hp = _panel(v)
		hp.add_child(_label("Últimas votações", 17, ThemeBuilder.COLOR_GOLD))
		for h in hist:
			hp.add_child(_wrap("%s %s em %s (%s): %d a %d  ·  pedido de %s" % ["✔" if h["passou"] else "✖", "BUFF" if str(h["tipo"]) == "buff" else "NERF", str(h["carta"]), "passou" if h["passou"] else "recusada", int(h["sim"]), int(h["nao"]), str(h["autor"])], 14, Color(0.7, 1, 0.7) if h["passou"] else Color(0.85, 0.8, 0.75)))
	v.add_child(_button("Fechar", _close.bind(v)))


func _vote_assembly(popup_box: Node, index: int, value: int):
	Assembleia.vote(index, value)
	_close(popup_box)
	_show_assembleia.call_deferred()


func _pick_assembly_card(popup_box: Node):
	_close(popup_box)
	var v = _popup(660, true)
	v.add_child(_title("Qual carta entra em pauta?"))
	v.add_child(_label("Toque numa carta.", 15, ThemeBuilder.COLOR_STAT_LABEL))
	var cards: Array = []
	for c in CardDatabase.all_cards:
		if c != null and !CustomContent.is_spawn_only(c):
			cards.append(c)
	cards.sort_custom(func(a, b): return a.cost < b.cost if a.cost != b.cost else a.card_name < b.card_name)
	var g = _grid(v, 4)
	for c in cards:
		var cv = CardView.make(c, 146)
		cv.show_level = false
		cv.mastery_override = 0
		cv.locked = false
		cv.tapped.connect(_pick_assembly_kind.bind(v))
		g.add_child(cv)
	v.add_child(_button("Cancelar", _close.bind(v)))


func _pick_assembly_kind(card: CardData, popup_box: Node):
	_close(popup_box)
	var v = _popup(600)
	v.add_child(_title(card.card_name))
	v.add_child(_wrap("O que você quer pedir pra essa carta?", 17))
	var bb = _button("⬆ BUFF  (%s)" % Assembleia.effect_text(card, "buff"), _confirm_assembly.bind(card, "buff", v), 20)
	bb.modulate = Color(0.7, 1, 0.7)
	v.add_child(bb)
	var nb = _button("⬇ NERF  (%s)" % Assembleia.effect_text(card, "nerf"), _confirm_assembly.bind(card, "nerf", v), 20)
	nb.modulate = Color(1, 0.7, 0.65)
	v.add_child(nb)
	v.add_child(_button("Cancelar", _close.bind(v)))


func _confirm_assembly(card: CardData, kind: String, popup_box: Node):
	var problem = Assembleia.propose(card, kind)
	_close(popup_box)
	if problem != "":
		_toast(problem)
	_show_assembleia.call_deferred()


func _load_replays() -> Array:
	if !FileAccess.file_exists("user://replays.json"):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://replays.json"))
	return parsed if parsed is Array else []


func _show_replays():
	var v = _popup(640, true)
	v.add_child(_title("🎬 Replays salvos"))
	var replays = _load_replays()
	if replays.is_empty():
		v.add_child(_wrap("Nenhum replay ainda. No fim de uma partida, toque em \"Salvar Replay\".", 16))
	for i in range(replays.size() - 1, -1, -1):
		var r: Dictionary = replays[i]
		var won = bool(r.get("player_won", false))
		var p = _panel(v)
		p.add_child(_label("%s  contra %s" % ["VITÓRIA" if won else "Derrota", str(r.get("bot_name", "?"))], 18, Color(0.6, 1, 0.6) if won else Color(1, 0.6, 0.55)))
		p.add_child(_label(str(r.get("date", "")), 14, ThemeBuilder.COLOR_STAT_LABEL))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		p.add_child(row)
		var wb = _button("▶ Assistir", _watch_replay.bind(r), 18)
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(wb)
		row.add_child(_button("🗑", _delete_replay.bind(i, v), 18))
	v.add_child(_button("Fechar", _close.bind(v)))


func _watch_replay(r: Dictionary):
	MatchSetup.clear_special()
	MatchSetup.replay_data = r
	get_tree().change_scene_to_file(MatchSetup.BATTLE_SCENE)


func _delete_replay(index: int, popup_box: Node):
	var replays = _load_replays()
	if index >= 0 and index < replays.size():
		replays.remove_at(index)
		var f = FileAccess.open("user://replays.json", FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(replays))
	_close(popup_box)
	_show_replays.call_deferred()


# ================================================================ registro das temporadas
func _show_registro():
	var v = _popup(660, true)
	v.add_child(_title("📜 Registro das temporadas"))
	var now = Registro.snapshot()
	var p = _panel(v)
	p.add_child(_label("Temporada %d (em andamento · faltam %.0f dias)" % [SeasonManager.season_number, SeasonManager.get_days_remaining()], 18, ThemeBuilder.COLOR_GOLD))
	_registro_summary(p, now)
	p.add_child(_button("Ver tabela", _show_registro_table.bind(now), 16))
	var fame = Registro.hall_of_fame()
	if !fame.is_empty():
		var fp = _panel(v)
		fp.add_child(_label("🏅 Hall da fama (títulos de temporada)", 17, ThemeBuilder.COLOR_STAT_LABEL))
		for e in fame.slice(0, 5):
			fp.add_child(_label("%s  ·  %d título(s)" % [e[0], e[1]], 17, Color(1, 1, 0.7) if e[0] == PlayerProfile.player_name else ThemeBuilder.COLOR_CREAM))
	var history: Array = Registro.entries().duplicate()
	history.reverse()
	if history.is_empty():
		v.add_child(_wrap("Quando a temporada atual terminar, ela fica guardada aqui: quem foi campeão, a sua colocação, vitórias e derrotas de todo mundo e as cartas que você mais usou.", 16))
	for e in history:
		var hp = _panel(v)
		hp.add_child(_label("Temporada %d  ·  terminou em %s" % [int(e["temporada"]), str(e["fim"])], 18, ThemeBuilder.COLOR_GOLD))
		_registro_summary(hp, e)
		hp.add_child(_button("Ver tabela completa", _show_registro_table.bind(e), 16))
	v.add_child(_button("Fechar", _close.bind(v)))


func _registro_summary(parent: Node, e: Dictionary):
	var rank: Array = e["ranking"]
	var medals = ["🥇", "🥈", "🥉"]
	var podium: Array = []
	for i in mini(3, rank.size()):
		podium.append("%s %s (%d)" % [medals[i], str(rank[i][0]), int(rank[i][1])])
	parent.add_child(_wrap("   ".join(podium), 16))
	var me: Dictionary = e["jogador"]
	parent.add_child(_wrap("Você: %dº lugar · %d pontos · %d vitórias / %d derrotas · 🏆 %d · nível %d" % [int(me["pos"]), int(me["pontos"]), int(me["v"]), int(me["d"]), int(me["trofeus"]), int(me["nivel"])], 16, Color(1, 1, 0.75)))
	var cards: Array = me.get("cartas", [])
	if !cards.is_empty():
		parent.add_child(_wrap("Mais jogadas: " + ", ".join(cards.map(func(c): return "%s (%dx)" % [str(c[0]), int(c[1])])), 15, ThemeBuilder.COLOR_STAT_LABEL))


func _show_registro_table(e: Dictionary):
	var v = _popup(660, true)
	v.add_child(_title("Temporada %d" % int(e["temporada"])))
	v.add_child(_label("Toque num nome pra ver o histórico dele.", 14, ThemeBuilder.COLOR_STAT_LABEL))
	var rank: Array = e["ranking"]
	for i in rank.size():
		var r = rank[i]
		var b = _button("%dº  %s   ·   %d pts   ·   %dV %dD   ·   🏆 %d" % [i + 1, str(r[0]), int(r[1]), int(r[2]), int(r[3]), int(r[4])], _show_registro_of.bind(str(r[0])), 15)
		b.custom_minimum_size.y = 44
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if str(r[0]) == PlayerProfile.player_name:
			b.modulate = Color(1, 1, 0.6)
		v.add_child(b)
	v.add_child(_button("Fechar", _close.bind(v)))


func _show_registro_of(who: String):
	var v = _popup(620, true)
	v.add_child(_title(who))
	v.add_child(_label("🏆 %d troféus agora  ·  %s" % [ArenaManager.get_trophies(who), ArenaManager.get_arena_info(ArenaManager.get_participant_arena(who)).get("name", "")], 16))
	var lines = Registro.history_of(who)
	if lines.is_empty():
		v.add_child(_wrap("Ainda sem temporadas terminadas no registro.", 16))
	for l in lines:
		v.add_child(_label("Temporada %d:  %dº lugar · %d pts · %dV %dD" % [l[0], l[1], l[2], l[3], l[4]], 16, Color(1, 1, 0.7) if l[1] == 1 else ThemeBuilder.COLOR_CREAM))
	v.add_child(_button("Fechar", _close.bind(v)))


func _goto(scene: String):
	if ResourceLoader.exists(scene):
		get_tree().change_scene_to_file(scene)
	else:
		_toast("Tela não encontrada.")


func _show_safra():
	var v = _popup()
	v.add_child(_title("🌱 Safra"))
	v.add_child(_wrap(Safra.status_text(), 16))
	v.add_child(_label("Colheita atual:", 17, ThemeBuilder.COLOR_STAT_LABEL))
	for c in Safra.current_cards():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var cv = CardView.make(c, 110)
		cv.show_level = Progresso.is_owned(c)
		cv.locked = false
		cv.badge = "" if Progresso.is_owned(c) else "falta achar"
		cv.tapped.connect(_show_card_popup)
		row.add_child(cv)
		row.add_child(_wrap("%s\n%s · %s · custo %d" % [c.card_name, c.get_nation_name(), CardData.role_name(c.role), c.cost], 16))
	var m = Safra.mission()
	if !m.is_empty():
		var p = _panel(v)
		p.add_child(_wrap("⭐ Missão da safra: %s" % Safra.mission_text(), 17, ThemeBuilder.COLOR_GOLD))
		p.add_child(_label("Progresso: %d/%d   ·   Prêmio: a outra carta da safra + Caixote da Feira" % [mini(int(m["prog"]), Safra.MISSION_WINS), Safra.MISSION_WINS], 15))
		if m["pego"]:
			p.add_child(_label("✔ Prêmio já pego", 16, Color(0.6, 1, 0.6)))
		elif Safra.mission_ready():
			var b = _button("PEGAR PRÊMIO", _claim_safra.bind(v))
			b.modulate = Color(1, 1, 0.7)
			p.add_child(b)
	var old_cards = Safra.all_cards().filter(func(c): return !Safra.current_cards().has(c))
	if !old_cards.is_empty():
		v.add_child(_label("Safras anteriores:", 15, ThemeBuilder.COLOR_STAT_LABEL))
		var g = _grid(v, 6)
		for c in old_cards.slice(maxi(0, old_cards.size() - 12)):
			var ov = CardView.make(c, 92)
			ov.show_level = false
			ov.tapped.connect(_show_card_popup)
			g.add_child(ov)
	v.add_child(_button("Fechar", _close.bind(v)))


func _claim_safra(popup_box: Node):
	var loot = Safra.claim_mission()
	_close(popup_box)
	if !loot.is_empty():
		_show_loot("🌱 Prêmio da safra", loot, Color(0.5, 0.9, 0.4))


# ================================================================ missões
func _mission_row(parent: Node, m: Dictionary, popup_box):
	parent.add_child(_wrap(str(m["description"]), 16))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var bar = ProgressBar.new()
	bar.max_value = m["target"]
	bar.value = mini(int(m["progress"]), int(m["target"]))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(_label("%d/%d" % [mini(int(m["progress"]), int(m["target"])), int(m["target"])], 16))
	var is_coins = int(m["reward_type"]) == MissionData.RewardType.COINS
	var reward_text = ("💰 %d" if is_coins else "⭐ %d XP") % int(m["reward_amount"])
	if m["claimed"]:
		row.add_child(_label("✔ " + reward_text, 16, Color(0.6, 1, 0.6)))
	elif m["progress"] >= m["target"]:
		var b = _button("PEGAR " + reward_text, _claim_mission.bind(str(m["id"]), popup_box), 16)
		b.modulate = Color(1, 1, 0.7)
		row.add_child(b)
	else:
		row.add_child(_label(reward_text, 16, ThemeBuilder.COLOR_GOLD))


func _show_missions():
	PlayerProfile._check_and_reset_daily_missions()
	var v = _popup()
	v.add_child(_title("📋 Missões do dia"))
	for m in PlayerProfile.daily_missions:
		_mission_row(_panel(v), m, v)
	v.add_child(_button("Fechar", _close.bind(v)))


func _claim_mission(id: String, popup_box):
	if PlayerProfile.claim_mission_reward(id):
		_toast("Missão cumprida!")
		_queue_refresh()
		if popup_box != null:
			_close(popup_box)
			_show_missions.call_deferred()


# ================================================================ prêmios
func _show_pending():
	if !get_tree().get_nodes_in_group("hub_popup").is_empty() or _loot_busy or _celebrating:
		return
	# um aviso de cada vez: o próximo aparece quando esse fechar
	while true:
		var r = Progresso.pop_one_pending()
		if r.is_empty():
			return
		match str(r.get("tipo", "")):
				"nivel":
					_show_loot("⬆ NÍVEL %d!" % int(r["nivel"]), [{"tipo": "ouro", "ouro": int(r["ouro"])}], Color(0.5, 1, 0.6))
					return
				"bau":
					_show_loot("🎁 " + Progresso.CHESTS[int(r["bau"])]["nome"], r["itens"], Color.html(Progresso.CHESTS[int(r["bau"])]["cor"]))
					return
				"safra":
					_show_loot("🌱 Dia de lançamento! Carta da safra liberada", r["itens"], Color(0.5, 0.9, 0.4))
					return
				"poder":
					_show_loot("⚡ PODER RARO!", [{"tipo": "poder", "id": str(r["id"])}], Color.html(Progresso.POWERS[str(r["id"])]["cor"]))
					return
				"assembleia":
					_show_assembly_result(r)
					return
				"maestria":
					var c = Catalogo.find_card(str(r["path"]))
					if c != null:
						_show_loot("✨ Maestria %s!" % Progresso.MASTERY_NAMES[int(r["nivel"])], [{"tipo": "carta", "path": c.resource_path, "qtd": 0, "nova": false, "ouro": 0}], Progresso.MASTERY_COLORS[int(r["nivel"])])
						return


var _loot_busy := false


func _show_loot(title_text: String, loot: Array, color: Color):
	# carta NOVA: a animação de desbloqueio vem PRIMEIRO, na hora, e só depois
	# aparece a lista do que veio (no máximo 2 animações pra não demorar)
	_loot_busy = true
	var shown = 0
	for item in loot:
		if item.get("nova", false) and shown < 2:
			var nc = Catalogo.find_card(str(item.get("path", "")))
			if nc != null:
				shown += 1
				await _celebrate(nc, "CARTA NOVA!", "%s  ·  %s" % [Catalogo.RARITY_NAMES[Catalogo.rarity_of(nc)], nc.get_nation_name() if nc.get_nation_name() != "" else "Coringa"], Catalogo.rarity_color(nc))
	_loot_busy = false
	Sfx.play("nivel" if title_text.contains("NÍVEL") or title_text.contains("Maestria") else "bau", 0.0, 2.0)
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
	var delay = 0.05
	var reveal: Array = []
	for item in loot:
		var w: Control
		if str(item.get("tipo", "")) == "poder":
			var pdef = Progresso.POWERS[str(item["id"])]
			var pb = VBoxContainer.new()
			pb.custom_minimum_size = Vector2(300, 150)
			pb.alignment = BoxContainer.ALIGNMENT_CENTER
			var bolt = _label("⚡", 54)
			bolt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pb.add_child(bolt)
			var pn = _label(pdef["nome"], 20, Color.html(pdef["cor"]))
			pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pb.add_child(pn)
			var pd = _wrap(pdef["desc"], 14)
			pd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pb.add_child(pd)
			w = pb
		elif str(item.get("tipo", "")) == "ouro":
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
		tw.tween_property(w, "modulate:a", 1.0, 0.08)
		reveal.append([w, tw])
		delay += 0.05
	Sfx.play("carta", 0.1, 0.0)
	# tocar em qualquer lugar mostra tudo de uma vez
	var overlay: Node = v.get_meta("overlay")
	var bg = overlay.get_child(0)
	if bg is Control:
		bg.gui_input.connect(_reveal_all.bind(reveal))
	v.add_child(_button("Boa!", _close_loot.bind(v), 22))


func _reveal_all(event: InputEvent, reveal: Array):
	if event is InputEventMouseButton and event.pressed:
		for pair in reveal:
			if is_instance_valid(pair[0]):
				if pair[1] != null and pair[1].is_valid():
					pair[1].kill()
				pair[0].modulate.a = 1.0


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
## DESLIZE: quando você solta o dedo no meio de uma rolagem, a lista continua
## andando um pouco e vai freando, em vez de parar seca. Fica pendurado em
## qualquer ScrollContainer. Se o próprio Godot já estiver deslizando, não mexe.
class ScrollGlide extends Node:
	var _down := false
	var _vel := 0.0
	var _last := 0.0
	var _coast := false
	var _frames := 0
	var _pos := 0.0

	func _input(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var sc: ScrollContainer = get_parent()
			_down = event.pressed
			if _down:
				_coast = false
				_vel = 0.0
				_last = float(sc.scroll_vertical)
			elif absf(_vel) > 140.0 and sc.is_visible_in_tree():
				_coast = true
				_frames = 0
				_pos = float(sc.scroll_vertical)

	func _process(delta):
		var sc: ScrollContainer = get_parent()
		if _down:
			var now = float(sc.scroll_vertical)
			_vel = clampf(lerpf(_vel, (now - _last) / maxf(delta, 0.001), 0.45), -7000.0, 7000.0)
			_last = now
		elif _coast:
			_frames += 1
			if _frames <= 2 and absf(float(sc.scroll_vertical) - _pos) > 1.5:
				_coast = false  # já está deslizando sozinho
				return
			_pos += _vel * delta
			var before = sc.scroll_vertical
			sc.scroll_vertical = int(round(_pos))
			_vel *= exp(-3.0 * delta)
			var stuck = sc.scroll_vertical == before and absf(_vel * delta) >= 1.0
			if absf(_vel) < 30.0 or stuck:
				_coast = false


## raios girando atrás da carta na comemoração
class BurstView extends Control:
	var color := Color(1, 0.9, 0.4)
	var _t := 0.0

	func _init():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta):
		_t += delta
		queue_redraw()

	func _draw():
		var grow = minf(1.0, _t * 4.0)
		var rays = 12
		for i in rays:
			var ang = TAU * i / rays + _t * 0.9
			var half = TAU / rays * 0.22
			var r = 560.0 * grow
			var pts = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(ang - half) * r, Vector2.RIGHT.rotated(ang + half) * r])
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.22))
		draw_circle(Vector2.ZERO, 210.0 * grow, Color(color.r, color.g, color.b, 0.18))
		# estrelinhas voando pra fora
		for i in 14:
			var a2 = TAU * i / 14.0 + 0.3
			var dist = fmod(_t * 260.0 + i * 37.0, 420.0)
			var alpha = 1.0 - dist / 420.0
			draw_rect(Rect2(Vector2.RIGHT.rotated(a2) * dist - Vector2(5, 5), Vector2(10, 10)), Color(1, 1, 0.8, alpha))


## chaveamento do mata-mata: 8 nomes, quartas -> semi -> final
class BracketView extends Control:
	var me := ""
	var ops: Array = []
	var figs: Array = []
	var round_now := 0

	func setup(player: String, opponents: Array, extras: Array, r: int):
		me = player
		ops = opponents
		figs = extras
		round_now = r
		custom_minimum_size = Vector2(620, 470)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _name(list: Array, i: int, fallback: String) -> String:
		return str(list[i]) if i < list.size() else fallback

	func _box(pos: Vector2, text: String, state: int):
		## state: 0 normal, 1 você, 2 eliminado, 3 ainda não se sabe, 4 próximo rival
		var w = 186.0
		var h = 40.0
		var bg = Color("#5a3a22")
		var fg = Color("#f3e6c8")
		match state:
			1:
				bg = Color("#c8a020")
				fg = Color("#2a1608")
			2:
				bg = Color("#3a2c24")
				fg = Color(0.6, 0.56, 0.52)
			3:
				bg = Color("#40302a")
				fg = Color(0.7, 0.66, 0.6)
			4:
				bg = Color("#b84838")
		draw_rect(Rect2(pos, Vector2(w, h)), Color("#2a1a12"))
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(w - 4, h - 4)), bg)
		var font = ThemeDB.fallback_font
		var fs = 15
		while fs > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 12:
			fs -= 1
		draw_string(font, pos + Vector2(6, h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, w - 10, fs, fg)

	func _link(a: Vector2, b: Vector2, c: Vector2, lit: bool):
		## liga duas caixas (a, b) na caixa seguinte (c)
		var col = Color("#f0c040") if lit else Color("#7a6048")
		var midx = (a.x + c.x) * 0.5
		draw_line(a, Vector2(midx, a.y), col, 3.0)
		draw_line(b, Vector2(midx, b.y), col, 3.0)
		draw_line(Vector2(midx, a.y), Vector2(midx, b.y), col, 3.0)
		draw_line(Vector2(midx, c.y), c, col, 3.0)

	func _draw():
		var font = ThemeDB.fallback_font
		var cols = [0.0, 217.0, 434.0]
		var titles = ["QUARTAS", "SEMI", "FINAL"]
		for i in 3:
			draw_string(font, Vector2(cols[i], 16), titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0c040") if i == round_now else Color(0.75, 0.7, 0.62))
		# quartas: você x op0 | fig0 x op1 | op2 x fig1 | fig2 x fig3
		var q: Array = [me, _name(ops, 0, "?"), _name(figs, 0, "?"), _name(ops, 1, "?"), _name(ops, 2, "?"), _name(figs, 1, "?"), _name(figs, 2, "?"), _name(figs, 3, "?")]
		var q_winner = [0, 3, 4, 6]   # quem passa em cada chave (a sua só se sabe depois)
		var qy: Array = []
		for i in 8:
			qy.append(30.0 + i * 52.0 + (int(i / 2.0)) * 6.0)
		var known_q = round_now >= 1
		for i in 8:
			var state = 0
			if i == 0:
				state = 1
			elif i == 1 and round_now == 0:
				state = 4
			elif known_q and !q_winner.has(i):
				state = 2
			_box(Vector2(cols[0], qy[i]), q[i], state)
		# semis
		var s: Array = [me if known_q else "vencedor", q[3] if known_q else "vencedor", q[4] if known_q else "vencedor", q[6] if known_q else "vencedor"]
		var sy: Array = []
		for i in 4:
			sy.append((qy[i * 2] + qy[i * 2 + 1]) * 0.5)
		var known_s = round_now >= 2
		for i in 4:
			var state2 = 3
			if known_q:
				state2 = 0
				if i == 0:
					state2 = 1
				elif i == 1 and round_now == 1:
					state2 = 4
				elif known_s and i == 3:
					state2 = 2
				elif known_s and i == 1:
					state2 = 2
			_box(Vector2(cols[1], sy[i]), s[i], state2)
			_link(Vector2(cols[0] + 186, qy[i * 2] + 20), Vector2(cols[0] + 186, qy[i * 2 + 1] + 20), Vector2(cols[1], sy[i] + 20), known_q and i == 0)
		# final
		var f: Array = [me if known_s else "vencedor", q[4] if known_s else "vencedor"]
		var fy: Array = [(sy[0] + sy[1]) * 0.5, (sy[2] + sy[3]) * 0.5]
		for i in 2:
			var state3 = 3
			if known_s:
				state3 = 1 if i == 0 else 4
			_box(Vector2(cols[2], fy[i]), f[i], state3)
			_link(Vector2(cols[1] + 186, sy[i * 2] + 20), Vector2(cols[1] + 186, sy[i * 2 + 1] + 20), Vector2(cols[2], fy[i] + 20), known_s and i == 0)
		# taça entre os dois finalistas
		var cup_y = (fy[0] + fy[1]) * 0.5 + 20
		draw_line(Vector2(cols[2] + 93, fy[0] + 40), Vector2(cols[2] + 93, fy[1]), Color("#7a6048"), 3.0)
		draw_circle(Vector2(cols[2] + 93, cup_y), 26, Color("#2a1a12"))
		draw_circle(Vector2(cols[2] + 93, cup_y), 23, Color("#f0c040"))
		draw_string(font, Vector2(cols[2] + 93 - 26, cup_y + 7), "TAÇA", HORIZONTAL_ALIGNMENT_CENTER, 52, 15, Color("#2a1608"))


## escada dos desafios: uma bolinha por vitória, baú marcado nos degraus de prêmio
class LadderView extends Control:
	var wins := 0
	var goal := 0
	var losses := 0
	var max_losses := 1
	var marks: Dictionary = {}

	func setup(w: int, g: int, l: int, ml: int, m: Dictionary):
		wins = w
		goal = g
		losses = l
		max_losses = ml
		marks = m
		custom_minimum_size = Vector2(620, 128)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var font = ThemeDB.fallback_font
		var steps = goal if goal > 0 else maxi(9, wins + 3)
		var first = 0 if goal > 0 else maxi(0, wins - 6)
		var shown = mini(steps - first, 10)
		var gap = 600.0 / shown
		var y = 40.0
		draw_line(Vector2(gap * 0.5, y), Vector2(gap * (shown - 0.5), y), Color("#7a6048"), 6.0)
		if wins > first:
			draw_line(Vector2(gap * 0.5, y), Vector2(gap * (mini(wins - first, shown) - 0.5), y), Color("#58c060"), 6.0)
		for i in shown:
			var n = first + i + 1
			var c = Vector2(gap * (i + 0.5), y)
			var done = n <= wins
			var prize = false
			for k in marks:
				if int(k) == n:
					prize = true
			if goal <= 0 and n % 3 == 0:
				prize = true
			draw_circle(c, 22, Color("#2a1a12"))
			draw_circle(c, 19, Color("#58c060") if done else (Color("#f0c040") if n == wins + 1 else Color("#5a3a22")))
			draw_string(font, c + Vector2(-20, 6), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color("#16240f") if done else Color("#f3e6c8"))
			if prize:
				draw_rect(Rect2(c + Vector2(-13, 28), Vector2(26, 18)), Color("#2a1a12"))
				draw_rect(Rect2(c + Vector2(-11, 30), Vector2(22, 14)), Color("#c84838") if !done else Color("#7a6048"))
				draw_rect(Rect2(c + Vector2(-3, 34), Vector2(6, 6)), Color("#ffd23c"))
		# vidas
		for i in max_losses:
			var hc = Vector2(24.0 + i * 44.0, 104.0)
			draw_circle(hc, 16, Color("#2a1a12"))
			draw_circle(hc, 13, Color("#4a3a34") if i < losses else Color("#e04848"))
			if i < losses:
				draw_line(hc + Vector2(-8, -8), hc + Vector2(8, 8), Color("#1a1210"), 4.0)
				draw_line(hc + Vector2(8, -8), hc + Vector2(-8, 8), Color("#1a1210"), 4.0)
		if max_losses > 0:
			draw_string(font, Vector2(24.0 + max_losses * 44.0, 110.0), "vidas", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.8, 0.72))


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
