extends RefCounted
class_name CardGenerator

# GERADOR de cartas e de pixel art aleatórios.
# Os atributos são balanceados olhando as SUAS cartas: calcula quanta "força
# por custo" as cartas do jogo têm em média e distribui esse orçamento entre
# vida/dano conforme a categoria sorteada.

const ANIMALS = ["Vaca", "Galo", "Bode", "Porco", "Pato", "Capivara", "Jegue", "Tatu", "Sapo",
	"Gato", "Ovelha", "Coruja", "Abelha", "Cabra", "Galinha", "Cavalo", "Boi", "Peru", "Tamanduá",
	"Jacaré", "Lagarto", "Formiga", "Minhoca", "Espantalho", "Caipira", "Peão", "Vaqueiro",
	"Lavrador", "Trator", "Milho", "Abóbora", "Mandioca", "Pamonha", "Rapadura", "Cuscuz"]
const SUFFIXES = ["da Lama", "do Brejo", "de Ferro", "Turbo", "Supremo", "Mutante", "Ninja",
	"do Sertão", "Atômico", "Pistoleiro", "Gigante", "Furioso", "Voador", "Encantado", "Sonolento",
	"Elétrico", "Blindado", "do Pasto", "Fantasma", "Rei", "Bombado", "Cósmico", "de Rodeio",
	"da Feira", "Sem Freio", "Raiz", "Nutella", "de Prata", "Barbudo", "Assustado"]
const SPELL_NAMES = ["Chuva de", "Tempestade de", "Nuvem de", "Explosão de", "Estouro de", "Praga de", "Granizo de", "Festa de"]
const SPELL_THINGS = ["Milho", "Esterco", "Pimenta", "Ovo", "Abelha", "Feno", "Rapadura", "Lama", "Raio", "Gafanhoto", "Fogos"]

const DEFAULT_POWER_PER_COST = 15.0  # na escala de custo 0-100 (mediana das oficiais: ~14)


# "força" crua igual à estimativa do BotSimulator (hp*0.3 + dps*3) * quantidade
static func _raw_power(stats: UnitData) -> float:
	var dps = stats.damage / max(stats.attack_speed, 0.1)
	return (stats.hp * 0.3 + dps * 3.0) * max(stats.unit_count, 1)


static var fixed_power := 0.0  # > 0: usa esse valor (a Safra usa pra não mudar carta antiga)


static func power_per_cost() -> float:
	if fixed_power > 0.0:
		return fixed_power
	var ratios: Array = []
	for card in CardDatabase.all_cards:
		if card == null or card.is_spell() or card.cost <= 0:
			continue
		var st = DeckBuilder.get_unit_stats(card)
		if st == null or st.unit_type == UnitData.UnitType.BUILDING:
			continue
		ratios.append(_raw_power(st) / card.cost)
	if ratios.size() < 3:
		return DEFAULT_POWER_PER_COST
	ratios.sort()
	return ratios[ratios.size() / 2]  # mediana -- ignora carta muito fora da curva


static func random_name(rng: RandomNumberGenerator, is_spell: bool) -> String:
	if is_spell:
		return SPELL_NAMES[rng.randi() % SPELL_NAMES.size()] + " " + SPELL_THINGS[rng.randi() % SPELL_THINGS.size()]
	return ANIMALS[rng.randi() % ANIMALS.size()] + " " + SUFFIXES[rng.randi() % SUFFIXES.size()]


# kind: 0 = aleatório, 1 = unidade, 2 = feitiço. role -1 = aleatório. cost 0 = aleatório
static func generate_card(kind: int = 0, role: int = -1, cost: int = 0, seed_value: int = -1) -> Dictionary:
	# 2.0: números + arte por peças + nome, tudo coerente com uma turma
	var seed_now = seed_value if seed_value >= 0 else int(randi())
	var gen = generate_def(seed_now, "", kind, role, cost)
	var def: Dictionary = gen["def"]
	var is_spell = gen["spell"] != null
	var pack = CustomContent.make_blank_card(is_spell)
	var card: CardData = pack["card"]
	card.card_name = def["nome"]
	card.cost = int(def["custo"])
	card.role = int(def["papel"]) as CardData.CardRole
	card.danger_level = int(def["perigo"])
	card.nation_data = Catalogo.nation(def["turma"])
	card.art_recipe = def["receita"]
	card.art_palette = def["paleta"]
	card.pros.assign(def["pros"])
	card.cons.assign(def["cons"])
	card.description = "Carta gerada. Turma: %s." % def["turma"]
	pack["image"] = SpriteForge.make_image(def["receita"], def["paleta"])
	if is_spell:
		pack["spell"] = gen["spell"]
	else:
		pack["stats"] = gen["stats"]
		if gen["stats"].is_ranged:
			pack["proj_image"] = SpriteForge.projectile(def["proj"], def["paleta"]).get_image()
	return pack


static func _fill_spell(sp: SpellData, role: int, cost: int, rng: RandomNumberGenerator):
	var cu = cost / 10.0  # custo em "elixir" (0-10) -- o recurso do jogo vai de 0 a 100
	sp.radius = rng.randf_range(55.0, 100.0)
	sp.affects_enemies = true
	sp.affects_allies = false
	match role:
		CardData.CardRole.SUPORTE:
			sp.affects_enemies = false
			sp.affects_allies = true
			sp.damage = 0
			sp.heal_amount = int(cu * rng.randf_range(35.0, 55.0))
			sp.duration = 3.0
			sp.tick_interval = 0.5
		CardData.CardRole.CONTROLE:
			sp.damage = int(cu * rng.randf_range(15.0, 30.0))
			sp.status_effect = [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.FREEZE][rng.randi() % 3]
			sp.status_effect_strength = 0.4
			sp.duration = rng.randf_range(2.0, 4.0)
			sp.tick_interval = 0.5
			sp.status_effect_duration = snapped(rng.randf_range(2.0, 4.0), 0.5)
		_:
			sp.damage = int(cu * rng.randf_range(70.0, 100.0))
			sp.duration = 0.0
	sp.base_damage_multiplier = 0.12 if role != CardData.CardRole.FINALIZADOR else 0.35
	sp.radius = round(sp.radius / 5.0) * 5.0


static func _fill_unit(st: UnitData, role: int, cost: int, rng: RandomNumberGenerator):
	var budget = power_per_cost() * cost * rng.randf_range(0.88, 1.1)
	var hp_share = 0.55
	st.unit_count = 1
	st.move_speed = rng.randf_range(40.0, 55.0)
	st.attack_speed = rng.randf_range(0.9, 1.5)
	st.attack_range = 15.0  # corpo a corpo: folga da borda
	st.push_weight = 1.0
	st.unit_type = UnitData.UnitType.GROUND
	st.target_type = UnitData.TargetType.GROUND
	st.detection_range = 110.0

	match role:
		CardData.CardRole.TANQUE:
			hp_share = 0.82
			st.move_speed = rng.randf_range(25.0, 35.0)
			st.push_weight = rng.randf_range(2.5, 4.0)
			st.unit_scale = 1.3
			st.attack_speed = 1.6
			st.target_type = UnitData.TargetType.BUILDING  # tanque vai direto pra torre
		CardData.CardRole.PUNICAO:
			hp_share = 0.35
			st.move_speed = rng.randf_range(50.0, 65.0)
			st.attack_speed = 1.4
		CardData.CardRole.ENXAME:
			st.unit_count = rng.randi_range(3, 6)
			hp_share = 0.5
			st.move_speed = rng.randf_range(55.0, 70.0)
			st.push_weight = 0.6
			st.unit_scale = 0.8
			st.spawn_formation = rng.randi() % 4
		CardData.CardRole.AEREO:
			st.unit_type = UnitData.UnitType.AIR
			st.target_type = UnitData.TargetType.ALL
			st.is_ranged = true
			st.attack_range = rng.randf_range(80.0, 120.0)
			hp_share = 0.5
		CardData.CardRole.CONSTRUCAO:
			st.unit_type = UnitData.UnitType.BUILDING
			st.target_type = [UnitData.TargetType.GROUND, UnitData.TargetType.ALL][rng.randi() % 2]
			st.is_ranged = true
			st.attack_range = rng.randf_range(130.0, 170.0)
			st.detection_range = st.attack_range + 20.0
			st.duration = rng.randf_range(25.0, 40.0)
			st.move_speed = 0.0
			hp_share = 0.6
		CardData.CardRole.CERCO:
			st.is_ranged = true
			st.target_type = UnitData.TargetType.BUILDING
			st.attack_range = rng.randf_range(200.0, 260.0)
			st.detection_range = st.attack_range + 20.0
			st.move_speed = rng.randf_range(30.0, 40.0)
			st.attack_speed = 2.2
			hp_share = 0.5
		CardData.CardRole.SUPORTE:
			st.is_ranged = true
			st.attack_range = 100.0
			st.can_heal_allies = true
			st.heal_aura_amount = int(cost / 10.0 * 4)
			st.heal_aura_radius = 80.0
			hp_share = 0.6
			budget *= 0.8  # a cura "paga" parte do orçamento
		CardData.CardRole.CONTROLE:
			st.is_ranged = rng.randf() < 0.6
			st.attack_range = 110.0 if st.is_ranged else 15.0
			st.on_hit_effect = [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.WEAKNESS][rng.randi() % 3]
			st.on_hit_effect_strength = 0.5
			st.on_hit_effect_duration = 1.5
			hp_share = 0.55
			budget *= 0.85
		CardData.CardRole.CONTRA_ATAQUE:
			st.is_aoe = true
			st.aoe_radius = 50.0
			hp_share = 0.55
			budget *= 0.9
		CardData.CardRole.FINALIZADOR:
			st.target_type = UnitData.TargetType.BUILDING
			st.move_speed = rng.randf_range(60.0, 75.0)
			hp_share = 0.5
		CardData.CardRole.INVOCADOR:
			# invoca uma unidade barata que já existe no jogo
			var pool: Array = []
			for c in CardDatabase.all_cards:
				if c != null and !c.is_spell() and c.unit_scene != null and c.cost <= 30:
					var cs = DeckBuilder.get_unit_stats(c)
					if cs != null and cs.unit_type != UnitData.UnitType.BUILDING and !cs.spawns_units:
						pool.append(c)
			if !pool.is_empty():
				st.spawns_units = true
				st.spawn_unit_scene = pool[rng.randi() % pool.size()].unit_scene
				st.spawn_interval = rng.randf_range(6.0, 10.0)
				st.spawn_count = 1
				budget *= 0.6
			hp_share = 0.7
			st.move_speed = 30.0
		_:
			hp_share = rng.randf_range(0.45, 0.65)

	if st.is_ranged and st.target_type == UnitData.TargetType.GROUND and rng.randf() < 0.5:
		st.target_type = UnitData.TargetType.ALL
		budget *= 0.92

	var count = max(st.unit_count, 1)
	st.hp = max(30, int(round(budget * hp_share / 0.3 / count / 10.0)) * 10)
	var dps = budget * (1.0 - hp_share) / 3.0 / count
	st.damage = max(5, int(round(dps * st.attack_speed / 5.0)) * 5)
	st.move_speed = round(st.move_speed / 5.0) * 5.0
	st.attack_range = round(st.attack_range / 5.0) * 5.0
	st.attack_speed = snapped(st.attack_speed, 0.1)
	st.role = role


