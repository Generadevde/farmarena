extends Control

# TELA DO CRIADOR -- tudo montado em código (não depende de layout de cena).
# Abas: Cartas | Bases | Arenas. Cada aba tem a lista (do jogo + criadas por
# você) e um formulário de edição com desenho em pixel art.
# Cartas/bases ORIGINAIS podem ser editadas: a edição é guardada à parte e
# dá pra "Restaurar original" a qualquer momento.

const MAIN_MENU_SCENE = "res://Scenes/hub.tscn"
const FONT = 18

var _tab: int = 0  # 0 cartas, 1 bases, 2 arenas
var _tab_buttons: Array = []
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label

# estado do formulário aberto
var _orig: Dictionary = {}      # pacote original (vai ser salvo)
var _work: Dictionary = {}      # cópias sendo editadas
var _image_changed := false
var _art_rect: TextureRect
var _proj_rect: TextureRect
var _proj_changed := false
var _field_box: VBoxContainer

# filtro da lista de cartas
var _show_custom_only := false

# gerador
var _gen_kind := 0
var _gen_role := -1
var _gen_cost := 0


func _ready():
	theme = ThemeBuilder.game_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.09, 0.05, 0.55)  # deixa o fundo de fazenda aparecer
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	_main_ui = margin
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top = HBoxContainer.new()
	root.add_child(top)
	var back = _button("◀ Voltar", _on_back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(150, 60)
	top.add_child(back)
	var title = Label.new()
	title.text = "🛠 Criador"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	for i in 3:
		var t = i
		var b = _button(["🃏 Cartas", "🧩 Módulos", "🏟 Arenas"][i], func(): _set_tab(t))
		b.toggle_mode = true
		tabs.add_child(b)
		_tab_buttons.append(b)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	# cabeçalho fixo do editor (só aparece com uma carta ou módulo aberto)
	_head = PanelContainer.new()
	_head.visible = false
	root.add_child(_head)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)

	_set_tab(0)


# botão "voltar" do Android
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


var _open_editor: Node = null
var _main_ui: Control


# o desenho abre como uma TELA SEPARADA: esconde o criador inteiro enquanto
# desenha (antes um ficava por cima do outro e não dava pra desenhar)
func _open_pixel_editor(img: Image, title: String, on_done: Callable):
	_main_ui.visible = false
	var ed = PixelEditor.open(self, img, title)
	_open_editor = ed
	ed.finished.connect(on_done)
	ed.tree_exited.connect(func():
		if is_instance_valid(_main_ui):
			_main_ui.visible = true
		_open_editor = null
	)


func _on_back():
	if _open_editor != null and is_instance_valid(_open_editor):
		_open_editor.queue_free()  # voltar com o editor de desenho aberto = fecha só o editor
		_open_editor = null
		return
	if !_orig.is_empty():
		_close_form()
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ============================================================ helpers de UI

func _button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT)
	b.pressed.connect(cb)
	return b


func _label(text: String, font_size: int = FONT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _clear_body():
	for c in _body.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0


func _say(text: String):
	_status.text = text


func _set_tab(t: int):
	_tab = t
	if is_instance_valid(_head):
		_head.visible = false
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == t)
	_orig = {}
	_work = {}
	_say("")
	_show_list()


func _show_list():
	_clear_body()
	match _tab:
		0: _build_card_list()
		1: _build_base_list()
		2: _build_arena_list()


func _icon_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var r = TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = min_size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _list_row(tex: Texture2D, title: String, subtitle: String, on_edit: Callable, icon_size := Vector2(56, 56)) -> Control:
	var panel = PanelContainer.new()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_icon_rect(tex, icon_size))
	var texts = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_label(title, 19))
	var sub = _label(subtitle, 14)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	texts.add_child(sub)
	row.add_child(texts)
	var edit = _button("✏️ Editar", on_edit)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_END
	edit.custom_minimum_size = Vector2(130, 60)
	row.add_child(edit)
	return panel


# ============================================================ CARTAS

func _build_card_list():
	var new_row = HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 6)
	_body.add_child(new_row)
	new_row.add_child(_button("+ Unidade", func(): _open_card_form(CustomContent.make_blank_card(false))))
	new_row.add_child(_button("+ Feitiço", func(): _open_card_form(CustomContent.make_blank_card(true))))
	_build_collection_panel()

	# gerador
	var gen_panel = PanelContainer.new()
	_body.add_child(gen_panel)
	var gen = VBoxContainer.new()
	gen_panel.add_child(gen)
	gen.add_child(_label("🎲 Gerador de cartas", 20))
	var gen_opts = HBoxContainer.new()
	gen_opts.add_theme_constant_override("separation", 6)
	gen.add_child(gen_opts)
	var kind = _option(["Qualquer", "Unidade", "Feitiço"], _gen_kind, func(i): _gen_kind = i)
	gen_opts.add_child(kind)
	var role_names = ["Qualquer categoria"] + Array(CustomContent.ROLE_NAMES)
	var role = _option(role_names, _gen_role + 1, func(i): _gen_role = i - 1)
	gen_opts.add_child(role)
	var cost_names = ["Custo aleatório"]
	for c in range(1, 11):
		cost_names.append("Custo %d" % (c * 10))
	var cost = _option(cost_names, _gen_cost, func(i): _gen_cost = i)
	gen_opts.add_child(cost)
	gen.add_child(_button("🎲 Gerar carta", func():
		var pack = CardGenerator.generate_card(_gen_kind, _gen_role, _gen_cost * 10)
		_open_card_form(pack)
		_say("Carta gerada! Ajusta o que quiser e aperta Salvar.")
	))

	var filter = _button("Mostrando: " + ("só as minhas" if _show_custom_only else "todas"), func():
		_show_custom_only = !_show_custom_only
		_show_list()
	)
	_body.add_child(filter)

	var se = LineEdit.new()
	se.placeholder_text = "🔎 Procurar carta pelo nome"
	se.text = _search
	se.custom_minimum_size = Vector2(0, 56)
	se.add_theme_font_size_override("font_size", FONT)
	se.text_changed.connect(func(t):
		_search = t
		_fill_card_rows())
	_body.add_child(se)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 8)
	_body.add_child(_rows_box)
	_fill_card_rows()


var _search := ""
var _rows_box: VBoxContainer


func _fill_card_rows():
	if !is_instance_valid(_rows_box):
		return
	for c in _rows_box.get_children():
		c.queue_free()
	var cards: Array = CardDatabase.all_cards.duplicate() + CustomContent.spawn_only_cards()
	cards.sort_custom(func(a, b):
		if a == null or b == null:
			return a != null
		var ac = CustomContent.is_custom(a)
		var bc = CustomContent.is_custom(b)
		if ac != bc:
			return ac
		return a.card_name < b.card_name
	)
	var want = _search.strip_edges().to_lower()
	for card in cards:
		if card == null:
			continue
		var custom = CustomContent.is_custom(card)
		if _show_custom_only and !custom:
			continue
		if want != "" and !card.card_name.to_lower().contains(want):
			continue
		var tag = "⭐ criada por você" if custom else ("✏️ editada" if CustomContent.has_override(card) else "do jogo")
		if CustomContent.is_spawn_only(card):
			tag = "🐣 só invocação"
		var kind_text = str(Catalogo.KINDS.get(Catalogo.kind_of(card), {}).get("nome", "Tropa"))
		var c = card
		_rows_box.add_child(_list_row(card.icon, card.card_name, "%s · custo %d · %s" % [kind_text, card.cost, tag],
			func(): _open_card_form(CustomContent.open_card_for_edit(c))))


func _open_card_form(pack: Dictionary):
	var card: CardData = pack["card"]
	if !pack.get("is_new", false):
		CustomContent.remember_original_card(card)
	_orig = pack
	_image_changed = pack.get("is_new", false)
	# edita CÓPIAS -- só passa pro original ao salvar (cancelar não estraga nada)
	_work = {
		"card": card.duplicate(),
		"stats": pack["stats"].duplicate() if pack["stats"] != null else null,
		"spell": pack["spell"].duplicate() if pack["spell"] != null else null,
		"image": pack["image"].duplicate(),
		"proj_image": pack.get("proj_image", CustomContent.default_projectile_image()).duplicate(),
	}
	_proj_changed = false
	_recipe_touched = false
	_recipe = card.art_recipe.duplicate() if card.art_recipe != null else {}
	_palette = card.art_palette.duplicate() if (card.art_palette != null and !card.art_palette.is_empty()) else SpriteForge.DEFAULT_PALETTE.duplicate()
	if pack.get("is_new", false) and _recipe.is_empty() and _work["image"].is_invisible():
		_recipe = MODE_DEFAULTS["icone" if _work["spell"] != null else "pe"].duplicate()
		_work["image"] = SpriteForge.make_image(_recipe, _palette)
		_recipe_touched = true
		_image_changed = true
	_start_editor("feitico" if _work["spell"] != null else "tropa", _save_card, CustomContent.is_custom(card), CustomContent.has_override(card),
		_delete_card.bind(card), _restore_card.bind(card))


func _power_hint() -> Label:
	var l = _label("", 14)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	if _work.get("stats") != null:
		var st: UnitData = _work["stats"]
		var ref = CardGenerator.power_per_cost() * max(_work["card"].cost, 1)
		var pw = CardGenerator._raw_power(st)
		var pct = int(round(pw / max(ref, 1.0) * 100.0))
		l.text = "⚖️ Força estimada: %d%% do normal pra esse custo (100%% = equilibrada; habilidades especiais não entram na conta)" % pct
	return l


func _save_card():
	var card: CardData = _orig["card"]
	_apply_zero_later.call_deferred()
	if _recipe_touched:
		card.art_recipe = _recipe.duplicate()
		card.art_palette = _palette.duplicate()
	Regua.clear()
	CustomContent.apply_snapshot(card, CustomContent.snapshot(_work["card"], CustomContent.CARD_FIELDS), CustomContent.CARD_FIELDS)
	Catalogo.apply_companion(card)
	if _work["card"].has_meta("spawn_only"):
		card.set_meta("spawn_only", _work["card"].get_meta("spawn_only"))
	if _orig["stats"] != null and _work["stats"] != null:
		var uf = CustomContent.all_unit_fields()
		CustomContent.apply_snapshot(_orig["stats"], CustomContent.snapshot(_work["stats"], uf), uf)
	if _orig["spell"] != null and _work["spell"] != null:
		CustomContent.apply_snapshot(_orig["spell"], CustomContent.snapshot(_work["spell"], CustomContent.SPELL_FIELDS), CustomContent.SPELL_FIELDS)
	_orig["image"] = _work["image"]
	_orig["proj_image"] = _work["proj_image"]
	_orig["proj_changed"] = _proj_changed
	var saved = CustomContent.save_card(_orig, _image_changed)
	_close_form()
	if CustomContent.is_spawn_only(saved):
		_remove_from_player_deck(saved.resource_path)
		_say("✔ \"%s\" salva como SÓ INVOCAÇÃO -- escolha ela em \"Unidade invocada\" de outra carta." % saved.card_name)
	else:
		_say("✔ \"%s\" salva! Já aparece na coleção e os bots podem usar." % saved.card_name)


