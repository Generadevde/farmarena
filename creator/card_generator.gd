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

const DEFAULT_POWER_PER_COST = 95.0


# "força" crua igual à estimativa do BotSimulator (hp*0.3 + dps*3) * quantidade
static func _raw_power(stats: UnitData) -> float:
	var dps = stats.damage / max(stats.attack_speed, 0.1)
	return (stats.hp * 0.3 + dps * 3.0) * max(stats.unit_count, 1)


static func power_per_cost() -> float:
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
	var rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var is_spell = (kind == 2) or (kind == 0 and rng.randf() < 0.18)
	if cost <= 0:
		cost = rng.randi_range(2, 14) * 5  # 10 a 70, igual às cartas do jogo
	if role < 0:
		role = rng.randi() % CardData.CardRole.size()
		if is_spell and !(role in [CardData.CardRole.PUNICAO, CardData.CardRole.CONTROLE, CardData.CardRole.SUPORTE, CardData.CardRole.FINALIZADOR]):
			role = [CardData.CardRole.PUNICAO, CardData.CardRole.CONTROLE, CardData.CardRole.SUPORTE][rng.randi() % 3]

	var pack = CustomContent.make_blank_card(is_spell)
	var card: CardData = pack["card"]
	card.card_name = random_name(rng, is_spell)
	card.cost = cost
	card.role = role as CardData.CardRole
	pack["image"] = generate_sprite(CustomContent.CARD_ART_SIZE.x, CustomContent.CARD_ART_SIZE.y, rng.randi())

	if is_spell:
		_fill_spell(pack["spell"], role, cost, rng)
		card.danger_level = clamp(int(cost / 10.0) + 1, 1, 10)
		card.description = "Feitiço gerado aleatoriamente."
	else:
		_fill_unit(pack["stats"], role, cost, rng)
		card.danger_level = clamp(int(cost / 10.0 * 1.2 + rng.randi_range(-1, 1)), 1, 10)
		card.description = "Carta gerada aleatoriamente. Categoria: %s." % CardData.role_name(role)
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
	st.attack_range = 25.0
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
			st.attack_range = 110.0 if st.is_ranged else 25.0
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

# gerador de "bichinho" em pixel art: máscara simétrica (meia largura,
# espelhada), corpo com degradê, contorno escuro e olhinhos. Funciona pra
# 32x32 (carta), 32x64 (base) e 36x64 (fundo de arena vira um padrão)
static func generate_sprite(w: int, h: int, seed_value: int) -> Image:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	if h > w * 1.5 and w >= 34:
		return generate_arena_background(w, h, seed_value)

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