# ============================================================== sprites

# ============================================================ estilo do jogo
# As artes das SUAS cartas viram matéria-prima do gerador:
#  - modo "peças" (2): pega cabeça de uma, corpo de outra e pernas de outra,
#    alinha pelo centro, troca as cores e refaz o contorno -- sai um
#    "parente" das cartas que você já tem
#  - modo "estrutura" (3): monta um bicho do zero no formato das suas artes
#    (em pé, de frente, cabeça grande, chifre/orelha, olhos, manchas, arma
#    na mão, contorno preto) usando a PALETA tirada das suas artes
# Quanto mais carta você desenha no Criador, mais peças e cores ele tem.
static var _donors: Array = []
static var _palette: Array = []
const PART_SPLITS = [0.0, 0.40, 0.70, 1.0]  # cabeça / corpo / pernas (fração da altura)


static func reset_style_cache():
	_donors.clear()
	_palette.clear()


static func _load_style():
	if !_donors.is_empty():
		return
	var counts: Dictionary = {}
	for card in CardDatabase.all_cards:
		if card == null or card.icon == null:
			continue
		var img: Image = CustomContent.texture_to_image(card.icon, Vector2i(32, 32))
		var used: Rect2i = img.get_used_rect()
		if used.size.x < 8 or used.size.y < 12:
			continue
		# só arte de UM bicho em pé serve de doadora de peça: grupo (trio,
		# enxame) ou bicho de lado (comprido) gera monstro quebrado
		if used.size.y >= used.size.x * 0.85 and _components(img) == 1:
			_donors.append({"img": img, "rect": used})
		for y in range(used.position.y, used.end.y):
			for x in range(used.position.x, used.end.x):
				var c = img.get_pixel(x, y)
				if c.a < 0.5 or c.v < 0.2:
					continue
				var key = Color(snapped(c.r, 0.0625), snapped(c.g, 0.0625), snapped(c.b, 0.0625)).to_html(false)
				counts[key] = counts.get(key, 0) + 1
	var keys = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 32):
		_palette.append(Color(k))
	if _palette.size() < 6:
		_palette = [Color("6b3e26"), Color("a0663c"), Color("e8d8a8"), Color("7a7a7a"), Color("b8b8b8"), Color("5a9e3a"), Color("ffffff"), Color("c0392b")]


static func generate_styled_sprite(seed_value: int) -> Image:
	_load_style()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	# mais peças das suas artes quando tem bastante arte pra misturar
	if _donors.size() >= 3 and rng.randf() < 0.6:
		return _kitbash(rng)
	return _structured(rng)


const OUTLINE = Color(0.0, 0.0, 0.0, 1.0)


static func _kitbash(rng: RandomNumberGenerator) -> Image:
	var out = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var pieces: Array = []
	var total_h = 0
	var bottom = 31
	for part in 3:
		var d = _donors[rng.randi() % _donors.size()]
		var r: Rect2i = d["rect"]
		var y0 = r.position.y + int(r.size.y * PART_SPLITS[part])
		var y1 = r.position.y + int(r.size.y * PART_SPLITS[part + 1])
		if y1 <= y0:
			continue
		# centro de massa da peça (ignora arma/acessório puxando pro lado)
		var sum_x = 0.0
		var n = 0
		for y in range(y0, y1):
			for x in range(r.position.x, r.end.x):
				if d["img"].get_pixel(x, y).a > 0.5:
					sum_x += x
					n += 1
		pieces.append({"img": d["img"], "rect": r, "y0": y0, "y1": y1, "cx": (sum_x / max(n, 1))})
		total_h += y1 - y0
		if part == 2:
			bottom = r.end.y - 1
	# se ficou alto demais, corta linhas do meio do corpo
	while total_h > 31 and pieces.size() >= 2:
		pieces[1]["y1"] -= 1
		total_h -= 1
	var y_cursor = clamp(bottom + 1 - total_h, 0, 31)
	for p in pieces:
		var dx = int(round(16.0 - p["cx"]))
		for y in range(p["y0"], p["y1"]):
			for x in range(p["rect"].position.x, p["rect"].end.x):
				var c = p["img"].get_pixel(x, y)
				if c.a < 0.5:
					continue
				var tx = x + dx
				var ty = y_cursor + (y - p["y0"])
				if tx >= 0 and tx < 32 and ty >= 0 and ty < 32:
					out.set_pixel(tx, ty, c)
		y_cursor += p["y1"] - p["y0"]
	# troca de cores (mantém contorno, preto, branco e cinza)
	if rng.randf() < 0.7:
		var shift = rng.randf_range(0.08, 0.92)
		var sat_mul = rng.randf_range(0.8, 1.2)
		for y in 32:
			for x in 32:
				var c = out.get_pixel(x, y)
				if c.a < 0.5 or c.s < 0.18 or c.v < 0.18:
					continue
				out.set_pixel(x, y, Color.from_hsv(fposmod(c.h + shift, 1.0), clamp(c.s * sat_mul, 0, 1), c.v))
	_keep_largest(out)
	_outline(out)
	return out


# quantos "pedaços" separados (de tamanho relevante) a arte tem
static func _components(img: Image) -> int:
	var seen: Dictionary = {}
	var count = 0
	for y in img.get_height():
		for x in img.get_width():
			var p = Vector2i(x, y)
			if seen.has(p) or img.get_pixelv(p).a < 0.5:
				continue
			var size = _flood_size(img, p, seen)
			if size >= 12:
				count += 1
	return count


static func _flood_size(img: Image, start: Vector2i, seen: Dictionary) -> int:
	var stack: Array[Vector2i] = [start]
	var n = 0
	var cells: Array = []
	while !stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p) or p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			continue
		if img.get_pixelv(p).a < 0.5:
			continue
		seen[p] = true
		n += 1
		cells.append(p)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(p + d)
	seen["__last"] = cells
	return n


# apaga pedacinhos soltos -- fica só o maior pedaço (o bicho)
static func _keep_largest(img: Image):
	var seen: Dictionary = {}
	var best: Array = []
	for y in img.get_height():
		for x in img.get_width():
			var p = Vector2i(x, y)
			if seen.has(p) or img.get_pixelv(p).a < 0.5:
				continue
			var n = _flood_size(img, p, seen)
			if n > best.size():
				best = seen["__last"]
	var keep: Dictionary = {}
	for p in best:
		keep[p] = true
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5 and !keep.has(Vector2i(x, y)):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _pick(rng: RandomNumberGenerator, filter: Callable) -> Color:
	var opts = _palette.filter(filter)
	if opts.is_empty():
		opts = _palette
	return opts[rng.randi() % opts.size()]


static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color, mirror := true):
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if x >= 0 and x < 32 and y >= 0 and y < 32:
				img.set_pixel(x, y, c)
				if mirror and 31 - x >= 0:
					img.set_pixel(31 - x, y, c)