func _delete_card(card: CardData):
	_confirm("Apagar a carta \"%s\"? Se ela estiver no seu deck, sai dele." % card.card_name, func():
		_remove_from_player_deck(card.resource_path)
		CustomContent.delete_custom_card(card)
		_close_form()
		_say("Carta apagada.")
	)


func _restore_card(card: CardData):
	CustomContent.restore_original_card(card)
	Catalogo.apply_companion(card)
	_close_form()
	_say("\"%s\" voltou ao original." % card.card_name)


func _remove_from_player_deck(path: String):
	if PlayerProfile.deck_card_paths.has(path):
		PlayerProfile.deck_card_paths = []  # volta pro deck padrão (evita deck com buraco)
		PlayerProfile.save_profile()
		DeckManager._load_deck_for_active_profile()


# ============================================================ BASES

func _build_base_list():
	_body.add_child(_button("+ Novo módulo", func(): _open_base_form(CustomContent.make_blank_base())))
	_body.add_child(_label("Módulo é o que você põe em volta da Casa Grande. Toque num pra mexer na função, nos números e no desenho.", 14))
	for b in CustomContent.all_bases([]):
		var custom = CustomContent.is_custom(b)
		var tag = "⭐ criada por você" if custom else ("✏️ editada" if CustomContent.has_override(b) else "do jogo")
		var tex = b.base_texture if b.base_texture != null else b.icon
		var base_ref = b
		_body.add_child(_list_row(tex, b.base_name, "vida %d · %s" % [b.base_hp, tag],
			func(): _open_base_form(CustomContent.open_base_for_edit(base_ref)), Vector2(40, 72)))


func _open_base_form(pack: Dictionary):
	var b: BaseData = pack["base"]
	if !pack.get("is_new", false):
		CustomContent.remember_original_base(b)
	_orig = pack
	_image_changed = pack.get("is_new", false)
	_work = {"base": b.duplicate(), "image": pack["image"].duplicate(),
		"proj_image": pack.get("proj_image", CustomContent.default_projectile_image()).duplicate()}
	_proj_changed = false
	_recipe_touched = false
	_recipe = {}
	_palette = SpriteForge.DEFAULT_PALETTE.duplicate()
	_start_editor("modulo", _save_base, CustomContent.is_custom(b), CustomContent.has_override(b), _delete_base.bind(b), _restore_base.bind(b))


func _delete_base(b: BaseData):
	_confirm("Apagar esse módulo?", _do_delete_base.bind(b))


func _do_delete_base(b: BaseData):
	if PlayerProfile.equipped_base_path == b.resource_path:
		PlayerProfile.equipped_base_path = ""
		PlayerProfile.save_profile()
	CustomContent.delete_custom_base(b)
	_close_form()
	_say("Módulo apagado.")


func _restore_base(b: BaseData):
	CustomContent.restore_original_base(b)
	_close_form()
	_say("Módulo voltou ao original.")


func _save_base():
	var b: BaseData = _orig["base"]
	_apply_zero_later.call_deferred()
	CustomContent.apply_snapshot(b, CustomContent.snapshot(_work["base"], CustomContent.BASE_FIELDS), CustomContent.BASE_FIELDS)
	_orig["image"] = _work["image"]
	_orig["proj_image"] = _work["proj_image"]
	_orig["proj_changed"] = _proj_changed
	CustomContent.save_base(_orig, _image_changed)
	_close_form()
	_say("✔ Módulo \"%s\" salvo! Aparece em Cartas > Módulos." % b.base_name)


# ============================================================ ARENAS

func _build_arena_list():
	var row = HBoxContainer.new()
	_body.add_child(row)
	row.add_child(_button("+ Nova arena", func():
		var idx = CustomContent.add_arena()
		_open_arena_form(idx)
	))
	row.add_child(_button("🗑 Apagar última criada", func():
		if CustomContent.remove_last_arena():
			_say("Última arena criada apagada.")
		else:
			_say("As 7 arenas originais não podem ser apagadas (mas podem ser editadas).")
		_show_list()
	))
	for i in range(1, ArenaManager.max_arena + 1):
		var a = ArenaManager.get_arena_info(i)
		var idx = i
		var tex = a.get("background_texture", null)
		_body.add_child(_list_row(tex, "%s %s" % [a.get("emoji", ""), a.get("name", "Arena %d" % i)],
			"a partir de %d troféus" % int(a.get("trophy_threshold", 0)),
			func(): _open_arena_form(idx), Vector2(36, 64)))


func _open_arena_form(index: int):
	var entry = CustomContent.get_arena_entry(index)
	var bg: Texture2D = entry.get("background_texture", null)
	var img: Image
	if bg != null:
		img = CustomContent.texture_to_image(bg, CustomContent.ARENA_ART_SIZE)
	else:
		img = CardGenerator.generate_arena_background(CustomContent.ARENA_ART_SIZE.x, CustomContent.ARENA_ART_SIZE.y, index * 7919)
	_orig = {"arena_index": index}
	_image_changed = false
	var rewards: Dictionary = entry["rewards"].duplicate(true)
	_work = {"name": entry.get("name", ""), "emoji": entry.get("emoji", "⭐"),
		"trophy_threshold": int(entry.get("trophy_threshold", 0)), "rewards": rewards, "image": img}
	_clear_body()
	_body.add_child(_label("Editando arena %d" % index, 22))
	_build_art_block(CustomContent.ARENA_ART_SIZE, "Fundo da arena", Vector2(144, 256))
	_body.add_child(_label("O fundo aparece atrás da batalha, esticado na tela toda (pixel grande, sem borrar).", 14))
	_field_box = VBoxContainer.new()
	_body.add_child(_field_box)
	_section("Arena")
	_dict_text_field("Nome", "name")
	_dict_text_field("Emoji", "emoji")
	if index == 1:
		_field_box.add_child(_label("Arena 1 sempre começa em 0 troféus.", 14))
	else:
		_dict_int_field("Troféus pra entrar", _work, "trophy_threshold", 0, 100000, 50)
	_section("Recompensas (mínimo / máximo)")
	for key in [["win_gold", "Ouro na vitória"], ["win_xp", "XP na vitória"], ["loss_gold", "Ouro na derrota"], ["loss_xp", "XP na derrota"]]:
		var pair: Array = rewards[key[0]]
		var row = HBoxContainer.new()
		row.add_child(_field_label(key[1]))
		row.add_child(_stepper(pair[0], 0, 5000, 5, func(v): pair[0] = int(v)))
		row.add_child(_stepper(pair[1], 0, 5000, 5, func(v): pair[1] = int(v)))
		_field_box.add_child(row)
	_form_buttons(_save_arena, false, index <= ArenaManager.DEFAULT_MAX_ARENA, Callable(), _reset_arena.bind(index))


func _reset_arena(index: int):
	CustomContent.reset_arena(index)
	_close_form()
	_say("Arena %d voltou ao padrão." % index)


func _save_arena():
	var idx: int = _orig["arena_index"]
	var r: Dictionary = _work["rewards"]
	for k in r:
		if r[k][1] < r[k][0]:
			r[k][1] = r[k][0]
	var data = {"name": _work["name"], "emoji": _work["emoji"], "rewards": r}
	if idx > 1:
		data["trophy_threshold"] = _work["trophy_threshold"]
	else:
		data["trophy_threshold"] = 0
	CustomContent.save_arena(idx, data, _work["image"] if _image_changed else null)
	_close_form()
	_say("✔ Arena salva!")


func _dict_text_field(title: String, key: String):
	var row = HBoxContainer.new()
	row.add_child(_field_label(title))
	var le = LineEdit.new()
	le.text = str(_work[key])
	le.custom_minimum_size = Vector2(0, 56)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", FONT)
	le.text_changed.connect(func(t): _work[key] = t)
	row.add_child(le)
	_field_box.add_child(row)


func _dict_int_field(title: String, d: Dictionary, key: String, mn: int, mx: int, step: int):
	var row = HBoxContainer.new()
	row.add_child(_field_label(title))
	row.add_child(_stepper(d[key], mn, mx, step, func(v): d[key] = int(v)))
	_field_box.add_child(row)


# ============================================================ formulário

func _build_art_block(art_size: Vector2i, title: String, show_size: Vector2):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var frame = PanelContainer.new()
	row.add_child(frame)
	_art_rect = _icon_rect(ImageTexture.create_from_image(_work["image"]), show_size)
	frame.add_child(_art_rect)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label(title + " (%dx%d)" % [art_size.x, art_size.y], 16))
	col.add_child(_button("🎨 Desenhar", func():
		_open_pixel_editor(_work["image"], title, func(img: Image):
			if !is_instance_valid(_art_rect) or _work.is_empty():
				return
			_work["image"] = img
			_image_changed = true
			_art_rect.texture = ImageTexture.create_from_image(img)
		)
	))
	col.add_child(_button("🎲 Arte aleatória", func():
		var img = CardGenerator.generate_sprite(art_size.x, art_size.y, randi())
		_work["image"] = img
		_image_changed = true
		_art_rect.texture = ImageTexture.create_from_image(img)
	))


# desenho do projétil (16x16) -- desenhe apontando pra DIREITA, ele gira
# sozinho na direção do tiro
func _build_proj_block():
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_field_box.add_child(row)
	var frame = PanelContainer.new()
	row.add_child(frame)
	_proj_rect = _icon_rect(ImageTexture.create_from_image(_work["proj_image"]), Vector2(96, 96))
	frame.add_child(_proj_rect)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label("Desenhe apontando pra direita ➡ (16x16)", 15))
	col.add_child(_button("🎯 Desenhar projétil", func():
		_open_pixel_editor(_work["proj_image"], "Projétil", func(img: Image):
			if !is_instance_valid(_proj_rect) or _work.is_empty():
				return
			_work["proj_image"] = img
			_proj_changed = true
			_proj_rect.texture = ImageTexture.create_from_image(img)
		)
	))
	col.add_child(_button("Bolinha padrão", func():
		_work["proj_image"] = CustomContent.default_projectile_image()
		_proj_changed = true
		_proj_rect.texture = ImageTexture.create_from_image(_work["proj_image"])
	))
	# TIPOS PRONTOS: mesma ideia das peças da carta -- escolhe o tipo, ele sai nas cores da carta
	var pal: Dictionary = _palette if !_palette.is_empty() else SpriteForge.DEFAULT_PALETTE
	var kinds: Array = SpriteForge.pieces("proj").filter(func(k): return _piece_in_theme(str(k)))
	if kinds.is_empty():
		kinds = SpriteForge.pieces("proj")
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_field_box.add_child(head)
	var ht = _label("Tipos prontos (%d) -- toque num" % kinds.size(), 16)
	ht.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	head.add_child(_button("🎲 Sortear", func():
		_set_proj_kind(str(kinds[randi() % kinds.size()]))))
	var grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_field_box.add_child(grid)
	for k in kinds:
		var b = Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.icon = SpriteForge.projectile(str(k), pal)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = str(k).replace("_", " ").capitalize()
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(_set_proj_kind.bind(str(k)))
		grid.add_child(b)
	_proj_name = _note("O tema escolhido em \"Tema das peças\" filtra esta lista também. O projétil sai nas cores da carta: se trocar as cores, toque no tipo de novo.")
	_field_box.add_child(_proj_name)


