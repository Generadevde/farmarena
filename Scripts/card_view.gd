extends Control
class_name CardView
## Carta desenhada por código: moldura na cor da raridade, faixa da turma,
## arte 48x48, custo, nível e a borda de MAESTRIA (quanto mais você usa a
## carta, mais ela brilha: bronze -> prata -> ouro -> diamante).

signal tapped(card)
signal held(card)  # dedo parado em cima da carta por um instante -> começa a arrastar

const HOLD_TIME = 0.32
var _press_id := 0
var _held_fired := false

var card: CardData
var locked := false          # ainda não encontrada
var show_level := true
var badge := ""              # texto pequeno no rodapé ("x12", "NOVA!", "Arena 3")
var badge_color := Color(1, 0.9, 0.5)
var selected := false
var show_stats := false
var mastery_override := -1   # -1 = usa a do jogador
var level_override := -1
var _t := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false


const FOOT = 24.0  # altura da faixa de dados no rodapé (em unidades da carta)

## with_stats: mostra os dados básicos DENTRO da carta -- vida e ataque nos
## cantos da arte; alcance, tipo de alvo e velocidade nos cantos de baixo
static func make(c: CardData, w: float = 132.0, with_stats: bool = false) -> CardView:
	var v = CardView.new()
	v.card = c
	v.show_stats = with_stats
	v.custom_minimum_size = Vector2(w, w * 1.34 + (FOOT * w / 132.0 if with_stats else 0.0))
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	return v


func _ready():
	set_process(false)
	_update_anim()


func _update_anim():
	set_process(is_inside_tree() and (selected or _mastery() >= 3))


func set_selected(v: bool):
	selected = v
	_update_anim()
	queue_redraw()


func _mastery() -> int:
	if mastery_override >= 0:
		return mastery_override
	return Progresso.mastery(card) if card != null and !locked else 0


func _process(delta):
	_t += delta
	queue_redraw()


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_held_fired = false
			_press_pos = event.global_position
			_press_id += 1
			if held.get_connections().size() > 0:
				_wait_hold(_press_id)
		elif _pressing:
			_pressing = false
			if !_held_fired and event.global_position.distance_to(_press_pos) < 18.0:
				tapped.emit(card)
	elif event is InputEventMouseMotion and _pressing and event.global_position.distance_to(_press_pos) > 14.0:
		_press_id += 1  # mexeu o dedo antes do tempo: é rolagem, não arrasto


func _wait_hold(id: int):
	await get_tree().create_timer(HOLD_TIME).timeout
	if is_inside_tree() and _pressing and id == _press_id:
		_held_fired = true
		held.emit(card)


func _draw():
	if card == null:
		return
	var w = size.x
	var h = size.y
	var u = w / 132.0
	var rarity_col: Color = Catalogo.rarity_color(card)
	var turma_col: Color = card.nation_data.color if card.nation_data != null else Color(0.55, 0.55, 0.55)
	var mastery = _mastery()
	var frame_col = rarity_col
	if locked:
		frame_col = Color(0.35, 0.33, 0.3)
		turma_col = Color(0.3, 0.29, 0.27)

	# sombra + moldura
	draw_rect(Rect2(3 * u, 5 * u, w - 3 * u, h - 5 * u), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, 0, w - 3 * u, h - 5 * u), Color("#2a1a22"))
	var inner = Rect2(3 * u, 3 * u, w - 9 * u, h - 11 * u)
	draw_rect(inner, frame_col)
	# fundo da arte (cor da turma, com faixa clara em cima)
	var art_box = Rect2(inner.position + Vector2(4, 4) * u, Vector2(inner.size.x - 8 * u, inner.size.x - 8 * u))
	draw_rect(art_box, turma_col.darkened(0.25))
	draw_rect(Rect2(art_box.position, Vector2(art_box.size.x, art_box.size.y * 0.5)), turma_col.darkened(0.08))
	if card.icon != null:
		var art_rect = Rect2(art_box.position, art_box.size)
		draw_texture_rect(card.icon, art_rect, false, Color(0.12, 0.12, 0.12, 0.9) if locked else Color.WHITE)
	# nome
	var font = ThemeDB.fallback_font
	var foot_h = FOOT * u if show_stats else 0.0
	var name_rect = Rect2(inner.position.x + 2 * u, art_box.end.y + 2 * u, inner.size.x - 4 * u, inner.end.y - art_box.end.y - 4 * u - foot_h)
	draw_rect(name_rect, Color("#f3e6c8") if !locked else Color(0.6, 0.58, 0.54))
	var fs = int(15 * u)
	var label = card.card_name if !locked else "???"
	while fs > 9 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_rect.size.x - 4:
		fs -= 1
	if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_rect.size.x - 4:
		draw_multiline_string(font, name_rect.position + Vector2(2, fs), label, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x - 4, fs, 2, Color("#3a2414"))
	else:
		draw_string(font, name_rect.position + Vector2(0, name_rect.size.y * 0.5 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, fs, Color("#3a2414"))
	# custo (gota no canto)
	var cc = Vector2(15, 15) * u
	draw_circle(cc, 17 * u, Color("#2a1a22"))
	draw_circle(cc, 15 * u, Color("#58b8f0") if !locked else Color(0.45, 0.45, 0.45))
	var cost = str(card.cost)
	var cfs = int(18 * u)
	var cw = font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	draw_string_outline(font, cc + Vector2(-cw * 0.5, cfs * 0.36), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, 3, Color("#12324a"))
	draw_string(font, cc + Vector2(-cw * 0.5, cfs * 0.36), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color.WHITE)
	# nível
	if show_level and !locked:
		var lv = level_override if level_override > 0 else PlayerProfile.get_card_level(card)
		var txt = "Nv %d" % lv
		var lfs = int(13 * u)
		var lw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 8 * u
		var lr = Rect2(w - 6 * u - lw, 5 * u, lw, 18 * u)
		draw_rect(lr, Color("#2a1a22"))
		draw_string(font, lr.position + Vector2(4 * u, 13.5 * u), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color("#ffe08a"))
	# selo
	if badge != "":
		var bfs = int(13 * u)
		var bw = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x + 10 * u
		var br = Rect2((w - 3 * u - bw) * 0.5, art_box.end.y - (40 if show_stats else 18) * u, bw, 18 * u)
		draw_rect(br, Color(0.1, 0.06, 0.05, 0.88))
		draw_string(font, br.position + Vector2(5 * u, 13.5 * u), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, badge_color)
	if show_stats and !locked:
		_draw_stats(art_box, Rect2(inner.position.x + 2 * u, name_rect.end.y + 1 * u, inner.size.x - 4 * u, foot_h - 2 * u), u)
	# MAESTRIA: borda extra + cantoneiras + brilho andando (ouro/diamante)
	if mastery > 0:
		var mc: Color = Progresso.MASTERY_COLORS[mastery]
		var r = Rect2(1 * u, 1 * u, w - 5 * u, h - 7 * u)
		draw_rect(r, mc, false, (2.0 + mastery * 0.6) * u)
		var k = (6 + mastery * 2) * u
		for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			draw_rect(Rect2(corner - Vector2(k, k) * 0.5, Vector2(k, k)), mc)
			draw_rect(Rect2(corner - Vector2(k, k) * 0.25, Vector2(k, k) * 0.5), mc.lightened(0.5))
		if mastery >= 3:
			var per = 2.0 * (r.size.x + r.size.y)
			for j in (2 if mastery >= 4 else 1):
				var dist = fposmod(_t * 90.0 + j * per * 0.5, per)
				draw_circle(_perimeter_point(r, dist), 4.5 * u, Color(1, 1, 1, 0.95))
				draw_circle(_perimeter_point(r, dist - 8.0), 3.0 * u, Color(mc.r, mc.g, mc.b, 0.8))
	if selected:
		var pulse = 0.6 + 0.4 * sin(_t * 7.0)
		draw_rect(Rect2(-2, -2, w + 1 - 3 * u, h + 1 - 5 * u), Color(1, 1, 1, pulse), false, 4.0)


static func _perimeter_point(r: Rect2, dist: float) -> Vector2:
	var per = 2.0 * (r.size.x + r.size.y)
	dist = fposmod(dist, per)
	if dist < r.size.x:
		return r.position + Vector2(dist, 0)
	dist -= r.size.x
	if dist < r.size.y:
		return Vector2(r.end.x, r.position.y + dist)
	dist -= r.size.y
	if dist < r.size.x:
		return Vector2(r.end.x - dist, r.end.y)
	dist -= r.size.x
	return Vector2(r.position.x, r.end.y - dist)


# ================================================================ dados dentro da carta
enum Ico { HEART, SWORD, RANGE, SPEED, AREA, CLOCK, PLUS, SHIELD }


func _stat_values() -> Dictionary:
	## {tl: [ícone, texto], tr: [...], bl: [...], br: [...], mid: texto do alvo}
	var lv = level_override if level_override > 0 else PlayerProfile.get_card_level(card)
	var mult = PlayerProfile.compute_stat_multiplier(lv)
	if card.is_spell():
		var sp: SpellData = card.spell_data
		var main = [Ico.SWORD, str(int(round(sp.damage * mult)))]
		if sp.damage <= 0:
			if sp.heal_amount > 0:
				main = [Ico.PLUS, str(int(round(sp.heal_amount * mult)))]
			elif sp.shield_amount > 0:
				main = [Ico.SHIELD, str(int(round(sp.shield_amount * mult)))]
			elif sp.summon_count > 0:
				main = [Ico.PLUS, "x%d" % sp.summon_count]
			else:
				main = [Ico.SWORD, "-"]
		var lasting = maxf(sp.duration, maxf(sp.buff_duration, sp.status_effect_duration))
		return {"left": main, "right": [Ico.AREA, str(int(sp.radius))], "bl": [Ico.CLOCK, ("%.0fs" % lasting if lasting >= 1.0 else "%.1fs" % lasting) if lasting > 0 else "na hora"],
			"mid": "Aliados" if (sp.affects_allies or !sp.affects_enemies) else "Inimigos", "br": []}
	var st: UnitData = DeckBuilder.get_unit_stats(card)
	if st == null:
		return {}
	var target = ["Chão", "Só ar", "Chão+Ar", "Só torres"][clampi(st.target_type, 0, 3)]
	if st.damage <= 0:
		target = "Não ataca"
	var hp_text = str(int(round(st.hp * mult)))
	if st.unit_count > 1:
		hp_text += " x%d" % st.unit_count
	return {
		"left": [Ico.HEART, hp_text],
		"right": [Ico.SWORD, str(int(round(st.damage * mult))) if st.damage > 0 else "-"],
		"bl": [Ico.RANGE, str(int(st.attack_range)) if st.is_ranged else "perto"],
		"br": [Ico.SPEED, str(int(st.move_speed)) if st.move_speed > 0 else "fixo"],
		"mid": ("Voa · " if st.unit_type == UnitData.UnitType.AIR else "") + target,
	}


func _draw_stats(art_box: Rect2, foot: Rect2, u: float):
	var vals = _stat_values()
	if vals.is_empty():
		return
	var font = ThemeDB.fallback_font
	# vida (canto esquerdo da arte) e ataque (canto direito)
	var chip_h = 19 * u
	var fs = int(14 * u)
	_chip(Vector2(art_box.position.x, art_box.end.y - chip_h), vals["left"], fs, chip_h, u, false)
	_chip(Vector2(art_box.end.x, art_box.end.y - chip_h), vals["right"], fs, chip_h, u, true)
	# rodapé: alcance | alvo | velocidade
	draw_rect(foot, Color("#2a1a22"))
	var ffs = int(13 * u)
	var base_y = foot.position.y + foot.size.y * 0.5
	var left_w = 0.0
	if !vals["bl"].is_empty():
		_icon(vals["bl"][0], Vector2(foot.position.x + 9 * u, base_y), 6 * u)
		draw_string(font, Vector2(foot.position.x + 18 * u, base_y + ffs * 0.36), vals["bl"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ffs, Color("#ffe9b8"))
		left_w = 18 * u + font.get_string_size(vals["bl"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ffs).x
	var right_w = 0.0
	if !vals["br"].is_empty():
		var tw = font.get_string_size(vals["br"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ffs).x
		draw_string(font, Vector2(foot.end.x - tw - 3 * u, base_y + ffs * 0.36), vals["br"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ffs, Color("#ffe9b8"))
		_icon(vals["br"][0], Vector2(foot.end.x - tw - 12 * u, base_y), 6 * u)
		right_w = tw + 20 * u
	var mid: String = vals["mid"]
	var room = foot.size.x - left_w - right_w - 6 * u
	var mfs = int(12 * u)
	while mfs > 7 and font.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x > room:
		mfs -= 1
	var mw = font.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
	var mx = foot.position.x + left_w + 3 * u + (room - mw) * 0.5
	draw_string(font, Vector2(mx, base_y + mfs * 0.36), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color("#ffb060") if mid.contains("Só torres") else (Color("#9fe0ff") if mid.begins_with("Voa") else Color("#c8f0a0")))


func _chip(corner: Vector2, val: Array, fs: int, h: float, u: float, right_side: bool):
	var font = ThemeDB.fallback_font
	var tw = font.get_string_size(val[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w = tw + 22 * u
	var r = Rect2(corner.x - (w if right_side else 0.0), corner.y, w, h)
	draw_rect(r, Color(0.1, 0.06, 0.07, 0.9))
	_icon(val[0], r.position + Vector2(10 * u, h * 0.5), 6.5 * u)
	draw_string(font, r.position + Vector2(19 * u, h * 0.5 + fs * 0.36), val[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## ícones desenhados (não dependem de emoji do aparelho)
func _icon(kind: int, c: Vector2, r: float):
	match kind:
		Ico.HEART:
			var red = Color("#ff5a5a")
			draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.55, red)
			draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.55, red)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, 0), c + Vector2(0, r)]), red)
		Ico.SWORD:
			draw_line(c + Vector2(-r * 0.8, r * 0.8), c + Vector2(r * 0.8, -r * 0.8), Color("#e8eef4"), maxf(2.0, r * 0.45))
			draw_line(c + Vector2(-r * 0.75, 0.05 * r), c + Vector2(-0.05 * r, r * 0.75), Color("#ffb050"), maxf(2.0, r * 0.4))
		Ico.RANGE:
			draw_arc(c, r * 0.95, 0, TAU, 16, Color("#ffd060"), maxf(1.5, r * 0.25))
			draw_circle(c, r * 0.35, Color("#ff6a50"))
		Ico.SPEED:
			var col = Color("#7fe0ff")
			for dx in [-r * 0.55, r * 0.25]:
				draw_polyline(PackedVector2Array([c + Vector2(dx - r * 0.3, -r * 0.7), c + Vector2(dx + r * 0.4, 0), c + Vector2(dx - r * 0.3, r * 0.7)]), col, maxf(1.5, r * 0.3))
		Ico.AREA:
			draw_circle(c, r * 0.95, Color(1, 0.6, 0.3, 0.45))
			draw_arc(c, r * 0.95, 0, TAU, 16, Color("#ffb060"), maxf(1.5, r * 0.25))
		Ico.CLOCK:
			draw_arc(c, r * 0.95, 0, TAU, 16, Color("#e8eef4"), maxf(1.5, r * 0.25))
			draw_line(c, c + Vector2(0, -r * 0.6), Color("#e8eef4"), maxf(1.5, r * 0.25))
			draw_line(c, c + Vector2(r * 0.45, 0), Color("#e8eef4"), maxf(1.5, r * 0.25))
		Ico.PLUS:
			var g = Color("#6af08a")
			draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.9), Vector2(r * 0.5, r * 1.8)), g)
			draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.25), Vector2(r * 1.8, r * 0.5)), g)
		Ico.SHIELD:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, 0.1 * r), c + Vector2(0, r), c + Vector2(-r * 0.8, 0.1 * r)]), Color("#80c0ff"))
