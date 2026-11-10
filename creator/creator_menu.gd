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
		var b = _button(["🃏 Cartas", "🏰 Bases", "🏟 Arenas"][i], func(): _set_tab(t))
		b.toggle_mode = true
		tabs.add_child(b)
		_tab_buttons.append(b)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

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
	for card in cards:
		if card == null:
			continue
		var custom = CustomContent.is_custom(card)
		if _show_custom_only and !custom:
			continue
		var tag = "⭐ criada por você" if custom else ("✏️ editada" if CustomContent.has_override(card) else "do jogo")
		if CustomContent.is_spawn_only(card):
			tag = "🐣 só invocação"
		var kind_text = "Feitiço" if card.is_spell() else CardData.role_name(card.role)
		var c = card
		_body.add_child(_list_row(card.icon, card.card_name, "%s · custo %d · %s" % [kind_text, card.cost, tag],
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
	_clear_body()

	_body.add_child(_label("Editando: " + card.card_name, 22))
	_build_art_block(CustomContent.CARD_ART_SIZE, "Arte da carta", Vector2(160, 160))

	_field_box = VBoxContainer.new()
	_field_box.add_theme_constant_override("separation", 6)
	_body.add_child(_field_box)

	_section("Carta")
	for f in CustomContent.CARD_FIELDS:
		_field(_work["card"], f)
	if _work["stats"] != null and (pack.get("is_new", false) or CustomContent.is_custom(card)):
		var so = CheckButton.new()
		so.text = "🐣 Só invocação (não vai pro baralho nem pra coleção; serve de filhote pra outra carta)"
		so.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		so.custom_minimum_size = Vector2(0, 64)
		so.button_pressed = CustomContent.is_spawn_only(card)
		so.toggled.connect(func(on): _work["card"].set_meta("spawn_only", on))
		_field_box.add_child(so)
	if _work["spell"] != null:
		_section("Feitiço")
		for f in CustomContent.SPELL_FIELDS:
			_field(_work["spell"], f)
	elif _work["stats"] != null:
		_section("Unidade")
		for f in CustomContent.UNIT_FIELDS:
			_field(_work["stats"], f)
		_section("Projétil (só vale com \"Ataque à distância\" ligado)")
		_build_proj_block()
		_section("Habilidades e efeitos (todas)")
		_field_box.add_child(_label("Liga a habilidade e ajusta os números logo abaixo dela.", 14))
		for f in CustomContent.unit_extra_fields():
			_field(_work["stats"], f)

	_body.add_child(_power_hint())
	_form_buttons(_save_card, CustomContent.is_custom(card), CustomContent.has_override(card),
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
	CustomContent.apply_snapshot(card, CustomContent.snapshot(_work["card"], CustomContent.CARD_FIELDS), CustomContent.CARD_FIELDS)
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
	_close_form()
	_say("\"%s\" voltou ao original." % card.card_name)


func _remove_from_player_deck(path: String):
	if PlayerProfile.deck_card_paths.has(path):
		PlayerProfile.deck_card_paths = []  # volta pro deck padrão (evita deck com buraco)
		PlayerProfile.save_profile()
		DeckManager._load_deck_for_active_profile()


# ============================================================ BASES

func _build_base_list():
	_body.add_child(_button("+ Nova base", func(): _open_base_form(CustomContent.make_blank_base())))
	_body.add_child(_label("Dica: a arte da base é 32x64 (em pé).", 14))
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
	_clear_body()
	_body.add_child(_label("Editando: " + b.base_name, 22))
	_build_art_block(CustomContent.BASE_ART_SIZE, "Arte da torre", Vector2(160, 160))
	_field_box = VBoxContainer.new()
	_body.add_child(_field_box)
	_section("Base")
	for f in CustomContent.BASE_FIELDS:
		_field(_work["base"], f)
	_section("Projétil do canhão")
	_build_proj_block()
	_body.add_child(_label("Canhão usa dano/alcance/tempo. Produção usa \"produção extra\". Cura usa cura/raio/intervalo. Espaço usa \"espaço extra\". Aura usa raio + efeito.", 14))
	_form_buttons(_save_base, CustomContent.is_custom(b), CustomContent.has_override(b),
		_delete_base.bind(b), _restore_base.bind(b))


func _delete_base(b: BaseData):
	_confirm("Apagar essa base?", _do_delete_base.bind(b))


func _do_delete_base(b: BaseData):
	if PlayerProfile.equipped_base_path == b.resource_path:
		PlayerProfile.equipped_base_path = ""
		PlayerProfile.save_profile()
	CustomContent.delete_custom_base(b)
	_close_form()
	_say("Base apagada.")


func _restore_base(b: BaseData):
	CustomContent.restore_original_base(b)
	_close_form()
	_say("Base voltou ao original.")


func _save_base():
	var b: BaseData = _orig["base"]
	CustomContent.apply_snapshot(b, CustomContent.snapshot(_work["base"], CustomContent.BASE_FIELDS), CustomContent.BASE_FIELDS)
	_orig["image"] = _work["image"]
	_orig["proj_image"] = _work["proj_image"]
	_orig["proj_changed"] = _proj_changed
	CustomContent.save_base(_orig, _image_changed)
	_close_form()
	_say("✔ Base \"%s\" salva! Aparece na Coleção > Bases." % b.base_name)


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
			le.text_changed.connect(func(t): obj.set(prop, t))
			row.add_child(le)
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
			row.add_child(_option(opts, int(value), func(i): obj.set(prop, i)))
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
	# atualiza o aviso de força (último Label laranja antes dos botões)
	for c in _body.get_children():
		if c is Label and c.text.begins_with("⚖️"):
			var fresh = _power_hint()
			c.text = fresh.text
			fresh.free()
			return


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
	sb.step = step
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