var _proj_name: Label = null


## troca o projétil por um tipo pronto do atlas, pintado com as cores da carta
func _set_proj_kind(kind: String):
	if _work.is_empty() or !SpriteForge.has_piece("proj", kind):
		return
	var pal: Dictionary = _palette if !_palette.is_empty() else SpriteForge.DEFAULT_PALETTE
	_work["proj_image"] = SpriteForge.projectile(kind, pal).get_image()
	_proj_changed = true
	if is_instance_valid(_proj_rect):
		_proj_rect.texture = ImageTexture.create_from_image(_work["proj_image"])
	if is_instance_valid(_proj_name):
		_proj_name.text = "Projétil: " + kind.replace("_", " ").capitalize()


func _form_buttons(on_save: Callable, can_delete: bool, can_restore: bool, on_delete: Callable, on_restore: Callable):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	var save = _button("💾 Salvar", on_save)
	save.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	row.add_child(save)
	row.add_child(_button("Cancelar", _close_form))
	if can_delete:
		row.add_child(_button("🗑 Apagar", on_delete))
	elif can_restore and on_restore.is_valid():
		row.add_child(_button("↺ Original", on_restore))
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)  # espaço pro teclado do celular não cobrir o último campo
	_body.add_child(spacer)


func _close_form():
	_orig = {}
	_work = {}
	if is_instance_valid(_head):
		_head.visible = false
	_show_list()


func _section(title: String):
	var l = _label("— " + title + " —", 20)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_field_box.add_child(l)


func _field_label(text: String) -> Label:
	var l = _label(text, 16)
	l.custom_minimum_size = Vector2(240, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# monta 1 campo do formulário a partir da definição em CustomContent
func _field(obj: Object, f: Array):
	var prop: String = f[0]
	var kind: String = f[2]
	var opts: Array = f[3]
	var value = obj.get(prop)
	if value == null and kind != "text" and kind != "multiline" and kind != "scene" and kind != "nation":
		return  # propriedade não existe nesse tipo de recurso
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	match kind:
		"text":
			row.add_child(_field_label(f[1]))
			var le = LineEdit.new()
			le.text = str(value if value != null else "")
			le.custom_minimum_size = Vector2(0, 56)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.add_theme_font_size_override("font_size", FONT)
			le.text_changed.connect(func(t):
				obj.set(prop, t)
				_refresh_hint())
			row.add_child(le)
		"cardid":
			# escolhe uma tropa do jogo e guarda o id dela (módulo que solta tropa)
			row.add_child(_field_label(f[1]))
			var ids: Array = [""]
			var id_names: Array = ["(nenhuma)"]
			for c in Catalogo.cards() + Catalogo.tokens():
				if c == null or c.is_spell():
					continue
				var id = c.resource_path.get_file().get_basename()
				if Catalogo.card(id) == c and !ids.has(id):
					ids.append(id)
					id_names.append(c.card_name)
			row.add_child(_option(id_names, max(ids.find(str(value)), 0), func(i): obj.set(prop, ids[i])))
		"multiline":
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(_field_label(f[1]))
			var te = TextEdit.new()
			te.text = str(value if value != null else "")
			te.custom_minimum_size = Vector2(0, 110)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 16)
			te.text_changed.connect(func(): obj.set(prop, te.text))
			col.add_child(te)
			row.add_child(col)
		"bool":
			var cb = CheckButton.new()
			cb.text = f[1]
			cb.button_pressed = bool(value)
			cb.custom_minimum_size = Vector2(0, 56)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.add_theme_font_size_override("font_size", 16)
			cb.toggled.connect(func(on):
				obj.set(prop, on)
				_refresh_hint()
			)
			row.add_child(cb)
		"enum":
			row.add_child(_field_label(f[1]))
			row.add_child(_option(opts, int(value), func(i):
				obj.set(prop, i)
				_refresh_hint()))
		"nation":
			# nação da carta/base -- "Coringa" = sem nação (só XP livre)
			row.add_child(_field_label(f[1]))
			var nations: Array = [null]
			var nation_names: Array = ["Coringa (sem nação)"]
			for n in CustomContent.all_nations():
				nations.append(n)
				nation_names.append(n.nation_name)
			var nsel = max(nations.find(value), 0)
			row.add_child(_option(nation_names, nsel, func(i): obj.set(prop, nations[i])))
		"scene":
			# escolhe a unidade entre as cartas de unidade do jogo
			row.add_child(_field_label(f[1]))
			var scenes: Array = [null]
			var names: Array = ["(nenhuma)"]
			for c in CustomContent.all_unit_cards_for_spawn():
				if c != null and c.unit_scene != null and !scenes.has(c.unit_scene):
					scenes.append(c.unit_scene)
					names.append(c.card_name)
			var sel = max(scenes.find(value), 0)
			row.add_child(_option(names, sel, func(i): obj.set(prop, scenes[i])))
		"int", "float":
			row.add_child(_field_label(f[1]))
			row.add_child(_stepper(value, opts[0], opts[1], opts[2], func(v):
				CustomContent.set_prop(obj, prop, v)
				_refresh_hint()
			))
	_field_box.add_child(row)


func _refresh_hint():
	# qualquer número mexido atualiza o cabeçalho (tipo, régua e tamanho) na hora
	_refresh_head()


func _option(items: Array, selected: int, on_select: Callable) -> OptionButton:
	var ob = OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.custom_minimum_size = Vector2(0, 56)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_theme_font_size_override("font_size", 16)
	ob.get_popup().add_theme_font_size_override("font_size", 20)
	ob.select(clamp(selected, 0, max(items.size() - 1, 0)))
	ob.item_selected.connect(on_select)
	return ob


# "− [valor] +" -- os setinhas do SpinBox são pequenas demais pra dedo
func _stepper(value, mn, mx, step, on_change: Callable) -> Control:
	var box = HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = SpinBox.new()
	sb.min_value = mn
	sb.max_value = mx
	# o passo vale só pros botões − e +. O campo aceita qualquer número: com o passo preso
	# à grade, 2300 de vida aparecia como 2301 e 32 de dano como 30.
	sb.step = 1.0 if (value is int) else 0.01
	sb.allow_greater = true
	sb.value = value
	sb.custom_minimum_size = Vector2(110, 56)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.get_line_edit().add_theme_font_size_override("font_size", FONT)
	sb.value_changed.connect(on_change)
	var minus = Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(56, 56)
	minus.add_theme_font_size_override("font_size", 22)
	minus.pressed.connect(func(): sb.value -= step)
	var plus = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 56)
	plus.add_theme_font_size_override("font_size", 22)
	plus.pressed.connect(func(): sb.value += step)
	box.add_child(minus)
	box.add_child(sb)
	box.add_child(plus)
	return box


func _confirm(text: String, on_yes: Callable):
	var layer = CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var l = _label(text, 18)
	l.custom_minimum_size = Vector2(480, 0)
	v.add_child(l)
	var row = HBoxContainer.new()
	v.add_child(row)
	row.add_child(_button("Cancelar", func(): layer.queue_free()))
	row.add_child(_button("Sim", func():
		layer.queue_free()
		on_yes.call()
	))


# ============================================================ OFICINA: o editor em abas
# O formulário antigo era uma lista só, comprida. Agora o editor tem:
#  - um CABEÇALHO FIXO (não rola): a arte ao vivo, o tipo que a carta virou, a
#    RÉGUA (vida, dano e força contra o padrão do tipo), o tamanho no campo ao
#    lado de um Peão e de uma torre, e os botões de salvar;
#  - ABAS: cada uma mostra um assunto só (Básico, Combate, Habilidades, Visual, Teste);
#  - HABILIDADES como botõezinhos: só a que você liga abre os números dela;
#  - ARTE POR PEÇAS: cabeça, corpo, pernas, arma, chapéu e 6 cores, sem desenhar
#    pixel por pixel (que continua existindo pra retoque).
# Vale pra tropa, construção, feitiço e módulo, do jogo ou criados por você.

const ED_TABS = {"tropa": ["Básico", "Combate", "Habilidades", "Visual", "Teste"], "feitico": ["Básico", "Efeito", "Visual", "Teste"], "modulo": ["Básico", "Função", "Visual"]}
const CORE_PROPS = ["hp", "damage", "attack_speed", "attack_range", "move_speed", "unit_count", "spawn_formation", "unit_type", "target_type",
	"is_ranged", "projectile_speed", "detection_range", "duration", "push_weight"]
const BASE_TYPE_NAMES = ["Canhão (atira)", "Produção (recurso mais rápido)", "Cura", "Só vida", "Espaço (guarda mais recurso)", "Aura (efeito em volta)"]
const BASE_TYPE_FIELDS = {0: ["attack_damage", "attack_range", "attack_speed", "is_aoe", "aoe_radius"], 1: ["production_speed_boost"],
	2: ["heal_amount", "heal_radius", "heal_interval"], 3: [], 4: ["capacity_bonus"], 5: ["aura_radius", "effect", "effect_strength"]}
