extends RefCounted
class_name SpriteForge
## Monta a arte 48x48 de cartas, unidades, torres, feitiços e projéteis a
## partir do atlas de PEÇAS (Resources/pecas/pecas.png) + uma PALETA.
##
## Uma "receita" é um Dictionary:
##   personagem: {"pernas":"bota","corpo":"macacao","bracos":"humanos",
##                "cabeca":"humano","chapeu":"palha","arma":"forcado","costas":""}
##   peça inteira: {"objeto":"silo"}  |  {"torre":"celeiro"}  |  {"icone":"raio"}
## Uma paleta é {"P":"#rrggbb","S":...,"A":...,"K":...,"M":...,"W":...}
##   P principal · S secundária · A acento · K pele/bico/palha · M metal · W madeira
##
## As peças são desenhadas em cores-modelo puras e trocadas pela paleta aqui
## (mesma regra do ci/tools/arte/kit.py). Cartas oficiais, o gerador e o
## Criador usam todos esta mesma função -- então tudo sai no mesmo estilo.

const ATLAS_PATH = "res://Resources/pecas/pecas.png"
const CELL = 48
const SOLO = ["objeto", "torre", "icone"]
const DEFAULT_PALETTE = {"P": "#d8c8a8", "S": "#7a5a3a", "A": "#c8483c", "K": "#e8b088", "M": "#a0a8b4", "W": "#7a5030"}
const SLOT_BY_BITS = {4: "P", 2: "S", 1: "A", 6: "K", 5: "M", 3: "W"}  # bits r g b

static var _atlas: PackedByteArray
static var _atlas_w := 0
static var _cache: Dictionary = {}
static var _ramp_cache: Dictionary = {}


static func _ensure_atlas() -> bool:
	if _atlas_w > 0:
		return true
	var tex = load(ATLAS_PATH)
	if tex == null:
		push_error("SpriteForge: atlas de peças não encontrado")
		return false
	var img: Image = tex.get_image()
	if img == null:
		return false
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_atlas = img.get_data()
	_atlas_w = img.get_width()
	return true


static func has_piece(cat: String, piece_name: String) -> bool:
	return PecasIndex.PECAS.has(cat) and PecasIndex.PECAS[cat].has(piece_name)


static func pieces(cat: String) -> Array:
	return PecasIndex.PECAS.get(cat, {}).keys()


static func _key(recipe: Dictionary, palette: Dictionary, extra: String = "") -> String:
	var parts: Array = []
	var cats = recipe.keys()
	cats.sort()
	for c in cats:
		parts.append("%s=%s" % [c, recipe[c]])
	var slots = palette.keys()
	slots.sort()
	for s in slots:
		parts.append("%s:%s" % [s, palette[s]])
	return "|".join(parts) + extra


## textura 48x48 pronta (com cache)
static func make(recipe: Dictionary, palette: Dictionary = {}) -> ImageTexture:
	var key = _key(recipe, palette)
	if _cache.has(key):
		return _cache[key]
	var tex = ImageTexture.create_from_image(make_image(recipe, palette))
	_cache[key] = tex
	return tex


## projétil 16x16 (apontando pra direita)
static func projectile(piece_name: String, palette: Dictionary = {}) -> ImageTexture:
	var key = "proj=" + piece_name + _key({}, palette)
	if _cache.has(key):
		return _cache[key]
	var img = make_image({"proj": piece_name}, palette).get_region(Rect2i(0, 0, 16, 16))
	var tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func make_image(recipe: Dictionary, palette: Dictionary = {}) -> Image:
	var out := PackedByteArray()
	out.resize(CELL * CELL * 4)
	if !_ensure_atlas():
		return Image.create_from_data(CELL, CELL, false, Image.FORMAT_RGBA8, out)
	var ramps = _ramps(palette)
	var order: Array = []
	for cat in SOLO + ["proj"]:
		if recipe.get(cat, "") != "":
			order.append(cat)
	if order.is_empty():
		order = PecasIndex.ORDEM
	for cat in order:
		var piece = str(recipe.get(cat, ""))
		if piece == "" or !has_piece(cat, piece):
			continue
		_stamp(out, int(PecasIndex.PECAS[cat][piece]), ramps)
	return Image.create_from_data(CELL, CELL, false, Image.FORMAT_RGBA8, out)