static func _structured(rng: RandomNumberGenerator) -> Image:
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var main = _pick(rng, func(c): return c.s > 0.2 and c.v > 0.25 and c.v < 0.9)
	var dark = main.darkened(rng.randf_range(0.3, 0.45))
	var light = _pick(rng, func(c): return c.v > 0.7)
	var metal = Color(0.6, 0.62, 0.66)
	var eye = [Color("c0392b"), Color.WHITE, Color("ffec27")][rng.randi() % 3]

	# medidas (metade esquerda; o _rect espelha pra direita)
	var leg_h = rng.randi_range(4, 6)
	var body_h = rng.randi_range(7, 10)
	var head_h = rng.randi_range(7, 9)
	var body_w = rng.randi_range(5, 7)   # meia largura
	var head_w = rng.randi_range(4, 6)
	var feet_y = 30
	var body_y = feet_y - leg_h - body_h + 1
	var head_y = body_y - head_h + 1

	# pernas
	var leg_x = 16 - rng.randi_range(3, 4)
	_rect(img, leg_x - 1, feet_y - leg_h + 1, 3, leg_h, dark)
	# corpo (cantos arredondados)
	_rect(img, 16 - body_w, body_y + 1, body_w, body_h - 1, main)
	_rect(img, 16 - body_w + 1, body_y, body_w - 1, 1, main)
	# barriga clara
	if rng.randf() < 0.6:
		_rect(img, 16 - body_w + 3, body_y + 3, body_w - 3, body_h - 4, light)
	# manchas (tipo vaca/boi)
	for i in rng.randi_range(0, 3):
		var sx = rng.randi_range(16 - body_w, 14)
		var sy = rng.randi_range(body_y + 1, body_y + body_h - 3)
		_rect(img, sx, sy, 2, 2, dark, rng.randf() < 0.3)
	# braços
	var arm_y = body_y + 1
	_rect(img, 16 - body_w - 2, arm_y, 2, body_h - 2, main)
	# cabeça
	_rect(img, 16 - head_w, head_y + 1, head_w, head_h - 1, main)
	_rect(img, 16 - head_w + 1, head_y, head_w - 1, 1, main)
	# focinho
	if rng.randf() < 0.7:
		_rect(img, 16 - 2, head_y + head_h - 3, 2, 2, light)
		img.set_pixel(15, head_y + head_h - 2, OUTLINE)
		img.set_pixel(16, head_y + head_h - 2, OUTLINE)
	# olhos
	var eye_y = head_y + int(head_h * 0.35)
	_rect(img, 16 - head_w + 1, eye_y, 1, 2, eye)
	# chifre ou orelha
	match rng.randi() % 3:
		0:  # chifres curvos
			_rect(img, 16 - head_w - 1, head_y - 1, 2, 1, metal)
			_rect(img, 16 - head_w - 2, head_y - 3, 1, 3, metal)
			_rect(img, 16 - head_w - 1, head_y - 4, 1, 1, metal)
		1:  # orelhas pra cima
			_rect(img, 16 - head_w, head_y - 2, 2, 2, dark)
		2:  # orelhas de lado
			_rect(img, 16 - head_w - 2, head_y + 1, 2, 2, dark)
	# arma na mão direita (não espelha)
	var hand_x = 31 - (16 - body_w - 2) + 1
	var hand_y = arm_y + body_h - 3
	match rng.randi() % 5:
		0:  # machado/marreta
			_rect(img, hand_x, hand_y - 9, 1, 13, Color("3b2614"), false)
			_rect(img, hand_x - 2, hand_y - 10, 5, 3, metal, false)
		1:  # forcado
			_rect(img, hand_x, hand_y - 9, 1, 13, Color("6b3e26"), false)
			for k in [-1, 1]:
				_rect(img, hand_x + k * 2, hand_y - 12, 1, 3, metal, false)
			_rect(img, hand_x - 2, hand_y - 10, 5, 1, metal, false)
			_rect(img, hand_x, hand_y - 12, 1, 3, metal, false)
		2:  # porrete
			_rect(img, hand_x, hand_y - 6, 2, 9, Color("8b5a2b"), false)
			_rect(img, hand_x - 1, hand_y - 8, 4, 3, Color("6b3e26"), false)
		3:  # espada/foice
			_rect(img, hand_x, hand_y - 9, 1, 10, metal, false)
			_rect(img, hand_x - 1, hand_y, 3, 1, Color("6b3e26"), false)
		_:
			pass  # sem arma
	_outline(img)
	return img


# contorno preto de 1px em volta de tudo (igual às suas artes)
static func _outline(img: Image):
	var src = img.duplicate()
	var w = img.get_width()
	var h = img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx = x + d.x
				var ny = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var c = src.get_pixel(nx, ny)
					if c.a > 0.5 and !(c.r < 0.08 and c.g < 0.08 and c.b < 0.08):
						img.set_pixel(x, y, OUTLINE)
						break


# gerador de "bichinho" em pixel art: máscara simétrica (meia largura,
# espelhada), corpo com degradê, contorno escuro e olhinhos. Funciona pra
# 32x32 (carta), 32x64 (base) e 36x64 (fundo de arena vira um padrão)
static func generate_sprite(w: int, h: int, seed_value: int) -> Image:
	if w == 48 and h == 48:
		# 2.0: personagem montado por peças, no estilo das cartas oficiais
		var rng48 = RandomNumberGenerator.new()
		rng48.seed = seed_value
		var st48 = UnitData.new()
		st48.is_ranged = rng48.randf() < 0.3
		st48.damage = rng48.randi_range(40, 160)
		if rng48.randf() < 0.15:
			st48.unit_type = UnitData.UnitType.AIR
		var d48 = design_card(rng48, random_turma(rng48), rng48.randi() % CardData.CardRole.size(), st48, null)
		return SpriteForge.make_image(d48["receita"], d48["paleta"])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	if h > w * 1.5 and w >= 34:
		return generate_arena_background(w, h, seed_value)
	if w == 32 and h == 32:
		return generate_styled_sprite(seed_value)  # no estilo das suas cartas

	var bw = int(w * 0.62)  # largura do corpo
	var bh = int(h * 0.62) if h <= w else int(h * 0.8)
	var half = int(ceil(bw / 2.0))
	var ox = int((w - bw) / 2.0)
	var oy = int((h - bh) / 2.0) + (1 if h <= w else 0)

	var mask: Array = []
	for y in bh:
		var row: Array = []
		for x in half:
			# mais denso no centro, mais vazio nas bordas e em cima
			var cx = float(x) / half
			var cy = float(y) / bh
			var p = 0.15 + cx * 0.55 + (1.0 - abs(cy - 0.55) * 1.6) * 0.35
			row.append(1 if rng.randf() < p else 0)
		mask.append(row)
	# suaviza a máscara 2x (fica mais "bicho" e menos "ruído")
	for _i in 2:
		var nm: Array = []
		for y in bh:
			var row: Array = []
			for x in half:
				var n = 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx = x + d.x
					var yy = y + d.y
					if xx >= half:
						xx = half - 1  # borda do espelho conta como cheia
					if xx >= 0 and yy >= 0 and yy < bh and mask[yy][xx] == 1:
						n += 1
				row.append(1 if (n >= 3 or (mask[y][x] == 1 and n >= 2)) else 0)
			nm.append(row)
		mask = nm

	var hue = rng.randf()
	var sat = rng.randf_range(0.35, 0.75)
	var hue2 = fmod(hue + rng.randf_range(0.08, 0.5), 1.0)
	for y in bh:
		for x in half:
			if mask[y][x] != 1:
				continue
			var t = float(y) / bh
			var c = Color.from_hsv(lerp(hue, hue2, t * 0.6), sat, lerp(0.95, 0.55, t))
			if rng.randf() < 0.12:
				c = c.darkened(0.2)
			var px = ox + x
			var mx = ox + bw - 1 - x
			img.set_pixel(px, oy + y, c)
			if mx >= 0 and mx < w:
				img.set_pixel(mx, oy + y, c)

	# olhos: procura uma linha no terço de cima com corpo nas duas metades
	for y in range(int(bh * 0.2), int(bh * 0.5)):
		var ex = ox + int(half * 0.55)
		if ex < w and img.get_pixel(ex, oy + y).a > 0 and img.get_pixel(ox + bw - 1 - int(half * 0.55), oy + y).a > 0:
			for e in [ex, ox + bw - 1 - int(half * 0.55)]:
				img.set_pixel(e, oy + y, Color.WHITE)
				if oy + y + 1 < h:
					img.set_pixel(e, oy + y + 1, Color("1a1018"))
			break

	# contorno
	var src = img.duplicate()
	var outline = Color("1a1018")
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and src.get_pixelv(n).a > 0:
					img.set_pixel(x, y, outline)
					break
	return img


# fundo de arena procedural: grama com variação, um rio no meio com 2
# pontes, e umas florzinhas/pedras -- ponto de partida pra você pintar por cima
static func generate_arena_background(w: int, h: int, seed_value: int) -> Image:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var palettes = [
		[Color("5a9e3a"), Color("4c8a30"), Color("6db04a")],  # pasto
		[Color("c9a66b"), Color("b8935a"), Color("d8b77c")],  # terra/sertão
		[Color("8fbf5a"), Color("7aa84b"), Color("a3cf6a")],  # campo claro
		[Color("e8eef2"), Color("d5dde3"), Color("f5f8fa")],  # neve
		[Color("3e6b45"), Color("335a3a"), Color("4b7d52")],  # mata
	]
	var pal = palettes[rng.randi() % palettes.size()]
	for y in h:
		for x in w:
			img.set_pixel(x, y, pal[rng.randi() % pal.size()] if rng.randf() < 0.35 else pal[0])
	var river_y = int(h / 2.0)
	var water = Color("3a7bd5") if pal[0] != Color("e8eef2") else Color("8fc3e8")
	for y in range(river_y - 2, river_y + 2):
		for x in w:
			img.set_pixel(x, y, water.lightened(0.15) if rng.randf() < 0.2 else water)
	for bx in [int(w * 0.25), int(w * 0.75)]:
		for y in range(river_y - 3, river_y + 3):
			for x in range(bx - 2, bx + 2):
				if x >= 0 and x < w:
					img.set_pixel(x, y, Color("8b5a2b") if (y % 2 == 0) else Color("a0703c"))
	for _i in int(w * h / 40.0):
		var x = rng.randi() % w
		var y = rng.randi() % h
		if abs(y - river_y) > 3:
			img.set_pixel(x, y, [Color("ffec27"), Color("ff77a8"), Color("fff1e8"), Color("7a7a7a")][rng.randi() % 4])
	return img