# [título, propriedade que liga, [números dela], {valor inicial ao ligar}]
const ABILITIES = [
	["⚔ Ataque", [
		["Efeito ao acertar", "on_hit_effect", ["on_hit_effect_strength", "on_hit_effect_duration", "on_hit_effect_tick_interval", "knockback_distance"], {"on_hit_effect": 1, "on_hit_effect_strength": 0.3, "on_hit_effect_duration": 2.0}],
		["Dano em área", "is_aoe", ["aoe_radius"], {"aoe_radius": 45.0}],
		["Ataque giratório (360°)", "spin_attack", ["aoe_radius"], {"aoe_radius": 45.0}],
		["Ataque em cone", "frontal_cone_attack", ["cone_angle_degrees", "aoe_radius"], {"aoe_radius": 45.0}],
		["Acerta +1 alvo", "aoe_hits_extra_one", [], {}],
		["Ataque contínuo", "continuous_attack", ["continuous_damage_per_second"], {"continuous_damage_per_second": 60.0}],
		["Golpe carregado", "charge_attack", ["charge_distance_needed", "charge_damage_multiplier", "charge_knockback_distance"], {}],
		["Avanço instantâneo", "bandit_dash", ["dash_speed_multiplier", "dash_duration"], {}],
		["1º ataque mais forte", "first_attack_bonus", ["first_attack_multiplier"], {}],
		["Dano cresce a cada golpe", "ramping_damage", ["ramping_damage_per_hit", "ramping_damage_max_multiplier"], {}],
		["Dano cresce no mesmo alvo", "same_target_ramping_damage", ["same_target_ramping_damage_per_hit", "same_target_ramping_damage_max_multiplier"], {}],
		["Ataca cada vez mais rápido", "ramping_attack_speed", ["attack_speed_ramp_per_hit", "attack_speed_ramp_min_multiplier"], {}],
		["Acelera ao achar alvo", "pre_attack_speed_boost", ["pre_attack_boost_multiplier", "pre_attack_boost_duration"], {}],
		["Dano extra de longe", "distance_damage_bonus_per_100px", [], {"distance_damage_bonus_per_100px": 0.1}],
		["Executa alvo fraco", "execute_threshold", ["execute_damage_mult"], {"execute_threshold": 0.2, "execute_damage_mult": 2.0}],
		["Dano extra contra uma categoria", "extra_damage_vs_role_mult", ["extra_damage_vs_role"], {"extra_damage_vs_role_mult": 0.5}],
		["Kamikaze", "kamikaze", [], {}],
		["Segundo ataque (cavaleiro / atiradores nas costas)", "rider_attack", ["rider_damage", "rider_range", "rider_interval", "rider_count", "rider_effect", "rider_effect_duration", "rider_effect_strength"], {}],
	]],
	["🎯 Projétil (só pra quem atira)", [
		["Atravessa", "projectile_pierces", ["projectile_max_targets"], {"projectile_max_targets": 3}],
		["Se divide", "projectile_splits", ["projectile_split_count", "projectile_split_range"], {}],
		["Pula em cadeia", "projectile_chains", ["projectile_chain_max_targets", "projectile_chain_range"], {}],
	]],
	["🛡 Defesa", [
		["Escudo", "has_shield", ["shield_amount", "shield_recharge_time"], {"shield_amount": 200}],
		["Escudo temporário", "has_temp_shield", ["temp_shield_amount", "temp_shield_duration"], {"temp_shield_amount": 200, "temp_shield_duration": 4.0}],
		["Redução de dano", "damage_reduction_percent", [], {"damage_reduction_percent": 0.2}],
		["Roubo de vida", "lifesteal_percent", [], {"lifesteal_percent": 0.2}],
		["Regenera vida", "passive_regen", ["regen_amount", "regen_interval"], {"regen_amount": 20, "regen_interval": 1.0}],
		["Cura ao matar", "heals_on_kill", ["heal_on_kill_amount"], {"heal_on_kill_amount": 100}],
		["Ressuscita 1x", "can_resurrect", ["resurrect_hp_percent"], {"resurrect_hp_percent": 0.5}],
		["Reflete dano", "reflects_damage", ["reflect_damage_percent"], {"reflect_damage_percent": 0.2}],
		["Contra-ataque", "counter_attack_chance", [], {"counter_attack_chance": 0.25}],
		["Vida compartilhada", "is_linked", ["link_share_percent"], {}],
		["Imune a um efeito", "immune_to_effect", [], {"immune_to_effect": 1}],
		["Imune a empurrão", "immune_to_knockback", [], {}],
		["Imune a puxão", "immune_to_pull", [], {}],
		["Imune enquanto anda", "immune_while_moving", [], {}],
		["Invulnerável ao nascer", "spawn_invulnerability_duration", [], {"spawn_invulnerability_duration": 1.5}],
		["Fúria com vida baixa", "low_hp_rage_threshold", ["low_hp_rage_damage_mult"], {"low_hp_rage_threshold": 0.3, "low_hp_rage_damage_mult": 1.5}],
		["Construção que se esconde", "hides_underground", [], {}],
	]],
	["🚪 Entrada em campo", [
		["Fúria ao entrar", "entrance_rage_duration", ["entrance_rage_damage_mult", "entrance_rage_speed_mult"], {"entrance_rage_duration": 4.0}],
		["Onda de choque ao entrar", "entrance_shockwave_damage", ["entrance_shockwave_radius"], {"entrance_shockwave_damage": 100, "entrance_shockwave_radius": 70.0}],
		["Dano ao chegar", "deals_arrival_damage", ["arrival_damage", "arrival_damage_radius"], {"arrival_damage": 100, "arrival_damage_radius": 70.0}],
		["Atordoado ao nascer", "initial_stun_duration", [], {"initial_stun_duration": 0.5}],
		["Nasce disfarçada", "spawns_disguised", [], {}],
		["Fica invisível", "can_stealth", ["stealth_reveal_range"], {}],
		["Nasce em qualquer lugar", "can_spawn_anywhere", [], {}],
		["Atravessa água", "crosses_water", [], {}],
		["Reforço aéreo (pousa)", "landing_duration", [], {"landing_duration": 1.0}],
	]],
	["🐣 Invocação", [
		["Invoca unidades", "spawns_units", ["spawn_unit_scene", "spawn_interval", "spawn_count"], {"spawn_interval": 6.0, "spawn_count": 1}],
		["Invoca ao morrer", "spawns_on_death", ["death_spawn_scene", "death_spawn_count"], {"death_spawn_count": 2}],
		["Invoca ao atacar", "summons_on_attack", ["attack_summon_scene", "attack_summon_chance"], {"attack_summon_chance": 0.25}],
		["Se clona", "can_clone", ["clone_hp_percent", "clone_count"], {}],
		["Vira construção", "transforms_into_building", ["transform_after_seconds", "transformed_scene"], {}],
		["Converte inimigo", "can_convert_enemy", ["convert_max_targets"], {}],
	]],
	["💚 Apoio e recurso", [
		["Cura quem está perto a cada golpe", "heals_on_attack", ["attack_heal_amount", "attack_heal_radius"], {}],
		["Cura aliados perto", "can_heal_allies", ["heal_aura_amount", "heal_aura_radius", "heal_aura_interval"], {"heal_aura_amount": 20, "heal_aura_radius": 90.0}],
		["Provoca (puxa inimigos)", "forces_aggro", ["taunt_radius"], {"taunt_radius": 120.0}],
		["Explode ao morrer", "explodes_on_death", ["death_explosion_damage", "death_explosion_radius"], {"death_explosion_damage": 150, "death_explosion_radius": 70.0}],
		["Gera recurso", "generates_resource", ["resource_per_tick", "resource_tick_interval"], {}],
		["Aumenta o limite de recurso", "stores_resource", ["storage_capacity_bonus"], {}],
		["Rouba recurso ao bater na base", "steals_resource_on_base_hit", ["resource_steal_amount"], {}],
		["Dá recurso ao morrer", "grants_resource_on_death", ["death_resource_amount"], {}],
		["Ganha ouro ao matar", "converts_kills_to_gold", ["gold_per_kill"], {}],
		["Efeito de maestria (nível alto)", "mastery_effect", ["mastery_effect_duration", "mastery_effect_strength", "mastery_effect_tick_interval"], {"mastery_effect": 1}],
	]],
]
const PALETTE_KEYS = ["P", "S", "A", "K", "M", "W"]
const PALETTE_NAMES = {"P": "Principal", "S": "Secundária", "A": "Detalhe", "K": "Pele / bico", "M": "Metal", "W": "Madeira"}
const SWATCHES = ["#f0f0e8", "#c8c8c0", "#888890", "#484850", "#202028", "#e8c040", "#f0a030", "#e87028", "#c84838", "#a02828", "#f0a0b0",
	"#d860a0", "#9850c0", "#6040a0", "#4060c8", "#48a8e8", "#70d0e0", "#40a878", "#58b848", "#a0c840", "#587830", "#e8b088", "#d89868",
	"#b07848", "#8a5a34", "#6a4428", "#4a3020", "#d8c8a8", "#a0a8b4", "#f0e0a0"]
const PIECE_SLOTS = {"pe": ["cabeca", "chapeu", "corpo", "bracos", "pernas", "arma", "costas"], "quatro": ["quatro", "cabeca", "chapeu", "costas"],
	"objeto": ["objeto"], "icone": ["icone"], "torre": ["torre"]}
const SLOT_NAMES = {"cabeca": "Cabeça", "chapeu": "Chapéu", "corpo": "Corpo", "bracos": "Braços", "pernas": "Pernas", "arma": "Arma", "costas": "Costas",
	"quatro": "Corpo (4 patas)", "objeto": "Objeto", "icone": "Ícone", "torre": "Construção"}
const MODE_DEFAULTS = {"pe": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano"}, "quatro": {"quatro": "vaca", "cabeca": "vaca"},
	"objeto": {"objeto": "silo"}, "icone": {"icone": "raio"}, "torre": {"torre": "celeiro"}}

var _head: PanelContainer
var _ed_kind := ""          # "tropa" | "feitico" | "modulo"
var _ed_tab := 0
var _ed_actions: Array = []  # [salvar, pode apagar, pode restaurar, apagar, restaurar]
var _recipe: Dictionary = {}
var _palette: Dictionary = {}
var _recipe_touched := false
var _parts_open := false
var _only_on := false
var _fill_kind := 0
var _fdefs: Dictionary = {}
var _h_art: TextureRect
var _h_title: Label
var _h_sub: Label
var _h_bars: Dictionary = {}
var _h_size: SizePreview
var _readout: Label
var _ed_tab_buttons: Array = []