static func _stamp(out: PackedByteArray, cell: int, ramps: Dictionary):
	var ox = (cell % PecasIndex.COLS) * CELL
	var oy = (cell / PecasIndex.COLS) * CELL
	for y in CELL:
		var src = ((oy + y) * _atlas_w + ox) * 4
		var dst = y * CELL * 4
		for x in CELL:
			var a = _atlas[src + 3]
			if a != 0:
				var r = _atlas[src]
				var g = _atlas[src + 1]
				var b = _atlas[src + 2]
				var mx = maxi(r, maxi(g, b))
				if (mx == 255 or mx == 192 or mx == 128) and (r == 0 or r == mx) and (g == 0 or g == mx) and (b == 0 or b == mx):
					var bits = (4 if r > 0 else 0) | (2 if g > 0 else 0) | (1 if b > 0 else 0)
					if SLOT_BY_BITS.has(bits):
						var tone = 0 if mx == 255 else (1 if mx == 192 else 2)
						var c: Color = ramps[SLOT_BY_BITS[bits]][tone]
						r = c.r8
						g = c.g8
						b = c.b8
				out[dst] = r
				out[dst + 1] = g
				out[dst + 2] = b
				out[dst + 3] = a
			src += 4
			dst += 4


static func _ramps(palette: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot in DEFAULT_PALETTE:
		var hex = str(palette.get(slot, DEFAULT_PALETTE[slot]))
		if !_ramp_cache.has(hex):
			_ramp_cache[hex] = ramp_from(Color.html(hex) if Color.html_is_valid(hex) else Color.html(DEFAULT_PALETTE[slot]))
		out[slot] = _ramp_cache[hex]
	return out


## 3 tons a partir da cor média: claro puxa pro amarelo, escuro pro roxo
static func ramp_from(base: Color) -> Array:
	var hls = _rgb_to_hls(base)
	return [
		_hls_to_rgb(fposmod(hls.x - 0.03, 1.0), clampf(hls.y + 0.13, 0, 1), clampf(hls.z + 0.05, 0, 1)),
		base,
		_hls_to_rgb(fposmod(hls.x + 0.04, 1.0), clampf(hls.y - 0.17, 0, 1), clampf(hls.z - 0.05, 0, 1)),
	]


static func _rgb_to_hls(c: Color) -> Vector3:
	var mx = maxf(c.r, maxf(c.g, c.b))
	var mn = minf(c.r, minf(c.g, c.b))
	var l = (mx + mn) / 2.0
	if is_equal_approx(mx, mn):
		return Vector3(0, l, 0)
	var d = mx - mn
	var s = d / (mx + mn) if l <= 0.5 else d / (2.0 - mx - mn)
	var h: float
	if mx == c.r:
		h = (c.g - c.b) / d
	elif mx == c.g:
		h = 2.0 + (c.b - c.r) / d
	else:
		h = 4.0 + (c.r - c.g) / d
	return Vector3(fposmod(h / 6.0, 1.0), l, s)


static func _hls_to_rgb(h: float, l: float, s: float) -> Color:
	if s == 0.0:
		return Color(l, l, l)
	var m2 = l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var m1 = 2.0 * l - m2
	return Color(_hue(m1, m2, h + 1.0 / 3.0), _hue(m1, m2, h), _hue(m1, m2, h - 1.0 / 3.0))


static func _hue(m1: float, m2: float, h: float) -> float:
	h = fposmod(h, 1.0)
	if h < 1.0 / 6.0:
		return m1 + (m2 - m1) * h * 6.0
	if h < 0.5:
		return m2
	if h < 2.0 / 3.0:
		return m1 + (m2 - m1) * (2.0 / 3.0 - h) * 6.0
	return m1


## cor média da paleta (pra molduras, efeitos, textos)
static func main_color(palette: Dictionary) -> Color:
	var hex = str(palette.get("P", DEFAULT_PALETTE["P"]))
	return Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE
