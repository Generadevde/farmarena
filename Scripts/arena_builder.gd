extends RefCounted
class_name ArenaBuilder

# ARENA 2.0 -- monta o campo inteiro POR CÓDIGO, simétrico entre jogador
# (embaixo) e bot (em cima), com DUAS torres por lado, lado a lado.
# As medidas batem com o cenário desenhado em ci/tools/arte/arena.py
# (cenário 144x240 px, ampliado 4x).

const SCALE = 4.0
const CENTER = Vector2(0, -240)          # meio do mapa (no rio)
const HALF = Vector2(288, 480)           # meio-tamanho do mapa (576 x 960)
const MARGIN = 10.0                      # folga da cerca
const RIVER_HALF = 20.0
const BRIDGE_X = 150.0
const BRIDGE_HALF = 24.0                 # meia-largura útil da ponte lateral (desenho tem 28)
const CENTER_BRIDGE_HALF = 12.0          # ponte do MEIO, mais estreita (desenho tem 16) -- gargalo
const TOWER_DX = 135.0
const TOWER_DY = 380.0
const TOWER_HP_FRACTION = 0.65           # cada torre tem 65% da vida da base (2 torres = 130%)
const CAMERA_ZOOM = 1.2
const CAMERA_OFFSET_Y = 95.0             # câmera um pouco abaixo do meio (espaço pras cartas embaixo)
const BG_PATH = "res://Resources/arena/arena_bg.png"


static func tower_positions(team) -> Array:
	var y = CENTER.y + (TOWER_DY if team == GameManager.Team.PLAYER else -TOWER_DY)
	return [Vector2(CENTER.x - TOWER_DX, y), Vector2(CENTER.x + TOWER_DX, y)]


# área onde cada lado pode soltar tropa (a sua metade inteira, sem o rio)
static func spawn_rect(team) -> Rect2:
	var w = (HALF.x - MARGIN) * 2.0
	var h = HALF.y - RIVER_HALF - MARGIN - 6.0
	if team == GameManager.Team.PLAYER:
		return Rect2(CENTER.x - w / 2.0, CENTER.y + RIVER_HALF + 6.0, w, h)
	return Rect2(CENTER.x - w / 2.0, CENTER.y - HALF.y + MARGIN, w, h)


static func build(battle: Node):
	_clear_old(battle)
	_background(battle)
	_navigation(battle)
	_towers(battle)
	_spawn_areas(battle)
	_camera(battle)


static func _clear_old(battle: Node):
	for child in battle.get_children():
		if child is NavigationRegion2D or child.name == "arena":
			battle.remove_child(child)
			child.queue_free()


static func _background(battle: Node):
	# cada arena tem o próprio cenário (mesmo traçado, tema diferente);
	# torneio sorteia um cenário qualquer
	var arena_i = MatchSetup.arena_override if MatchSetup.arena_override > 0 else ArenaManager.get_player_arena()
	var tex: Texture2D = ArenaManager.get_background(arena_i) if MatchSetup.arena_override <= 0 else null
	var themed = "res://Resources/arena/arena_bg_%d.png" % clampi(arena_i, 1, 7)
	if tex == null and ResourceLoader.exists(themed):
		tex = load(themed)
	if tex == null and ResourceLoader.exists(BG_PATH):
		tex = load(BG_PATH)
	if tex == null:
		return
	var bg = Sprite2D.new()
	bg.name = "ArenaBackground"
	bg.texture = tex
	bg.centered = true
	bg.position = CENTER
	bg.scale = Vector2(HALF.x * 2.0 / tex.get_width(), HALF.y * 2.0 / tex.get_height())
	bg.z_index = -100
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	battle.add_child(bg)
	battle.move_child(bg, 0)