## rótulo de UMA linha (sem quebra): dentro do cabeçalho fixo, texto com quebra
## automática faz o painel "medir" errado (foi o defeito da coleção sumida)
func _line(text: String, font_size: int, col: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _start_editor(kind: String, on_save: Callable, can_delete: bool, can_restore: bool, on_delete: Callable, on_restore: Callable):
	_ed_kind = kind
	_ed_tab = 0
	_only_on = false
	_parts_open = false
	_ed_actions = [on_save, can_delete, can_restore, on_delete, on_restore]
	_build_head()
	_build_ed_body()


func _build_head():
	for c in _head.get_children():
		c.queue_free()
	_head.visible = true
	_h_bars = {}
	_h_size = null
	_ed_tab_buttons = []
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_head.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var frame = PanelContainer.new()
	top.add_child(frame)
	_h_art = _icon_rect(ImageTexture.create_from_image(_work["image"]), Vector2(100, 100))
	frame.add_child(_h_art)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	_h_title = _line("", 21, ThemeBuilder.COLOR_GOLD)
	_h_sub = _line("", 15, Color(0.85, 0.95, 1.0))
	col.add_child(_h_title)
	col.add_child(_h_sub)
	if _ed_kind == "tropa" or _ed_kind == "feitico":
		for key in (["vida", "dano", "geral"] if _ed_kind == "tropa" else ["dano", "cura", "raio"]):
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var nm = _line({"vida": "Vida", "dano": "Dano", "geral": "Força", "cura": "Cura", "raio": "Raio"}[key], 14, Color(0.85, 0.82, 0.75))
			nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			nm.custom_minimum_size.x = 48
			row.add_child(nm)
			var bar = ProgressBar.new()
			bar.min_value = 0
			bar.max_value = 200
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(50, 14)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var pct = _line("", 14)
			pct.size_flags_horizontal = Control.SIZE_SHRINK_END
			pct.custom_minimum_size.x = 52
			row.add_child(pct)
			col.add_child(row)
			_h_bars[key] = [bar, pct]
	if _ed_kind == "tropa":
		_h_size = SizePreview.new()
		var peao: CardData = Catalogo.card("peao_forcado")
		_h_size.ref_unit = peao.icon if peao != null else null
		_h_size.ref_tower = Catalogo.main_base().icon
		top.add_child(_h_size)
	var acts = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	v.add_child(acts)
	var save = _button("💾 Salvar", _ed_actions[0])
	save.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	save.custom_minimum_size.y = 54
	acts.add_child(save)
	var cancel = _button("Cancelar", _close_form)
	cancel.custom_minimum_size.y = 54
	acts.add_child(cancel)
	if _ed_actions[1]:
		var del = _button("🗑 Apagar", _ed_actions[3])
		del.custom_minimum_size.y = 54
		acts.add_child(del)
	elif _ed_actions[2] and _ed_actions[4].is_valid():
		var res = _button("↺ Original", _ed_actions[4])
		res.custom_minimum_size.y = 54
		acts.add_child(res)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	var names: Array = ED_TABS[_ed_kind]
	for i in names.size():
		var b = _button(str(names[i]), _show_ed_tab.bind(i))
		b.toggle_mode = true
		b.button_pressed = i == _ed_tab
		b.custom_minimum_size.y = 50
		b.add_theme_font_size_override("font_size", 16)
		tabs.add_child(b)
		_ed_tab_buttons.append(b)
	_refresh_head()


func _show_ed_tab(i: int):
	_ed_tab = i
	for k in _ed_tab_buttons.size():
		if is_instance_valid(_ed_tab_buttons[k]):
			_ed_tab_buttons[k].button_pressed = k == i
	_build_ed_body()
	_refresh_head()


func _refresh_head():
	if !is_instance_valid(_head) or !_head.visible or _work.is_empty() or !is_instance_valid(_h_title):
		return
	if is_instance_valid(_h_art):
		_h_art.texture = ImageTexture.create_from_image(_work["image"])
	_update_readout()
	if _ed_kind == "modulo":
		var b: BaseData = _work["base"]
		_h_title.text = b.base_name
		_h_sub.text = "❤ %d  ·  %s" % [b.base_hp, BASE_TYPE_NAMES[clampi(int(b.base_type), 0, BASE_TYPE_NAMES.size() - 1)]]
		return
	var card: CardData = _work["card"]
	_h_title.text = card.card_name
	if _ed_kind == "feitico":
		var sp: SpellData = _work["spell"]
		var np = Regua.spell_pulses(sp)
		_h_sub.text = "Feitiço  ·  custo %d  ·  dano %d%s  ·  raio %d" % [card.cost, sp.damage, (" x%d" % np) if np > 1 else "", int(sp.radius)]
		var sc = Regua.spell_compare(sp, card.cost)
		for key in _h_bars:
			var sp_p = int(sc[key])
			var sbar: ProgressBar = _h_bars[key][0]
			var spct: Label = _h_bars[key][1]
			sbar.value = clampi(sp_p, 0, 200)
			spct.text = "%d%%" % sp_p if sp_p >= 0 else "não tem"
			var scol = Color(0.6, 0.6, 0.6) if sp_p < 0 else (Color(0.5, 1.0, 0.5) if (sp_p >= 85 and sp_p <= 115) else (Color(1.0, 0.85, 0.35) if (sp_p >= 70 and sp_p <= 130) else Color(1.0, 0.45, 0.4)))
			sbar.modulate = scol
			spct.add_theme_color_override("font_color", scol)
		return
	var st: UnitData = _work["stats"]
	var cmp = Regua.compare(st, card.cost)
	var kd: Dictionary = Catalogo.KINDS.get(cmp["kind"], {})
	_h_sub.text = "%s  ·  custo %d  ·  ❤ %d%s  ⚔ %d" % [kd.get("nome", "?"), card.cost, st.hp, (" x%d" % st.unit_count) if st.unit_count > 1 else "", st.damage]
	for key in _h_bars:
		var p = int(cmp[key])
		var bar: ProgressBar = _h_bars[key][0]
		var pct: Label = _h_bars[key][1]
		bar.value = clampi(p, 0, 200)
		pct.text = "%d%%" % p
		var c = Color(0.5, 1.0, 0.5) if (p >= 85 and p <= 115) else (Color(1.0, 0.85, 0.35) if (p >= 70 and p <= 130) else Color(1.0, 0.45, 0.4))
		bar.modulate = c
		pct.add_theme_color_override("font_color", c)
	if is_instance_valid(_h_size):
		_h_size.art = _h_art.texture
		_h_size.unit_scale = st.unit_scale
		_h_size.queue_redraw()


func _build_ed_body():
	_clear_body()
	_readout = null
	_field_box = VBoxContainer.new()
	_field_box.add_theme_constant_override("separation", 6)
	_body.add_child(_field_box)
	match str(ED_TABS[_ed_kind][_ed_tab]):
		"Básico": _tab_basico()
		"Combate": _tab_combate()
		"Habilidades": _tab_habilidades()
		"Visual": _tab_visual()
		"Teste": _tab_teste()
		"Efeito": _tab_efeito()
		"Função": _tab_funcao()
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 140)  # espaço pro teclado do celular não cobrir o último campo
	_body.add_child(spacer)


func _note(text: String, col: Color = Color(0.85, 0.82, 0.75)) -> Label:
	var l = _label(text, 14)
	l.add_theme_color_override("font_color", col)
	return l


func _field_defs() -> Dictionary:
	if _fdefs.is_empty():
		for f in CustomContent.all_unit_fields():
			_fdefs[f[0]] = f
	return _fdefs


# ---------------------------------------------------------------- aba Básico
func _tab_basico():
	if _ed_kind == "modulo":
		for f in CustomContent.BASE_FIELDS:
			if f[0] in ["base_name", "description", "nation_data", "category", "unlock_arena"]:
				_field(_work["base"], f)
		return
	for f in CustomContent.CARD_FIELDS:
		if _ed_kind == "feitico" and str(f[0]).begins_with("companion_"):
			continue   # feitiço não leva tropa junto (ele invoca: está na aba Efeito)
		_field(_work["card"], f)
	if _ed_kind != "tropa":
		return
	var card: CardData = _orig["card"]
	if _orig.get("is_new", false) or CustomContent.is_custom(card):
		var so = CheckButton.new()
		so.text = "🐣 Só invocação (não vai pro baralho; serve de filhote pra outra carta)"
		so.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		so.custom_minimum_size = Vector2(0, 64)
		so.button_pressed = CustomContent.is_spawn_only(card)
		so.toggled.connect(func(on): _work["card"].set_meta("spawn_only", on))
		_field_box.add_child(so)
	# a régua: preenche os números pelo padrão do tipo
	var p = PanelContainer.new()
	_field_box.add_child(p)
	var v = VBoxContainer.new()
	p.add_child(v)
	var t = _label("✨ Preencher pelo padrão", 19)
	t.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	v.add_child(t)
	v.add_child(_note("Escolha o tipo. O Criador põe vida, dano, velocidade, alcance, quantidade e tamanho no padrão das cartas do jogo desse tipo, pro custo que está acima. Depois você ajusta o que quiser."))
	var names: Array = []
	for k in Regua.KIND_ORDER:
		names.append(str(Catalogo.KINDS[k]["nome"]))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(_option(names, _fill_kind, func(i): _fill_kind = i))
	row.add_child(_button("Preencher", _apply_standard))


func _apply_standard():
	var st: UnitData = _work["stats"]
	var kind = str(Regua.KIND_ORDER[clampi(_fill_kind, 0, Regua.KIND_ORDER.size() - 1)])
	var sug = Regua.suggest(kind, _work["card"].cost)
	for prop in sug:
		if st.get(prop) != null:
			CustomContent.set_prop(st, prop, sug[prop])
	if st.is_ranged:
		st.detection_range = maxf(st.detection_range, st.attack_range + 20.0)
	if st.unit_type != UnitData.UnitType.BUILDING:
		st.unit_scale = Regras.strength_scale(st.hp, st.damage, Catalogo.porte(_recipe))
	_refresh_head()
	_say("✔ Números no padrão de %s pro custo %d. Confira na aba Combate." % [Catalogo.KINDS[kind]["nome"], _work["card"].cost])


# ---------------------------------------------------------------- aba Combate
func _tab_combate():
	var st: UnitData = _work["stats"]
	var defs = _field_defs()
	_readout = _note("", Color(0.75, 0.95, 1.0))
	_field_box.add_child(_readout)
	for prop in CORE_PROPS:
		if defs.has(prop):
			_field(st, defs[prop])
	_update_readout()


func _update_readout():
	if is_instance_valid(_readout) and _ed_kind == "feitico" and _work.get("spell") != null:
		_readout.text = "📜 " + _spell_summary(_work["spell"])
		return
	if is_instance_valid(_readout) and _ed_kind == "modulo" and _work.get("base") != null:
		# os números do módulo passam pela regra das torres antes de ir pro campo
		var b: BaseData = _work["base"]
		var txt = "No campo (nível 1): ❤ %d" % Regras.tower_hp(b)
		if Regras.tower_shoots(b):
			txt += "  ·  tiro %d a cada %.1fs  ·  alcance %d" % [int(round(Regras.tower_damage(b))), Regras.tower_interval(b), int(Regras.tower_range(b))]
		_readout.text = txt + ". A regra das torres multiplica vida e tiro pra todos os módulos por igual."
		return
	if !is_instance_valid(_readout) or _work.get("stats") == null:
		return
	var st: UnitData = _work["stats"]
	var n = maxi(st.unit_count, 1)
	var dps = st.damage / maxf(st.attack_speed, 0.1)
	var shot = maxf(Regras.tower_damage(Catalogo.main_base()), 1.0)
	_readout.text = "Dano por segundo: %d%s  ·  vida total: %d  ·  cada uma aguenta %d tiro(s) de torre" % [int(round(dps * n)),
		(" (%d cada)" % int(round(dps))) if n > 1 else "", st.hp * n, int(ceil(st.hp / shot))]


# ---------------------------------------------------------------- aba Habilidades
func _ability_on(st: UnitData, key: String) -> bool:
	var v = st.get(key)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return false