# ================================================================ 2.0: gerador por PEÇAS e por TURMA
# Carta nova sai com a cara da turma dela (peças, cores e nome), usando o
# mesmo SpriteForge das cartas oficiais. Usado pelo Criador ("Gerar") e pela
# Safra (cartas automáticas a cada 3 dias).
const TURMA_THEMES = {
	"Curral": {"cabeca": ["vaca", "boi", "cavalo", "ovelha", "bode", "burro"], "pernas": ["casco"], "corpo": ["redondo", "la", "armadura", "poncho", "colete"], "bracos": ["patas"],
		"cores": ["#f2ede0", "#8a5a3c", "#c89060", "#4a4048", "#d8c0a0", "#b87848"], "proj": "estrume"},
	"Galinheiro": {"cabeca": ["galinha", "pato", "coruja", "urubu"], "pernas": ["ave"], "corpo": ["penas"], "bracos": ["asas"],
		"cores": ["#f4f0e4", "#f8dc50", "#b84828", "#8a6848", "#f0e8a0", "#506078"], "proj": "ovo"},
	"Brejo": {"cabeca": ["sapo", "capivara", "gato", "jacare", "tatu"], "pernas": ["patinha"], "corpo": ["redondo", "poncho"], "bracos": ["patas"],
		"cores": ["#68b848", "#a87848", "#3c8848", "#58a0a0", "#8a6038", "#90c060"], "proj": "gota"},
	"Roçado": {"cabeca": ["milho", "abobora", "cebola", "espantalho", "tomate", "cacto"], "pernas": ["bota", "fantasma"], "corpo": ["macacao", "poncho", "saco"], "bracos": ["humanos"],
		"cores": ["#f4d040", "#f08828", "#c880c0", "#c8a860", "#e05050", "#90c040"], "proj": "milho"},
	"Peões": {"cabeca": ["humano", "velho", "porco", "cachorro"], "pernas": ["bota"], "corpo": ["macacao", "poncho", "armadura", "colete", "terno"], "bracos": ["humanos"],
		"cores": ["#c84838", "#58a050", "#e8c040", "#3c6cb8", "#b83830", "#e8e0d0"], "proj": "pedra"},
	"Coisa Estranha": {"cabeca": ["et", "balde", "abelha", "espantalho", "gato", "caveira"], "pernas": ["rodas", "fantasma", "inseto", "bota"], "corpo": ["armadura", "listrado", "redondo"], "bracos": ["humanos", "patas"],
		"cores": ["#78c878", "#98a0ac", "#f4c830", "#d8e8f0", "#9a5cd0", "#50c0e0"], "proj": "raio"},
}
const HEAD_NAMES = {"vaca": "Vaca", "boi": "Boi", "cavalo": "Cavalo", "ovelha": "Ovelha", "bode": "Bode", "galinha": "Galinha", "pato": "Pato", "coruja": "Coruja",
	"sapo": "Sapo", "capivara": "Capivara", "gato": "Gato", "milho": "Milho", "abobora": "Abóbora", "cebola": "Cebola", "espantalho": "Espantalho",
	"humano": "Peão", "velho": "Vovô", "porco": "Porco", "et": "ET", "balde": "Robô", "abelha": "Abelha",
	"cachorro": "Caramelo", "burro": "Jegue", "tatu": "Tatu", "jacare": "Jacaré", "urubu": "Urubu", "tomate": "Tomate", "cacto": "Cacto", "caveira": "Caveira"}
const HEAD_FEMININE = ["vaca", "ovelha", "galinha", "coruja", "capivara", "abobora", "cebola", "abelha", "caveira"]
const WEAPON_TITLES = {"forcado": ["do Forcado", "do Forcado"], "machado": ["Lenhador", "Lenhadora"], "marreta": ["Marreteiro", "Marreteira"], "foice": ["Ceifador", "Ceifadora"],
	"enxada": ["da Enxada", "da Enxada"], "frigideira": ["Cozinheiro", "Cozinheira"], "porrete": ["Brigão", "Brigona"], "motosserra": ["da Motosserra", "da Motosserra"],
	"estilingue": ["Atirador", "Atiradora"], "lampiao": ["do Lampião", "do Lampião"], "viola": ["Violeiro", "Violeira"], "escudo": ["Blindado", "Blindada"],
	"rastelo": ["do Rastelo", "do Rastelo"], "regador": ["Jardineiro", "Jardineira"], "vara": ["Pescador", "Pescadora"], "berrante": ["Berranteiro", "Berranteira"],
	"garrafa": ["Cachaceiro", "Cachaceira"], "espingarda": ["Caçador", "Caçadora"]}
const ROLE_TITLES = {0: ["em Bando", "em Bando"], 1: ["Parrudo", "Parruda"], 2: ["Nervoso", "Nervosa"], 3: ["Manhoso", "Manhosa"], 4: ["Vingativo", "Vingativa"], 5: ["Curandeiro", "Curandeira"],
	6: ["Arrombador", "Arrombadora"], 7: ["de Guarda", "de Guarda"], 8: ["Voador", "Voadora"], 9: ["Ligeiro", "Ligeira"], 10: ["Parideiro", "Parideira"], 11: ["de Longe", "de Longe"]}
const FUNNY_SUFFIXES = ["do Brejo", "de Ferro", "Turbo", "3000", "Mutante", "Ninja", "da Madrugada", "Atômico", "de Domingo", "Sem Freio", "do Além", "Premium", "Raiz", "Gourmet", "Caipira", "do Zap"]
const MELEE_WEAPONS = ["forcado", "machado", "marreta", "foice", "enxada", "frigideira", "porrete", "motosserra", "rastelo", "regador"]
const RANGED_WEAPONS = ["estilingue", "lampiao", "viola", "vara", "berrante", "garrafa", "espingarda"]
const WEAPON_PROJ = {"estilingue": "pedra", "lampiao": "fogo", "viola": "nota", "vara": "espinho", "berrante": "nota", "garrafa": "gota", "espingarda": "pedra"}
const HATS = ["palha", "cowboy", "balde", "bandana", "coroa", "cozinheiro", "flor", "penacho", "bone", "cartola", "chifres", "melancia"]
const BUILDINGS = ["galinheiro", "silo", "colmeia", "poco", "barril", "canhao_milho", "fornalha", "tenda", "ninho", "feno", "carroca", "casinha", "cerca_eletrica"]
const BUILDING_NAMES = {"galinheiro": "Galinheiro", "silo": "Silo", "colmeia": "Colmeia", "poco": "Poço", "barril": "Barril", "canhao_milho": "Canhão", "fornalha": "Forno", "tenda": "Barraca", "ninho": "Ninho", "feno": "Monte de Feno", "carroca": "Carroça", "casinha": "Casinha", "cerca_eletrica": "Cerca Elétrica"}
const BUILDING_SUFFIX = ["Nervoso", "Blindado", "Assombrado", "Turbinado", "da Discórdia", "Atômico", "do Vizinho", "Encantado"]
const ACCENTS = ["#c8483c", "#3c6cb8", "#e8a020", "#8048a0", "#40a060", "#e06080", "#30303c", "#50c0e0"]


static func random_turma(rng: RandomNumberGenerator) -> String:
	var names = TURMA_THEMES.keys()
	return names[rng.randi() % names.size()]


static func _pick_of(rng: RandomNumberGenerator, list: Array):
	return list[rng.randi() % list.size()]


## monta a arte (receita + paleta), o nome e o projétil de uma carta nova
## já com os números decididos (stats de unidade OU dados de feitiço)
static func design_card(rng: RandomNumberGenerator, turma: String, role: int, stats: UnitData, spell: SpellData) -> Dictionary:
	var theme: Dictionary = TURMA_THEMES.get(turma, TURMA_THEMES["Peões"])
	var palette = {"P": _pick_of(rng, theme["cores"]), "S": _pick_of(rng, theme["cores"]), "A": _pick_of(rng, ACCENTS)}
	var out = {"receita": {}, "paleta": palette, "nome": "", "proj": theme["proj"]}

	if spell != null:
		var icon = "melancia"
		var thing = "Melancia"
		if spell.summon_count > 0:
			icon = "ovo"; thing = "Ovo Surpresa"
		elif spell.heal_amount > 0:
			icon = _pick_of(rng, ["coracao", "nota"]); thing = "Carinho" if icon == "coracao" else "Modão"
		elif spell.shield_amount > 0:
			icon = "escudo"; thing = "Tampa"
		elif spell.rage_damage_mult > 1.0:
			icon = "pimenta"; thing = "Pimenta"
		elif spell.status_effect == UnitData.OnHitEffect.FREEZE:
			icon = "floco"; thing = "Geada"
		elif spell.status_effect == UnitData.OnHitEffect.SLOW:
			icon = "lama"; thing = "Lama"
		elif spell.status_effect == UnitData.OnHitEffect.STUN:
			icon = "raio"; thing = "Trovão"
		elif spell.status_effect == UnitData.OnHitEffect.POISON:
			icon = "cogumelo"; thing = "Cogumelo"
		elif spell.status_effect == UnitData.OnHitEffect.PULL:
			icon = "tornado"; thing = "Redemoinho"
		elif spell.damage >= 350:
			icon = "vaca_caindo"; thing = "Vaca"
		elif rng.randf() < 0.5:
			icon = "raio"; thing = "Raio"
		out["receita"] = {"icone": icon}
		palette["K"] = _pick_of(rng, ["#f8e040", "#f8ecc8", "#f0d060"])
		palette["M"] = _pick_of(rng, ["#a8b4c0", "#c8d4e0"])
		out["nome"] = "%s %s" % [_pick_of(rng, ["Chuva de", "Festa de", "Praga de", "Estouro de", "Benção de", "Surra de"]), thing] if rng.randf() < 0.7 else "%s %s" % [thing, _pick_of(rng, FUNNY_SUFFIXES)]
		return out

	if stats.unit_type == UnitData.UnitType.BUILDING:
		var obj = _pick_of(rng, BUILDINGS)
		out["receita"] = {"objeto": obj}
		palette["W"] = _pick_of(rng, ["#8a5a34", "#6a4428", "#a07040"])
		out["nome"] = "%s %s" % [BUILDING_NAMES[obj], _pick_of(rng, BUILDING_SUFFIX)]
		return out

	var head = _pick_of(rng, theme["cabeca"])
	var recipe = {"cabeca": head, "pernas": _pick_of(rng, theme["pernas"]), "corpo": _pick_of(rng, theme["corpo"]), "bracos": _pick_of(rng, theme["bracos"])}
	var weapon = ""
	if stats.is_ranged:
		if rng.randf() < 0.75:
			weapon = _pick_of(rng, RANGED_WEAPONS)
			out["proj"] = WEAPON_PROJ[weapon]
	elif stats.damage >= 90 or rng.randf() < 0.4:
		weapon = _pick_of(rng, MELEE_WEAPONS)
	elif role == CardData.CardRole.TANQUE and rng.randf() < 0.5:
		weapon = "escudo"
	if weapon != "":
		recipe["arma"] = weapon
	if rng.randf() < 0.55:
		recipe["chapeu"] = _pick_of(rng, HATS)
	if stats.unit_type == UnitData.UnitType.AIR:
		if recipe["bracos"] != "asas":
			recipe["costas"] = _pick_of(rng, ["asas_inseto", "foguete"])
	elif rng.randf() < 0.15:
		recipe["costas"] = _pick_of(rng, ["capa", "rabo_galo", "cesto", "morcego"])
	if head in ["humano", "velho"]:
		palette["K"] = _pick_of(rng, ["#e8b088", "#d89868", "#c08058", "#f0c8a0"])
	elif head in ["galinha", "pato", "coruja"]:
		palette["K"] = _pick_of(rng, ["#f0b030", "#f09030"])
	out["receita"] = recipe

	var fem = 1 if head in HEAD_FEMININE else 0
	var title = WEAPON_TITLES[weapon][fem] if weapon != "" and rng.randf() < 0.7 else ROLE_TITLES.get(role, ["Ligeiro", "Ligeira"])[fem]
	var name = "%s %s" % [HEAD_NAMES.get(head, "Bicho"), title]
	if stats.unit_count > 1:
		name = "Bando de %s" % HEAD_NAMES.get(head, "Bicho")
	if rng.randf() < 0.45:
		name += " " + _pick_of(rng, FUNNY_SUFFIXES)
	out["nome"] = name
	return out


static func _unit_score(st: UnitData) -> int:
	var total = 0
	for pair in Catalogo.unit_abilities(st):
		total += int(pair[1])
	return total


static func _roll_extra(rng: RandomNumberGenerator) -> int:
	var total = 0
	for w in EXTRA_WEIGHTS:
		total += w
	var roll = rng.randi() % total
	for i in EXTRA_WEIGHTS.size():
		roll -= EXTRA_WEIGHTS[i]
		if roll < 0:
			return i
	return 0


static func describe_unit(stats: UnitData, role: int) -> Dictionary:
	var pros: Array = []
	var cons: Array = []
	if stats.unit_type == UnitData.UnitType.AIR:
		pros.append("Voa por cima de tudo")
	if stats.unit_count > 1:
		pros.append("Vêm em %d" % stats.unit_count)
		cons.append("Dano em área acaba com o grupo")
	if stats.is_ranged:
		pros.append("Ataca de longe")
	if stats.target_type == UnitData.TargetType.ALL:
		pros.append("Acerta voador")
	elif stats.target_type == UnitData.TargetType.BUILDING:
		pros.append("Vai direto na torre")
		cons.append("Ignora as tropas")
	elif stats.unit_type != UnitData.UnitType.AIR:
		cons.append("Não acerta voador")
	if stats.can_heal_allies:
		pros.append("Cura quem está perto")
	if stats.on_hit_effect != UnitData.OnHitEffect.NONE:
		pros.append("Golpe com efeito: %s" % CustomContent.EFFECT_NAMES[stats.on_hit_effect])
	if stats.is_aoe:
		pros.append("Dano em área")
	if stats.spawns_units:
		pros.append("Invoca ajudantes")
	if role == CardData.CardRole.TANQUE:
		pros.append("Muita vida")
		cons.append("Lento")
	if stats.unit_type == UnitData.UnitType.BUILDING:
		cons.append("Some com o tempo")
	if pros.is_empty():
		pros.append("Equilibrada")
	if cons.is_empty():
		cons.append("Sem truque especial")
	return {"pros": pros.slice(0, 3), "cons": cons.slice(0, 2)}


# habilidades extras que o gerador pode somar a uma carta (todas passam na
# auditoria automática). Quanto mais habilidades, mais rara a carta -- e um
# pouco menos de vida/dano, pra força total continuar na mesma régua.
const EXTRA_WEIGHTS = [40, 30, 23, 5, 2]  # raridade alvo: Normal, Rara, Épica, Lendária, Mística
const EXTRA_POOL = ["escudo", "roubo", "casca", "regen", "primeiro", "furia_entrada", "onda", "investida", "executa", "furia_morte", "cresce",
	"cura_matar", "devolve", "inabalavel", "explode", "clone", "contra", "ouro_matar", "rouba", "corrente", "longe", "mais_um", "avanco", "levanta", "efeito"]


static func add_extras(st: UnitData, rng: RandomNumberGenerator, n: int) -> Array:
	var labels: Array = []
	var pool = EXTRA_POOL.duplicate()
	var is_b = st.unit_type == UnitData.UnitType.BUILDING
	var melee = !st.is_ranged
	var tries = 0
	while labels.size() < n and !pool.is_empty() and tries < 60:
		tries += 1
		var pick = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		var hits = st.damage > 0
		match pick:
			"escudo":
				st.has_shield = true
				st.shield_amount = int(max(40, st.hp * 0.25 / 10.0)) * 10 if st.hp >= 400 else max(40, int(st.hp * 0.25))
				labels.append("Começa com escudo")
			"casca":
				if st.damage_reduction_percent > 0: continue
				st.damage_reduction_percent = 0.2
				labels.append("Leva 20% menos dano")
			"regen":
				st.passive_regen = true
				st.regen_amount = max(4, int(st.hp * 0.02))
				st.regen_interval = 1.5
				labels.append("Regenera sozinha")
			"devolve":
				st.reflects_damage = true
				st.reflect_damage_percent = 0.2
				labels.append("Devolve parte do dano")
			"explode":
				if !hits: continue
				st.explodes_on_death = true
				st.death_explosion_damage = int(st.damage * 1.5)
				st.death_explosion_radius = 55.0
				labels.append("Explode ao morrer")
			"efeito":
				if !hits or st.on_hit_effect != UnitData.OnHitEffect.NONE: continue
				st.on_hit_effect = [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.POISON, UnitData.OnHitEffect.WEAKNESS][rng.randi() % 3]
				st.on_hit_effect_strength = 10.0 if st.on_hit_effect == UnitData.OnHitEffect.POISON else 0.6
				st.on_hit_effect_duration = 2.5
				st.on_hit_effect_tick_interval = 1.0
				labels.append("Golpe com efeito: %s" % CustomContent.EFFECT_NAMES[st.on_hit_effect])
			"corrente":
				if !st.is_ranged or !hits or st.is_aoe: continue
				st.projectile_chains = true
				st.projectile_chain_max_targets = 3
				st.projectile_chain_range = 90.0
				labels.append("Tiro pula entre inimigos")
			"longe":
				if !st.is_ranged or !hits: continue
				st.distance_damage_bonus_per_100px = 0.3
				labels.append("Mais dano quanto mais longe")
			_:
				if is_b or !hits:
					continue  # as de baixo são só pra tropa que anda e bate
				match pick:
					"roubo":
						st.lifesteal_percent = 0.25
						labels.append("Rouba vida")
					"primeiro":
						st.first_attack_bonus = true
						st.first_attack_multiplier = 2.0
						labels.append("Primeiro golpe em dobro")
					"furia_entrada":
						st.entrance_rage_duration = 4.0
						labels.append("Entra em fúria")
					"onda":
						st.entrance_shockwave_damage = int(st.damage * max(st.unit_count, 1) * 0.8)
						st.entrance_shockwave_radius = 60.0
						labels.append("Onda de choque ao entrar")
					"investida":
						if !melee: continue
						st.charge_attack = true
						st.charge_distance_needed = 120.0
						labels.append("Investida em dobro")
					"executa":
						st.execute_threshold = 0.3
						st.execute_damage_mult = 2.0
						labels.append("Dobro em quem está quase morrendo")
					"furia_morte":
						st.low_hp_rage_threshold = 0.35
						st.low_hp_rage_damage_mult = 1.5
						labels.append("Mais forte quase morrendo")
					"cresce":
						st.ramping_damage = true
						st.ramping_damage_per_hit = 0.1
						st.ramping_damage_max_multiplier = 2.0
						labels.append("Cada golpe bate mais forte")
					"cura_matar":
						st.heals_on_kill = true
						st.heal_on_kill_amount = max(20, int(st.hp * 0.15))
						labels.append("Cura ao matar")
					"inabalavel":
						st.immune_to_knockback = true
						st.immune_to_pull = true
						labels.append("Ninguém empurra nem puxa")
					"clone":
						if st.unit_count > 1: continue
						st.can_clone = true
						st.clone_hp_percent = 0.4
						st.clone_count = 1
						labels.append("Deixa um clone ao morrer")
					"contra":
						if !melee: continue
						st.counter_attack_chance = 0.3
						labels.append("Revida quando apanha")
					"ouro_matar":
						st.converts_kills_to_gold = true
						st.gold_per_kill = 4
						labels.append("Ganha recurso ao matar")
					"rouba":
						if !melee: continue
						st.steals_resource_on_base_hit = true
						st.resource_steal_amount = 3
						labels.append("Rouba recurso batendo na torre")
					"mais_um":
						if !melee or st.is_aoe or st.spin_attack: continue
						st.aoe_hits_extra_one = true
						st.aoe_radius = 45.0
						labels.append("Golpe acerta dois")
					"avanco":
						st.bandit_dash = true
						st.dash_speed_multiplier = 3.0
						st.dash_duration = 0.4
						labels.append("Dá um bote no primeiro alvo")
					"levanta":
						if n < 3 or st.unit_count > 1: continue  # só nas Místicas
						st.can_resurrect = true
						st.resurrect_hp_percent = 0.35
						labels.append("Levanta uma vez depois de morrer")
	if !labels.is_empty():
		var keep = 1.0 - 0.07 * labels.size()
		st.hp = max(30, int(round(st.hp * keep / 10.0)) * 10)
		if st.damage > 0:
			st.damage = max(5, int(round(st.damage * keep / 5.0)) * 5)
	return labels


## gera uma carta completa (na memória) no formato do Catalogo.
## Devolve {"def": {...}, "stats": UnitData|null, "spell": SpellData|null}
## FREQUÊNCIA das raridades do gerador (cartas e torres):
## Normal 40% · Rara 30% · Épica 23% · Lendária 5% · Mística 2%
static func generate_def(seed_value: int, turma: String = "", kind: int = 0, role: int = -1, cost: int = 0) -> Dictionary:
	var trng = RandomNumberGenerator.new()
	trng.seed = hash("alvo%d" % seed_value)
	var target = _roll_extra(trng)
	# tenta até a raridade REAL (a que sai dos pontos de habilidade) bater com a sorteada
	var best: Dictionary = {}
	var best_gap = 99
	for attempt in 12:
		var gen = _generate_once(seed_value if attempt == 0 else hash("%d#%d" % [seed_value, attempt]), turma, kind, role, cost, target)
		var gap = absi(gen_rarity(gen) - target)
		if gap < best_gap:
			best_gap = gap
			best = gen
		if gap == 0:
			break
	return best