# caminhos: chão (camada 1) = as duas metades + as 2 pontes; água (camada
# 2) = o rio, só pra aérea e quem atravessa água. As bordas que se
# encostam usam OS MESMOS pontos, então os pedaços se ligam sozinhos
static func _navigation(battle: Node):
	var x0 = CENTER.x - HALF.x + MARGIN
	var x1 = CENTER.x + HALF.x - MARGIN
	var y_top = CENTER.y - HALF.y + MARGIN
	var y_bot = CENTER.y + HALF.y - MARGIN
	var rt = CENTER.y - RIVER_HALF
	var rb = CENTER.y + RIVER_HALF
	var lb0 = CENTER.x - BRIDGE_X - BRIDGE_HALF
	var lb1 = CENTER.x - BRIDGE_X + BRIDGE_HALF
	var rb0 = CENTER.x + BRIDGE_X - BRIDGE_HALF
	var rb1 = CENTER.x + BRIDGE_X + BRIDGE_HALF
	var cb0 = CENTER.x - CENTER_BRIDGE_HALF
	var cb1 = CENTER.x + CENTER_BRIDGE_HALF

	# 3 passagens: esquerda, MEIO (estreita) e direita
	var ground = _poly_builder()
	_add_poly(ground, [Vector2(x0, rb), Vector2(lb0, rb), Vector2(lb1, rb), Vector2(cb0, rb), Vector2(cb1, rb), Vector2(rb0, rb), Vector2(rb1, rb), Vector2(x1, rb), Vector2(x1, y_bot), Vector2(x0, y_bot)])
	_add_poly(ground, [Vector2(x0, y_top), Vector2(x1, y_top), Vector2(x1, rt), Vector2(rb1, rt), Vector2(rb0, rt), Vector2(cb1, rt), Vector2(cb0, rt), Vector2(lb1, rt), Vector2(lb0, rt), Vector2(x0, rt)])
	_add_poly(ground, [Vector2(lb0, rt), Vector2(lb1, rt), Vector2(lb1, rb), Vector2(lb0, rb)])
	_add_poly(ground, [Vector2(cb0, rt), Vector2(cb1, rt), Vector2(cb1, rb), Vector2(cb0, rb)])
	_add_poly(ground, [Vector2(rb0, rt), Vector2(rb1, rt), Vector2(rb1, rb), Vector2(rb0, rb)])
	_make_region(battle, "NavChao", ground, 0b01)

	var water = _poly_builder()
	_add_poly(water, [Vector2(x0, rt), Vector2(lb0, rt), Vector2(lb0, rb), Vector2(x0, rb)])
	_add_poly(water, [Vector2(lb1, rt), Vector2(cb0, rt), Vector2(cb0, rb), Vector2(lb1, rb)])
	_add_poly(water, [Vector2(cb1, rt), Vector2(rb0, rt), Vector2(rb0, rb), Vector2(cb1, rb)])
	_add_poly(water, [Vector2(rb1, rt), Vector2(x1, rt), Vector2(x1, rb), Vector2(rb1, rb)])
	_make_region(battle, "NavAgua", water, 0b10)


static func _poly_builder() -> Dictionary:
	return {"verts": PackedVector2Array(), "index": {}, "polys": []}


static func _add_poly(b: Dictionary, pts: Array):
	var idx = PackedInt32Array()
	for p in pts:
		var key = "%d,%d" % [int(round(p.x)), int(round(p.y))]
		if !b["index"].has(key):
			b["index"][key] = b["verts"].size()
			b["verts"].append(p)
		idx.append(b["index"][key])
	b["polys"].append(idx)


static func _make_region(battle: Node, region_name: String, b: Dictionary, layers: int):
	var np = NavigationPolygon.new()
	np.vertices = b["verts"]
	for idx in b["polys"]:
		np.add_polygon(idx)
	var region = NavigationRegion2D.new()
	region.name = region_name
	region.navigation_layers = layers
	region.navigation_polygon = np
	battle.add_child(region)


# usa as bases da cena como torre 1 e cria uma cópia de cada como torre 2
static func _towers(battle: Node):
	for team in [GameManager.Team.PLAYER, GameManager.Team.ENEMY]:
		var group = "player_base" if team == GameManager.Team.PLAYER else "enemy_base"
		var first = battle.get_tree().get_first_node_in_group(group)
		if first == null:
			continue
		var pos = tower_positions(team)
		first.position = battle.to_local(pos[0])
		first.name = ("Torre_Jogador_" if team == GameManager.Team.PLAYER else "Torre_Bot_") + "1"
		var second = first.duplicate()
		second.name = ("Torre_Jogador_" if team == GameManager.Team.PLAYER else "Torre_Bot_") + "2"
		battle.add_child(second)
		second.position = battle.to_local(pos[1])


static func _spawn_areas(battle: Node):
	for team in [GameManager.Team.PLAYER, GameManager.Team.ENEMY]:
		var area_name = "SpawnPlayerArea" if team == GameManager.Team.PLAYER else "SpawnEnemyArea"
		var area = battle.get_node_or_null(area_name)
		if area == null:
			continue
		var col: CollisionShape2D = area.get_node("CollisionShape2D")
		var r = spawn_rect(team)
		var shape = RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		col.scale = Vector2.ONE
		col.rotation = 0
		area.position = Vector2.ZERO
		area.scale = Vector2.ONE
		col.position = battle.to_local(r.get_center())


static func _camera(battle: Node):
	var cam: Camera2D = battle.get_node_or_null("Camera2D")
	if cam == null:
		return
	cam.position = battle.to_local(CENTER + Vector2(0, CAMERA_OFFSET_Y))
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