func _tab_habilidades():
	var st: UnitData = _work["stats"]
	var defs = _field_defs()
	var used := {"unit_scale": true}
	for p in CORE_PROPS:
		used[p] = true
	var on_total = 0
	for group in ABILITIES:
		for ab in group[1]:
			if defs.has(ab[1]) and _ability_on(st, ab[1]):
				on_total += 1
	_field_box.add_child(_note("%d habilidade(s) ligada(s). Toque numa pra ligar: só a ligada mostra os números dela." % on_total, Color(0.75, 0.95, 1.0)))
	_field_box.add_child(_button("Mostrando: " + ("só as ligadas" if _only_on else "todas"), func():
		_only_on = !_only_on
		_build_ed_body()))
	for group in ABILITIES:
		var on_list: Array = []
		var off_list: Array = []
		for ab in group[1]:
			if !defs.has(ab[1]):
				continue
			used[ab[1]] = true
			for prm in ab[2]:
				used[prm] = true
			if _ability_on(st, ab[1]):
				on_list.append(ab)
			else:
				off_list.append(ab)
		if on_list.is_empty() and (off_list.is_empty() or _only_on):
			continue
		_section(str(group[0]))
		for ab in on_list:
			_ability_panel(st, ab, defs)
		if !_only_on and !off_list.is_empty():
			var flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			_field_box.add_child(flow)
			for ab in off_list:
				var chip = Button.new()
				chip.text = "＋ " + str(ab[0])
				chip.custom_minimum_size = Vector2(0, 48)
				chip.add_theme_font_size_override("font_size", 15)
				chip.pressed.connect(_toggle_ability.bind(ab, true))
				flow.add_child(chip)
	if _only_on:
		return
	var rest: Array = []
	for f in CustomContent.all_unit_fields():
		if !used.has(f[0]):
			rest.append(f)
	if !rest.is_empty():
		_section("Outros números")
		for f in rest:
			_field(st, f)


func _ability_panel(st: UnitData, ab: Array, defs: Dictionary):
	var p = PanelContainer.new()
	_field_box.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hb = _button("✔ %s    (toque pra desligar)" % str(ab[0]), _toggle_ability.bind(ab, false))
	hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.custom_minimum_size.y = 50
	hb.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	v.add_child(hb)
	var keep = _field_box
	_field_box = v
	if str(defs[ab[1]][2]) != "bool":
		_field(st, defs[ab[1]])
	for prm in ab[2]:
		if defs.has(prm):
			_field(st, defs[prm])
	_field_box = keep


func _toggle_ability(ab: Array, on: bool):
	if _work.get("stats") == null:
		return
	var st: UnitData = _work["stats"]
	var cur = st.get(ab[1])
	if cur is bool:
		st.set(ab[1], on)
	elif !on:
		CustomContent.set_prop(st, ab[1], 0)
	if on:
		var start: Dictionary = ab[3]
		for prop in start:
			var val = st.get(prop)
			if (val is bool and !val) or ((val is int or val is float) and val == 0):
				CustomContent.set_prop(st, prop, start[prop])
		if !(cur is bool) and !_ability_on(st, ab[1]):
			CustomContent.set_prop(st, ab[1], 1)
	var y = _scroll.scroll_vertical
	_build_ed_body()
	_refresh_head()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = y


# ---------------------------------------------------------------- aba Visual
func _set_image(img: Image):
	_work["image"] = img
	_image_changed = true
	if is_instance_valid(_art_rect):
		_art_rect.texture = ImageTexture.create_from_image(img)
	_refresh_head()


func _recipe_mode() -> String:
	for m in ["torre", "icone", "objeto", "quatro"]:
		if str(_recipe.get(m, "")) != "":
			return m
	if _recipe.is_empty():
		return "torre" if _ed_kind == "modulo" else ("icone" if _ed_kind == "feitico" else "pe")
	return "pe"


func _tab_visual():
	var art_size: Vector2i = CustomContent.BASE_ART_SIZE if _ed_kind == "modulo" else CustomContent.CARD_ART_SIZE
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_field_box.add_child(row)
	var frame = PanelContainer.new()
	row.add_child(frame)
	_art_rect = _icon_rect(ImageTexture.create_from_image(_work["image"]), Vector2(180, 180))
	frame.add_child(_art_rect)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_button("🧩 Montar por peças" + (" ▲" if _parts_open else " ▼"), func():
		_parts_open = !_parts_open
		_build_ed_body()))
	col.add_child(_button("🎨 Desenhar pixel a pixel", func():
		_open_pixel_editor(_work["image"], "Arte", func(img: Image):
			if !_work.is_empty():
				_set_image(img))))
	col.add_child(_button("🎲 Arte aleatória", func():
		_set_image(CardGenerator.generate_sprite(art_size.x, art_size.y, randi()))))
	if _parts_open:
		_parts_picker()
	if _ed_kind == "tropa":
		var st: UnitData = _work["stats"]
		_section("Tamanho no campo")
		var rule = Regras.strength_scale(st.hp, st.damage, Catalogo.porte(_recipe))
		_field_box.add_child(_note("O desenho do cabeçalho mostra a tropa ao lado de um Peão e da Casa Grande. Pela regra do jogo (força × porte do bicho) esta carta teria tamanho %.2f." % rule))
		_field(st, _field_defs()["unit_scale"])
		_field_box.add_child(_button("📏 Usar o tamanho da regra (%.2f)" % rule, func():
			st.unit_scale = Regras.strength_scale(st.hp, st.damage, Catalogo.porte(_recipe))
			_build_ed_body()
			_refresh_head()))
		_section("Projétil (só vale com \"Ataque à distância\" ligado)")
		_build_proj_block()
	elif _ed_kind == "modulo":
		_section("Projétil do canhão")
		_build_proj_block()


func _parts_picker():
	var p = PanelContainer.new()
	_field_box.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var mode = _recipe_mode()
	if _ed_kind == "tropa":
		var modes = ["pe", "quatro", "objeto"]
		var mrow = HBoxContainer.new()
		mrow.add_child(_field_label("Postura"))
		mrow.add_child(_option(["Em pé (peças)", "Quatro patas", "Objeto / construção"], maxi(modes.find(mode), 0), func(i):
			_recipe = MODE_DEFAULTS[modes[i]].duplicate()
			_regen_art()
			_build_ed_body()))
		v.add_child(mrow)
	# TEMA: filtra as peças de todas as listas abaixo (Comida, Guerra, Oceano...)
	var themes: Array = ["Todos os temas", "Fazenda"] + PecasIndex.TEMAS.keys()
	var trow = HBoxContainer.new()
	trow.add_child(_field_label("Tema das peças"))
	trow.add_child(_option(themes, maxi(themes.find(_theme), 0), func(i):
		_theme = str(themes[i])
		_build_ed_body()))
	v.add_child(trow)
	for slot in PIECE_SLOTS[mode]:
		var solo = PIECE_SLOTS[mode].size() == 1
		var items: Array = ([] if solo else [""])
		for piece in SpriteForge.pieces(slot):
			if _piece_in_theme(str(piece)) or str(piece) == str(_recipe.get(slot, "")):
				items.append(piece)
		if items.is_empty() or (items.size() == 1 and str(items[0]) == ""):
			continue   # este tema não tem peça pra este lugar
		var shown: Array = []
		for it in items:
			shown.append("(nada)" if str(it) == "" else str(it).replace("_", " ").capitalize())
		var srow = HBoxContainer.new()
		srow.add_child(_field_label(str(SLOT_NAMES.get(slot, slot))))
		var slot_name = str(slot)
		srow.add_child(_option(shown, maxi(items.find(str(_recipe.get(slot, ""))), 0), func(i):
			if str(items[i]) == "":
				_recipe.erase(slot_name)
			else:
				_recipe[slot_name] = str(items[i])
			_regen_art()))
		v.add_child(srow)
	# SORTEAR: troca só as peças dos lugares que você já está usando (dentro do tema escolhido)
	var rrow = HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	rrow.add_child(_button("🎲 Sortear peças", _shuffle_pieces))
	rrow.add_child(_button("🎨 Sortear cores", _shuffle_colors))
	v.add_child(rrow)
	v.add_child(_note("Sortear peças mexe só nos lugares que já têm peça (não põe chapéu em quem está sem), dentro do tema. Toque quantas vezes quiser."))
	var ct = _label("Cores (toque pra trocar)", 16)
	ct.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	v.add_child(ct)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for key in PALETTE_KEYS:
		var cell = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb = _color_button(Color(str(_palette.get(key, SpriteForge.DEFAULT_PALETTE[key]))), _pick_color.bind(key))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(cb)
		var cl = _line(str(PALETTE_NAMES[key]), 13, Color(0.85, 0.82, 0.75))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cl)
		grid.add_child(cell)


func _regen_art():
	if _recipe.is_empty():
		_recipe = MODE_DEFAULTS[_recipe_mode()].duplicate()
	_recipe_touched = true
	_set_image(SpriteForge.make_image(_recipe, _palette))


func _color_button(col: Color, cb: Callable) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(64, 52)
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0.55)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(cb)
	return b


func _pick_color(key: String):
	var layer = CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_line("Cor: " + str(PALETTE_NAMES[key]), 20, ThemeBuilder.COLOR_GOLD))
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for hex in SWATCHES:
		var h = str(hex)
		grid.add_child(_color_button(Color(h), func():
			layer.queue_free()
			_palette[key] = h
			_regen_art()
			_build_ed_body()))
	v.add_child(_button("Cancelar", func(): layer.queue_free()))


