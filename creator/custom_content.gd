extends Node

# CONTEÚDO PERSONALIZADO (autoload "CustomContent")
# Tudo que você cria/edita DENTRO do jogo (no celular) vem parar aqui:
#   - cartas novas  -> user://custom/cards/<id>.tres (+ arte, stats, cena)
#   - bases novas   -> user://custom/bases/<id>.tres (+ arte)
#   - edição de carta/base QUE JÁ EXISTIA no jogo -> user://custom/overrides.json
#     (o res:// do jogo exportado é somente-leitura, então a edição é
#     reaplicada por cima toda vez que o jogo abre)
#   - arenas (nome, emoji, troféu, recompensa, fundo) -> user://custom/arenas.json
# Cartas/bases novas entram no CardDatabase / BotSimulator.available_bases,
# então aparecem na coleção, no deck e nos decks dos BOTS também.

signal content_changed

const ROOT = "user://custom/"
const CARDS_DIR = "user://custom/cards/"
const UNITS_DIR = "user://custom/units/"
const BASES_DIR = "user://custom/bases/"
const ART_DIR = "user://custom/art/"
const OVERRIDES_PATH = "user://custom/overrides.json"
const ARENAS_PATH = "user://custom/arenas.json"
const UNIT_TEMPLATE = "res://Units/scenes/unit_base.tscn"

const CARD_ART_SIZE = Vector2i(32, 32)
const BASE_ART_SIZE = Vector2i(32, 64)
const ARENA_ART_SIZE = Vector2i(36, 64)  # 9:16, igual a tela

# ---------------------------------------------------------------- campos
# lista ÚNICA de campos editáveis -- usada pelo formulário do criador E pra
# salvar/reaplicar edição de carta original. Formato:
#   [propriedade, rótulo, tipo, opções]
# tipos: "int" [min,max,passo], "float" [min,max,passo], "bool", "text",
#        "multiline", "enum" [lista de nomes]
const ROLE_NAMES = ["Enxame", "Tanque", "Punição", "Controle", "Contra-ataque", "Suporte", "Finalizador", "Construção", "Aéreo", "Versátil", "Invocador", "Cerco"]
const EFFECT_NAMES = ["Nenhum", "Lentidão", "Fraqueza", "Congelar", "Veneno", "Atordoar", "Empurrão", "Choque", "Confusão", "Puxão", "Enraizar", "Silêncio", "Marcar"]

const CARD_FIELDS = [
	["card_name", "Nome", "text", []],
	["cost", "Custo", "int", [1, 10, 1]],
	["role", "Categoria", "enum", ROLE_NAMES],
	["danger_level", "Perigo (pra IA)", "int", [1, 10, 1]],
	["description", "Descrição", "multiline", []],
]