## raridade real de uma carta gerada (pelos pontos de habilidade)
static func gen_rarity(gen: Dictionary) -> int:
	var score = 0
	for pair in (Catalogo.spell_abilities(gen["spell"]) if gen["spell"] != null else Catalogo.unit_abilities(gen["stats"])):
		score += int(pair[1])
	return Catalogo.rarity_from_score(score, int(gen["def"].get("raridade", 0)))


static func _generate_once(seed_value: int, turma: String, kind: int, role: int, cost: int, target: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	if turma == "":
		turma = random_turma(rng)
	var is_spell = (kind == 2) or (kind == 0 and rng.randf() < 0.22)
	if cost <= 0:
		cost = rng.randi_range(3, 13) * 5
	if role < 0:
		role = rng.randi() % CardData.CardRole.size()
	if is_spell and !(role in [CardData.CardRole.PUNICAO, CardData.CardRole.CONTROLE, CardData.CardRole.SUPORTE]):
		role = [CardData.CardRole.PUNICAO, CardData.CardRole.CONTROLE, CardData.CardRole.SUPORTE][rng.randi() % 3]
	var stats: UnitData = null
	var spell: SpellData = null
	var text = {"pros": [], "cons": []}
	if is_spell:
		spell = SpellData.new()
		_fill_spell(spell, role, cost, rng)
		# variações 2.0: fúria e escudo
		if role == CardData.CardRole.SUPORTE and rng.randf() < 0.5:
			spell.heal_amount = 0
			spell.duration = 0.0
			if rng.randf() < 0.5:
				spell.rage_damage_mult = 1.3
				spell.rage_speed_mult = 1.25
				spell.rage_attack_speed_mult = 1.25
				spell.buff_duration = 4.0 + cost / 10.0
				text["pros"] = ["Deixa os aliados em fúria"]
			else:
				spell.shield_amount = int(cost * 11.0)
				spell.buff_duration = 8.0
				text["pros"] = ["Dá escudo aos aliados"]
			text["cons"] = ["Não causa dano"]
		elif spell.heal_amount > 0:
			text = {"pros": ["Cura em área"], "cons": ["Não causa dano"]}
		elif role == CardData.CardRole.CONTROLE:
			text = {"pros": ["Atrapalha os inimigos: %s" % CustomContent.EFFECT_NAMES[spell.status_effect]], "cons": ["Dano baixo"]}
		else:
			text = {"pros": ["Dano na hora, em área"], "cons": ["Fraco contra torre"]}
	else:
		stats = UnitData.new()
		_fill_unit(stats, role, cost, rng)
		text = describe_unit(stats, role)
	# o desenho usa a sua própria sequência de sorteio, pra arte/nome não mudarem
	# quando as regras de habilidade mudarem
	var art_rng = RandomNumberGenerator.new()
	art_rng.seed = hash("arte%d" % seed_value)
	# RECEITAS ESPECIAIS (3 em cada 10): cartas de "formato" diferente, tipo
	# atiradora de longe, barril de tropa, cemitério, tornado, voador que vira
	# filhotes... Elas já vêm prontas, então pulam o sorteio de habilidade.
	var special: Dictionary = {}
	if rng.randf() < 0.3 and Catalogo.card("abelha") != null:
		# só as receitas que cabem na raridade sorteada
		var allowed: Array = []
		if is_spell:
			allowed = ["barril", "tornado"] if target == Catalogo.EPICA else (["cemiterio"] if target == Catalogo.LENDARIA else [])
		else:
			if target <= Catalogo.RARA:
				allowed = ["longe", "corredor", "morteiro", "besta", "exercito", "torre_bomba"]
			elif target == Catalogo.EPICA:
				allowed = ["voador_filhotes", "mineiro", "balao", "bruxa", "tesla", "coletor", "inferno", "gigante_bomba"]
			elif target == Catalogo.LENDARIA:
				allowed = ["ariete"]
		if !allowed.is_empty():
			special = _special_spell(rng, turma, cost, allowed) if is_spell else _special_unit(rng, turma, cost, allowed)
	if !special.is_empty():
		stats = special.get("stats", null)
		spell = special.get("spell", null)
		cost = int(special["custo"])
		role = int(special["papel"])
		text = {"pros": special["pros"], "cons": special["cons"]}
	# RARIDADE 3.0: sorteia a raridade ALVO primeiro. Normal e Rara saem sem
	# habilidade nenhuma; Épica, Lendária e Mística ganham habilidades até
	# somar os pontos da faixa (ver Catalogo.rarity_from_score).
	if !special.is_empty():
		pass  # receita pronta: a raridade sai dos pontos dela
	elif stats != null:
		if target <= Catalogo.RARA:
			Catalogo.strip_abilities(stats)
			if stats.spawns_units and stats.unit_type != UnitData.UnitType.BUILDING:
				stats.spawns_units = false
				stats.hp = int(round(stats.hp * 1.5 / 10.0)) * 10
				stats.damage = int(round(stats.damage * 1.5 / 5.0)) * 5
			text = describe_unit(stats, role)
			if target == Catalogo.RARA:
				# Rara: sem habilidade, mas números um pouco melhores
				stats.hp = int(round(stats.hp * 1.07 / 10.0)) * 10
				if stats.damage > 0:
					stats.damage = int(round(stats.damage * 1.07 / 5.0)) * 5
		else:
			var want = [1, 3, 5][target - Catalogo.EPICA]
			var all_extras: Array = []
			var guard = 0
			while _unit_score(stats) < want and guard < 6:
				guard += 1
				all_extras += add_extras(stats, rng, 1 if target < Catalogo.MISTICA else 3)
			if !all_extras.is_empty():
				text["pros"] = (all_extras + text["pros"]).slice(0, 3)
	elif spell != null:
		if target <= Catalogo.RARA:
			# feitiço simples: só a função (dano, cura ou escudo), sem efeito
			if spell.damage <= 0 and spell.heal_amount <= 0 and spell.shield_amount <= 0:
				spell.damage = int(cost * 9.0)
				text = {"pros": ["Dano na hora, em área"], "cons": ["Fraco contra torre"]}
			spell.status_effect = UnitData.OnHitEffect.NONE
			spell.cleanses = false
			spell.rage_damage_mult = 1.0
			spell.rage_speed_mult = 1.0
			spell.rage_attack_speed_mult = 1.0
			spell.summon_count = 0
			if text["pros"].size() > 0 and str(text["pros"][0]).begins_with("Atrapalha"):
				text = {"pros": ["Dano na hora, em área"], "cons": ["Fraco contra torre"]}
		elif spell.status_effect == UnitData.OnHitEffect.NONE and spell.rage_damage_mult <= 1.0 and spell.summon_count <= 0:
			var options = [UnitData.OnHitEffect.SLOW, UnitData.OnHitEffect.KNOCKBACK]
			if target == Catalogo.LENDARIA:
				options = [UnitData.OnHitEffect.STUN, UnitData.OnHitEffect.PULL]
			elif target == Catalogo.MISTICA:
				options = [UnitData.OnHitEffect.FREEZE]
			spell.status_effect = options[rng.randi() % options.size()]
			spell.status_effect_strength = 0.6
			spell.status_effect_duration = 2.0 if target < Catalogo.MISTICA else 2.5
			spell.knockback_distance = 40.0
			if spell.damage > 0:
				spell.damage = int(spell.damage * 0.9)
			text["pros"] = (["E ainda: %s" % CustomContent.EFFECT_NAMES[spell.status_effect]] + text["pros"]).slice(0, 3)
	var design = design_card(art_rng, turma, role, stats, spell)
	if special.has("nome"):
		design["nome"] = special["nome"]
	var rarity = mini(target, Catalogo.RARA)
	# ARENA: carta gerada sai pra TODAS as arenas, não só a primeira. Quanto
	# mais rara, mais alta a arena em que ela aparece.
	var final_score = 0
	for pair in (Catalogo.spell_abilities(spell) if spell != null else Catalogo.unit_abilities(stats)):
		final_score += int(pair[1])
	var final_rarity = Catalogo.rarity_from_score(final_score, rarity)
	var arena_range = [[0, 3], [1, 4], [2, 5], [4, 6], [6, 6]][final_rarity]
	var arena_pick = art_rng.randi_range(arena_range[0], arena_range[1])
	var def = {"nome": design["nome"], "turma": turma, "custo": cost, "papel": role, "raridade": rarity, "arena": arena_pick,
		"perigo": clampi(int(cost / 10.0) + 1, 1, 10), "desc": "", "pros": text["pros"], "cons": text["cons"],
		"receita": design["receita"], "paleta": design["paleta"], "proj": design["proj"], "especial": str(special.get("id", ""))}
	return {"def": def, "stats": stats, "spell": spell}


# ---------------------------------------------------------------- receitas especiais
const TURMA_TOKEN = {"Curral": "bezerro", "Galinheiro": "pintinho", "Brejo": "sapinho", "Roçado": "aboborinha", "Peões": "moleque", "Coisa Estranha": "abelha"}
const SMALL_TOKENS = ["pintinho", "sapinho", "abelha"]
const SPECIAL_UNITS = ["longe", "voador_filhotes", "mineiro", "balao", "bruxa", "corredor", "morteiro", "besta", "exercito", "torre_bomba", "tesla", "coletor", "inferno", "gigante_bomba", "ariete"]
const SPECIAL_SPELLS = ["barril", "cemiterio", "tornado"]


static func _token_plural(token: String) -> String:
	var c = Catalogo.card(token)
	return (c.card_name + "s") if c != null else "Bichos"


static func _special_unit(rng: RandomNumberGenerator, turma: String, cost: int, allowed: Array = SPECIAL_UNITS) -> Dictionary:
	var k = power_per_cost() / DEFAULT_POWER_PER_COST * rng.randf_range(0.93, 1.07)
	var token = str(TURMA_TOKEN.get(turma, "moleque"))
	var st = UnitData.new()
	st.unit_count = 1
	st.attack_range = 15.0
	st.push_weight = 1.0
	st.unit_type = UnitData.UnitType.GROUND
	st.target_type = UnitData.TargetType.GROUND
	var hp_v := 100.0
	var dmg_v := 10.0
	var which = allowed[rng.randi() % allowed.size()]
	var c = cost
	var role = CardData.CardRole.VERSATIL
	var pros: Array = []
	var cons: Array = []
	match which:
		"longe":  # atira de MUITO longe, em área
			c = clampi(cost, 25, 40)
			st.is_ranged = true
			st.attack_range = 240.0
			st.is_aoe = true
			st.aoe_radius = 45.0
			st.target_type = UnitData.TargetType.ALL
			hp_v = 7.5 * c * k
			dmg_v = 3.6 * c * k
			st.attack_speed = 3.0
			st.move_speed = 40.0
			role = CardData.CardRole.CERCO
			pros = ["Alcance enorme: atira de fora do alcance das torres", "Dano em área"]
			cons = ["Vida de papel", "Atira devagar"]
		"voador_filhotes":  # tanque voador que só quer torre e vira filhotes
			c = clampi(cost, 55, 70)
			st.unit_type = UnitData.UnitType.AIR
			st.target_type = UnitData.TargetType.BUILDING
			hp_v = 42.0 * c * k
			dmg_v = 0.9 * c * k
			st.attack_speed = 1.5
			st.move_speed = 30.0
			st.unit_scale = 1.5
			st.push_weight = 3.0
			st.spawns_on_death = true
			st.death_spawn_scene = Catalogo.card("abelha").unit_scene
			st.death_spawn_count = 6
			role = CardData.CardRole.TANQUE
			pros = ["Tanque que voa direto pra torre", "Quando morre vira 6 abelhas"]
			cons = ["Quase não causa dano", "Caro"]
		"mineiro":  # nasce em qualquer lugar
			c = clampi(cost, 25, 35)
			st.can_spawn_anywhere = true
			hp_v = 21.0 * c * k
			dmg_v = 3.0 * c * k
			st.attack_speed = 1.2
			st.move_speed = 60.0
			role = CardData.CardRole.PUNICAO
			pros = ["Nasce em QUALQUER lugar do campo", "Bom pra pegar quem fica atrás"]
			cons = ["Dano baixo"]
		"balao":  # voador lento que só quer torre e explode
			c = clampi(cost, 40, 55)
			st.unit_type = UnitData.UnitType.AIR
			st.target_type = UnitData.TargetType.BUILDING
			hp_v = 15.0 * c * k
			dmg_v = 7.5 * c * k
			st.attack_speed = 3.0
			st.move_speed = 38.0
			st.unit_scale = 1.3
			st.explodes_on_death = true
			st.death_explosion_damage = int(4.0 * c * k)
			st.death_explosion_radius = 60.0
			role = CardData.CardRole.FINALIZADOR
			pros = ["Voa direto pra torre", "Pancada enorme", "Explode ao cair"]
			cons = ["Lento", "Ignora as tropas"]
		"bruxa":  # anda atirando e chamando tropa
			c = clampi(cost, 45, 55)
			st.is_ranged = true
			st.attack_range = 110.0
			st.is_aoe = true
			st.aoe_radius = 35.0
			st.target_type = UnitData.TargetType.ALL
			hp_v = 13.0 * c * k
			dmg_v = 2.2 * c * k
			st.attack_speed = 1.4
			st.move_speed = 40.0
			st.spawns_units = true
			st.spawn_unit_scene = Catalogo.card(token).unit_scene
			st.spawn_interval = 7.0
			st.spawn_count = 2 if token in SMALL_TOKENS else 1
			role = CardData.CardRole.INVOCADOR
			pros = ["Chama %s enquanto anda" % _token_plural(token).to_lower(), "Tiro em área"]
			cons = ["Frágil de perto"]
		"morteiro":  # construção que joga bomba de MUITO longe, só no chão
			c = clampi(cost, 35, 45)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 30.0
			st.move_speed = 0.0
			st.is_ranged = true
			st.attack_range = 260.0
			st.is_aoe = true
			st.aoe_radius = 50.0
			hp_v = 15.0 * c * k
			dmg_v = 5.5 * c * k
			st.attack_speed = 4.5
			st.unit_scale = 1.4
			role = CardData.CardRole.CONSTRUCAO
			pros = ["Bombardeia de muito longe", "Dano em área"]
			cons = ["Atira bem devagar", "Não acerta voador"]
		"besta":  # construção de tiro rápido e alcance enorme
			c = clampi(cost, 50, 60)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 35.0
			st.move_speed = 0.0
			st.is_ranged = true
			st.attack_range = 270.0
			hp_v = 18.0 * c * k
			dmg_v = 0.5 * c * k
			st.attack_speed = 0.3
			st.unit_scale = 1.4
			role = CardData.CardRole.CONSTRUCAO
			pros = ["Alcance enorme", "Metralha sem parar"]
			cons = ["Cara", "Não acerta voador"]
		"exercito":  # um monte de bichinho fraco
			c = clampi(cost, 25, 35)
			st.unit_count = 10 if c >= 30 else 8
			hp_v = 1.6 * c * k
			dmg_v = 0.9 * c * k
			st.attack_speed = 1.0
			st.move_speed = 70.0
			st.unit_scale = 0.6
			st.push_weight = 0.4
			role = CardData.CardRole.ENXAME
			pros = ["Vêm em %d" % st.unit_count, "Derretem qualquer tanque sozinho"]
			cons = ["Qualquer dano em área acaba com todos"]
		"torre_bomba":  # construção de defesa com dano em área
			c = clampi(cost, 35, 45)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 35.0
			st.move_speed = 0.0
			st.is_ranged = true
			st.attack_range = 150.0
			st.is_aoe = true
			st.aoe_radius = 50.0
			hp_v = 26.0 * c * k
			dmg_v = 4.2 * c * k
			st.attack_speed = 1.7
			st.unit_scale = 1.4
			role = CardData.CardRole.CONSTRUCAO
			pros = ["Defesa com dano em área", "Aguenta bastante"]
			cons = ["Não acerta voador"]
		"tesla":  # construção que dá choque em tudo, chão e ar
			c = clampi(cost, 35, 45)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 35.0
			st.move_speed = 0.0
			st.is_ranged = true
			st.attack_range = 150.0
			st.target_type = UnitData.TargetType.ALL
			st.on_hit_effect = UnitData.OnHitEffect.STUN
			st.on_hit_effect_duration = 0.3
			hp_v = 20.0 * c * k
			dmg_v = 3.2 * c * k
			st.attack_speed = 1.1
			st.unit_scale = 1.3
			role = CardData.CardRole.CONSTRUCAO
			pros = ["Acerta chão e ar", "O choque trava o alvo um instante"]
			cons = ["Some depois de um tempo"]
		"coletor":  # construção que só gera recurso
			c = clampi(cost, 50, 60)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 45.0
			st.move_speed = 0.0
			hp_v = 15.0 * c * k
			dmg_v = 0.0
			st.attack_speed = 0.0
			st.attack_range = 0.0
			st.generates_resource = true
			st.resource_per_tick = 1
			st.resource_tick_interval = 0.6
			st.unit_scale = 1.4
			role = CardData.CardRole.CONSTRUCAO
			pros = ["Devolve mais recurso do que custou", "Ótimo pra baralho caro"]
			cons = ["Não ataca nem defende", "Demora a se pagar"]
		"inferno":  # construção que esquenta: dano sobe no mesmo alvo
			c = clampi(cost, 45, 55)
			st.unit_type = UnitData.UnitType.BUILDING
			st.duration = 35.0
			st.move_speed = 0.0
			st.is_ranged = true
			st.attack_range = 160.0
			st.target_type = UnitData.TargetType.ALL
			st.same_target_ramping_damage = true
			st.same_target_ramping_damage_per_hit = 0.25
			st.same_target_ramping_damage_max_multiplier = 8.0
			hp_v = 20.0 * c * k
			dmg_v = 0.7 * c * k
			st.attack_speed = 0.4
			st.unit_scale = 1.4
			role = CardData.CardRole.CONSTRUCAO
			pros = ["O dano vai subindo no mesmo alvo", "Derrete tanque"]
			cons = ["Fraca contra bando"]
		"gigante_bomba":  # tanque que explode ao morrer
			c = clampi(cost, 55, 65)
			hp_v = 36.0 * c * k
			dmg_v = 2.6 * c * k
			st.attack_speed = 1.5
			st.move_speed = 32.0
			st.unit_scale = 1.6
			st.push_weight = 3.5
			st.explodes_on_death = true
			st.death_explosion_damage = int(13.0 * c * k)
			st.death_explosion_radius = 85.0
			role = CardData.CardRole.TANQUE
			pros = ["Tanque", "Quando morre solta uma explosão enorme"]
			cons = ["Lento", "Caro"]
		"ariete":  # corre pra torre, bate forte na chegada e solta tropa ao quebrar
			c = clampi(cost, 40, 50)
			st.target_type = UnitData.TargetType.BUILDING
			hp_v = 18.0 * c * k
			dmg_v = 4.0 * c * k
			st.attack_speed = 1.5
			st.move_speed = 65.0
			st.charge_attack = true
			st.charge_distance_needed = 140.0
			st.charge_damage_multiplier = 2.0
			st.spawns_on_death = true
			st.death_spawn_scene = Catalogo.card(token).unit_scene
			st.death_spawn_count = 3 if token in SMALL_TOKENS else 2
			role = CardData.CardRole.FINALIZADOR
			pros = ["Investida em dobro na torre", "Quando quebra solta %s" % _token_plural(token).to_lower()]
			cons = ["Ignora as tropas"]
		_:  # corredor: rápido e só quer torre
			c = clampi(cost, 35, 45)
			st.target_type = UnitData.TargetType.BUILDING
			hp_v = 17.0 * c * k
			dmg_v = 5.0 * c * k
			st.attack_speed = 1.5
			st.move_speed = 85.0
			role = CardData.CardRole.FINALIZADOR
			pros = ["Muito rápido", "Corre direto pra torre"]
			cons = ["Ignora as tropas"]
	st.hp = max(30, int(round(hp_v / 10.0)) * 10)
	st.damage = max(5, int(round(dmg_v / 5.0)) * 5) if dmg_v > 0.0 else 0
	st.detection_range = max(110.0, st.attack_range + 20.0)
	st.role = role
	return {"id": which, "stats": st, "custo": c, "papel": role, "pros": pros, "cons": cons}


static func _special_spell(rng: RandomNumberGenerator, turma: String, cost: int, allowed: Array = SPECIAL_SPELLS) -> Dictionary:
	var token = str(TURMA_TOKEN.get(turma, "moleque"))
	var small = token in SMALL_TOKENS
	var sp = SpellData.new()
	var which = allowed[rng.randi() % allowed.size()]
	var c = cost
	var role = CardData.CardRole.CONTROLE
	var pros: Array = []
	var cons: Array = []
	var nm = ""
	match which:
		"barril":  # joga tropa em qualquer lugar
			c = clampi(cost, 25, 35)
			sp.radius = 45.0
			sp.damage = 0
			sp.affects_enemies = false
			sp.summon_scene = Catalogo.card(token).unit_scene
			sp.summon_count = (5 if small else 3) if c >= 30 else (4 if small else 2)
			role = CardData.CardRole.INVOCADOR
			nm = "Barril de %s" % _token_plural(token)
			pros = ["Joga %d tropas em QUALQUER lugar" % sp.summon_count, "Ótimo em cima da torre"]
			cons = ["Morre fácil pra dano em área"]
		"cemiterio":  # fica brotando tropa na área
			c = clampi(cost, 45, 55)
			sp.radius = 85.0
			sp.damage = 0
			sp.affects_enemies = false
			sp.duration = 8.0
			sp.tick_interval = 1.0
			sp.summon_scene = Catalogo.card(token).unit_scene
			sp.summon_count = 1
			sp.summon_interval = 1.0 if small else 1.7
			role = CardData.CardRole.INVOCADOR
			nm = ["Terra Mexida", "Cova Rasa", "Ninho Sem Fim", "Brotação"][rng.randi() % 4]
			pros = ["Fica brotando %s por 8 segundos" % _token_plural(token).to_lower(), "Dá pra jogar em cima da torre"]
			cons = ["Caro", "Dano em área limpa tudo"]
		_:  # tornado: puxa todo mundo pro meio
			c = clampi(cost, 25, 35)
			sp.radius = 105.0
			sp.duration = 3.5
			sp.tick_interval = 0.25
			sp.damage = 8
			sp.status_effect = UnitData.OnHitEffect.PULL
			sp.knockback_distance = 22.0
			sp.base_damage_multiplier = 0.1
			nm = ["Pé de Vento", "Rodamoinho", "Ventania"][rng.randi() % 3]
			pros = ["Puxa todo mundo pro meio", "Junta os inimigos pra um dano em área"]
			cons = ["Quase não causa dano"]
	return {"id": which, "spell": sp, "custo": c, "papel": role, "pros": pros, "cons": cons, "nome": nm}



# ================================================================ gerador de TORRES (Safra)
const TOWER_NAMES_A = {"HP": ["Paiol", "Muralha", "Cercado", "Barracão"], "CANNON": ["Guarita", "Torre", "Mirante", "Canhoneira"],
	"PRODUCTION": ["Engenho", "Roda d'Água", "Alambique", "Casa de Farinha"], "CAPACITY": ["Silo", "Tulha", "Depósito", "Celeiro"],
	"HEAL": ["Bica", "Cacimba", "Fonte", "Enfermaria"], "AURA": ["Sineira", "Fogueira", "Cata-vento", "Espantadeira"]}
const TOWER_NAMES_B = ["do Compadre", "da Vovó", "Torta", "de Pau a Pique", "da Encruzilhada", "do Seu Zé", "Mal-Assombrada", "de Lata", "Remendada", "do Fim do Mundo"]
const TOWER_PIECES = {"HP": ["forte", "celeiro"], "CANNON": ["celeiro", "castelo_feno", "antena"], "PRODUCTION": ["moinho", "cocho"],
	"CAPACITY": ["armazem"], "HEAL": ["caixa_dagua"], "AURA": ["capela", "colmeia"]}
const TOWER_COLORS = ["#b8402c", "#3c6cb8", "#58a040", "#e8c040", "#8a5a34", "#c880c0", "#50b0a8", "#e07a28", "#6a7480", "#f2ede0"]


## gera uma torre no formato do Catalogo (def pra Catalogo.build_base), com a
## raridade sorteada na mesma frequência das cartas.
static func generate_base_def(seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("torre%d" % seed_value)
	var target = _roll_extra(rng)
	var kind = "HP"
	var b: Dictionary = {}
	var pros: Array = []
	var cons: Array = []
	var category = "DEFENSIVO"
	match target:
		Catalogo.COMUM:
			if rng.randf() < 0.5:
				kind = "HP"
				b = {"base_hp": rng.randi_range(160, 180) * 10}
				pros = ["Vida muito alta"]
				cons = ["Não ataca", "Nenhum bônus"]
			else:
				kind = "CANNON"
				b = {"base_hp": rng.randi_range(120, 135) * 10, "attack_damage": rng.randi_range(6, 8) * 5, "attack_range": float(rng.randi_range(24, 27) * 5), "attack_speed": 1.0}
				pros = ["Atira sozinha", "Boa vida"]
				cons = ["Tiro fraco"]
		Catalogo.RARA:
			kind = "CANNON"
			category = "OFENSIVO"
			if rng.randf() < 0.5:
				b = {"base_hp": rng.randi_range(100, 110) * 10, "attack_damage": rng.randi_range(8, 10) * 5, "attack_range": float(rng.randi_range(34, 37) * 5), "attack_speed": 2.4, "is_aoe": true, "aoe_radius": 55.0, "projectile_speed": 250.0}
				pros = ["Tiro em área", "Alcance longo"]
				cons = ["Atira devagar", "Menos vida"]
			else:
				b = {"base_hp": rng.randi_range(90, 100) * 10, "attack_damage": rng.randi_range(15, 18) * 5, "attack_range": float(rng.randi_range(38, 42) * 5), "attack_speed": 2.0, "projectile_speed": 420.0}
				pros = ["Tiro forte", "Alcance enorme"]
				cons = ["Pouca vida", "Atira devagar"]
		Catalogo.EPICA:
			var pick = rng.randi() % 3
			if pick == 0:
				kind = "PRODUCTION"
				category = "ECONOMICO"
				var boost = rng.randi_range(10, 14) / 100.0
				b = {"base_hp": rng.randi_range(110, 120) * 10, "production_speed_boost": boost}
				pros = ["Recurso %d%% mais rápido" % int(round(boost * 100))]
				cons = ["Não ataca", "Menos vida"]
			elif pick == 1:
				kind = "CAPACITY"
				category = "ECONOMICO"
				var cap = rng.randi_range(4, 6) * 5
				b = {"base_hp": rng.randi_range(115, 125) * 10, "capacity_bonus": cap}
				pros = ["Guarda %d a mais de recurso" % cap]
				cons = ["Não ataca"]
			else:
				kind = "HEAL"
				b = {"base_hp": rng.randi_range(115, 125) * 10, "heal_amount": rng.randi_range(12, 16), "heal_radius": 110.0, "heal_interval": 1.0}
				pros = ["Cura aliados próximos"]
				cons = ["Não ataca"]
		Catalogo.LENDARIA:
			if rng.randf() < 0.35:
				kind = "PRODUCTION"
				category = "ECONOMICO"
				var boost2 = rng.randi_range(18, 22) / 100.0
				b = {"base_hp": rng.randi_range(90, 100) * 10, "production_speed_boost": boost2}
				pros = ["Recurso %d%% mais rápido" % int(round(boost2 * 100))]
				cons = ["Pouca vida", "Não ataca"]
			else:
				kind = "AURA"
				var eff = ["SLOW", "POISON", "WEAKNESS"][rng.randi() % 3]
				b = {"base_hp": rng.randi_range(115, 125) * 10, "aura_radius": float(rng.randi_range(23, 27) * 5), "aura_tick_interval": 1.2, "effect": eff,
					"effect_strength": 14.0 if eff == "POISON" else 0.6, "effect_duration": 2.0, "effect_tick_interval": 1.0}
				category = "OFENSIVO" if eff == "POISON" else "DEFENSIVO"
				pros = [{"SLOW": "Deixa lentos os inimigos por perto", "POISON": "Envenena os inimigos por perto", "WEAKNESS": "Enfraquece os inimigos por perto"}[eff]]
				cons = ["Não causa dano direto" if eff != "POISON" else "Alcance curto"]
		_:
			kind = "AURA"
			b = {"base_hp": rng.randi_range(105, 115) * 10, "aura_radius": float(rng.randi_range(21, 24) * 5), "aura_tick_interval": 2.5, "effect": "FREEZE",
				"effect_strength": 0.5, "effect_duration": 1.0}
			pros = ["Congela quem chega perto", "A aura mais forte do jogo"]
			cons = ["Alcance curto", "Não causa dano"]
	var pieces: Array = TOWER_PIECES[kind]
	var name_a: Array = TOWER_NAMES_A[kind]
	var arena_range = [[0, 3], [1, 4], [2, 5], [4, 6], [6, 6]][target]
	return {"nome": "%s %s" % [name_a[rng.randi() % name_a.size()], TOWER_NAMES_B[rng.randi() % TOWER_NAMES_B.size()]],
		"turma": random_turma(rng), "arena": rng.randi_range(arena_range[0], arena_range[1]), "tipo": kind, "categoria": category,
		"desc": "", "pros": pros, "cons": cons, "receita": {"torre": pieces[rng.randi() % pieces.size()]},
		"paleta": {"A": TOWER_COLORS[rng.randi() % TOWER_COLORS.size()], "K": TOWER_COLORS[rng.randi() % TOWER_COLORS.size()], "S": TOWER_COLORS[rng.randi() % TOWER_COLORS.size()], "W": "#6a4428", "M": "#a0a8b4", "P": TOWER_COLORS[rng.randi() % TOWER_COLORS.size()]},
		"proj": ["milho", "pedra", "raio"][rng.randi() % 3], "b": b}