# ---------------------------------------------------------------- aba Teste
func _tab_teste():
	if _ed_kind == "feitico":
		_tab_teste_feitico()
		return
	var st: UnitData = _work["stats"]
	var card: CardData = _work["card"]
	var cmp = Regua.compare(st, card.cost)
	var kd: Dictionary = Catalogo.KINDS.get(cmp["kind"], {})
	var std = Regua.standard(cmp["kind"])
	var t = _label("Tipo: %s" % kd.get("nome", "?"), 20)
	t.add_theme_color_override("font_color", Color(str(kd.get("cor", "#ffffff"))))
	_field_box.add_child(t)
	_field_box.add_child(_note(str(kd.get("serve", ""))))
	_field_box.add_child(_note("Ganha de: %s   ·   Perde pra: %s" % [kd.get("ganha", "-"), kd.get("perde", "-")], Color(0.75, 0.95, 1.0)))
	_section("Régua (padrão de %d cartas desse tipo, custo %d)" % [int(std.get("cartas", 0)), card.cost])
	var n = maxi(st.unit_count, 1)
	_field_box.add_child(_note("Vida total: %d  (padrão %d)  →  %d%%" % [st.hp * n, int(round(std["hp_c"] * card.cost)), cmp["vida"]]))
	_field_box.add_child(_note("Dano por segundo: %d  (padrão %d)  →  %d%%" % [int(round(st.damage / maxf(st.attack_speed, 0.1) * n)), int(round(std["dps_c"] * card.cost)), cmp["dano"]]))
	_field_box.add_child(_note("Força geral: %d%% do normal pra esse custo. Entre 85%% e 115%% é equilibrada; habilidade especial não entra nessa conta." % cmp["geral"]))
	if st.unit_type != UnitData.UnitType.BUILDING:
		_section("Contra uma torre")
		_field_box.add_child(_note("Sozinha, se ninguém defender, tira %d%% da vida de um módulo de tiro (Celeiro)." % int(round(DueloPapel.tower_share_stats(st) * 100.0))))
	if st.unit_type == UnitData.UnitType.BUILDING or st.target_type == UnitData.TargetType.BUILDING:
		_field_box.add_child(_note("Construção e quem só bate em torre não entram em duelo."))
		return
	_section("Duelo contra cartas de custo parecido")
	var refs: Array = []
	for c in Catalogo.cards():
		if c != null and DueloPapel.duels(c) and c.card_name != card.card_name:
			refs.append(c)
	refs.sort_custom(func(a, b): return absi(a.cost - card.cost) < absi(b.cost - card.cost))
	var wins = 0
	var lines: Array = []
	for c in refs.slice(0, 10):
		var r = DueloPapel.duel_stats(st, c)
		if r > 0.02:
			wins += 1
			lines.append(["✔ ganha de %s (custo %d): sobra %d%% da vida" % [c.card_name, c.cost, int(round(r * 100.0))], Color(0.6, 1.0, 0.6)])
		elif r < -0.02:
			lines.append(["✖ perde pra %s (custo %d): ele fica com %d%%" % [c.card_name, c.cost, int(round(-r * 100.0))], Color(1.0, 0.62, 0.55)])
		else:
			lines.append(["= empata com %s (custo %d)" % [c.card_name, c.cost], Color(0.9, 0.9, 0.8)])
	_field_box.add_child(_note("Ganhou %d de %d." % [wins, lines.size()], Color(0.75, 0.95, 1.0)))
	for l in lines:
		_field_box.add_child(_note(str(l[0]), l[1]))
	_field_box.add_child(_note("É uma conta no papel (vida, dano, alcance, velocidade, quantidade e as habilidades principais), feita na hora com os números que estão na tela. Serve pra comparar; não substitui jogar."))


# ---------------------------------------------------------------- feitiço e módulo
const SPELL_GROUPS = [["Onde e por quanto tempo", ["radius", "duration", "tick_interval", "affects_enemies", "affects_allies"]],
	["Dano", ["damage", "base_damage_multiplier", "knockback_distance"]],
	["Efeito em quem é atingido", ["status_effect", "status_effect_strength", "status_effect_duration"]],
	["Cura e escudo nos aliados", ["heal_amount", "shield_amount"]],
	["Fúria nos aliados", ["rage_damage_mult", "rage_speed_mult", "rage_attack_speed_mult"]],
	["Reforço nos aliados (fúria, escudo, limpar)", ["buff_duration", "cleanses"]],
	["Invocação", ["summon_scene", "summon_count"]],
	["Jeitos especiais", ["rolls", "roll_distance", "roll_speed", "picks_strongest", "mirror"]]]

# MOLDES: um toque monta o feitiço inteiro, na força certa pro custo da carta (pela régua).
# "d" e "h" são frações do dano/cura padrão do custo; o resto são os campos do feitiço
const SPELL_MOLDS = [
	["🔥 Bola de fogo", {"radius": 90.0, "d": 1.0, "knockback_distance": 0.0}],
	["⚡ Raio", {"radius": 60.0, "d": 0.65, "status_effect": UnitData.OnHitEffect.STUN, "status_effect_duration": 0.6}],
	["🎯 Tiro certeiro", {"radius": 110.0, "d": 1.5, "picks_strongest": 1}],
	["Veneno", {"radius": 110.0, "d": 1.3, "duration": 8.0, "tick_interval": 1.0, "status_effect": UnitData.OnHitEffect.SLOW, "status_effect_strength": 0.15}],
	["❄ Gelo", {"radius": 100.0, "d": 0.25, "status_effect": UnitData.OnHitEffect.FREEZE, "status_effect_duration": 3.0}],
	["Tornado", {"radius": 110.0, "d": 0.5, "duration": 3.0, "tick_interval": 0.5, "status_effect": UnitData.OnHitEffect.PULL, "knockback_distance": 40.0}],
	["🪵 Tronco", {"radius": 55.0, "d": 0.7, "rolls": true, "status_effect": UnitData.OnHitEffect.KNOCKBACK, "knockback_distance": 45.0}],
	["🌋 Terremoto", {"radius": 120.0, "d": 0.5, "duration": 3.0, "tick_interval": 1.0, "base_damage_multiplier": 1.0, "status_effect": UnitData.OnHitEffect.SLOW, "status_effect_strength": 0.35}],
	["💚 Cura", {"radius": 110.0, "h": 1.0, "duration": 3.0, "tick_interval": 0.5, "affects_enemies": false, "affects_allies": true}],
	["💢 Fúria", {"radius": 120.0, "duration": 6.0, "affects_enemies": false, "affects_allies": true, "rage_damage_mult": 1.35, "rage_speed_mult": 1.35, "rage_attack_speed_mult": 1.35}],
	["Escudo", {"radius": 110.0, "s": 0.8, "affects_enemies": false, "affects_allies": true, "cleanses": true}],
]


func _apply_spell_mold(i: int):
	var sp: SpellData = _work["spell"]
	var mold: Dictionary = SPELL_MOLDS[i][1]
	var blank = SpellData.new()
	for f in CustomContent.SPELL_FIELDS:        # zera tudo pro padrão antes: molde não mistura com o que tinha
		if str(f[2]) != "scene" and blank.get(f[0]) != null:
			sp.set(f[0], blank.get(f[0]))
	sp.summon_count = 0
	for k in mold:
		if !(k in ["d", "h", "s"]):
			sp.set(k, mold[k])
	var std = Regua.spell_standard()
	var cost = maxf(float(_work["card"].cost), 1.0)
	var pulses = maxi(Regua.spell_pulses(sp), 1)
	sp.damage = int(round(float(std["dmg_c"]) * cost * float(mold.get("d", 0.0)) / pulses / 5.0)) * 5
	sp.heal_amount = int(round(float(std["cura_c"]) * cost * float(mold.get("h", 0.0)) / pulses / 5.0)) * 5
	sp.shield_amount = int(round(float(std["dmg_c"]) * cost * float(mold.get("s", 0.0)) / 10.0)) * 10
	_build_ed_body()
	_refresh_head()


## o feitiço contado em português, pra conferir de bate-pronto o que ele faz
func _spell_summary(sp: SpellData) -> String:
	if sp.mirror:
		return "Espelho: repete a última carta que você jogou."
	var parts: Array = []
	var n = maxi(Regua.spell_pulses(sp), 1)
	var who: Array = []
	if sp.affects_enemies:
		who.append("inimigos")
	if sp.affects_allies:
		who.append("aliados")
	var head = "Num raio de %d" % int(sp.radius)
	if sp.rolls:
		head = "Rola %d pra frente (largura %d)" % [int(sp.roll_distance), int(sp.radius * 2)]
	head += ", " + ("na hora" if sp.duration <= 0.0 else "por %.1fs (%d pulsos)" % [sp.duration, n])
	head += ", pega " + (" e ".join(who) if !who.is_empty() else "NINGUÉM (ligue inimigos ou aliados)")
	if sp.picks_strongest > 0:
		head += " — só os %d de mais vida" % sp.picks_strongest
	if sp.damage > 0:
		parts.append("dano %d" % (sp.damage * n) + ((" (%d x %d)" % [sp.damage, n]) if n > 1 else "") + ", nas torres %d" % int(round(sp.damage * n * sp.base_damage_multiplier)))
	if int(sp.status_effect) > 0:
		var e = str(CustomContent.EFFECT_NAMES[clampi(int(sp.status_effect), 0, CustomContent.EFFECT_NAMES.size() - 1)]).to_lower()
		parts.append(e + ((" por %.1fs" % sp.status_effect_duration) if sp.status_effect_duration > 0.0 else ""))
	if sp.heal_amount > 0:
		parts.append("cura %d" % (sp.heal_amount * n))
	if sp.shield_amount > 0:
		parts.append("escudo de %d" % sp.shield_amount)
	if sp.rage_damage_mult > 1.0 or sp.rage_speed_mult > 1.0 or sp.rage_attack_speed_mult > 1.0:
		parts.append("fúria (dano x%.2f, passo x%.2f, ataque x%.2f)" % [sp.rage_damage_mult, sp.rage_speed_mult, sp.rage_attack_speed_mult])
	if sp.cleanses:
		parts.append("tira efeitos ruins")
	if sp.summon_scene != null and sp.summon_count > 0:
		parts.append("invoca %d tropa(s)" % sp.summon_count)
	if parts.is_empty():
		return head + ". ⚠ Ainda não faz nada: ponha dano, cura, efeito, fúria, escudo ou invocação."
	return head + ": " + "; ".join(parts) + "."


func _tab_efeito():
	var defs := {}
	for f in CustomContent.SPELL_FIELDS:
		defs[f[0]] = f
	var used := {}
	_readout = _note("", Color(0.75, 0.95, 1.0))
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_box.add_child(_readout)
	_update_readout()
	_section("Moldes prontos (na força do custo %d)" % int(_work["card"].cost))
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_field_box.add_child(flow)
	for i in SPELL_MOLDS.size():
		flow.add_child(_button(str(SPELL_MOLDS[i][0]), _apply_spell_mold.bind(i)))
	_field_box.add_child(_note("Um toque monta o feitiço inteiro e apaga o que tinha nesta aba. Depois é só ajustar os números embaixo."))
	for g in SPELL_GROUPS:
		_section(str(g[0]))
		for prop in g[1]:
			if defs.has(prop):
				used[prop] = true
				_field(_work["spell"], defs[prop])
	var rest: Array = []
	for f in CustomContent.SPELL_FIELDS:
		if !used.has(f[0]):
			rest.append(f)
	if !rest.is_empty():
		_section("Outros")
		for f in rest:
			_field(_work["spell"], f)


func _tab_funcao():
	var b: BaseData = _work["base"]
	var defs := {}
	for f in CustomContent.BASE_FIELDS:
		defs[f[0]] = f
	_readout = _note("", Color(0.75, 0.95, 1.0))
	_field_box.add_child(_readout)
	_update_readout()
	_field(b, defs["base_hp"])
	var row = HBoxContainer.new()
	row.add_child(_field_label("Função"))
	row.add_child(_option(BASE_TYPE_NAMES, int(b.base_type), func(i):
		b.base_type = i
		_build_ed_body()
		_refresh_head()))
	_field_box.add_child(row)
	var kind = clampi(int(b.base_type), 0, 5)
	if BASE_TYPE_FIELDS[kind].is_empty():
		_field_box.add_child(_note("Esta função não tem número próprio: o módulo vale pela vida e pelo que estiver ligado em \"Especial\" aqui embaixo."))
	for prop in BASE_TYPE_FIELDS[kind]:
		_field(b, defs[prop])
	_section("Especial (vale com qualquer função)")
	for prop in ["spawn_card_id", "spawn_on_hit", "spawn_cooldown", "ally_speed_bonus", "ally_speed_max_cost"]:
		if defs.has(prop):
			_field(b, defs[prop])