const UNIT_FIELDS = [
	["hp", "Vida", "int", [1, 20000, 10]],
	["damage", "Dano", "int", [0, 5000, 5]],
	["attack_speed", "Tempo entre ataques (s)", "float", [0.1, 10.0, 0.1]],
	["attack_range", "Alcance", "float", [5.0, 600.0, 5.0]],
	["move_speed", "Velocidade", "float", [0.0, 200.0, 5.0]],
	["unit_count", "Quantidade", "int", [1, 20, 1]],
	["push_weight", "Peso (empurrão)", "float", [0.1, 10.0, 0.1]],
	["unit_scale", "Tamanho", "float", [0.5, 3.0, 0.1]],
	["unit_type", "Tipo", "enum", ["Terrestre", "Aérea", "Construção"]],
	["target_type", "Ataca", "enum", ["Terrestre", "Aéreo", "Tudo", "Só construção/base"]],
	["is_ranged", "Ataque à distância", "bool", []],
	["projectile_speed", "Velocidade do projétil", "float", [50.0, 1500.0, 25.0]],
	["is_aoe", "Dano em área", "bool", []],
	["aoe_radius", "Raio da área", "float", [10.0, 300.0, 5.0]],
	["detection_range", "Visão", "float", [20.0, 600.0, 10.0]],
	["duration", "Dura X segundos (0 = pra sempre)", "float", [0.0, 120.0, 1.0]],
	["spawn_formation", "Formação", "enum", ["Grupo", "Linha", "Coluna", "Círculo"]],
	["on_hit_effect", "Efeito ao acertar", "enum", EFFECT_NAMES],
	["on_hit_effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
	["on_hit_effect_duration", "Duração do efeito (s)", "float", [0.0, 20.0, 0.25]],
	["can_heal_allies", "Cura aliados perto", "bool", []],
	["heal_aura_amount", "Cura por pulso", "int", [0, 500, 1]],
	["heal_aura_radius", "Raio da cura", "float", [10.0, 300.0, 5.0]],
	["forces_aggro", "Provoca (puxa inimigos)", "bool", []],
	["explodes_on_death", "Explode ao morrer", "bool", []],
	["death_explosion_damage", "Dano da explosão", "int", [0, 3000, 10]],
	["death_explosion_radius", "Raio da explosão", "float", [10.0, 300.0, 5.0]],
	["kamikaze", "Kamikaze (morre ao atacar)", "bool", []],
	["crosses_water", "Atravessa água", "bool", []],
	["can_spawn_anywhere", "Pode nascer em qualquer lugar", "bool", []],
	["damage_reduction_percent", "Redução de dano (0-0.9)", "float", [0.0, 0.9, 0.05]],
	["lifesteal_percent", "Roubo de vida (0-1)", "float", [0.0, 1.0, 0.05]],
]

const SPELL_FIELDS = [
	["radius", "Raio", "float", [10.0, 400.0, 5.0]],
	["damage", "Dano", "int", [0, 5000, 5]],
	["duration", "Duração (0 = instantâneo)", "float", [0.0, 20.0, 0.5]],
	["tick_interval", "Intervalo entre pulsos (s)", "float", [0.1, 5.0, 0.1]],
	["heal_amount", "Cura", "int", [0, 2000, 5]],
	["status_effect", "Efeito", "enum", EFFECT_NAMES],
	["status_effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
	["affects_enemies", "Afeta inimigos", "bool", []],
	["affects_allies", "Afeta aliados", "bool", []],
	["base_damage_multiplier", "Dano na base (fração)", "float", [0.0, 2.0, 0.02]],
]

const BASE_FIELDS = [
	["base_name", "Nome", "text", []],
	["description", "Descrição", "multiline", []],
	["base_hp", "Vida", "int", [100, 20000, 50]],
	["base_type", "Função", "enum", ["Canhão", "Produção", "Cura", "Vida extra", "Espaço", "Aura"]],
	["category", "Categoria", "enum", ["Ofensivo", "Defensivo", "Econômico"]],
	["attack_damage", "Dano do canhão", "int", [0, 2000, 5]],
	["attack_range", "Alcance do canhão", "float", [20.0, 600.0, 10.0]],
	["attack_speed", "Tempo entre tiros (s)", "float", [0.1, 10.0, 0.1]],
	["is_aoe", "Tiro em área", "bool", []],
	["aoe_radius", "Raio do tiro", "float", [10.0, 300.0, 5.0]],
	["production_speed_boost", "Produção extra (0.12 = 12%)", "float", [0.0, 1.0, 0.01]],
	["heal_amount", "Cura por pulso", "int", [0, 500, 1]],
	["heal_radius", "Raio da cura", "float", [10.0, 400.0, 10.0]],
	["heal_interval", "Intervalo da cura (s)", "float", [0.2, 10.0, 0.1]],
	["capacity_bonus", "Espaço extra de recurso", "int", [0, 200, 5]],
	["aura_radius", "Raio da aura", "float", [10.0, 400.0, 10.0]],
	["effect", "Efeito da aura", "enum", EFFECT_NAMES],
	["effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
]

var custom_cards: Array[CardData] = []
var custom_bases: Array[BaseData] = []
var _overrides: Dictionary = {"cards": {}, "bases": {}}
var _originals: Dictionary = {}  # caminho -> snapshot original (pra "restaurar original")
var _sprite_overrides: Dictionary = {}  # caminho da carta -> Texture2D (sprite da unidade em campo)
var _arena_data: Array = []
var _loaded := false
var default_projectile: ImageTexture


func _ready():
	for d in [ROOT, CARDS_DIR, UNITS_DIR, BASES_DIR, ART_DIR]:
		DirAccess.make_dir_recursive_absolute(d)
	default_projectile = _make_default_projectile()
	load_all()


func load_all():
	if _loaded:
		return
	_loaded = true
	_load_custom_cards()
	_load_custom_bases()
	_load_overrides()
	_load_arenas()


# ================================================================ helpers

static func new_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]


static func image_to_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func texture_to_image(tex: Texture2D, size: Vector2i) -> Image:
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	if img == null:
		img = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		return img
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != size:
		# arte maior/menor -- encaixa no tamanho do editor sem borrar
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	return img


func _make_default_projectile() -> ImageTexture:
	var img = Image.create_empty(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 6:
		for y in 6:
			if Vector2(x - 2.5, y - 2.5).length() <= 2.6:
				img.set_pixel(x, y, Color(1, 0.95, 0.6))
	return ImageTexture.create_from_image(img)


func _save_texture(tex: ImageTexture, path: String) -> ImageTexture:
	ResourceSaver.save(tex, path)
	tex.take_over_path(path)
	return tex


func _list_files(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if !dir.current_is_dir() and f.ends_with(ext):
			out.append(dir_path + f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func get_prop(obj: Object, prop: String):
	return obj.get(prop)


static func set_prop(obj: Object, prop: String, value):
	var current = obj.get(prop)
	if current is int and value is float:
		value = int(round(value))
	elif current is float and value is int:
		value = float(value)
	obj.set(prop, value)


static func snapshot(obj: Object, fields: Array) -> Dictionary:
	var d = {}
	for f in fields:
		d[f[0]] = obj.get(f[0])
	return d


static func apply_snapshot(obj: Object, data: Dictionary, fields: Array):
	for f in fields:
		if data.has(f[0]):
			set_prop(obj, f[0], data[f[0]])


func is_custom(res: Resource) -> bool:
	return res != null and res.resource_path.begins_with(ROOT)


func has_override(res: Resource) -> bool:
	if res == null:
		return false
	return _overrides["cards"].has(res.resource_path) or _overrides["bases"].has(res.resource_path)


func get_sprite_override(card_path: String) -> Texture2D:
	return _sprite_overrides.get(card_path, null)


# ================================================================ cartas

func _load_custom_cards():
	for path in _list_files(CARDS_DIR, ".tres"):
		var card = load(path)
		if card is CardData:
			_register_card(card)


func _register_card(card: CardData):
	if !custom_cards.has(card):
		custom_cards.append(card)
	if !CardDatabase.all_cards.has(card):
		CardDatabase.all_cards.append(card)


# cria uma carta NOVA vazia (unidade ou feitiço) com valores razoáveis --
# o criador preenche e chama save_card()
func make_blank_card(is_spell: bool) -> Dictionary:
	var card = CardData.new()
	card.card_name = "Nova carta"
	card.cost = 3
	card.role = CardData.CardRole.VERSATIL
	card.danger_level = 3
	card.description = ""
	card.tier = 1
	card.nation_xp_cost = 0
	var stats: UnitData = null
	var spell: SpellData = null
	if is_spell:
		spell = SpellData.new()
		spell.damage = 200
		spell.radius = 70.0
	else:
		stats = UnitData.new()
		stats.hp = 400
		stats.damage = 60
		stats.attack_speed = 1.2
		stats.attack_range = 25.0
		stats.move_speed = 45.0
	var img = Image.create_empty(CARD_ART_SIZE.x, CARD_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return {"card": card, "stats": stats, "spell": spell, "image": img, "is_new": true}


# monta o "pacote de edição" de uma carta existente (original ou criada)
func open_card_for_edit(card: CardData) -> Dictionary:
	var stats: UnitData = DeckBuilder.get_unit_stats(card)
	var img = texture_to_image(card.icon, CARD_ART_SIZE)
	return {"card": card, "stats": stats, "spell": card.spell_data, "image": img, "is_new": false}


# salva um pacote de edição. Pra carta criada: grava os arquivos. Pra carta
# ORIGINAL do jogo: aplica na memória e guarda como override
func save_card(pack: Dictionary, image_changed: bool) -> CardData:
	var card: CardData = pack["card"]
	if pack.get("is_new", false) or is_custom(card):
		return _save_custom_card(pack, image_changed)
	_save_card_override(pack, image_changed)
	DeckBuilder.clear_cache()
	content_changed.emit()
	return card


func _save_custom_card(pack: Dictionary, image_changed: bool) -> CardData:
	var card: CardData = pack["card"]
	var id: String
	if card.resource_path.begins_with(CARDS_DIR):
		id = card.resource_path.get_file().get_basename()
	else:
		id = new_id("carta")

	# arte -- ImageTexture salva em .res (load() funciona no celular, PNG cru não)
	var art_path = ART_DIR + id + ".res"
	var tex: ImageTexture = card.icon if card.icon is ImageTexture and card.icon.resource_path == art_path else null
	if tex == null:
		tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
	elif image_changed:
		tex.set_image(pack["image"])
		ResourceSaver.save(tex, art_path)
	card.icon = tex

	if pack["spell"] != null:
		var spell: SpellData = pack["spell"]
		var spell_path = UNITS_DIR + id + "_spell.tres"
		ResourceSaver.save(spell, spell_path)
		spell.take_over_path(spell_path)
		card.spell_data = spell
		card.unit_scene = null
	else:
		var stats: UnitData = pack["stats"]
		stats.role = card.role
		if stats.is_ranged and stats.projectile_texture == null:
			stats.projectile_texture = default_projectile
		var stats_path = UNITS_DIR + id + "_stats.tres"
		ResourceSaver.save(stats, stats_path)
		stats.take_over_path(stats_path)
		var scene_path = UNITS_DIR + id + ".tscn"
		if card.unit_scene == null or card.unit_scene.resource_path != scene_path:
			card.unit_scene = _build_unit_scene(stats, tex, scene_path)
		card.spell_data = null

	var card_path = CARDS_DIR + id + ".tres"
	var err = ResourceSaver.save(card, card_path)
	if err != OK:
		push_error("CustomContent: não consegui salvar a carta (%d)" % err)
	card.take_over_path(card_path)
	_register_card(card)
	DeckBuilder.clear_cache()
	content_changed.emit()
	return card


# duplica o molde de unidade do jogo (mantém colisão, barra de vida, área
# de detecção, navegação...) e só troca stats + sprite
func _build_unit_scene(stats: UnitData, tex: Texture2D, scene_path: String) -> PackedScene:
	var template: PackedScene = load(UNIT_TEMPLATE)
	var node = template.instantiate()
	node.stats = stats
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var packed = PackedScene.new()
	packed.pack(node)
	node.free()
	ResourceSaver.save(packed, scene_path)
	packed.take_over_path(scene_path)
	return packed


func delete_custom_card(card: CardData):
	if !is_custom(card):
		return
	var id = card.resource_path.get_file().get_basename()
	for p in [CARDS_DIR + id + ".tres", UNITS_DIR + id + ".tscn", UNITS_DIR + id + "_stats.tres", UNITS_DIR + id + "_spell.tres", ART_DIR + id + ".res"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	custom_cards.erase(card)
	CardDatabase.all_cards.erase(card)
	content_changed.emit()


func _save_card_override(pack: Dictionary, image_changed: bool):
	var card: CardData = pack["card"]
	var path = card.resource_path
	var entry: Dictionary = _overrides["cards"].get(path, {})
	entry["card"] = snapshot(card, CARD_FIELDS)
	if pack["stats"] != null:
		entry["unit"] = snapshot(pack["stats"], UNIT_FIELDS)
	if pack["spell"] != null:
		entry["spell"] = snapshot(pack["spell"], SPELL_FIELDS)
	if image_changed:
		var art_path = ART_DIR + "ov_" + str(abs(hash(path))) + ".res"
		var tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
		entry["art"] = art_path
		card.icon = tex
		_sprite_overrides[path] = tex
	_overrides["cards"][path] = entry
	_write_overrides()


func restore_original_card(card: CardData):
	var path = card.resource_path
	if _originals.has(path):
		var o = _originals[path]
		apply_snapshot(card, o["card"], CARD_FIELDS)
		var stats = DeckBuilder.get_unit_stats(card)
		if stats != null and o.has("unit"):
			apply_snapshot(stats, o["unit"], UNIT_FIELDS)
		if card.spell_data != null and o.has("spell"):
			apply_snapshot(card.spell_data, o["spell"], SPELL_FIELDS)
		if o.has("icon"):
			card.icon = o["icon"]
	_sprite_overrides.erase(path)
	_overrides["cards"].erase(path)
	_write_overrides()
	content_changed.emit()


# guarda os valores originais ANTES de aplicar edição (só na 1ª vez), pra
# conseguir "restaurar original" sem reiniciar o jogo
func remember_original_card(card: CardData):
	var path = card.resource_path
	if _originals.has(path) or is_custom(card):
		return
	var o = {"card": snapshot(card, CARD_FIELDS), "icon": card.icon}
	var stats = DeckBuilder.get_unit_stats(card)
	if stats != null:
		o["unit"] = snapshot(stats, UNIT_FIELDS)
	if card.spell_data != null:
		o["spell"] = snapshot(card.spell_data, SPELL_FIELDS)
	_originals[path] = o


func remember_original_base(base: BaseData):
	var path = base.resource_path
	if _originals.has(path) or is_custom(base):
		return
	_originals[path] = {"base": snapshot(base, BASE_FIELDS), "icon": base.icon, "texture": base.base_texture}


# ================================================================ bases

func _load_custom_bases():
	for path in _list_files(BASES_DIR, ".tres"):
		var b = load(path)
		if b is BaseData:
			_register_base(b)


func _register_base(b: BaseData):
	if !custom_bases.has(b):
		custom_bases.append(b)
	if !BotSimulator.available_bases.has(b):
		BotSimulator.available_bases.append(b)


func make_blank_base() -> Dictionary:
	var b = BaseData.new()
	b.base_name = "Nova base"
	b.base_hp = 1000
	b.base_type = BaseData.BaseType.CANNON
	b.nation_xp_cost = 0
	var img = Image.create_empty(BASE_ART_SIZE.x, BASE_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return {"base": b, "image": img, "is_new": true}


func open_base_for_edit(b: BaseData) -> Dictionary:
	var tex = b.base_texture if b.base_texture != null else b.icon
	return {"base": b, "image": texture_to_image(tex, BASE_ART_SIZE), "is_new": false}


func save_base(pack: Dictionary, image_changed: bool) -> BaseData:
	var b: BaseData = pack["base"]
	if !(pack.get("is_new", false) or is_custom(b)):
		var path = b.resource_path
		var entry: Dictionary = _overrides["bases"].get(path, {})
		entry["base"] = snapshot(b, BASE_FIELDS)
		if image_changed:
			var art_path = ART_DIR + "ovb_" + str(abs(hash(path))) + ".res"
			var tex = image_to_texture(pack["image"])
			_save_texture(tex, art_path)
			entry["art"] = art_path
			b.base_texture = tex
			b.icon = tex
		_overrides["bases"][path] = entry
		_write_overrides()
		content_changed.emit()
		return b

	var id: String = b.resource_path.get_file().get_basename() if b.resource_path.begins_with(BASES_DIR) else new_id("base")
	var art_path = ART_DIR + id + ".res"
	var tex: ImageTexture = b.base_texture if b.base_texture is ImageTexture and b.base_texture.resource_path == art_path else null
	if tex == null:
		tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
	elif image_changed:
		tex.set_image(pack["image"])
		ResourceSaver.save(tex, art_path)
	b.base_texture = tex
	b.icon = tex
	if b.projectile_texture == null:
		b.projectile_texture = default_projectile
	var base_path = BASES_DIR + id + ".tres"
	ResourceSaver.save(b, base_path)
	b.take_over_path(base_path)
	_register_base(b)
	content_changed.emit()
	return b


func restore_original_base(b: BaseData):
	var path = b.resource_path
	if _originals.has(path):
		apply_snapshot(b, _originals[path]["base"], BASE_FIELDS)
		b.icon = _originals[path]["icon"]
		b.base_texture = _originals[path]["texture"]
	_overrides["bases"].erase(path)
	_write_overrides()
	content_changed.emit()


func delete_custom_base(b: BaseData):
	if !is_custom(b):
		return
	var id = b.resource_path.get_file().get_basename()
	for p in [BASES_DIR + id + ".tres", ART_DIR + id + ".res"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	custom_bases.erase(b)
	BotSimulator.available_bases.erase(b)
	content_changed.emit()


# todas as bases que o jogo conhece (originais da coleção + criadas)
func all_bases(original_list: Array) -> Array:
	var out: Array = []
	for b in original_list:
		if b != null and !out.has(b):
			out.append(b)
	for b in BotSimulator.available_bases:
		if b != null and !out.has(b):
			out.append(b)
	for b in custom_bases:
		if !out.has(b):
			out.append(b)
	return out


# ================================================================ overrides

func _load_overrides():
	if !FileAccess.file_exists(OVERRIDES_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
	if !(data is Dictionary):
		return
	_overrides["cards"] = data.get("cards", {})
	_overrides["bases"] = data.get("bases", {})

	for path in _overrides["cards"]:
		if !ResourceLoader.exists(path):
			continue
		var card = load(path)
		if !(card is CardData):
			continue
		remember_original_card(card)
		var entry = _overrides["cards"][path]
		apply_snapshot(card, entry.get("card", {}), CARD_FIELDS)
		var stats = DeckBuilder.get_unit_stats(card)
		if stats != null and entry.has("unit"):
			apply_snapshot(stats, entry["unit"], UNIT_FIELDS)
			if stats.is_ranged and stats.projectile_texture == null:
				stats.projectile_texture = default_projectile
		if card.spell_data != null and entry.has("spell"):
			apply_snapshot(card.spell_data, entry["spell"], SPELL_FIELDS)
		var art = entry.get("art", "")
		if art != "" and ResourceLoader.exists(art):
			var tex = load(art)
			card.icon = tex
			_sprite_overrides[path] = tex

	for path in _overrides["bases"]:
		if !ResourceLoader.exists(path):
			continue
		var b = load(path)
		if !(b is BaseData):
			continue
		remember_original_base(b)
		var entry = _overrides["bases"][path]
		apply_snapshot(b, entry.get("base", {}), BASE_FIELDS)
		var art = entry.get("art", "")
		if art != "" and ResourceLoader.exists(art):
			var tex = load(art)
			b.base_texture = tex
			b.icon = tex


func _write_overrides():
	var f = FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_overrides, "\t"))


# ================================================================ arenas

func _load_arenas():
	_arena_data = []
	if FileAccess.file_exists(ARENAS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(ARENAS_PATH))
		if data is Array:
			_arena_data = data
	_apply_arenas()


func _apply_arenas():
	var list: Array = ArenaManager.DEFAULT_ARENAS.duplicate(true)
	for entry in _arena_data:
		var idx = int(entry.get("index", 0))
		if idx <= 0:
			continue
		while list.size() <= idx:
			list.append({"name": "Arena %d" % list.size(), "emoji": "⭐", "trophy_threshold": 0})
		var a: Dictionary = list[idx].duplicate(true)
		for k in ["name", "emoji", "trophy_threshold", "rewards"]:
			if entry.has(k):
				a[k] = entry[k]
		a["trophy_threshold"] = int(a["trophy_threshold"])
		var bg = entry.get("background", "")
		if bg != "" and ResourceLoader.exists(bg):
			a["background_texture"] = load(bg)
			a["background"] = bg
		list[idx] = a
	ArenaManager.arenas = list
	ArenaManager.max_arena = list.size() - 1


func get_arena_entry(index: int) -> Dictionary:
	var a: Dictionary = ArenaManager.get_arena_info(index).duplicate(true) if index <= ArenaManager.max_arena else {}
	if !a.has("rewards"):
		a["rewards"] = ArenaManager.default_rewards_for(index)
	a["index"] = index
	return a


func save_arena(index: int, data: Dictionary, image: Image):
	var entry: Dictionary = {}
	for e in _arena_data:
		if int(e.get("index", 0)) == index:
			entry = e
			break
	if entry.is_empty():
		entry = {"index": index}
		_arena_data.append(entry)
	for k in ["name", "emoji", "trophy_threshold", "rewards"]:
		if data.has(k):
			entry[k] = data[k]
	if image != null:
		var art_path = ART_DIR + "arena_%d.res" % index
		var tex: ImageTexture = null
		if ResourceLoader.exists(art_path):
			tex = load(art_path)
			tex.set_image(image)
			ResourceSaver.save(tex, art_path)
		else:
			tex = image_to_texture(image)
			_save_texture(tex, art_path)
		entry["background"] = art_path
	_write_arenas()
	_apply_arenas()
	content_changed.emit()


func reset_arena(index: int):
	for e in _arena_data.duplicate():
		if int(e.get("index", 0)) == index:
			_arena_data.erase(e)
	_write_arenas()
	_apply_arenas()
	content_changed.emit()


func add_arena() -> int:
	var idx = ArenaManager.max_arena + 1
	var prev = ArenaManager.get_arena_info(ArenaManager.max_arena)
	save_arena(idx, {
		"name": "Arena %d" % idx, "emoji": "⭐",
		"trophy_threshold": int(prev.get("trophy_threshold", 0)) + 1000,
		"rewards": ArenaManager.default_rewards_for(idx),
	}, null)
	return idx


# só dá pra apagar a ÚLTIMA arena criada por você (as 7 originais ficam)
func remove_last_arena() -> bool:
	var idx = ArenaManager.max_arena
	if idx <= ArenaManager.DEFAULT_MAX_ARENA:
		return false
	reset_arena(idx)
	return true


func _write_arenas():
	var f = FileAccess.open(ARENAS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_arena_data, "\t"))
