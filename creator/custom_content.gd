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
const PROJ_ART_SIZE = Vector2i(16, 16)  # projétil -- desenhe apontando pra DIREITA (ele gira na direção do tiro)

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
	["cost", "Custo (0 a 100, igual a barra de recurso)", "int", [5, 100, 5]],
	["role", "Categoria", "enum", ROLE_NAMES],
	["nation_data", "Nação", "nation", []],
	["danger_level", "Perigo (pra IA)", "int", [1, 10, 1]],
	["description", "Descrição", "multiline", []],
]

const UNIT_FIELDS = [
	["hp", "Vida", "int", [1, 20000, 10]],
	["damage", "Dano", "int", [0, 5000, 5]],
	["attack_speed", "Tempo entre ataques (s)", "float", [0.1, 10.0, 0.1]],
	["attack_range", "Alcance (corpo a corpo: folga até encostar, padrão 15)", "float", [0.0, 600.0, 5.0]],
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

# TODOS os outros campos do UnitData (habilidades/efeitos) -- a lista é
# montada sozinha a partir do próprio recurso (unit_extra_fields), esses são
# só os nomes em português. Campo novo que você criar no UnitData aparece
# sozinho no Criador, com o nome técnico mesmo.
const UNIT_EXTRA_LABELS = {
	"spawns_disguised": "Nasce disfarçada (revela no 1º ataque)",
	"charge_attack": "Golpe carregado (anda e bate forte)",
	"charge_distance_needed": "Distância pra carregar",
	"charge_damage_multiplier": "Multiplicador do golpe carregado",
	"charge_knockback_distance": "Empurrão do golpe carregado",
	"bandit_dash": "Avanço instantâneo (1x)",
	"dash_speed_multiplier": "Velocidade do avanço",
	"dash_duration": "Duração do avanço",
	"projectile_pierces": "Projétil atravessa",
	"projectile_max_targets": "Máx. alvos atravessados",
	"projectile_splits": "Projétil se divide",
	"projectile_split_count": "Pedaços da divisão",
	"projectile_split_range": "Alcance da divisão",
	"projectile_chains": "Projétil em cadeia (pula)",
	"projectile_chain_max_targets": "Máx. pulos da cadeia",
	"projectile_chain_range": "Alcance do pulo",
	"initial_stun_duration": "Atordoado ao nascer (s)",
	"on_hit_effect_tick_interval": "Intervalo do efeito (veneno)",
	"knockback_distance": "Distância do empurrão/puxão",
	"mastery_effect": "Efeito de maestria (nível 7+)",
	"mastery_effect_duration": "Duração da maestria",
	"mastery_effect_strength": "Força da maestria",
	"mastery_effect_tick_interval": "Intervalo da maestria",
	"heal_aura_interval": "Intervalo da cura",
	"spawns_units": "Invoca unidades",
	"spawn_unit_scene": "Unidade invocada",
	"spawn_interval": "Invoca a cada (s)",
	"spawn_count": "Quantas invoca",
	"spawns_on_death": "Invoca ao morrer",
	"death_spawn_scene": "Unidade que surge ao morrer",
	"death_spawn_count": "Quantas surgem ao morrer",
	"generates_resource": "Gera recurso",
	"resource_per_tick": "Recurso por pulso",
	"resource_tick_interval": "Intervalo do recurso",
	"stores_resource": "Aumenta limite de recurso",
	"storage_capacity_bonus": "Limite extra",
	"steals_resource_on_base_hit": "Rouba recurso ao bater na base",
	"resource_steal_amount": "Quanto rouba",
	"summons_on_attack": "Invoca ao atacar",
	"attack_summon_scene": "Unidade invocada no ataque",
	"attack_summon_chance": "Chance de invocar (0-1)",
	"first_attack_bonus": "Primeiro ataque mais forte",
	"first_attack_multiplier": "Multiplicador do 1º ataque",
	"ramping_damage": "Dano cresce a cada golpe",
	"ramping_damage_per_hit": "Aumento por golpe",
	"ramping_damage_max_multiplier": "Máximo do aumento",
	"same_target_ramping_damage": "Dano cresce no mesmo alvo",
	"same_target_ramping_damage_per_hit": "Aumento por golpe (mesmo alvo)",
	"same_target_ramping_damage_max_multiplier": "Máximo (mesmo alvo)",
	"distance_damage_bonus_per_100px": "Dano extra por distância (a cada 100px)",
	"ramping_attack_speed": "Ataca cada vez mais rápido",
	"attack_speed_ramp_per_hit": "Aceleração por golpe",
	"attack_speed_ramp_min_multiplier": "Limite da aceleração",
	"pre_attack_speed_boost": "Acelera ao achar alvo",
	"pre_attack_boost_multiplier": "Multiplicador da aceleração",
	"pre_attack_boost_duration": "Duração da aceleração",
	"entrance_rage_duration": "Fúria ao entrar (s)",
	"entrance_rage_damage_mult": "Dano na fúria de entrada",
	"entrance_rage_speed_mult": "Velocidade na fúria de entrada",
	"entrance_shockwave_damage": "Onda de choque ao entrar (dano)",
	"entrance_shockwave_radius": "Raio da onda de choque",
	"execute_threshold": "Executa alvo com vida abaixo de (0-1)",
	"execute_damage_mult": "Dano da execução",
	"low_hp_rage_threshold": "Fúria com vida abaixo de (0-1)",
	"low_hp_rage_damage_mult": "Dano na fúria de vida baixa",
	"continuous_attack": "Ataque contínuo (raio/lança-chamas)",
	"continuous_damage_per_second": "Dano por segundo contínuo",
	"spin_attack": "Ataque giratório (360°)",
	"frontal_cone_attack": "Ataque em cone",
	"cone_angle_degrees": "Ângulo do cone",
	"aoe_hits_extra_one": "Acerta +1 alvo extra",
	"has_shield": "Tem escudo",
	"shield_amount": "Escudo",
	"shield_recharge_time": "Escudo recarrega após (s)",
	"has_temp_shield": "Escudo temporário",
	"temp_shield_amount": "Escudo temporário (valor)",
	"temp_shield_duration": "Duração do escudo temporário",
	"is_linked": "Vida compartilhada com o grupo",
	"link_share_percent": "Fração compartilhada",
	"can_resurrect": "Ressuscita 1x",
	"resurrect_hp_percent": "Vida ao ressuscitar (0-1)",
	"taunt_radius": "Raio da provocação",
	"immune_to_effect": "Imune ao efeito",
	"immune_to_knockback": "Imune a empurrão",
	"immune_to_pull": "Imune a puxão",
	"counter_attack_chance": "Chance de contra-ataque (0-1)",
	"reflects_damage": "Reflete dano",
	"reflect_damage_percent": "Fração refletida",
	"passive_regen": "Regenera vida",
	"regen_amount": "Regeneração",
	"regen_interval": "Intervalo da regeneração",
	"heals_on_kill": "Cura ao matar",
	"heal_on_kill_amount": "Cura ao matar (valor)",
	"converts_kills_to_gold": "Ganha ouro ao matar",
	"gold_per_kill": "Ouro por abate",
	"landing_duration": "Tempo pousando (reforço aéreo)",
	"can_stealth": "Fica invisível",
	"stealth_reveal_range": "Distância que revela",
	"immune_while_moving": "Imune enquanto anda",
	"spawn_invulnerability_duration": "Invulnerável ao nascer (s)",
	"extra_damage_vs_role": "Dano extra contra categoria",
	"extra_damage_vs_role_mult": "Dano extra (0.5 = +50%)",
	"deals_arrival_damage": "Dano ao chegar",
	"arrival_damage": "Dano de chegada",
	"arrival_damage_radius": "Raio do dano de chegada",
	"transforms_into_building": "Vira construção",
	"transform_after_seconds": "Vira depois de (s)",
	"transformed_scene": "Construção em que se transforma",
	"can_clone": "Se clona",
	"clone_hp_percent": "Vida do clone (0-1)",
	"clone_count": "Quantos clones",
	"grants_resource_on_death": "Dá recurso ao morrer",
	"death_resource_amount": "Recurso ao morrer",
	"can_convert_enemy": "Converte inimigo",
	"convert_max_targets": "Máx. conversões",
}

# campos que não fazem sentido no formulário (já estão acima ou são imagem)
const UNIT_SKIP = ["role", "projectile_texture"]

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
	["nation_data", "Nação", "nation", []],
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

var _extra_fields_cache: Array = []


# gera a lista [prop, rótulo, tipo, opções] de TODO campo exportado do
# UnitData que não está em UNIT_FIELDS
func unit_extra_fields() -> Array:
	if !_extra_fields_cache.is_empty():
		return _extra_fields_cache
	var base: Dictionary = {}
	for f in UNIT_FIELDS:
		base[f[0]] = true
	var probe = UnitData.new()
	for p in probe.get_property_list():
		var pname: String = p["name"]
		if base.has(pname) or pname in UNIT_SKIP:
			continue
		if !(p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or !(p["usage"] & PROPERTY_USAGE_EDITOR):
			continue
		var label = UNIT_EXTRA_LABELS.get(pname, pname.replace("_", " ").capitalize())
		match p["type"]:
			TYPE_BOOL:
				_extra_fields_cache.append([pname, label, "bool", []])
			TYPE_INT:
				if p["hint"] == PROPERTY_HINT_ENUM:
					var opts: Array = []
					for item in String(p["hint_string"]).split(","):
						opts.append(item.split(":")[0].strip_edges())
					if pname.ends_with("effect"):
						opts = Array(EFFECT_NAMES)
					_extra_fields_cache.append([pname, label, "enum", opts])
				else:
					_extra_fields_cache.append([pname, label, "int", [0, 100000, 1]])
			TYPE_FLOAT:
				_extra_fields_cache.append([pname, label, "float", [0.0, 100000.0, 0.05]])
			TYPE_OBJECT:
				if p["hint_string"] == "PackedScene":
					_extra_fields_cache.append([pname, label, "scene", []])
	return _extra_fields_cache


# todos os campos de unidade (básicos + habilidades) -- usado pra salvar edição
func all_unit_fields() -> Array:
	return UNIT_FIELDS + unit_extra_fields()


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


func default_projectile_image() -> Image:
	var img = Image.create_empty(PROJ_ART_SIZE.x, PROJ_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in PROJ_ART_SIZE.x:
		for y in PROJ_ART_SIZE.y:
			var d = Vector2(x - 7.5, y - 7.5).length()
			if d <= 3.2:
				img.set_pixel(x, y, Color(1, 0.95, 0.6))
			elif d <= 4.3:
				img.set_pixel(x, y, Color("1a1018"))
	return img


# grava a arte do projétil (se foi desenhada) e devolve a textura a usar
func _store_projectile(pack: Dictionary, art_path: String, current: Texture2D) -> Texture2D:
	if !pack.get("proj_changed", false) or pack.get("proj_image") == null:
		return current
	var tex: ImageTexture = null
	if current is ImageTexture and current.resource_path == art_path:
		tex = current
		tex.set_image(pack["proj_image"])
		ResourceSaver.save(tex, art_path)
	else:
		tex = image_to_texture(pack["proj_image"])
		_save_texture(tex, art_path)
	return tex


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
		var v = obj.get(f[0])
		if f[2] == "scene" or f[2] == "nation":
			v = "res:" + (v.resource_path if v is Resource else "")
		d[f[0]] = v
	return d


static func apply_snapshot(obj: Object, data: Dictionary, fields: Array):
	for f in fields:
		if !data.has(f[0]):
			continue
		var v = data[f[0]]
		if f[2] == "scene" or f[2] == "nation":
			var path = String(v).trim_prefix("res:")
			obj.set(f[0], load(path) if path != "" and ResourceLoader.exists(path) else null)
		else:
			set_prop(obj, f[0], v)


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
	CardGenerator.reset_style_cache()  # arte nova vira peça/cor pro gerador
	if !custom_cards.has(card):
		custom_cards.append(card)
	if !CardDatabase.all_cards.has(card):
		CardDatabase.all_cards.append(card)


# cria uma carta NOVA vazia (unidade ou feitiço) com valores razoáveis --
# o criador preenche e chama save_card()
func make_blank_card(is_spell: bool) -> Dictionary:
	var card = CardData.new()
	card.card_name = "Nova carta"
	card.cost = 30
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
		stats.attack_range = 15.0
		stats.move_speed = 45.0
	var img = Image.create_empty(CARD_ART_SIZE.x, CARD_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return {"card": card, "stats": stats, "spell": spell, "image": img, "is_new": true,
		"proj_image": default_projectile_image()}


# monta o "pacote de edição" de uma carta existente (original ou criada)
func open_card_for_edit(card: CardData) -> Dictionary:
	var stats: UnitData = DeckBuilder.get_unit_stats(card)
	var img = texture_to_image(card.icon, CARD_ART_SIZE)
	var proj_img = default_projectile_image()
	if stats != null and stats.projectile_texture != null:
		proj_img = texture_to_image(stats.projectile_texture, PROJ_ART_SIZE)
	return {"card": card, "stats": stats, "spell": card.spell_data, "image": img, "is_new": false, "proj_image": proj_img}


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
		stats.projectile_texture = _store_projectile(pack, ART_DIR + id + "_proj.res", stats.projectile_texture)
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
		entry["unit"] = snapshot(pack["stats"], all_unit_fields())
		if pack.get("proj_changed", false):
			var proj_path = ART_DIR + "ovp_" + str(abs(hash(path))) + ".res"
			pack["stats"].projectile_texture = _store_projectile(pack, proj_path, null)
			entry["proj_art"] = proj_path
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
			apply_snapshot(stats, o["unit"], all_unit_fields())
			stats.projectile_texture = o.get("proj", stats.projectile_texture)
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
		o["unit"] = snapshot(stats, all_unit_fields())
		o["proj"] = stats.projectile_texture
	if card.spell_data != null:
		o["spell"] = snapshot(card.spell_data, SPELL_FIELDS)
	_originals[path] = o


func remember_original_base(base: BaseData):
	var path = base.resource_path
	if _originals.has(path) or is_custom(base):
		return
	_originals[path] = {"base": snapshot(base, BASE_FIELDS), "icon": base.icon, "texture": base.base_texture, "proj": base.projectile_texture}


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
	return {"base": b, "image": img, "is_new": true, "proj_image": default_projectile_image()}


func open_base_for_edit(b: BaseData) -> Dictionary:
	var tex = b.base_texture if b.base_texture != null else b.icon
	var proj_img = texture_to_image(b.projectile_texture, PROJ_ART_SIZE) if b.projectile_texture != null else default_projectile_image()
	return {"base": b, "image": texture_to_image(tex, BASE_ART_SIZE), "is_new": false, "proj_image": proj_img}


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
		if pack.get("proj_changed", false):
			var proj_path = ART_DIR + "ovbp_" + str(abs(hash(path))) + ".res"
			b.projectile_texture = _store_projectile(pack, proj_path, null)
			entry["proj_art"] = proj_path
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
	b.projectile_texture = _store_projectile(pack, ART_DIR + id + "_proj.res", b.projectile_texture)
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
		b.projectile_texture = _originals[path].get("proj", b.projectile_texture)
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
			apply_snapshot(stats, entry["unit"], all_unit_fields())
			if stats.is_ranged and stats.projectile_texture == null:
				stats.projectile_texture = default_projectile
		if card.spell_data != null and entry.has("spell"):
			apply_snapshot(card.spell_data, entry["spell"], SPELL_FIELDS)
		var proj_art = entry.get("proj_art", "")
		if stats != null and proj_art != "" and ResourceLoader.exists(proj_art):
			stats.projectile_texture = load(proj_art)
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
		var bproj = entry.get("proj_art", "")
		if bproj != "" and ResourceLoader.exists(bproj):
			b.projectile_texture = load(bproj)
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