## a tropa desenhada no tamanho de campo, entre um Peão e a Casa Grande
class SizePreview extends Control:
	var art: Texture2D
	var unit_scale := 1.0
	var ref_unit: Texture2D
	var ref_tower: Texture2D

	func _init():
		custom_minimum_size = Vector2(196, 100)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw():
		var k = 0.6
		var ground = size.y - 4.0
		draw_line(Vector2(0, ground), Vector2(size.x, ground), Color(1, 1, 1, 0.25), 2.0)
		var unit_px = 48.0 * 1.1 * Regras.SPRITE_BOOST * k
		var x = 2.0
		for it in [[ref_unit, unit_px, 0.5], [art, unit_px * clampf(unit_scale, 0.2, 3.0), 1.0], [ref_tower, 150.0 * k, 0.5]]:
			if it[0] == null:
				continue
			var s = float(it[1])
			draw_texture_rect(it[0], Rect2(x, ground - s, s, s), false, Color(1, 1, 1, float(it[2])))
			x += s * 0.8 + 4.0


## Teste do feitiço: o que o dano dele faz, na hora, com os números da tela
func _tab_teste_feitico():
	var sp: SpellData = _work["spell"]
	var card: CardData = _work["card"]
	var std = Regua.spell_standard()
	var cmp = Regua.spell_compare(sp, card.cost)
	var n = Regua.spell_pulses(sp)
	var total = sp.damage * n
	_section("Régua (padrão de %d feitiços do jogo, custo %d)" % [int(std["cartas"]), card.cost])
	if sp.damage > 0:
		_field_box.add_child(_note("Dano total: %d%s  (padrão %d)  →  %d%%" % [total, (" (%d x %d)" % [sp.damage, n]) if n > 1 else "", int(round(std["dmg_c"] * card.cost)), cmp["dano"]]))
	if sp.heal_amount > 0:
		_field_box.add_child(_note("Cura total: %d  (padrão %d)  →  %d%%" % [sp.heal_amount * n, int(round(std["cura_c"] * card.cost)), cmp["cura"]]))
	_field_box.add_child(_note("Raio: %d  (padrão %d)  →  %d%%" % [int(sp.radius), int(std["raio"]), cmp["raio"]]))
	if sp.damage <= 0 and sp.heal_amount <= 0:
		_field_box.add_child(_note("Este feitiço não dá dano nem cura: ele vale pelo efeito, e efeito não entra na régua."))
	if sp.damage <= 0 or !sp.affects_enemies:
		return
	_section("Contra uma torre")
	var tower_hp = maxf(float(Regras.tower_hp(Catalogo.bases()[0])), 1.0) if !Catalogo.bases().is_empty() else 1560.0
	var on_tower = total * sp.base_damage_multiplier
	_field_box.add_child(_note("Tira %d de vida de um módulo (%d%% de um Celeiro). Feitiço bate em construção com %d%% do dano." % [int(round(on_tower)), int(round(on_tower / tower_hp * 100.0)), int(round(sp.base_damage_multiplier * 100.0))]))
	_section("Contra tropas de custo parecido")
	var refs: Array = []
	for c in Catalogo.cards():
		if c == null or c.is_spell():
			continue
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st != null and st.unit_type != UnitData.UnitType.BUILDING:
			refs.append(c)
	refs.sort_custom(func(a, b): return absi(a.cost - card.cost) < absi(b.cost - card.cost))
	var kills = 0
	var lines: Array = []
	for c in refs.slice(0, 12):
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		var each = "cada um" if st.unit_count > 1 else "ela"
		if total >= st.hp:
			kills += 1
			lines.append(["✔ mata %s (custo %d, %d de vida%s)" % [c.card_name, c.cost, st.hp, " x%d" % st.unit_count if st.unit_count > 1 else ""], Color(0.6, 1.0, 0.6)])
		else:
			lines.append(["✖ não mata %s (custo %d): tira %d%% da vida d%s" % [c.card_name, c.cost, int(round(total * 100.0 / maxf(st.hp, 1.0))), "e " + each if each == "cada um" else "ela"], Color(1.0, 0.75, 0.6)])
	_field_box.add_child(_note("Mata %d de %d (se pegar todo mundo dentro do raio)." % [kills, lines.size()], Color(0.75, 0.95, 1.0)))
	for l in lines:
		_field_box.add_child(_note(str(l[0]), l[1]))
	_field_box.add_child(_note("Conta feita com os números da tela, no nível 1. Feitiço que fica no chão só dá o dano total em quem ficar dentro até o fim."))


func _apply_zero_later():
	CustomContent.apply_zero()


## Coleção do jogo: começar do zero, pausar o criador automático e a cópia de segurança
func _build_collection_panel():
	var p = PanelContainer.new()
	_body.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t = _label("⚙ Coleção do jogo", 20)
	t.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	v.add_child(t)
	var zero = CustomContent.zero_on()
	var zb = _button("Começar do zero: " + ("LIGADO (só as suas cartas)" if zero else "desligado (todas as cartas do jogo)"), func():
		Config.data["do_zero"] = !CustomContent.zero_on()
		Config.save()
		CustomContent.apply_zero()
		_show_list())
	zb.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if zero else Color(1, 1, 1))
	v.add_child(zb)
	if zero:
		var mine = CustomContent.zero_pool().size() - CustomContent.zero_borrowed()
		v.add_child(_note("Em jogo: %d carta(s) sua(s)%s. Baralho e bots usam só essas. Carta de arena 0 já nasce com você; as de arena maior caem nos baús e na Feira quando você chega nessa arena, e o bot só usa as da arena dele. As cartas do jogo não foram apagadas: desligue aqui e voltam todas." % [mine,
			" (com menos de 8, elas se repetem no baralho)" if (mine > 0 and mine < 8) else (". A coleção está vazia e não dá pra batalhar até você criar a primeira" if mine == 0 else "")], Color(0.75, 0.95, 1.0)))
	else:
		v.add_child(_note("Ligado, o jogo passa a usar só as cartas que você criar, uma por uma. Nada é apagado de verdade."))
	if zero:
		var lend = bool(Config.data.get("zero_inicial", false))
		v.add_child(_button("Cartas iniciais do jogo: " + ("EMPRESTADAS enquanto você não tem nenhuma" if lend else "travadas (não existem)"), func():
			Config.data["zero_inicial"] = !bool(Config.data.get("zero_inicial", false))
			Config.save()
			CustomContent.apply_zero()
			_show_list()))
	var zm = CustomContent.zero_modules_on()
	var zmb = _button("Módulos do zero: " + ("LIGADO (só os seus módulos)" if zm else "desligado (todos os módulos do jogo)"), func():
		Config.data["do_zero_mod"] = !CustomContent.zero_modules_on()
		Config.save()
		CustomContent.apply_zero()
		_show_list())
	zmb.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if zm else Color(1, 1, 1))
	v.add_child(zmb)
	if zm:
		v.add_child(_note("Em jogo: %d módulo(s) seu(s). Sem nenhum, a batalha é só com a Casa Grande, pros dois lados. Crie na aba Módulos; desligando aqui, os do jogo voltam." % BotSimulator.available_bases.size(), Color(0.75, 0.95, 1.0)))
	v.add_child(_button("Cartas da safra: " + ("DESLIGADAS (não existem no jogo)" if CustomContent.safra_off() else "ligadas"), func():
		Config.data["safra_off"] = !CustomContent.safra_off()
		Config.save()
		CustomContent.apply_zero()
		_show_list()))
	v.add_child(_button("Assembleia (bufa e nerfa cartas): " + ("DESLIGADA (nenhum ajuste vale)" if Assembleia.off() else "ligada"), func():
		Config.data["assembleia_off"] = !Assembleia.off()
		Config.save()
		Assembleia.sync()
		_show_list()))
	var paused = bool(Config.data.get("safra_pausa", false))
	v.add_child(_button("Safra nova a cada período: " + ("PAUSADA (não cria carta nova)" if paused else "ligada"), func():
		Config.data["safra_pausa"] = !bool(Config.data.get("safra_pausa", false))
		Config.save()
		_show_list()))
	var when = CustomContent.backup_when()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(_button("💾 Guardar cópia", func():
		var n = CustomContent.backup_save()
		_show_list()
		_say("✔ Cópia guardada (%d arquivo(s)) do que você criou e editou." % n)))
	if when != "":
		row.add_child(_button("↩ Voltar a cópia", func():
			_confirm("Pôr de volta a cópia de %s por cima do que tem agora?" % when, func():
				var n = CustomContent.backup_restore()
				_say("✔ Cópia de volta (%d arquivo(s)). Feche e abra o jogo pra ela valer." % n))))
	v.add_child(_note("Cópia guardada: %s" % (when if when != "" else "nenhuma ainda")))


var _theme := "Todos os temas"


## a peça é do tema escolhido? ("Fazenda" = a que não está em nenhum outro tema)
func _piece_in_theme(piece: String) -> bool:
	if _theme == "Todos os temas":
		return true
	if _theme == "Fazenda":
		for t in PecasIndex.TEMAS:
			if PecasIndex.TEMAS[t].has(piece):
				return false
		return true
	return PecasIndex.TEMAS.get(_theme, []).has(piece)


## troca por outra, ao acaso, cada peça que JÁ está em uso (os lugares vazios ficam vazios)
func _shuffle_pieces():
	if _recipe.is_empty():
		_recipe = MODE_DEFAULTS[_recipe_mode()].duplicate()
	for slot in PIECE_SLOTS[_recipe_mode()]:
		if str(_recipe.get(slot, "")) == "":
			continue
		var options: Array = SpriteForge.pieces(slot).filter(func(p): return _piece_in_theme(str(p)))
		if options.is_empty():
			options = SpriteForge.pieces(slot)
		if options.size() > 1:
			options.erase(_recipe[slot])
		_recipe[slot] = str(options[randi() % options.size()])
	_regen_art()
	_build_ed_body_keep_scroll()


func _shuffle_colors():
	for key in PALETTE_KEYS:
		_palette[key] = str(SWATCHES[randi() % SWATCHES.size()])
	_regen_art()
	_build_ed_body_keep_scroll()


func _build_ed_body_keep_scroll():
	var y = _scroll.scroll_vertical
	_build_ed_body()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = y
