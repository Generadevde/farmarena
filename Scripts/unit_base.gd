extends CharacterBody2D

# caracteristicas
@export var stats: UnitData
@export var team: GameManager.Team

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

# variaveis gerais
var enemy_base = null
var target = null
var attack_cooldown = 0.0
var is_preview = false
var current_hp
var module_speed_bonus: float = 1.0  # módulo do dono que acelera cartas baratas (regra "modulos")
var speed_multiplier: float = 1.0  # >1 = sob efeito de fúria, <1 = sob efeito de lentidão
var card_level: int = 1  # nível de upgrade da carta que gerou essa unidade
var card_role: int = CardData.CardRole.VERSATIL  # categoria da carta, pra IA usar na defesa
var card_data: CardData = null  # a própria carta que gerou essa unidade -- pra missão de "matar unidade X" saber quem morreu

signal died(dead_unit_team, dead_unit_card_data)
var card_danger_level: int = 3  # nível de perigo da carta, pra IA saber se vale responder com força total

# --- estado dos efeitos especiais (status recebidos, cooldowns próprios) ---
var damage_multiplier: float = 1.0  # <1 = enfraquecida (WEAKNESS)
var _incapacitated_until: float = 0.0  # FREEZE/STUN: não anda nem ataca
var _rooted_until: float = 0.0  # ROOT: não anda, mas ainda ataca
var _confused_until: float = 0.0  # CONFUSE: anda na direção errada
var _silenced_until: float = 0.0  # SILENCE: ataca normal, mas sem aplicar efeito nem habilidade passiva
var _marked_until: float = 0.0  # MARK: recebe dano multiplicado de qualquer fonte
var _mark_multiplier: float = 1.0
var _last_damage_time: float = -999.0  # usado pelo escudo recarregável, pra saber há quanto tempo não leva dano
var _retarget_check_cooldown: float = 0.0
var _is_actively_attacking: bool = false  # true só quando o alvo atual está dentro do alcance de ataque de verdade
const RETARGET_CHECK_INTERVAL = 0.4  # a cada quanto tempo confere se ainda é o alvo mais próximo
var _formation_speed_cap: float = -1.0  # -1 = sem trava; senão, velocidade máxima permitida (não ultrapassa aliado mais pesado à frente)
var _formation_check_cooldown: float = 0.0
const FORMATION_CHECK_INTERVAL = 0.2
const FORMATION_CHECK_RADIUS = 70.0  # só considera aliado bem perto, não qualquer um do mapa
var _poison_damage_per_tick: float = 0.0
var _poison_tick_interval: float = 1.0
var _poison_cooldown: float = 0.0
var _poison_ticks_left: int = 0
var _has_attacked_before: bool = false
var _damage_ramp_multiplier: float = 1.0
var _same_target_ramp_multiplier: float = 1.0  # cresce enquanto continua no MESMO alvo, reseta se trocar
var _same_target_ramp_last_target = null  # pra detectar troca de alvo entre um ataque e outro
var _attack_speed_ramp_multiplier: float = 1.0
var _heal_aura_cooldown: float = 0.0
var _spawn_cooldown: float = 0.0
var _resource_gen_cooldown: float = 0.0
var _regen_cooldown: float = 0.0
var current_shield: int = 0
var linked_units: Array = []
var _has_resurrected: bool = false  # trava a ressurreição pra só acontecer uma vez
var _spawn_invulnerable_until: float = 0.0  # até quando (Time.get_ticks_msec) essa unidade fica intocável desde que nasceu
var _converted_count: int = 0  # quantas unidades essa já converteu (pro can_convert_enemy)
var _duration_remaining: float = 0.0  # pra atualizar a barra de duração visual
var _true_sprite_texture: Texture2D = null  # textura de verdade, guardada enquanto disfarçada
var _is_disguised: bool = false
var _is_clone := false
var _charge_distance_accumulated: float = 0.0  # distância andada desde o último ataque, pro golpe carregado
var _has_dashed: bool = false  # se já usou o avanço estilo Bandida (só acontece 1 vez na vida)
var _dash_time_remaining: float = 0.0  # quanto tempo ainda falta do avanço em andamento

# BATALHA 2.5 (ver Scripts/regras.gd)
var _deploy_until: float = 0.0     # entrando em campo: aparece, mas ainda não anda nem bate
var _windup_left: float = -1.0     # preparo do golpe em andamento (<0 = não está preparando)
var _windup_total: float = 0.0
var _aim_dir := Vector2.ZERO
var _hit_squash := 0.0             # "amassada" rápida ao levar golpe
static var _reflecting := false    # trava do "devolve dano" (vale pra todas as unidades)
var _base_sprite_scale := Vector2.ONE
var deploy_clock := true           # numa leva (6 pintinhos), só o primeiro mostra o relógio


## relógio de entrada em campo (o arco vai sumindo)
class DeployClock extends Node2D:
	var total := 1.0
	var left := 1.0
	var col := Color.WHITE
	var r := 9.0

	func _process(delta):
		left -= delta
		if left <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw():
		var f = clampf(left / total, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * f, 24, Color(0, 0, 0, 0.55), 5.0, true)
		draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * f, 24, col, 3.0, true)


# troca a textura da unidade pelo ícone de uma carta aleatória qualquer do
# banco -- guarda a textura verdadeira pra devolver depois, no primeiro
# ataque (_reveal_disguise). Se não achar nenhum ícone válido pra sortear,
# desiste em silêncio e a unidade fica com o visual normal mesmo
func _apply_disguise():
	var candidates: Array[Texture2D] = []
	for card in CardDatabase.all_cards:
		if card != null and card.icon != null:
			candidates.append(card.icon)
	if candidates.is_empty():
		return

	_true_sprite_texture = $Sprite2D.texture
	$Sprite2D.texture = candidates[randi() % candidates.size()]
	_is_disguised = true


# devolve a textura verdadeira -- chamada assim que a unidade dá o
# primeiro ataque de verdade, "revelando" quem ela era o tempo todo
func _reveal_disguise():
	if !_is_disguised:
		return
	_is_disguised = false
	if _true_sprite_texture != null:
		$Sprite2D.texture = _true_sprite_texture


func _ready():
	# sprite redesenhado no Criador pra uma carta ORIGINAL do jogo
	if card_data != null:
		var sprite_override = CustomContent.get_sprite_override(card_data.resource_path)
		if sprite_override != null:
			$Sprite2D.texture = sprite_override
			$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_unit_scale()
	_setup_visuals()

	if !is_preview and stats.spawns_disguised:
		_apply_disguise()

	if is_preview:
		set_physics_process(false)
		set_process(false)
		$Area2D.monitoring = false
		$CollisionShape2D.disabled = true
		if Regras.on("visual"):
			$ProgressBar.visible = false
			$LevelLabel.visible = false
			$DurationBar.visible = false
		return

	add_to_group("units")  # usado pela separação macia (_apply_soft_separation)
	current_hp = stats.hp
	$ProgressBar.max_value = stats.hp
	$ProgressBar.value = current_hp
	$ProgressBar.theme = ThemeBuilder.game_theme
	$ProgressBar.custom_minimum_size = Vector2(40, 8)  # garante formato de barra alongada, não um quadrado pequeno
	$LevelLabel.text = "Nv%d" % card_level
	# nível SEMPRE à mostra (antes o Nv1 sumia e parecia que a carta do bot "não tinha nível");
	# só some quando todo mundo joga no mesmo nível (torneio, modo teste)
	$LevelLabel.visible = card_level >= 1 and MatchSetup.fixed_level() <= 0
	$LevelLabel.add_theme_font_size_override("font_size", 11)
	_setup_bar()
	add_to_group("damageable")

	if stats.spawn_invulnerability_duration > 0:
		_spawn_invulnerable_until = GameManager.game_time + stats.spawn_invulnerability_duration

	var deploy = Regras.deploy_time(stats)
	if deploy > 0:
		apply_incapacitate(deploy)
		if Regras.on("peso"):
			_begin_deploy(deploy)

	if stats.deals_arrival_damage:
		_deal_area_damage(global_position, stats.arrival_damage_radius, stats.arrival_damage, true)

	if stats.entrance_rage_duration > 0:
		apply_speed_multiplier(stats.entrance_rage_speed_mult, stats.entrance_rage_duration)
		apply_damage_multiplier(stats.entrance_rage_damage_mult, stats.entrance_rage_duration)

	if stats.entrance_shockwave_damage > 0:
		_deal_area_damage(global_position, stats.entrance_shockwave_radius, stats.entrance_shockwave_damage)
	# CHOQUE AO ENTRAR: a onda (ou o dano de chegada) também atordoa / congela / deixa lento
	if stats.entrance_effect != UnitData.OnHitEffect.NONE:
		var er = maxf(stats.entrance_shockwave_radius if stats.entrance_shockwave_damage > 0 else stats.arrival_damage_radius, 60.0)
		_area_effect(global_position, er, stats.entrance_effect, stats.entrance_effect_duration, 0.4)
		if Regras.on("visual"):
			Fx.bolt(get_parent(), position, Color(0.6, 0.85, 1.0))
			Fx.ring(get_parent(), position, er, Color(0.6, 0.85, 1.0), 0.35)

	_configure_physics_layers()

	if stats.has_shield:
		current_shield = stats.shield_amount
	if stats.has_temp_shield:
		current_shield = stats.temp_shield_amount
		get_tree().create_timer(stats.temp_shield_duration).timeout.connect(func():
			current_shield = 0
		)

	_configure_detection_area()
	_configure_avoidance()

	if stats.duration > 0:
		_duration_remaining = stats.duration
		$DurationBar.max_value = stats.duration
		$DurationBar.value = stats.duration
		$DurationBar.visible = true
		get_tree().create_timer(stats.duration).timeout.connect(die)
	else:
		$DurationBar.visible = false

	if stats.transforms_into_building and stats.transformed_scene != null:
		get_tree().create_timer(stats.transform_after_seconds).timeout.connect(_do_transform)

	if stats.stores_resource:
		var battle = get_tree().get_first_node_in_group("battle_scene")
		if battle != null and battle.has_method("add_storage_capacity"):
			battle.add_storage_capacity(team, stats.storage_capacity_bonus)

	_refresh_enemy_tower()


# ============================================================
# VISUAL 2.0 -- animação por código (balanço ao andar, bote ao atacar,
# voador flutuando com sombra). Só mexe em posição/rotação do sprite:
# a ESCALA fica intacta porque o tamanho do corpo é medido por ela.
# ============================================================
var _sprite_home := Vector2.ZERO
var _anim_t := 0.0
var _lunge := Vector2.ZERO
var _visual_scale := 1.0
var _is_air_visual := false

# IDENTIDADE: cada tipo de corpo anda e bate do seu jeito (antes todo mundo
# dava o mesmo pulinho e o mesmo bote -- era isso que deixava tudo "igual")
enum Gait { MARCHA, TROTE, GALOPE, CORRIDINHA, CISCA, PULO, RASTEJA, FLUTUA, RODA, PISADA, VOO, ZUMBE, DISCO, FORMIGA, ONDULA, PATINA, QUICA, ROBO, BEBADO,
	SERPENTE, SALTITA, NINJA, DANCA }
# nomes na ordem dos enums, pra aba "Animação" do Criador (o índice 0 da lista do Criador é "Automática")
const GAIT_NAMES = ["Marcha (gente)", "Trote (casco)", "Galope", "Corridinha", "Cisca (galinha)", "Pulo (sapo)", "Rasteja", "Flutua (assombração)",
	"Roda (motor)", "Pisada pesada", "Voo (ave)", "Zumbe (inseto)", "Disco voador", "Formiga", "Ondula (polvo)", "Patina (desliza)", "Quica (bola)", "Robô (passo duro)", "Cambaleia",
	"Serpente (zigue-zague)", "Saltita (pulinhos)", "Ninja (abaixado e rápido)", "Dança"]
const HIT_NAMES = ["Bote", "Pancada (marreta)", "Estocada", "Giro", "Cabeçada", "Bicada", "Tiro", "Mordida dupla", "Pulo em cima", "Tremor",
	"Arremesso (joga de cima)", "Rajada (três golpes rápidos)", "Chicote"]
const DEATH_NAMES = ["Fumaça (padrão)", "Explosão", "Vira fantasma", "Estouro de penas", "Chuva de moedas", "Derrete", "Some num clarão",
	"Vira pedra", "Afunda no chão", "Confete", "Choque elétrico"]
const ENTRY_NAMES = ["Automática (cai de pertinho)", "Cai do céu", "Sai do chão", "Aparece na fumaça", "Teleporte (clarão)", "Chega rodando", "Raio do céu"]
# famílias de corpo (peças "quatro" do SpriteForge)
const BODY_HOOF = ["casco", "malhado", "cavalo", "bezerro", "vaca", "bode", "jegue", "montado"]
const BODY_PAW = ["pata", "cachorro", "capivara", "porco", "gato", "onca", "cerbero"]
const BODY_CRAWL = ["rasteiro", "casca", "cobra", "caranguejo"]
enum Hit { BOTE, PANCADA, ESTOCADA, GIRO, CABECADA, BICADA, TIRO, MORDIDA, PULAO, TREMOR, ARREMESSO, RAJADA, CHICOTE }
var _gait: int = Gait.MARCHA
var _hit_style: int = Hit.BOTE
var _step_index := 0        # conta as passadas (poeira na pisada pesada)
var _spin_left := 0.0       # giro do golpe em roda
var _dip := 0.0             # cabeçada / bicada (inclina e volta)
var _slam := 0.0            # pancada (achata e volta)
var _idle_t := 0.0
const SPIN_TIME = 0.3


func _recipe() -> Dictionary:
	return card_data.art_recipe if card_data != null and card_data.art_recipe != null else {}


func _pick_gait() -> int:
	var r = _recipe()
	var legs = str(r.get("pernas", ""))
	if stats.unit_type == UnitData.UnitType.AIR:
		if str(r.get("objeto", "")) != "":
			return Gait.DISCO
		if legs == "inseto":
			return Gait.ZUMBE
		return Gait.VOO
	var q = str(r.get("quatro", ""))
	if q == "sapo" or legs == "saci":
		return Gait.PULO
	if q in BODY_CRAWL:
		return Gait.RASTEJA
	if q == "formiga":
		return Gait.FORMIGA
	if q in BODY_HOOF:
		if stats.move_speed >= 70.0:
			return Gait.GALOPE
		return Gait.PISADA if stats.unit_scale >= 1.4 else Gait.TROTE
	if q in BODY_PAW:
		return Gait.GALOPE if stats.move_speed >= 90.0 else Gait.CORRIDINHA
	if q == "mapinguari" or q == "tripe":
		return Gait.PISADA
	if q == "polvo":
		return Gait.ONDULA
	if str(r.get("objeto", "")) != "" or legs == "rodas":
		return Gait.RODA
	if legs == "fantasma":
		return Gait.FLUTUA
	if legs == "ave":
		return Gait.CISCA
	if stats.unit_scale >= 1.6 or stats.push_weight >= 4.0:
		return Gait.PISADA
	return Gait.MARCHA


func _pick_hit_style() -> int:
	var r = _recipe()
	if stats.is_ranged:
		return Hit.TIRO
	if stats.spin_attack:
		return Hit.GIRO
	if stats.is_aoe or (stats.attack_speed >= 1.8 and stats.damage >= 150):
		return Hit.PANCADA
	var q = str(r.get("quatro", ""))
	if q == "montado":
		return Hit.ESTOCADA if !stats.charge_attack else Hit.CABECADA   # lança em riste
	if q in BODY_HOOF or q in BODY_PAW or q in BODY_CRAWL:
		return Hit.CABECADA
	if str(r.get("pernas", "")) == "ave":
		return Hit.BICADA
	if stats.attack_speed <= 0.9:
		return Hit.ESTOCADA
	return Hit.BOTE


func _setup_visuals():
	var sprite: Sprite2D = $Sprite2D
	_visual_scale = stats.unit_scale * Regras.sprite_factor(stats.unit_scale)
	_base_sprite_scale = sprite.scale
	_is_air_visual = stats.unit_type == UnitData.UnitType.AIR
	_anim_t = randf() * 10.0
	_idle_t = randf() * 10.0
	_gait = _pick_gait()
	_hit_style = _pick_hit_style()
	# escolha da aba "Animação" do Criador por cima da automática
	if stats.anim_gait > 0:
		_gait = clampi(stats.anim_gait - 1, 0, Gait.size() - 1)
	if stats.anim_hit > 0:
		_hit_style = clampi(stats.anim_hit - 1, 0, Hit.size() - 1)
	if Regras.on("visual") and !is_preview:
		sprite.flip_h = team == GameManager.Team.ENEMY   # cada lado olha pro campo do outro
	var team_look = Regras.on("visual") and !is_preview
	if stats.unit_type != UnitData.UnitType.BUILDING or team_look:
		var shadow = Polygon2D.new()
		var pts := PackedVector2Array()
		var rx = 10.0 if !team_look else 12.5
		var ry = 4.0 if !team_look else 5.5
		for i in 16:
			var a = TAU * i / 16.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry) * _visual_scale)
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.22)
		shadow.position = Vector2(0, (20.0 if team_look else 14.0) * _visual_scale)
		shadow.z_index = -1
		shadow.name = "Sombra"
		add_child(shadow)
		move_child(shadow, 0)
		if team_look:
			# COR DE TIME: roda no chão + contorno do desenho. Azul = seu, vermelho = do adversário
			var tc = Regras.team_color(team == GameManager.Team.PLAYER)
			shadow.color = Color(tc.r, tc.g, tc.b, 0.45)
			var ring = Line2D.new()
			ring.points = pts
			ring.closed = true
			ring.width = 2.0
			ring.default_color = Color(tc.r, tc.g, tc.b, 0.95)
			ring.name = "AnelTime"
			shadow.add_child(ring)
			sprite.material = Regras.outline_material(team == GameManager.Team.PLAYER)
	if _is_air_visual:
		sprite.position.y -= 16.0 * _visual_scale
		if team_look:
			sprite.z_index = 2  # voador sempre por cima de quem está no chão
	_sprite_home = sprite.position
	if !is_preview:
		_spawn_fx.call_deferred()


static var _top_cache := {}


## quantos pixels do desenho ficam acima do centro (48x48 -> no máximo 24)
func _sprite_top_px() -> float:
	var tex: Texture2D = $Sprite2D.texture
	if tex == null:
		return 20.0
	var key = tex.get_rid()
	if !_top_cache.has(key):
		var img = tex.get_image()
		_top_cache[key] = (tex.get_height() * 0.5 - float(img.get_used_rect().position.y)) if img != null else 20.0
	return _top_cache[key]


## altura da cabeça acima do centro (pra barra de vida ficar em cima dela)
func _head_height() -> float:
	var h = 24.0 * absf(_base_sprite_scale.y) * 0.86
	if Regras.on("visual"):
		# bicho baixinho (sapo, jacaré, tatu) tem a cabeça bem mais embaixo:
		# mede onde o desenho começa de verdade pra barra encostar nele
		h = (_sprite_top_px() + 1.0) * absf(_base_sprite_scale.y)
	if _is_air_visual:
		h += 16.0 * _visual_scale
	return h


## VISUAL 2.5: barra do tamanho da tropa, azul (sua) ou vermelha (do
## adversário), e só aparece depois que a tropa apanha -- campo limpo
func _setup_bar():
	if !Regras.on("visual"):
		return
	var bar: ProgressBar = $ProgressBar
	var tc = Regras.team_color(team == GameManager.Team.PLAYER)
	var w = clampf(18.0 + 16.0 * _visual_scale, 26.0, 64.0)
	var h = 5.0 if stats.unit_scale < 0.75 else 7.0
	var top = -_head_height() - h - 3.0
	var fill = StyleBoxFlat.new()
	fill.bg_color = tc
	fill.set_corner_radius_all(2)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.05, 0.05, 0.9)
	bg.border_color = Color(0, 0, 0, 0.95)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	bar.custom_minimum_size = Vector2(w, h)
	bar.set_deferred("size", Vector2(w, h))
	bar.position = Vector2(-w / 2.0, top)
	bar.visible = false
	var lv: Label = $LevelLabel
	lv.position = Vector2(w / 2.0 + 2.0, top - 6.0)
	lv.add_theme_color_override("font_color", tc.lightened(0.45))
	lv.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lv.add_theme_constant_override("outline_size", 3)
	var db: ProgressBar = $DurationBar
	db.custom_minimum_size = Vector2(w, 3)
	db.set_deferred("size", Vector2(w, 3))
	db.position = Vector2(-w / 2.0, top - 5.0)


func _refresh_bar():
	if Regras.on("visual"):
		$ProgressBar.visible = current_hp < stats.hp or current_shield > 0


## ENTRADA EM CAMPO: cai do alto, quica e mostra o reloginho. Enquanto o
## relógio roda a tropa já pode apanhar, mas não anda nem bate.
func _begin_deploy(seconds: float):
	_deploy_until = GameManager.game_time + seconds
	var drop = 26.0 * minf(_visual_scale, 1.8)
	_lunge = Vector2(0, -drop)  # a própria "volta do bote" faz a queda
	_entry_fx(drop)
	if !is_inside_tree() or !deploy_clock:
		return
	var clock = DeployClock.new()
	clock.total = seconds
	clock.left = seconds
	clock.col = Regras.team_color(team == GameManager.Team.PLAYER).lightened(0.3)
	clock.r = clampf(7.0 + 3.0 * _visual_scale, 8.0, 14.0)
	clock.position = Vector2(0, -_head_height() - 14.0)
	clock.z_index = 20
	add_child(clock)


const SPAWN_LINES = {
	"Curral": ["Muuu!", "Sai da frente!", "Ô boi!"], "Galinheiro": ["Có có!", "Piu!", "Cocoricó!"], "Brejo": ["Croac.", "Tô de boa.", "Blub."],
	"Roçado": ["Tá na hora da colheita!", "Uai!", "Pipoca!"], "Peões": ["Ô trem bão!", "Bão?", "Simbora!", "Eita!"], "Coisa Estranha": ["Bip bop.", "Buuu!", "Zzzt!", "Viemos em paz."], "Mar": ["Glub!", "Maré cheia!", "Splash!"], "Lendas": ["Uuuuh...", "É lenda!", "Reza brava!"],
}
const DEATH_LINES = ["Uai...", "Avisa a mãe.", "Fui!", "Ai.", "Nem doeu.", "Volto já."]


func _say(text: String):
	if is_inside_tree():
		Fx.text(get_parent(), position + Vector2(0, -30.0 * _visual_scale), text, Color(1, 1, 0.92), 1.1)


## JEITO DE ENTRAR (aba Animação). Só visual: o tempo de entrada é o mesmo.
func _entry_fx(drop: float):
	if stats == null or stats.anim_entry <= 0 or !is_inside_tree():
		return
	var par = get_parent()
	var sc = clampf(_visual_scale, 0.6, 2.2)
	match stats.anim_entry:
		1:   # cai do céu: começa bem alto e bate no chão
			_lunge = Vector2(0, -drop * 6.0)
			get_tree().create_timer(0.22, false).timeout.connect(func():
				if is_instance_valid(self) and is_inside_tree():
					_hit_squash = 1.0
					Fx.burst(get_parent(), position + Vector2(0, 8.0 * sc), Color(0.78, 0.68, 0.5, 0.9), 10, 110.0, 3.5))
		2:   # sai do chão: começa afundado e sobe, com terra
			_lunge = Vector2(0, drop * 1.2)
			Fx.burst(par, position + Vector2(0, 6.0 * sc), Color(0.55, 0.42, 0.28), 12, 70.0, 3.5)
			Fx.zone(par, position + Vector2(0, 6.0 * sc), 18.0 * sc, Color(0.35, 0.25, 0.15), 0.8)
		3:   # aparece na fumaça
			_lunge = Vector2.ZERO
			Fx.puff(par, position, sc * 1.3)
			Fx.puff(par, position + Vector2(10, -4), sc)
		4:   # teleporte
			_lunge = Vector2.ZERO
			Fx.ring(par, position, 30.0 * sc, Color(0.8, 0.6, 1.0), 0.3)
			Fx.burst(par, position, Color(0.85, 0.7, 1.0), 12, 90.0, 3.0)
		5:   # chega rodando
			_lunge = Vector2(-drop * 2.0, -drop * 0.6)
			_dip = 1.0
		6:   # raio do céu
			_lunge = Vector2.ZERO
			Fx.bolt(par, position, Color(1, 1, 0.7))
			Fx.ring(par, position, 26.0 * sc, Color(1, 1, 0.7), 0.3)


func _spawn_fx():
	if is_inside_tree():
		Fx.ring(get_parent(), position, 18.0 * _visual_scale, Color(1, 1, 1, 0.9), 0.25)
		Sfx.play("nasce", 0.12, -3.0, clampf(1.5 - 0.42 * stats.unit_scale, 0.6, 1.4) if Regras.on("visual") else 1.0)
		# defesa recém-colocada mostra por um instante até onde alcança
		if stats.unit_type == UnitData.UnitType.BUILDING and stats.is_ranged and stats.damage > 0:
			Fx.zone(get_parent(), position, stats.attack_range + 14.0, Color(1.0, 0.85, 0.3), 2.0)
		# falinha de entrada (só às vezes, e só de carta do baralho -- filhote não fala)
		if card_data != null and !CustomContent.is_spawn_only(card_data) and randf() < 0.22:
			var lines: Array = SPAWN_LINES.get(card_data.get_nation_name(), ["Eita!"])
			_say(lines[randi() % lines.size()])


func _process(delta):
	var sprite: Sprite2D = $Sprite2D
	var moving = _really_moving and velocity.length() > 4.0 and stats.unit_type != UnitData.UnitType.BUILDING
	# dá pra VER o estado: intocável/furtiva fica transparente; sólida quando dá pra bater nela
	var ghostly = (stats.immune_while_moving and _really_moving) or (stats.can_stealth and !_has_attacked_before)
	sprite.self_modulate.a = lerpf(sprite.self_modulate.a, 0.6 if ghostly else 1.0, minf(1.0, delta * 10.0))
	var pos = _sprite_home
	var rot = 0.0
	var squash = Vector2.ONE
	if !Regras.on("visual"):
		# jeito antigo: todo mundo com o mesmo pulinho
		if _is_air_visual:
			_anim_t += delta
			pos.y += sin(_anim_t * 3.2) * 2.5 * _visual_scale
			rot = sin(_anim_t * 1.6) * 0.05
		elif moving:
			_anim_t += delta * clampf(velocity.length() / 45.0, 0.6, 2.2)
			pos.y -= absf(sin(_anim_t * 9.0)) * 2.2 * _visual_scale
			rot = sin(_anim_t * 9.0) * 0.07
	else:
		var walk = _walk_anim(delta, moving)
		pos += walk[0]
		rot = walk[1]
		squash = walk[2]
	if moving and absf(velocity.x) > 6.0:
		sprite.flip_h = velocity.x < 0
	pos.y -= _jump_height   # SALTO: o desenho sobe no arco do pulo
	if _lunge.length_squared() > 0.05:
		pos += _lunge
		_lunge = _lunge.lerp(Vector2.ZERO, minf(1.0, delta * 11.0))
	# golpe em roda: o desenho dá uma volta inteira
	if _spin_left > 0.0:
		_spin_left = maxf(0.0, _spin_left - delta)
		rot += (1.0 - _spin_left / SPIN_TIME) * TAU * (-1.0 if sprite.flip_h else 1.0)
	# cabeçada / bicada: inclina pra frente e volta
	if absf(_dip) > 0.01:
		rot += _dip
		_dip = lerpf(_dip, 0.0, minf(1.0, delta * 10.0))
	# pancada: achata no impacto e volta
	if _slam > 0.01:
		squash *= Vector2(1.0 + 0.2 * _slam, 1.0 - 0.18 * _slam)
		_slam = lerpf(_slam, 0.0, minf(1.0, delta * 8.0))
	# PESO: preparo do golpe (recua e "arma") e amassada ao apanhar
	if _windup_left >= 0.0 and _windup_total > 0.0:
		var k = clampf(1.0 - _windup_left / _windup_total, 0.0, 1.0)
		var reach = minf(_visual_scale, 1.8) * (3.0 if stats.is_ranged else 7.0)
		var side = signf(_aim_dir.x if absf(_aim_dir.x) > 0.15 else 1.0)
		if _hit_style == Hit.PANCADA and Regras.on("visual"):
			# levanta a marreta: sobe, inclina bem pra trás e estica
			pos -= _aim_dir * reach * 0.6 * k
			pos.y -= 6.0 * minf(_visual_scale, 1.8) * k
			rot -= side * 0.3 * k
			squash *= Vector2(1.0 - 0.06 * k, 1.0 + 0.1 * k)
		elif _hit_style == Hit.GIRO and Regras.on("visual"):
			rot -= side * 0.45 * k            # torce o corpo antes de girar
			squash *= Vector2(1.0 + 0.05 * k, 1.0 - 0.05 * k)
		else:
			pos -= _aim_dir * reach * k
			rot -= side * 0.16 * k
			squash *= Vector2(1.0 + 0.07 * k, 1.0 - 0.07 * k)
	if _hit_squash > 0.01:
		squash *= Vector2(1.0 + 0.16 * _hit_squash, 1.0 - 0.14 * _hit_squash)
		_hit_squash = lerpf(_hit_squash, 0.0, minf(1.0, delta * 14.0))
	if _deploy_until > GameManager.game_time:
		var left = _deploy_until - GameManager.game_time
		sprite.self_modulate.a = minf(sprite.self_modulate.a, 0.92)
		squash *= Vector2(1.0, 1.0 + 0.05 * sin(left * 14.0))
	sprite.scale = _base_sprite_scale * squash
	sprite.position = pos
	sprite.rotation = rot


## JEITO DE ANDAR: devolve [deslocamento, rotação, amassada] do desenho.
## Só visual -- a posição de verdade da tropa não muda.
func _walk_anim(delta: float, moving: bool) -> Array:
	var vs = _visual_scale
	var pos = Vector2.ZERO
	var rot = 0.0
	var sq = Vector2.ONE
	var speed_k = clampf(velocity.length() / 45.0, 0.6, 2.4)
	delta *= clampf(stats.anim_speed, 0.2, 4.0)
	_idle_t += delta
	match _gait:
		Gait.VOO:        # ave grande: plana subindo e descendo, bate asa devagar
			_anim_t += delta
			pos.y = sin(_anim_t * 3.2) * 2.5 * vs
			rot = sin(_anim_t * 1.6) * 0.05
			sq = Vector2(1.0 + 0.05 * sin(_anim_t * 9.0), 1.0 - 0.03 * sin(_anim_t * 9.0))
			return [pos, rot, sq]
		Gait.ZUMBE:      # inseto: treme e ziguezagueia sem parar
			_anim_t += delta
			pos = Vector2(sin(_anim_t * 23.0) * 1.3 + sin(_anim_t * 5.1) * 2.0, sin(_anim_t * 17.0) * 1.6) * vs
			rot = sin(_anim_t * 29.0) * 0.07
			return [pos, rot, sq]
		Gait.DISCO:      # disco voador: paira e inclina pro lado que vai
			_anim_t += delta
			pos.y = sin(_anim_t * 2.0) * 3.0 * vs
			rot = clampf(velocity.x / 60.0, -1.0, 1.0) * 0.14 + sin(_anim_t * 1.3) * 0.03
			return [pos, rot, sq]
		Gait.FLUTUA:     # assombração: desliza flutuando, nunca toca o chão
			_anim_t += delta * (1.4 if moving else 0.8)
			pos.y = (sin(_anim_t * 2.6) * 2.5 - 2.5) * vs
			rot = sin(_anim_t * 1.9) * 0.09
			return [pos, rot, sq]
	if !moving:
		# parado: respira (ninguém vira estátua)
		var b = sin(_idle_t * 2.6)
		if _gait == Gait.RODA:
			return [Vector2(0, sin(_idle_t * 34.0) * 0.35 * vs), 0.0, sq]   # motor ligado
		return [pos, rot, Vector2(1.0 - 0.012 * b, 1.0 + 0.02 * b)]
	_anim_t += delta * speed_k
	var step = 0
	match _gait:
		Gait.CISCA:      # galinha, pinto, pato: passinho rápido rebolando
			pos.y = -absf(sin(_anim_t * 13.0)) * 1.6 * vs
			rot = sin(_anim_t * 13.0) * 0.14
		Gait.TROTE:      # bicho de casco: balanço de lombo
			pos.y = -absf(sin(_anim_t * 8.0)) * 1.8 * vs
			rot = sin(_anim_t * 8.0 + 0.6) * 0.055
		Gait.GALOPE:     # cavalo / bezerro correndo: salto comprido, estica e encolhe
			var g = sin(_anim_t * 7.5)
			pos.y = -maxf(g, 0.0) * 4.5 * vs
			rot = -g * 0.13 * (-1.0 if $Sprite2D.flip_h else 1.0)
			sq = Vector2(1.0 + 0.07 * g, 1.0 - 0.07 * g)
			step = int(floor(_anim_t * 7.5 / TAU))
		Gait.CORRIDINHA: # cachorro, capivara: perninha curta, pulinho miúdo
			pos.y = -absf(sin(_anim_t * 12.0)) * 1.5 * vs
			rot = sin(_anim_t * 12.0) * 0.05
		Gait.PULO:       # sapo: salta, cai agachado, salta de novo
			var ph = fposmod(_anim_t * 1.5, 1.0)
			if ph < 0.62:
				var h = sin(ph / 0.62 * PI)
				pos.y = -h * 9.0 * vs
				sq = Vector2(1.0 - 0.1 * h, 1.0 + 0.14 * h)
			else:
				var d = sin((ph - 0.62) / 0.38 * PI)
				sq = Vector2(1.0 + 0.14 * d, 1.0 - 0.13 * d)
			step = int(floor(_anim_t * 1.5 + 0.38))
		Gait.RASTEJA:    # jacaré, tatu: rente ao chão, gingando de lado
			pos.x = sin(_anim_t * 7.0) * 1.7 * vs
			rot = sin(_anim_t * 7.0) * 0.07
		Gait.ONDULA:     # polvo: se arrasta inchando e murchando
			var o = sin(_anim_t * 6.0)
			pos.y = -maxf(o, 0.0) * 2.0 * vs
			sq = Vector2(1.0 + 0.09 * o, 1.0 - 0.09 * o)
		Gait.FORMIGA:    # formiga: corre rente ao chão num tremidinho ligeiro
			pos = Vector2(sin(_anim_t * 31.0) * 0.8, -absf(sin(_anim_t * 19.0)) * 0.9) * vs
			rot = sin(_anim_t * 19.0) * 0.09
		Gait.RODA:       # trator, robô: não pula -- treme com o motor
			pos = Vector2(sin(_anim_t * 41.0) * 0.5, sin(_anim_t * 53.0) * 0.7) * vs
			rot = sin(_anim_t * 37.0) * 0.012
		Gait.PISADA:     # grandão: passada lenta e pesada, levanta poeira
			var p = sin(_anim_t * 5.0)
			pos.y = -absf(p) * 3.2 * vs
			rot = p * 0.06
			sq = Vector2(1.0 + 0.05 * (1.0 - absf(p)), 1.0 - 0.05 * (1.0 - absf(p)))
			step = int(floor(_anim_t * 5.0 / PI))
		Gait.PATINA:     # desliza: quase não sobe, inclina pro lado que vai e balança devagar
			pos.x = sin(_anim_t * 3.0) * 2.2 * vs
			rot = clampf(velocity.x / 50.0, -1.0, 1.0) * 0.16 + sin(_anim_t * 3.0) * 0.04
		Gait.QUICA:      # bola: quica alto, achata no chão
			var q = absf(sin(_anim_t * 6.0))
			pos.y = -q * 7.0 * vs
			sq = Vector2(1.0 + 0.16 * (1.0 - q), 1.0 - 0.16 * (1.0 - q)) if q < 0.25 else Vector2(1.0 - 0.05 * q, 1.0 + 0.07 * q)
			step = int(floor(_anim_t * 6.0 / PI))
		Gait.ROBO:       # robô: passo duro, em degraus, sem balanço mole
			var rs = floor(_anim_t * 5.0)
			pos.y = -(1.8 if int(rs) % 2 == 0 else 0.0) * vs
			rot = (0.06 if int(rs) % 2 == 0 else -0.06)
			step = int(rs)
		Gait.BEBADO:     # cambaleia: vai de um lado pro outro e quase cai
			pos.x = sin(_anim_t * 4.0) * 3.5 * vs
			pos.y = -absf(sin(_anim_t * 8.0)) * 1.4 * vs
			rot = sin(_anim_t * 4.0 + 0.8) * 0.24
		Gait.SERPENTE:   # zigue-zague baixo, o corpo acompanha a curva
			pos.x = sin(_anim_t * 6.0) * 4.0 * vs
			rot = cos(_anim_t * 6.0) * 0.18
			sq = Vector2(1.0 + 0.05 * absf(sin(_anim_t * 6.0)), 1.0 - 0.04 * absf(sin(_anim_t * 6.0)))
		Gait.SALTITA:    # pulinhos curtos e rápidos, sem amassar
			pos.y = -absf(sin(_anim_t * 14.0)) * 3.0 * vs
			step = int(floor(_anim_t * 14.0 / PI))
		Gait.NINJA:      # abaixado, inclinado pra frente, passo miúdo
			pos.y = 1.5 * vs - absf(sin(_anim_t * 16.0)) * 0.8 * vs
			rot = clampf(velocity.x / 60.0, -1.0, 1.0) * 0.22
			sq = Vector2(1.06, 0.92)
		Gait.DANCA:      # gira o corpo e balança no ritmo
			pos.y = -absf(sin(_anim_t * 7.0)) * 2.4 * vs
			rot = sin(_anim_t * 3.5) * 0.3
			sq = Vector2(1.0 + 0.06 * sin(_anim_t * 7.0), 1.0 - 0.06 * sin(_anim_t * 7.0))
		_:               # gente: marcha
			pos.y = -absf(sin(_anim_t * 9.0)) * 2.2 * vs
			rot = sin(_anim_t * 9.0) * 0.07
	if stats.anim_amount != 1.0:
		var am = clampf(stats.anim_amount, 0.0, 3.0)
		pos *= am
		rot *= am
		sq = Vector2.ONE + (sq - Vector2.ONE) * am
	# poeira quando o pé (ou o corpo todo) bate no chão
	if step != _step_index:
		_step_index = step
		if is_inside_tree() and !is_preview:
			Fx.burst(get_parent(), position + Vector2(0, 17.0 * vs), Color(0.78, 0.68, 0.5, 0.75), 3, 26.0, 2.0 * minf(vs, 1.8))
	return [pos, rot, sq]


func _attack_anim():
	if target == null or !is_instance_valid(target) or !("global_position" in target):
		return
	var dir = (target.global_position - global_position).normalized()
	if absf(dir.x) > 0.2:
		$Sprite2D.flip_h = dir.x < 0
	var k = minf(_visual_scale, 1.6)
	_lunge = dir * (-4.0 if stats.is_ranged else 9.0) * k
	if Regras.on("peso") and !stats.is_ranged:
		_lunge *= 1.35  # o bote sai do recuo do preparo: mais curso, mais peso
	if !Regras.on("visual"):
		return
	var side = -1.0 if $Sprite2D.flip_h else 1.0
	match _hit_style:
		Hit.GIRO:        # foice em roda: o corpo dá a volta
			_lunge = Vector2.ZERO
			_spin_left = SPIN_TIME
		Hit.PANCADA:     # marretada: desce com tudo, achata e levanta poeira
			_lunge = dir * 13.0 * k
			_slam = 1.0
			if is_inside_tree():
				Fx.ring(get_parent(), target.global_position, 16.0 * k, Color(1, 0.95, 0.8, 0.9), 0.22)
				Fx.burst(get_parent(), target.global_position, Color(0.78, 0.68, 0.5, 0.85), 6, 60.0, 2.6)
		Hit.CABECADA:    # bicho de quatro patas: abaixa a cabeça e arremete
			_lunge = dir * 14.0 * k
			_dip = side * 0.32
		Hit.BICADA:      # ave: bicada curta e seca
			_lunge = dir * 6.0 * k
			_dip = side * 0.5
		Hit.ESTOCADA:    # golpe rápido: toque curto
			_lunge = dir * 6.5 * k
		Hit.MORDIDA:     # duas dentadas seguidas
			_lunge = dir * 8.0 * k
			_dip = side * 0.25
			get_tree().create_timer(0.14, false).timeout.connect(func():
				if is_instance_valid(self) and current_hp > 0:
					_lunge = dir * 8.0 * k
					_dip = side * 0.25)
		Hit.PULAO:       # pula em cima do alvo e cai achatando
			_lunge = dir * 12.0 * k + Vector2(0, -10.0 * k)
			_slam = 0.8
		Hit.TREMOR:      # não sai do lugar: treme e solta uma onda
			_lunge = Vector2.ZERO
			_hit_squash = 1.0
			if is_inside_tree():
				Fx.ring(get_parent(), position, 22.0 * k, Color(1, 0.9, 0.6, 0.9), 0.25)
		Hit.ARREMESSO:   # joga pra trás e solta de cima
			_lunge = -dir * 5.0 * k + Vector2(0, -6.0 * k)
			_dip = -side * 0.35
			get_tree().create_timer(0.1, false).timeout.connect(func():
				if is_instance_valid(self) and current_hp > 0:
					_lunge = dir * 7.0 * k
					_dip = side * 0.3)
		Hit.RAJADA:      # três golpes curtinhos
			for i in 3:
				get_tree().create_timer(0.07 * i, false).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0:
						_lunge = dir * 5.0 * k
						_hit_squash = 0.5)
		Hit.CHICOTE:     # gira um pouco e estala
			_dip = side * 0.6
			_lunge = dir * 4.0 * k
			if is_inside_tree():
				Fx.slash(get_parent(), position + dir * 12.0 * k, dir, 16.0 * k, 90.0, Color(1, 1, 1, 0.8))


## jeito de morrer escolhido na aba "Animação" (0 = fumaça padrão)
func _death_fx():
	var par = get_parent()
	var sc = clampf(_visual_scale, 0.6, 2.2)
	match stats.anim_death:
		1:   # explosão
			Fx.ring(par, position, 34.0 * sc, Color(1.0, 0.6, 0.2), 0.35)
			Fx.burst(par, position, Color(1.0, 0.75, 0.3), 14, 150.0, 4.0)
		2:   # fantasma subindo
			Fx.text(par, position + Vector2(0, -10), "👻", Color(0.9, 0.95, 1.0), 1.1)
			Fx.puff(par, position, sc * 0.6)
		3:   # penas
			Fx.burst(par, position, Color(1, 1, 1), 16, 90.0, 3.5)
			Fx.burst(par, position, Color(0.95, 0.85, 0.6), 8, 60.0, 2.5)
		4:   # moedas
			Fx.burst(par, position, Color(1.0, 0.85, 0.25), 12, 120.0, 4.0)
			Fx.text(par, position + Vector2(0, -14), "$", Color(1.0, 0.9, 0.3))
		5:   # derrete
			Fx.zone(par, position, 18.0 * sc, SpriteForge.main_color(card_data.art_palette) if card_data != null else Color(0.5, 0.8, 0.4), 1.2)
		6:   # clarão
			Fx.ring(par, position, 46.0 * sc, Color(1, 1, 1), 0.25)
			Fx.bolt(par, position, Color(1, 1, 0.8))
		7:   # vira pedra
			Fx.burst(par, position, Color(0.55, 0.55, 0.58), 14, 80.0, 4.5)
			Fx.burst(par, position, Color(0.4, 0.4, 0.44), 6, 50.0, 6.0)
		8:   # afunda no chão
			Fx.zone(par, position + Vector2(0, 8.0 * sc), 16.0 * sc, Color(0.35, 0.25, 0.15), 1.0)
			Fx.burst(par, position + Vector2(0, 6.0 * sc), Color(0.55, 0.42, 0.28), 8, 40.0, 3.0)
		9:   # confete
			for cc in [Color(1, 0.35, 0.4), Color(0.4, 0.8, 1), Color(1, 0.9, 0.3), Color(0.5, 1, 0.5)]:
				Fx.burst(par, position, cc, 5, 140.0, 3.0)
		10:  # choque elétrico
			Fx.bolt(par, position, Color(0.6, 0.85, 1.0))
			Fx.bolt(par, position + Vector2(8, 0), Color(1, 1, 0.6))
			Fx.ring(par, position, 26.0 * sc, Color(0.6, 0.85, 1.0), 0.3)
		_:
			Fx.puff(par, position, sc)


func _apply_unit_scale():
	# VISUAL 2.5: desenho bem maior (as pequenas crescem mais que as gigantes)
	# e corpo um pouco maior -- dá pra reconhecer a carta no campo
	var sprite_mult = stats.unit_scale * Regras.sprite_factor(stats.unit_scale)
	var body_mult = stats.unit_scale * Regras.body_factor(stats.unit_scale)
	if sprite_mult != 1.0:
		$Sprite2D.scale *= sprite_mult
	if body_mult != 1.0:
		$CollisionShape2D.scale *= body_mult


# "andando de verdade" = a posição mudou neste quadro. NÃO dá pra usar a
# velocidade: quando a unidade para pra atacar, a velocidade antiga fica
# guardada -- era por isso que a Assombração ficava imune pra sempre.
var _prev_pos := Vector2.ZERO
var _really_moving := false
var _still_frames := 0


func _physics_process(delta):
	if is_preview:
		return
	if global_position.distance_squared_to(_prev_pos) > 0.02:
		_really_moving = true
		_still_frames = 0
	else:
		_still_frames += 1
		if _still_frames >= 3:  # 3 quadros parada = parou mesmo (não é só um tranco)
			_really_moving = false
	_prev_pos = global_position

	_process_extras(delta)
	_process_new_mechanics(delta)
	_process_ability_fx(delta)
	_process_poison(delta)
	_update_status_modulate()

	_process_forced_move(delta)
	_process_spell_shield()

	# a recarga do ataque conta SEMPRE (antes só contava enquanto estava no
	# alcance -- se o alvo se mexia um pouco, a recarga congelava e o golpe
	# seguinte demorava muito ou nem saía)
	if attack_cooldown > 0:
		attack_cooldown -= delta

	_retarget_check_cooldown -= delta
	if _retarget_check_cooldown <= 0:
		_retarget_check_cooldown = RETARGET_CHECK_INTERVAL
		_check_for_closer_target()

	_formation_check_cooldown -= delta
	if _formation_check_cooldown <= 0:
		_formation_check_cooldown = FORMATION_CHECK_INTERVAL
		_update_formation_speed_cap()

	if stats.duration > 0:
		_duration_remaining = max(_duration_remaining - delta, 0.0)
		$DurationBar.value = _duration_remaining

	if _dash_time_remaining > 0:
		_dash_time_remaining = max(_dash_time_remaining - delta, 0.0)

	if stats.can_heal_allies:
		_process_heal_aura(delta)
	if stats.spawns_units:
		_process_unit_spawning(delta)
	if stats.generates_resource:
		_process_resource_generation(delta)
	if stats.passive_regen:
		_process_regen(delta)
	if stats.shield_recharge_time > 0:
		_process_shield_recharge()

	if _is_incapacitated():
		_set_nav_velocity(Vector2.ZERO)
		return

	if stats.unit_type == UnitData.UnitType.BUILDING:
		_process_building(delta)
		return

	if target == null or !is_instance_valid(target):
		target = null
		_windup_left = -1.0
		find_target()
		_pre_attack_done = false   # alvo novo: pode acelerar de novo ao chegar perto dele

	if target == null:
		_move_towards_base()
	else:
		_process_combat(delta)


func _process_building(delta):
	if target == null or !is_instance_valid(target):
		target = null
		find_target()

	if target == null:
		return

	# construção também TRAVA no alvo enquanto ele estiver no alcance (igual às
	# torres): sem isso ela largava o tanque assim que algo chegava mais perto
	_is_actively_attacking = _in_attack_range(target)
	if _is_actively_attacking:
		_try_attack(delta)
	else:
		_windup_left = -1.0


func _configure_detection_area():
	var col: CollisionShape2D = $Area2D/CollisionShape2D
	col.shape = col.shape.duplicate()

	var sight = stats.detection_range if stats.detection_range > 0 else stats.attack_range
	# quem atira precisa ENXERGAR pelo menos até onde alcança (+ folga do corpo
	# do alvo) -- senão a construção de longo alcance ficava parada sem atirar
	if stats.is_ranged:
		sight = max(sight, stats.attack_range + 40.0)
	var contact_floor = _get_own_target_radius() * 2.0 + 40.0
	# a área de detecção tem escala própria na cena; compensa pra o raio valer em unidades de mundo
	var area_scale = max(min($Area2D.scale.x, $Area2D.scale.y), 0.01)
	col.shape.radius = max(sight, contact_floor) / area_scale

	# a detecção precisa "ver" TODO MUNDO (os dois times, terrestre e
	# aéreo, e construção) -- quem realmente decide se um corpo é um alvo
	# válido é o _can_target()/_is_valid_enemy() em código, não a camada de
	# física. Define isso aqui, em código, pra nunca mais ficar dessincronizado
	# de qualquer mudança futura no esquema de camadas físicas
	const LAYER_GROUND_PLAYER = 0b000001
	const LAYER_GROUND_ENEMY = 0b000010
	const LAYER_AIR_PLAYER = 0b000100
	const LAYER_AIR_ENEMY = 0b001000
	const LAYER_BUILDING = 0b010000
	$Area2D.collision_mask = (
		LAYER_GROUND_PLAYER | LAYER_GROUND_ENEMY |
		LAYER_AIR_PLAYER | LAYER_AIR_ENEMY |
		LAYER_BUILDING
	)


# camada 1 = terrestres, camada 2 = aéreas, camada 3 = construções/base --
# terrestre não colide fisicamente com aérea (ela "voa por cima"), mas as
# duas continuam colidindo com construções normalmente. A mira/combate
# (Area2D + find_target) é 100% separada disso, então nada do combate muda
func _configure_physics_layers():
	# camadas divididas por TIME além de por tipo -- sem isso, unidades do
	# MESMO time colidiam fisicamente entre si (não só com inimigo), e
	# várias convergindo pro mesmo lugar (perto da base) travavam numa
	# aglomeração sólida de verdade, sem conseguir se espremer. Agora só
	# colide fisicamente com inimigo e construção -- entre unidades do
	# mesmo time, só resta o desvio suave (avoidance), que não trava.
	const LAYER_GROUND_PLAYER = 0b000001
	const LAYER_GROUND_ENEMY = 0b000010
	const LAYER_AIR_PLAYER = 0b000100
	const LAYER_AIR_ENEMY = 0b001000
	const LAYER_BUILDING = 0b010000

	if stats.unit_type == UnitData.UnitType.BUILDING:
		collision_layer = LAYER_BUILDING
		collision_mask = 0
	# unidade x unidade NÃO colide mais fisicamente (nem inimiga) -- a
	# colisão "dura" do Godot ignora peso: 5 galinhas de 0.9 viravam uma
	# parede pra vaca de 3.8. Quem resolve o encostão agora é só a
	# separação por peso (_apply_soft_separation). Parede de verdade só
	# construção e base
	elif stats.unit_type == UnitData.UnitType.AIR:
		collision_layer = LAYER_AIR_PLAYER if team == GameManager.Team.PLAYER else LAYER_AIR_ENEMY
		collision_mask = LAYER_BUILDING
	else:
		collision_layer = LAYER_GROUND_PLAYER if team == GameManager.Team.PLAYER else LAYER_GROUND_ENEMY
		collision_mask = LAYER_BUILDING
	# tropa NÃO esbarra nas torres do próprio time: quem é solto atrás da torre
	# passa por ela em vez de ficar preso (o caminho até o inimigo é reto)
	if stats.unit_type != UnitData.UnitType.BUILDING and is_inside_tree():
		for own_tower in get_tree().get_nodes_in_group("player_base" if team == GameManager.Team.PLAYER else "enemy_base"):
			if own_tower is PhysicsBody2D:
				add_collision_exception_with(own_tower)


# raio de DESVIO -- cresce mais devagar que o raio de colisão de verdade
# quando a escala é grande (raiz quadrada em vez de linear), senão uma
# unidade bem grande cria um "campo de força" de desvio desproporcional.
# A colisão em si (_get_target_radius, usada pro alcance de ataque de
# verdade) continua com a escala completa, intacta -- só o desvio amortece
func _get_base_avoidance_radius() -> float:
	var own_radius = _get_own_target_radius()
	if stats.unit_scale > 1.0:
		return own_radius / sqrt(stats.unit_scale)
	return own_radius


func _configure_avoidance():
	nav_agent.avoidance_enabled = true
	nav_agent.radius = _get_base_avoidance_radius()
	nav_agent.max_speed = stats.move_speed
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	# prioridade de desvio baseada no peso -- quem é mais pesado (tanque)
	# desvia MENOS, ficando firme no lugar; quem é mais leve (suporte)
	# desvia MAIS, contornando o pesado. Isso é o sistema de DESVIO em si
	# (RVO), separado da colisão física por peso -- sem isso, o tanque podia
	# "fugir" de um aliado se aproximando por trás, mesmo pesando mais
	nav_agent.avoidance_priority = clamp(stats.push_weight / 3.0, 0.05, 1.0)

	# desvio de multidão também separado por camada: terrestre só desvia de
	# terrestre, aérea só desvia de aérea -- senão elas ficariam "desviando"
	# de unidades que nem colidem de verdade
	if stats.unit_type == UnitData.UnitType.AIR:
		nav_agent.avoidance_layers = 0b010
		nav_agent.avoidance_mask = 0b010
	else:
		nav_agent.avoidance_layers = 0b001
		nav_agent.avoidance_mask = 0b001

	# unidades aéreas sempre atravessam água (voar já implica isso); unidades
	# terrestres só atravessam se tiverem crosses_water ligado -- precisa de
	# uma NavigationRegion2D configurada nessa camada extra sobre a água
	if stats.crosses_water or stats.unit_type == UnitData.UnitType.AIR:
		nav_agent.navigation_layers = 0b11
	else:
		nav_agent.navigation_layers = 0b01


# SEMPRE usa essa função em vez de chamar nav_agent.set_velocity() direto
# -- é o padrão oficial documentado pelo Godot: com desvio LIGADO, passa
# pelo sinal (set_velocity → velocity_computed, que negocia com outros
# agentes antes de aplicar). Com desvio DESLIGADO, chamar set_velocity()
# NÃO funciona direito (é um comportamento conhecido do próprio Godot --
# a velocidade não propaga certo), então chama a função de aplicar
# velocidade DIRETO, sem passar pelo sinal
func _set_nav_velocity(desired_velocity: Vector2):
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		_on_velocity_computed(desired_velocity)


var _stuck_time := 0.0


func _on_velocity_computed(safe_velocity: Vector2):
	var before = global_position
	velocity = safe_velocity
	move_and_slide()
	# ANTI-TRAVA: quer andar mas não saiu do lugar (ex.: nasceu atrás de uma
	# torre ou construção e o caminho é reto por dentro dela). Depois de meio
	# segundo assim, dá passos de lado, pro centro do mapa, até destravar.
	var dt = get_physics_process_delta_time()
	if safe_velocity.length() > 8.0 and global_position.distance_to(before) < safe_velocity.length() * dt * 0.25:
		_stuck_time += dt
	else:
		_stuck_time = maxf(0.0, _stuck_time - dt * 2.0)
	if _stuck_time > 0.5:
		var side = Vector2(1.0 if global_position.x < 0.0 else -1.0, 0.0)
		if absf(global_position.x) < 12.0:
			side = Vector2(1.0 if get_instance_id() % 2 == 0 else -1.0, 0.0)
		velocity = side * maxf(safe_velocity.length(), 40.0)
		move_and_slide()
		if _stuck_time > 1.6:
			_stuck_time = 0.3  # deu uma boa andada de lado: tenta ir reto de novo
	_resolve_weight_collisions()
	_apply_soft_separation()

	if stats.charge_attack:
		_charge_distance_accumulated += get_position_delta().length()


# o Godot não tem massa nativa pra CharacterBody2D -- depois do movimento
# normal, confere se esbarrou em outra unidade MAIS PESADA e, se sim,
# desfaz uma fração do avanço nessa direção (a mais leve cede espaço,
# a mais pesada nem percebe, porque ela roda essa mesma checagem e não
# acha ninguém mais pesado que ela pra ceder)
func _resolve_weight_collisions():
	# construção nunca participa desse sistema -- é parada por design,
	# nunca cede espaço nem empurra ninguém
	if stats.unit_type == UnitData.UnitType.BUILDING:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == null or !("stats" in collider) or collider.stats == null:
			continue

		if collider.stats.push_weight > stats.push_weight:
			# o outro é mais pesado que eu -- eu cedo espaço
			var weight_ratio = collider.stats.push_weight / max(stats.push_weight, 0.1)
			var yield_factor = clamp(weight_ratio - 1.0, 0.0, 1.0)
			global_position -= collision.get_travel() * yield_factor * 0.5
		elif stats.push_weight > collider.stats.push_weight:
			# construção nunca é empurrada -- ela é parada por design, não
			# faz sentido nenhum ela "sair do lugar" só porque uma unidade
			# mais pesada esbarrou nela
			if "stats" in collider and collider.stats != null and collider.stats.unit_type == UnitData.UnitType.BUILDING:
				continue

			# quem já está ATIVAMENTE me atacando não é empurrado -- o
			# empurrão serve pra destravar caminho (unidade tentando
			# atravessar/passar), não pra atrapalhar quem está lutando de
			# propósito contra mim. Sem essa exceção, o empurrão ficava
			# cutucando o atacante pra fora do alcance a cada frame que
			# ficavam encostados, fazendo ele "piscar" entre atacando/não
			# atacando e bater bem menos do que devia
			if "target" in collider and collider.target == self:
				continue

			# EU sou mais pesado -- empurro o outro pra fora do caminho
			# diretamente. Isso cobre o caso que faltava: se o outro estiver
			# PARADO (ex: travado num combate), ele nunca gera colisão na
			# própria lista dele, então o "cede espaço" acima nunca dispara
			# pro lado dele -- sem essa metade, o mais pesado ficava travado
			# tentando avançar contra alguém que nunca sai do lugar
			#
			# usa a NORMAL da colisão (vem da forma física de verdade, sempre
			# bem definida) em vez de "posição menos posição" -- quando duas
			# unidades ficam quase perfeitamente sobrepostas, a distância
			# entre os centros fica quase zero, e normalizar isso dá uma
			# direção instável/quase aleatória -- foi isso que causava
			# unidade "disparando" pro canto da tela do nada
			var weight_ratio = stats.push_weight / max(collider.stats.push_weight, 0.1)
			var push_factor = clamp(weight_ratio - 1.0, 0.0, 1.0)
			var push_dir = -collision.get_normal()  # normal aponta de volta pra mim -- inverto pra apontar pro outro lado
			collider.global_position += push_dir * push_factor * 1.5


# SEPARAÇÃO MACIA (estilo Clash Royale) -- resolve a "mistureba".
# Unidades do mesmo time não colidem fisicamente (camadas separadas por time,
# pra não travar em aglomeração), e o desvio RVO desliga durante combate --
# então aliados acabavam um em cima do outro. Aqui cada unidade, todo frame,
# se afasta de quem estiver SOBREPOSTO a ela (aliado OU inimigo), só o
# suficiente pra desfazer a sobreposição. Cada um move só a SI MESMO, e a
# fatia que cada um cede depende do peso: o mais pesado cede pouco, o leve
# cede muito -- então o tanque "abre caminho" naturalmente.
# Usa um raio um pouco menor que o real (SEPARATION_RADIUS_FRACTION) pra
# nunca afastar quem está corpo a corpo além do alcance mínimo de contato.
const SEPARATION_RADIUS_FRACTION = 0.85
const SEPARATION_STRENGTH = 0.5  # fração da sobreposição resolvida por frame (suaviza, evita tremedeira)
const SEPARATION_MAX_STEP = 8.0  # px máximos por frame, evita "disparar" pro canto

func _apply_soft_separation():
	if stats.unit_type == UnitData.UnitType.BUILDING:
		return
	var my_is_air = stats.unit_type == UnitData.UnitType.AIR
	var my_body = _get_own_target_radius()
	# ESPAÇO PRÓPRIO (visual 2.5): com as tropas maiores, o raio antigo deixava
	# uma em cima da outra (um "bolo" na trilha). Agora cada tropa guarda um
	# espaço do tamanho do desenho dela. Só quem está brigando entre si
	# (atacante e alvo) continua podendo encostar, senão ninguém se alcançava.
	var wide = Regras.spacing()
	var push_total = Vector2.ZERO

	for body in get_tree().get_nodes_in_group("units"):
		if body == self or !is_instance_valid(body) or body.stats == null:
			continue
		var other_is_building = body.stats.unit_type == UnitData.UnitType.BUILDING
		var other_is_air = body.stats.unit_type == UnitData.UnitType.AIR
		# aérea só separa de aérea, terrestre de terrestre (+ construção)
		if !other_is_building and other_is_air != my_is_air:
			continue
		if other_is_building and my_is_air:
			continue

		var offset = global_position - body.global_position
		var fraction = SEPARATION_RADIUS_FRACTION
		if wide > fraction and body != target and body.target != self and !other_is_building:
			fraction = wide
		var min_d = (my_body + body._get_own_target_radius()) * fraction
		var d = offset.length()
		if d >= min_d:
			continue
		if d < 0.01:
			# perfeitamente sobrepostos -- direção estável (baseada no id), nunca aleatória por frame
			var angle = float(get_instance_id() % 628) / 100.0
			offset = Vector2.RIGHT.rotated(angle)
			d = 0.01
		var overlap = min_d - d

		var my_share = 1.0
		if !other_is_building:
			# peso AO QUADRADO: diferença de peso pesa muito mais. Vaca 3.8 x
			# galinha 0.9 -> a galinha cede 95%, a vaca só 5% (antes 81%/19%,
			# e várias galinhas juntas ainda seguravam a vaca)
			var my_w = max(stats.push_weight, 0.1)
			var their_w = max(body.stats.push_weight, 0.1)
			my_share = (their_w * their_w) / (my_w * my_w + their_w * their_w)

		push_total += (offset / d) * overlap * my_share * SEPARATION_STRENGTH

	if push_total != Vector2.ZERO:
		global_position += push_total.limit_length(SEPARATION_MAX_STEP)


# ---------- MOVIMENTO ----------

# anda pra torre inimiga MAIS PERTO: com o portão de pé é ele (fica no meio
# e na frente); depois que ele cai, a torre de trás da "sua" rota. E
# troca sozinha quando ela cai
var lane := 99   # rota: -1 esquerda, 0 meio, 1 direita (99 = ainda não escolhida; vale a posição em que foi solta)


func _refresh_enemy_tower():
	var group = "enemy_base" if team == GameManager.Team.PLAYER else "player_base"
	var best = null
	var best_d = INF
	if Regras.routes():
		# ROTAS: a torre é a do fim da rota onde a tropa foi solta. Só quando
		# ela já caiu é que vale "a mais perto"
		if lane == 99:
			lane = Regras.lane_of(global_position.x)
		var mine = Regras.route_tower(get_tree(), team, lane)
		if mine != null:
			enemy_base = mine
			return
	for t in get_tree().get_nodes_in_group(group):
		if !is_instance_valid(t) or t.is_queued_for_deletion() or ("hp" in t and t.hp <= 0):
			continue
		var d = global_position.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	enemy_base = best


func _move_towards_base():
	if enemy_base == null or !is_instance_valid(enemy_base) or enemy_base.is_queued_for_deletion():
		_refresh_enemy_tower()
	if _is_rooted():
		_set_nav_velocity(Vector2.ZERO)
		return
	if enemy_base != null and is_instance_valid(enemy_base):
		var dir_base = _get_nav_direction(enemy_base.global_position)
		_set_nav_velocity(dir_base * _get_move_speed())
	else:
		_set_nav_velocity(Vector2.ZERO)


func _process_combat(delta):
	var target_is_base = _is_base(target)
	_is_actively_attacking = _in_attack_range(target)
	if stats.bandit_dash and !_has_dashed and !_is_actively_attacking:
		_start_bandit_dash()  # achou o alvo enquanto entrava em campo: avança agora

	# Clash Royale de verdade NÃO usa desvio inteligente (RVO) entre
	# unidades -- cada uma trava no alvo e anda RETO até ele; o empurrão
	# físico (_resolve_weight_collisions, sistema separado) resolve
	# esbarrão pelo caminho. RVO serve pra desviar de OBSTÁCULO/TERRENO,
	# não pra "negociar" espaço com o próprio alvo que a unidade quer
	# encostar -- por isso desliga o desvio de vez enquanto perseguindo
	# alvo de combate (liga de novo assim que volta a andar rumo à base,
	# onde ainda ajuda a desviar de obstáculo de verdade)
	# em combate o desvio RVO fica desligado (alvo unidade OU base): quem
	# resolve aglomeração agora é a separação por peso. Com RVO ligado perto
	# da base, a fila de aliados "negociava" espaço e tinha unidade que nunca
	# chegava a encostar na base pra bater
	nav_agent.avoidance_enabled = false
	if target_is_base:
		pass

	if !_is_actively_attacking:
		_windup_left = -1.0  # o alvo saiu do alcance: desarma o golpe
		if _is_rooted():
			_set_nav_velocity(Vector2.ZERO)
		else:
			var dir = _get_nav_direction(target.global_position)
			_set_nav_velocity(dir * _get_move_speed())
	else:
		_set_nav_velocity(Vector2.ZERO)
		if stats.continuous_attack:
			_perform_continuous_attack(delta)
		else:
			_try_attack(delta)


func _get_move_speed() -> float:
	var speed = stats.move_speed * speed_multiplier * module_speed_bonus * _rage_mult(_rage_speed)
	var sprint = false
	if _dash_time_remaining > 0:
		speed *= stats.dash_speed_multiplier
		sprint = true
	# ACELERA PERTO DO ALVO: do momento em que chega perto até dar o primeiro golpe nele.
	# (Antes acelerava por um tempinho assim que ACHAVA o alvo -- quase sempre a torre, lá do
	# outro lado -- e o efeito acabava muito antes de chegar: parecia que não funcionava.)
	if stats.pre_attack_speed_boost and !_pre_attack_done and target != null and is_instance_valid(target) and _gap_to(target) <= stats.pre_attack_boost_range:
		speed *= stats.pre_attack_boost_multiplier
		sprint = true
	# INVESTIDA: já andou metade do caminho do golpe carregado = está correndo
	if stats.charge_attack and stats.charge_speed_mult != 1.0 and _charge_distance_accumulated >= stats.charge_distance_needed * 0.5:
		speed *= stats.charge_speed_mult
		sprint = true
	if _late_on:
		speed *= stats.late_boost_speed_mult
	_sprinting = sprint
	# quem está correndo de propósito não espera a formação
	if _formation_speed_cap >= 0.0 and !sprint:
		speed = min(speed, _formation_speed_cap)
	return speed


# procura um aliado mais PESADO que eu (push_weight maior) que já esteja
# mais perto do alvo (mais "na frente") -- se achar, trava minha velocidade
# na dele, pra eu nunca ultrapassar só por ser naturalmente mais rápido.
# É isso que garante tanque na frente/suporte atrás por design, não só por
# sorte de física -- o peso sozinho só resolve "quem vence esbarrão", não
# "quem lidera a formação com o tempo"
func _update_formation_speed_cap():
	_formation_speed_cap = -1.0

	if enemy_base == null or !is_instance_valid(enemy_base):
		return

	# usa a base inimiga como referência, NÃO o alvo de combate individual --
	# tanque e aliado quase sempre miram em alvos DIFERENTES, então comparar
	# "quem está mais perto do MEU alvo" não fazia sentido nenhum (o aliado
	# podia nem estar indo na direção desse alvo). A base é um ponto em
	# comum de verdade, pra qualquer unidade do time, resolvendo isso
	# unidade AÉREA voa por cima de todo mundo -- nunca segura o passo atrás
	# de ninguém (antes ficava presa atrás do tanque terrestre)
	if stats.unit_type == UnitData.UnitType.AIR:
		return
	var my_dist_to_base = global_position.distance_to(enemy_base.global_position)
	var to_base = (enemy_base.global_position - global_position).normalized()

	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team != team:
			continue
		if !("stats" in body) or body.stats == null:
			continue
		# construção nunca anda -- travar a velocidade nela deixaria a
		# unidade presa pra sempre, já que a trava só solta quando o
		# "líder" anda mais rápido de novo, o que nunca acontece com construção
		if body.stats.unit_type == UnitData.UnitType.BUILDING:
			continue
		# só segura atrás de quem anda no CHÃO como ela, e que esteja
		# realmente NA FRENTE (no caminho até a base), não do lado
		if body.stats.unit_type == UnitData.UnitType.AIR:
			continue
		if to_base.dot((body.global_position - global_position).normalized()) < 0.6:
			continue
		if body.stats.push_weight <= stats.push_weight:
			continue
		if global_position.distance_to(body.global_position) > FORMATION_CHECK_RADIUS:
			continue

		var their_dist_to_base = body.global_position.distance_to(enemy_base.global_position)
		if their_dist_to_base < my_dist_to_base:
			_formation_speed_cap = body._get_move_speed()
			return


func _get_nav_direction(target_pos: Vector2) -> Vector2:
	nav_agent.target_position = target_pos
	var next_point = nav_agent.get_next_path_position()
	var dir = (next_point - global_position).normalized()

	# se a navegação não conseguir calcular um próximo ponto de verdade --
	# ex: a unidade ficou fora da malha navegável, empurrada pra uma zona
	# sem caminho -- a direção sai zerada e ela fica travada pra sempre,
	# "não querendo ir" pra lugar nenhum. Nesse caso, usa linha reta até o
	# alvo como saída de emergência, só pra ela conseguir voltar a se mexer
	if dir == Vector2.ZERO:
		dir = (target_pos - global_position).normalized()

	if _confused_until > GameManager.game_time:
		dir = -dir

	return dir


func _is_base(body) -> bool:
	return body.is_in_group("enemy_base") or body.is_in_group("player_base")


# se o alvo for uma base, avisa a cena de batalha pra ela acumular o dano
# por CARTA (não por unidade individual) -- usado depois pro bot aprender
# qual carta inimiga mais o machucou, e reagir com uma contra-carta
func _report_base_damage(body, amount: float):
	if !_is_base(body) or card_data == null:
		return
	var battle = get_tree().get_first_node_in_group("battle_scene")
	if battle != null and battle.has_method("record_base_damage_by_card"):
		battle.record_base_damage_by_card(card_data.resource_path, amount, body.is_in_group("player_base"))


func _get_target_radius(body) -> float:
	var col = body.get_node_or_null("CollisionShape2D")
	if col != null and col.shape != null:
		var shape = col.shape
		if shape is CircleShape2D:
			return shape.radius * col.scale.x
		elif shape is CapsuleShape2D:
			return shape.radius * col.scale.x
		elif shape is RectangleShape2D:
			return max(shape.size.x, shape.size.y) * 0.5 * col.scale.x

	# formato irregular (comum em construção/base) -- pega o vértice mais
	# distante do centro do polígono como aproximação do raio
	var poly = body.get_node_or_null("CollisionPolygon2D")
	if poly != null and poly.polygon.size() > 0:
		var max_dist = 0.0
		for point in poly.polygon:
			max_dist = max(max_dist, point.length())
		return max_dist * poly.scale.x

	var sprite = body.get_node_or_null("Sprite2D")
	if sprite != null and sprite.texture != null:
		var size = sprite.texture.get_size() * sprite.scale
		return max(size.x, size.y) * 0.5

	return 20.0


# ponto da SUPERFÍCIE de `body` mais perto de `from` -- usa o formato real
# da colisão: retângulo (base), cápsula (unidade, comprida na vertical) ou
# círculo. Antes tudo era tratado como círculo pelo lado menor
func _closest_surface_point(body, from: Vector2) -> Vector2:
	var col = body.get_node_or_null("CollisionShape2D")
	if col != null and col.shape != null:
		var xf: Transform2D = col.global_transform
		var local = xf.affine_inverse() * from
		var shape = col.shape
		if shape is RectangleShape2D:
			var half = shape.size / 2.0
			return xf * Vector2(clamp(local.x, -half.x, half.x), clamp(local.y, -half.y, half.y))
		if shape is CapsuleShape2D:
			var seg = max(shape.height / 2.0 - shape.radius, 0.0)
			var core = Vector2(0, clamp(local.y, -seg, seg))
			var dir = local - core
			var surf = core + (dir.normalized() * shape.radius if dir.length() > 0.001 else Vector2(shape.radius, 0))
			return xf * surf
		if shape is CircleShape2D:
			var d = local.normalized() if local.length() > 0.001 else Vector2.RIGHT
			return xf * (d * shape.radius)
	var c = body.global_position
	var r = _get_target_radius(body)
	var dd = (from - c)
	return c + (dd.normalized() * r if dd.length() > 0.001 else Vector2.ZERO)


# distância do MEU CENTRO até a borda do outro (usada pelo ataque à distância)
func _edge_distance(body) -> float:
	var p = _closest_surface_point(body, global_position)
	return global_position.distance_to(p)


# folga entre a MINHA borda e a borda do outro (usada pelo corpo a corpo):
# acha o ponto do outro mais perto de mim e mede até a minha superfície
func _gap_to(body) -> float:
	var p = _closest_surface_point(body, global_position)
	var mine = _closest_surface_point(self, p)
	var to_p = global_position.distance_to(p)
	var to_mine = global_position.distance_to(mine)
	return max(to_p - to_mine, 0.0)


# regra ÚNICA de alcance pra todo mundo:
#  - corpo a corpo: alcance = folga entre a MINHA borda e a borda do alvo
#    (encostou, bate -- não importa o tamanho nem o formato de ninguém)
#  - à distância: alcance = do meu centro até a borda do alvo
const MELEE_MIN_REACH = 8.0

func _in_attack_range(body) -> bool:
	if body == null or !is_instance_valid(body):
		return false
	if stats.min_attack_range > 0.0 and _edge_distance(body) < stats.min_attack_range:
		return false   # perto demais: o morteiro não consegue mirar
	if stats.is_ranged:
		return _edge_distance(body) <= stats.attack_range
	return _gap_to(body) <= max(stats.attack_range, MELEE_MIN_REACH)


func _get_own_target_radius() -> float:
	return _get_target_radius(self)


func _get_min_contact_range(body) -> float:
	return _get_own_target_radius() + _get_target_radius(body)


# ---------- COMBATE ----------

func _try_attack(delta):
	var period = stats.attack_speed * _attack_speed_ramp_multiplier / _rage_mult(_rage_attack_speed)
	var windup = Regras.windup_time(stats)
	if windup <= 0.0:
		if attack_cooldown <= 0:
			if is_instance_valid(target):
				_perform_attack()
			attack_cooldown = period
		return
	# PESO: o golpe tem preparo. A tropa "arma" o ataque (dá pra ver) e só
	# então acerta. O intervalo entre golpes continua o mesmo.
	windup = minf(windup, period * 0.6)
	if _windup_left >= 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_windup_left = -1.0
			if is_instance_valid(target):
				_perform_attack()
			attack_cooldown = maxf(period - _windup_total, 0.05)
		return
	if attack_cooldown <= 0 and is_instance_valid(target):
		_windup_total = windup
		_windup_left = windup
		_aim_dir = (target.global_position - global_position).normalized() if "global_position" in target else Vector2.UP
		if absf(_aim_dir.x) > 0.2:
			$Sprite2D.flip_h = _aim_dir.x < 0


func _perform_continuous_attack(delta):
	if target == null or !is_instance_valid(target):
		return
	_reveal_disguise()
	var dmg = stats.continuous_damage_per_second * delta * damage_multiplier
	target.take_damage(dmg)
	_report_base_damage(target, dmg)


func _get_effective_damage() -> int:
	var dmg = float(stats.damage) * damage_multiplier * _rage_mult(_rage_damage)

	if stats.first_attack_bonus and !_has_attacked_before:
		dmg *= stats.first_attack_multiplier

	if stats.ramping_damage:
		dmg *= _damage_ramp_multiplier

	if stats.same_target_ramping_damage:
		dmg *= _same_target_ramp_multiplier

	# DANO EM CONSTRUÇÃO: multiplica o dano em construção e torre
	if stats.building_damage_mult != 1.0 and target != null and is_instance_valid(target):
		var is_bld = target.is_in_group("player_base") or target.is_in_group("enemy_base") or ("stats" in target and target.stats != null and target.stats.unit_type == UnitData.UnitType.BUILDING)
		if is_bld:
			dmg *= maxf(stats.building_damage_mult, 0.0)
	# DANO DE PERTO (caçador): quanto mais perto, mais forte
	if stats.close_damage_bonus > 0.0 and target != null and is_instance_valid(target):
		var gap_c = _edge_distance(target)
		dmg *= 1.0 + stats.close_damage_bonus * clampf(1.0 - gap_c / maxf(stats.attack_range, 1.0), 0.0, 1.0)

	# franco-atirador: dano a mais quanto mais longe o alvo estiver
	if stats.distance_damage_bonus_per_100px > 0 and target != null and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		dmg *= (1.0 + (dist / 100.0) * stats.distance_damage_bonus_per_100px)

	# execução: alvo com vida abaixo do limite configurado leva dano extra
	if stats.execute_threshold > 0 and target != null and is_instance_valid(target):
		if "current_hp" in target and "stats" in target and target.stats != null:
			var target_hp_fraction = float(target.current_hp) / target.stats.hp
			if target_hp_fraction <= stats.execute_threshold:
				dmg *= stats.execute_damage_mult

	# fúria por vida baixa: a PRÓPRIA unidade causa mais dano com pouca vida
	if stats.low_hp_rage_threshold > 0:
		var own_hp_fraction = float(current_hp) / stats.hp
		if own_hp_fraction <= stats.low_hp_rage_threshold:
			dmg *= stats.low_hp_rage_damage_mult

	# especialista contra categoria: dano a mais contra unidade de uma
	# categoria específica (ex: +50% contra Aéreo)
	if stats.extra_damage_vs_role_mult > 0 and target != null and is_instance_valid(target):
		if "stats" in target and target.stats != null and target.stats.role == stats.extra_damage_vs_role:
			dmg *= (1.0 + stats.extra_damage_vs_role_mult)

	if stats.grows_over_time:
		dmg *= _grow_mult
	if _late_on:
		dmg *= stats.late_boost_damage_mult
	if _dash_bonus_pending:
		dmg *= stats.dash_damage_mult   # o golpe que vem logo depois de um avanço
		_dash_bonus_pending = false
	_pre_attack_done = true            # deu o golpe: a aceleração de chegada acabou
	return round(dmg)


## construção escondida debaixo da terra: sem alvo, ninguém acerta nem escolhe ela
func is_hidden() -> bool:
	if stats != null and stats.is_trap and !_trap_sprung and current_hp > 0:
		return true   # armadilha armada: ninguém vê nem acerta
	return stats != null and stats.hides_underground and (target == null or !is_instance_valid(target)) and current_hp > 0


# ---- mecânicas da leva "aura, pulso, rastro, cresce, armadilha, pisca"
var _grow_mult := 1.0
var _grow_clock := 0.0
var _aura_clock := 0.0
var _pulse_clock := 0.0
var _trail_last := Vector2.INF
var _trap_sprung := false
var _trap_shown := false
var _blink_clock := 0.0
var _pre_attack_done := false
var _decay_acc := 0.0
var _collect_clock := 0.0
var _zap_ready := {}   # quem já levou choque de volta há pouco (instance_id -> hora)
var _sprinting := false
var _afx_clock := 0.0
var _afx_tint := Color(1, 1, 1)
var ability_cue := ""   # o que a tropa está mostrando agora (os testes leem isto)
var _dash_clock := 0.0
var _dash_bonus_pending := false
var _jump_clock := 0.0
var _jump_left := -1.0
var _jump_from := Vector2.ZERO
var _jump_to := Vector2.ZERO
var _jump_height := 0.0
var _late_on := false
var _alive_t := 0.0
const JUMP_TIME = 0.45
var _repair_clock := 0.0
var _ward_listed := false
var _ward_fx := 0.0


## ANIMAÇÃO DAS HABILIDADES: a tropa MOSTRA o que está fazendo -- risco de vento quando
## acelera, brilho dourado quando o golpe forte está pronto, faísca enquanto carrega,
## vermelho na fúria, laranja quando esquentou, verde regenerando.
func _process_ability_fx(delta):
	if is_preview or stats == null or current_hp <= 0 or !Regras.on("visual"):
		return
	var par = get_parent()
	var sp: Sprite2D = get_node_or_null("Sprite2D")
	var tint = Color(1, 1, 1)
	var cue = ""
	var moving = _really_moving and velocity.length() > 8.0
	var charging = stats.charge_attack and moving and _charge_distance_accumulated >= stats.charge_distance_needed * 0.5
	var charged = stats.charge_attack and _charge_distance_accumulated >= stats.charge_distance_needed
	var strong_next = _dash_bonus_pending or (stats.first_attack_bonus and !_has_attacked_before and target != null and is_instance_valid(target)) or charged
	var raging = (stats.low_hp_rage_threshold > 0.0 and float(current_hp) / maxf(float(stats.hp), 1.0) <= stats.low_hp_rage_threshold) or _rage_until > GameManager.game_time
	var fast = moving and (_sprinting or _dash_time_remaining > 0.0)
	if _late_on:
		tint = Color(1.0, 0.8, 0.6)
		cue = "esquentou"
	if raging:
		tint = Color(1.0, 0.72, 0.72)
		cue = "furia"
	if strong_next:
		var pulse = 0.5 + 0.5 * sin(GameManager.game_time * 12.0)
		tint = Color(1.0, 0.95, 0.55).lerp(Color(1, 1, 1), pulse * 0.5)
		cue = "golpe forte pronto"
	elif charging:
		cue = "carregando"
	# TIRO CARREGADO: mostra a carga enchendo e avisa quando está pronta
	var charge_k = -1.0
	if stats.charged_shot:
		charge_k = clampf(1.0 - attack_cooldown / maxf(stats.attack_speed, 0.1), 0.0, 1.0)
		if charge_k >= 1.0:
			var pulse2 = 0.5 + 0.5 * sin(GameManager.game_time * 14.0)
			tint = Color(1.0, 0.95, 0.5).lerp(Color(1, 1, 1), pulse2 * 0.5)
			cue = "tiro carregado pronto"
		else:
			cue = "carregando tiro"
	if fast:
		cue = "acelerando" if cue == "" or cue == "esquentou" else cue + " + acelerando"
	if _jump_left >= 0.0:
		cue = "saltando"
	ability_cue = cue
	if sp != null:
		_afx_tint = _afx_tint.lerp(tint, minf(1.0, delta * 10.0))
		sp.self_modulate = Color(_afx_tint.r, _afx_tint.g, _afx_tint.b, sp.self_modulate.a)
	_afx_clock -= delta
	if _afx_clock > 0.0:
		return
	_afx_clock = 0.14
	var back = -velocity.normalized() if velocity.length() > 1.0 else Vector2.ZERO
	if fast:
		# riscos de vento e poeira saindo por trás
		Fx.burst(par, position + back * 10.0 + Vector2(0, 8.0 * _visual_scale), Color(1, 1, 1, 0.8), 2, 30.0, 2.5)
		Fx.slash(par, position + back * 14.0, back, 12.0 * _visual_scale, 50.0, Color(1, 1, 1, 0.7))
	if charge_k >= 0.0:
		# anel que cresce com a carga; cheio, fica pulsando com faísca
		Fx.ring(par, position + Vector2(0, -10.0 * _visual_scale), (5.0 + 13.0 * charge_k) * _visual_scale, Color(1.0, 0.9, 0.3, 0.35 + 0.5 * charge_k), 0.2)
		if charge_k >= 1.0:
			Fx.burst(par, position + Vector2(randf_range(-9, 9), randf_range(-22, -4)) * _visual_scale, Color(1.0, 1.0, 0.6), 2, 40.0, 2.5)
	if charging and !charged:
		Fx.burst(par, position + Vector2(randf_range(-8, 8), randf_range(-16, 0)) * _visual_scale, Color(1.0, 0.9, 0.4), 1, 20.0, 2.5)
	if strong_next:
		Fx.ring(par, position, 14.0 * _visual_scale, Color(1.0, 0.9, 0.35, 0.8), 0.25)
	if raging and randf() < 0.5:
		Fx.burst(par, position + Vector2(0, -20.0 * _visual_scale), Color(1.0, 0.35, 0.25), 1, 30.0, 3.0)
	if _late_on and randf() < 0.4:
		Fx.burst(par, position + Vector2(randf_range(-6, 6), -14.0 * _visual_scale), Color(1.0, 0.6, 0.2), 1, 26.0, 3.0)
	if stats.passive_regen and current_hp < stats.hp and randf() < 0.3:
		Fx.text(par, position + Vector2(randf_range(-8, 8), -22.0 * _visual_scale), "+", Color(0.45, 1.0, 0.5), 0.5)
	if stats.ramping_damage and _damage_ramp_multiplier > 1.05 and randf() < 0.25:
		Fx.burst(par, position + Vector2(0, -24.0 * _visual_scale), Color(1.0, 0.5, 0.2), 1, 18.0, 2.0 + 2.0 * (_damage_ramp_multiplier - 1.0))
	if stats.damage_reduction_percent > 0.0 and randf() < 0.06:
		Fx.ring(par, position, 16.0 * _visual_scale, Color(0.7, 0.8, 0.95, 0.5), 0.35)


func _enemies_within(r: float, ground_only: bool = false) -> Array:
	var out: Array = []
	for body in get_tree().get_nodes_in_group("units"):
		if !is_instance_valid(body) or body == self or !("team" in body) or body.team == team or body.is_queued_for_deletion() or body.stats == null:
			continue
		if body.has_method("is_hidden") and body.is_hidden():
			continue
		if ground_only and body.stats.unit_type == UnitData.UnitType.AIR:
			continue
		if global_position.distance_to(body.global_position) <= r:
			out.append(body)
	return out


func _process_new_mechanics(delta):
	if current_hp <= 0:
		return
	# AURA: reforça os aliados em volta (a fúria vale o maior valor, então duas auras não somam)
	if stats.aura_buff:
		_aura_clock -= delta
		if _aura_clock <= 0.0:
			_aura_clock = 0.5
			for body in get_tree().get_nodes_in_group("units"):
				if is_instance_valid(body) and body != self and "team" in body and body.team == team and body.has_method("apply_rage") \
						and global_position.distance_to(body.global_position) <= stats.aura_radius:
					body.apply_rage(stats.aura_damage_mult, stats.aura_speed_mult, stats.aura_attack_speed_mult, 0.8)
			if Regras.on("visual"):
				Fx.ring(get_parent(), position, stats.aura_radius, Color(1.0, 0.85, 0.35, 0.5), 0.5)
	# PULSO: onda em volta de tempos em tempos
	if stats.pulses:
		_pulse_clock += delta
		if _pulse_clock >= maxf(stats.pulse_interval, 0.5):
			var hit = _enemies_within(stats.pulse_radius)
			if !hit.is_empty():
				_pulse_clock = 0.0
				Fx.ring(get_parent(), position, stats.pulse_radius, Color(0.7, 0.9, 1.0), 0.4)
				for body in hit:
					if stats.pulse_damage > 0:
						body.take_damage(int(round(stats.pulse_damage * _level_mult_safe())))
					if stats.pulse_effect != UnitData.OnHitEffect.NONE and is_instance_valid(body) and body.has_method("apply_on_hit_effect"):
						body.apply_on_hit_effect(stats.pulse_effect, stats.pulse_effect_strength, stats.pulse_effect_duration, 1.0, 30.0, global_position)
	# RASTRO: uma poça a cada pedaço andado
	if stats.leaves_trail and stats.unit_type != UnitData.UnitType.BUILDING:
		if _trail_last == Vector2.INF or _trail_last.distance_to(global_position) >= stats.trail_radius * 1.3:
			_trail_last = global_position
			Poca.drop(get_parent(), position, team, int(round(stats.trail_damage * _level_mult_safe())), stats.trail_radius, stats.trail_duration,
				stats.trail_slow, Color(0.5, 0.85, 0.3) if stats.trail_slow <= 0.0 else Color(0.55, 0.4, 0.25))
	# VIDA ÚTIL: a vida cai sozinha até acabar no tempo marcado
	if stats.lifetime > 0.0 and current_hp > 0:
		_decay_acc += float(stats.hp) / stats.lifetime * delta
		if _decay_acc >= 1.0:
			var lose = int(_decay_acc)
			_decay_acc -= lose
			current_hp = maxi(current_hp - lose, 0)
			_refresh_bar()
			if current_hp <= 0:
				die()
				return
	# COLETOR: dá recurso pro dono de tempos em tempos
	if stats.produces_resource:
		_collect_clock += delta
		if _collect_clock >= maxf(stats.resource_interval, 1.0):
			_collect_clock = 0.0
			_grant_gold(stats.resource_amount)
			if Regras.on("visual"):
				Fx.text(get_parent(), position + Vector2(0, -28.0 * _visual_scale), "+%d" % stats.resource_amount, Color(0.95, 0.5, 1.0))
	# TIRO CARREGADO: a primeira carga começa quando entra em campo
	if stats.charged_shot and !_charge_primed:
		_reset_charged_shot()
	# VÁRIOS AVANÇOS: o avanço da bandida volta a cada intervalo, se o alvo ainda está longe
	if stats.bandit_dash and stats.dash_repeats and _has_dashed and _dash_time_remaining <= 0.0 and stats.unit_type != UnitData.UnitType.BUILDING:
		_dash_clock += delta
		if _dash_clock >= maxf(stats.dash_cooldown, 0.5) and target != null and is_instance_valid(target) and !_is_incapacitated() and _gap_to(target) >= stats.dash_min_range:
			_start_bandit_dash()
			if Regras.on("visual"):
				Fx.puff(get_parent(), position, 0.7)
	# ESQUENTA: depois de um tempo em campo ganha dano e/ou passo
	if stats.late_boost_after > 0.0 and !_late_on:
		_alive_t += delta
		if _alive_t >= stats.late_boost_after:
			_late_on = true
			Fx.ring(get_parent(), position, 30.0, Color(1.0, 0.5, 0.2), 0.4)
			Fx.text(get_parent(), position + Vector2(0, -30), "ESQUENTOU!", Color(1.0, 0.6, 0.25))
	# SALTO: pula em cima do alvo a meia distância e cai dando dano em área
	if stats.jump_attack and stats.unit_type != UnitData.UnitType.BUILDING:
		if _jump_left >= 0.0:
			_jump_left -= delta
			var k = clampf(1.0 - _jump_left / JUMP_TIME, 0.0, 1.0)
			global_position = _jump_from.lerp(_jump_to, k)
			_jump_height = sin(k * PI) * 46.0
			if _jump_left <= 0.0:
				_jump_left = -1.0
				_jump_height = 0.0
				_slam = 1.0
				_deal_area_damage(global_position, stats.jump_radius, int(round(stats.jump_damage * _level_mult_safe())), true)
				Fx.burst(get_parent(), position, Color(0.78, 0.68, 0.5, 0.9), 12, 130.0, 3.5)
		else:
			_jump_clock += delta
			if _jump_clock >= maxf(stats.jump_cooldown, 0.8) and target != null and is_instance_valid(target) and !_is_incapacitated():
				var gap = _gap_to(target)
				if gap >= stats.jump_min_range and gap <= stats.jump_max_range:
					_jump_clock = 0.0
					_hit_squash = 1.0   # agacha pra pegar impulso
					Fx.ring(get_parent(), position, 18.0 * _visual_scale, Color(1, 1, 1, 0.7), 0.2)
					_jump_left = JUMP_TIME
					_jump_from = global_position
					var to_t = target.global_position - global_position
					_jump_to = global_position + to_t.normalized() * maxf(gap - 6.0, 0.0)
					_spawn_invulnerable_until = maxf(_spawn_invulnerable_until, GameManager.game_time + JUMP_TIME)   # no ar ninguém acerta
	# CONSERTA: devolve vida pras construções aliadas em volta (e torres, se ligado)
	if stats.repairs_buildings:
		_repair_clock += delta
		if _repair_clock >= maxf(stats.repair_interval, 0.3):
			_repair_clock = 0.0
			var amount_r = int(round(stats.repair_amount * _level_mult_safe()))
			for body in get_tree().get_nodes_in_group("units"):
				if is_instance_valid(body) and body != self and "team" in body and body.team == team and body.stats != null \
						and body.stats.unit_type == UnitData.UnitType.BUILDING and body.current_hp > 0 and body.current_hp < body.stats.hp \
						and global_position.distance_to(body.global_position) <= stats.repair_radius:
					body.heal(amount_r)
			if stats.repair_towers:
				for t in BattleBrain.get_bases(get_tree(), team):
					if is_instance_valid(t) and "hp" in t and "max_hp" in t and t.hp > 0 and t.hp < t.max_hp and global_position.distance_to(t.global_position) <= stats.repair_radius:
						if t.has_method("heal"):
							t.heal(amount_r)
						else:
							t.hp = mini(t.hp + amount_r, t.max_hp)
			if Regras.on("visual"):
				Fx.ring(get_parent(), position, stats.repair_radius, Color(0.45, 1.0, 0.5, 0.5), 0.45)
	# CÚPULA: entra na lista de quem protege (sai sozinha quando morre)
	if stats.ward_allies and !_ward_listed:
		_ward_listed = true
		wards = wards.filter(func(w): return is_instance_valid(w) and w.current_hp > 0)
		wards.append(self)
	if stats.ward_allies and Regras.on("visual"):
		_ward_fx -= delta
		if _ward_fx <= 0.0:
			_ward_fx = 1.2
			Fx.ring(get_parent(), position, stats.ward_radius, Color(0.5, 0.75, 1.0, 0.45), 0.6)
	# CRESCE: mais dano a cada intervalo no campo
	if stats.grows_over_time and _grow_mult < stats.grow_max_mult:
		_grow_clock += delta
		if _grow_clock >= maxf(stats.grow_interval, 0.5):
			_grow_clock = 0.0
			_grow_mult = minf(_grow_mult + stats.grow_damage_step, stats.grow_max_mult)
			if Regras.on("visual"):
				Fx.text(get_parent(), position + Vector2(0, -30), "+%d%%" % int(round((_grow_mult - 1.0) * 100.0)), Color(1.0, 0.8, 0.3))
	# ARMADILHA: armada (quase invisível) até um inimigo do chão chegar perto
	if stats.is_trap and !_trap_sprung:
		if !_trap_shown:
			_trap_shown = true
			var sp = get_node_or_null("Sprite2D")
			if sp != null:
				sp.modulate.a = 0.35
		_trap_sprung = !_enemies_within(stats.trap_trigger_radius, true).is_empty()
		if _trap_sprung:
			Fx.ring(get_parent(), position, stats.trap_radius, Color(1.0, 0.5, 0.2), 0.45)
			Fx.burst(get_parent(), position, Color(1.0, 0.6, 0.25), 16, stats.trap_radius * 2.0, 4.0)
			Sfx.play("explosao")
			for body in _enemies_within(stats.trap_radius):
				body.take_damage(int(round(stats.trap_damage * _level_mult_safe())))
				if stats.trap_effect != UnitData.OnHitEffect.NONE and is_instance_valid(body) and body.has_method("apply_on_hit_effect"):
					body.apply_on_hit_effect(stats.trap_effect, 0.5, stats.trap_effect_duration, 1.0, 40.0, global_position)
			die()
			return
	# PISCA: teleporta pra perto do alvo que está longe
	if stats.blinks and stats.unit_type != UnitData.UnitType.BUILDING:
		_blink_clock += delta
		if _blink_clock >= maxf(stats.blink_interval, 1.0) and target != null and is_instance_valid(target) and !_is_incapacitated():
			var d = global_position.distance_to(target.global_position)
			var reach = stats.attack_range + 40.0
			if d > reach + 30.0 and d <= stats.blink_range:
				_blink_clock = 0.0
				Fx.puff(get_parent(), position)
				global_position = target.global_position + (global_position - target.global_position).normalized() * reach * 0.8
				Fx.ring(get_parent(), position, 22.0, Color(0.8, 0.6, 1.0), 0.3)


var _rider_clock := 0.0
var _hidden_shown := false


## esconder (visual) e o SEGUNDO ATAQUE: roda todo quadro, fora do golpe normal
func _process_extras(delta):
	if stats.hides_underground:
		var h = is_hidden()
		if h != _hidden_shown:
			_hidden_shown = h
			var sp = get_node_or_null("Sprite2D")
			if sp != null:
				sp.modulate.a = 0.3 if h else 1.0
				sp.position.y += 10.0 if h else -10.0
	if !stats.rider_attack or stats.rider_damage <= 0 or current_hp <= 0:
		return
	_rider_clock -= delta
	if _rider_clock > 0.0:
		return
	var found: Array = []
	for body in get_tree().get_nodes_in_group("units"):
		if !is_instance_valid(body) or body == self or !("team" in body) or body.team == team or body.is_queued_for_deletion():
			continue
		if body.has_method("is_hidden") and body.is_hidden():
			continue
		var d = global_position.distance_to(body.global_position)
		if d <= stats.rider_range:
			found.append([d, body])
	if found.is_empty():
		return
	_rider_clock = maxf(stats.rider_interval, 0.2)
	found.sort_custom(func(a, b): return a[0] < b[0])
	for it in found.slice(0, maxi(stats.rider_count, 1)):
		var victim = it[1]
		Fx.ring(get_parent(), victim.position, 12.0, Color(1, 0.95, 0.7, 0.9), 0.2)
		victim.take_damage(int(round(stats.rider_damage * _level_mult_safe())))
		if stats.rider_effect != UnitData.OnHitEffect.NONE and is_instance_valid(victim) and victim.has_method("apply_on_hit_effect"):
			victim.apply_on_hit_effect(stats.rider_effect, stats.rider_effect_strength, stats.rider_effect_duration, 1.0, 20.0, global_position)


func _level_mult_safe() -> float:
	# o segundo ataque sobe de nível junto com a carta, como o dano normal
	return PlayerProfile.compute_stat_multiplier(card_level)


func _perform_attack():
	_reveal_disguise()
	_attack_anim()
	if stats.heals_on_attack and stats.attack_heal_amount > 0:
		# cura quem está perto (ela também) a cada golpe
		for ally in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(ally) and ("team" in ally) and ally.team == team and ally.has_method("heal") \
					and global_position.distance_to(ally.global_position) <= stats.attack_heal_radius:
				ally.heal(stats.attack_heal_amount)
		Fx.ring(get_parent(), position, stats.attack_heal_radius, Color(0.5, 1.0, 0.6, 0.6), 0.3)

	var dmg = _get_effective_damage()
	var target_killed = false

	if stats.charge_attack:
		if _charge_distance_accumulated >= stats.charge_distance_needed:
			dmg *= stats.charge_damage_multiplier
			# empurrão da investida: só em UNIDADE (torre e construção nunca saem do lugar),
			# e deslizando -- antes movia o alvo na marra, inclusive as torres
			if stats.charge_knockback_distance > 0 and target != null and is_instance_valid(target) and target.has_method("apply_knockback"):
				target.apply_knockback(global_position, stats.charge_knockback_distance)
		_charge_distance_accumulated = 0.0  # sempre reseta -- carregado ou não, precisa andar de novo pra carregar o próximo

	if stats.is_ranged and stats.beam_attack:
		# RAIO CONTÍNUO: sem projétil -- o dano cai na hora e a linha fica ligada no alvo
		var heat = 0.0
		if stats.same_target_ramping_damage and stats.same_target_ramping_damage_max_multiplier > 1.0:
			heat = clampf((_same_target_ramp_multiplier - 1.0) / (stats.same_target_ramping_damage_max_multiplier - 1.0), 0.0, 1.0)
		elif stats.ramping_damage and stats.ramping_damage_max_multiplier > 1.0:
			heat = clampf((_damage_ramp_multiplier - 1.0) / (stats.ramping_damage_max_multiplier - 1.0), 0.0, 1.0)
		var beam_col: Color = SpriteForge.main_color(card_data.art_palette) if card_data != null else Color(1.0, 0.5, 0.2)
		if stats.beam_tint > 0:
			beam_col = SpellData.TINT_COLORS[clampi(stats.beam_tint, 1, SpellData.TINT_COLORS.size() - 1)]   # cor escolhida no Criador
		if stats.beam_heats_red:
			beam_col = beam_col.lerp(Color(1.0, 0.35, 0.15), heat * 0.7)   # esquentando: puxa pro vermelho
		beam_col.a = 1.0
		var muzzle = position + Vector2(0, -14.0 * _visual_scale)
		Fx.beam(get_parent(), muzzle, target.position if target.get_parent() == get_parent() else get_parent().to_local(target.global_position),
			beam_col, 2.0 + 5.0 * heat, maxf(stats.attack_speed * _attack_speed_ramp_multiplier / _rage_mult(_rage_attack_speed) * 1.25, 0.2))
		if heat <= 0.02:
			Sfx.play("tiro", 0.2, -8.0)
		var beam_body = target
		beam_body.take_damage(dmg)
		if is_instance_valid(beam_body):
			_report_base_damage(beam_body, dmg)
			_apply_on_hit_effect_to(beam_body)
	elif stats.is_ranged:
		Sfx.play("tiro", 0.2, -4.0)
		# QUANTOS PROJÉTEIS POR ATAQUE: todos juntos em leque, ou em rajada (um atrás do outro)
		var n_shots = maxi(1, stats.projectiles_per_attack)
		if n_shots == 1:
			_fire_shot(dmg, Vector2.ZERO)
		elif stats.projectile_burst_delay > 0.0:
			_fire_shot(dmg, Vector2.ZERO)
			for k in range(1, n_shots):
				get_tree().create_timer(stats.projectile_burst_delay * k, false).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and target != null and is_instance_valid(target):
						_fire_shot(dmg, Vector2.ZERO))
		else:
			var aim = (target.global_position - global_position).normalized() if is_instance_valid(target) else Vector2.UP
			var perp = aim.orthogonal()
			var gap = maxf(stats.projectile_spread, 2.0)
			for k in n_shots:
				_fire_shot(dmg, perp * (float(k) - float(n_shots - 1) * 0.5) * gap)
		# COICE: depois do tiro dá um pulinho pra trás (usa o mesmo empurrão dos efeitos)
		if stats.recoil_distance > 0.0 and is_instance_valid(target):
			_recoil_push(target.global_position)
	elif stats.spin_attack:
		_perform_spin_attack(dmg)
	elif stats.frontal_cone_attack:
		_perform_cone_attack(dmg)
	elif stats.aoe_hits_extra_one:
		_perform_attack_with_one_extra(dmg)
	elif stats.is_aoe:
		_deal_area_damage(target.global_position, stats.aoe_radius, dmg, true)
		_apply_on_hit_to_area(target.global_position, stats.aoe_radius)
	else:
		# guarda o alvo: o golpe pode mudar o "target" no meio (o choque de volta atordoa quem
		# bateu e zera o alvo dele) -- antes isso quebrava o resto do ataque
		var hit_body = target
		var was_alive_before = "current_hp" in hit_body and hit_body.current_hp > 0
		if stats.impact_fx > 0 and !stats.is_ranged and get_parent() is Node2D:
			Fx.impact(get_parent(), get_parent().to_local(hit_body.global_position), stats.impact_fx, stats.impact_tint, stats.impact_size)
		hit_body.take_damage(dmg)
		if !is_instance_valid(hit_body):
			return
		_report_base_damage(hit_body, dmg)
		_apply_on_hit_effect_to(hit_body)
		if was_alive_before and "current_hp" in hit_body and hit_body.current_hp <= 0:
			target_killed = true
		if target == null or !is_instance_valid(target):
			return

		if _is_base(target) and stats.steals_resource_on_base_hit:
			_steal_resource_from(target)

		# domina o inimigo: converte ele pro meu time em vez de só bater --
		# versão inicial; não converte base, só unidades normais
		if stats.can_convert_enemy and _converted_count < stats.convert_max_targets:
			if !_is_base(target) and target.has_method("convert_to"):
				target.convert_to(team)
				_converted_count += 1
				target = null  # era meu alvo; agora é aliado

	if target_killed:
		if stats.heals_on_kill:
			heal(stats.heal_on_kill_amount)
		if stats.converts_kills_to_gold:
			_grant_gold(stats.gold_per_kill)

	if stats.summons_on_attack and stats.attack_summon_scene != null and !_is_silenced():
		if randf() < stats.attack_summon_chance:
			_spawn_child(stats.attack_summon_scene, global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)))

	if stats.lifesteal_percent > 0:
		heal(round(dmg * stats.lifesteal_percent))

	# ROUBO DE VELOCIDADE: o alvo fica lento e eu fico mais rápida
	if stats.steals_speed and target != null and is_instance_valid(target) and target.has_method("apply_on_hit_effect") and !_is_base(target) and !_is_silenced():
		var amt = clampf(stats.speed_steal_amount, 0.05, 0.8)
		target.apply_on_hit_effect(UnitData.OnHitEffect.SLOW, 1.0 - amt, stats.speed_steal_duration, 1.0, 0.0, global_position)
		apply_speed_multiplier(maxf(speed_multiplier, 1.0 + amt), stats.speed_steal_duration)
		if Regras.on("visual"):
			Fx.ring(get_parent(), position, 16.0, Color(0.5, 0.9, 1.0, 0.8), 0.3)

	_has_attacked_before = true

	if stats.ramping_damage:
		_damage_ramp_multiplier = min(
			_damage_ramp_multiplier + stats.ramping_damage_per_hit,
			stats.ramping_damage_max_multiplier
		)

	if stats.same_target_ramping_damage:
		if target == _same_target_ramp_last_target:
			_same_target_ramp_multiplier = min(
				_same_target_ramp_multiplier + stats.same_target_ramping_damage_per_hit,
				stats.same_target_ramping_damage_max_multiplier
			)
		else:
			_same_target_ramp_multiplier = 1.0  # trocou de alvo -- reseta, perde o foco acumulado
		_same_target_ramp_last_target = target

	if stats.ramping_attack_speed:
		_attack_speed_ramp_multiplier = max(
			_attack_speed_ramp_multiplier - stats.attack_speed_ramp_per_hit,
			stats.attack_speed_ramp_min_multiplier
		)

	if stats.kamikaze:
		die()


func _grant_gold(amount: int):
	if team == GameManager.Team.PLAYER:
		GameManager.player_money += amount
	else:
		GameManager.enemy_money += amount


func _steal_resource_from(base_body):
	var stolen = stats.resource_steal_amount
	if base_body.team == GameManager.Team.PLAYER:
		GameManager.player_money = max(0, GameManager.player_money - stolen)
		GameManager.enemy_money += stolen
	else:
		GameManager.enemy_money = max(0, GameManager.enemy_money - stolen)
		GameManager.player_money += stolen


# alcance do golpe em ÁREA (360° / cone), medido da MINHA borda: usa o raio
# da área se tiver, senão o alcance do ataque + uma folga -- antes media do
# centro com o alcance de corpo a corpo (15) e não pegava ninguém
func _melee_area_reach() -> float:
	return max(stats.aoe_radius, max(stats.attack_range, MELEE_MIN_REACH) + 18.0)


# inimigos que esse golpe consegue acertar (respeita aéreo/terrestre,
# invisível, invulnerável ao nascer) -- o alvo atual sempre entra
func _area_hit_list(cone_dir: Vector2 = Vector2.ZERO, cone_angle: float = 360.0) -> Array:
	var reach = _melee_area_reach()
	var hits: Array = []
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team == team or !_is_valid_enemy(body):
			continue
		if body != target and _gap_to(body) > reach:
			continue
		if cone_angle < 360.0 and body != target:
			var to_body = body.global_position - global_position
			if rad_to_deg(abs(cone_dir.angle_to(to_body.normalized()))) > cone_angle * 0.5:
				continue
		hits.append(body)
	return hits


func _hit_body(body, dmg):
	var was_alive = "current_hp" in body and body.current_hp > 0
	body.take_damage(dmg)
	_report_base_damage(body, dmg)
	_apply_on_hit_effect_to(body)
	if was_alive and "current_hp" in body and body.current_hp <= 0:
		_on_killed(body)


func _on_killed(body):
	if stats.heals_on_kill:
		heal(stats.heal_on_kill_amount)
	if stats.converts_kills_to_gold:
		_grant_gold(stats.gold_per_kill)


func _perform_spin_attack(dmg):
	for body in _area_hit_list():
		_hit_body(body, dmg)
	_show_swing_fx(360.0, Vector2.RIGHT)


func _perform_cone_attack(dmg):
	var forward = (target.global_position - global_position).normalized()
	var angle = stats.cone_angle_degrees if stats.cone_angle_degrees > 0 else 90.0
	for body in _area_hit_list(forward, angle):
		_hit_body(body, dmg)
	_show_swing_fx(angle, forward)


# rastro rápido do golpe (arco ou círculo) -- só visual
func _show_swing_fx(angle_deg: float, forward: Vector2):
	var fx = Line2D.new()
	fx.width = 3.0
	fx.default_color = Color(1, 1, 0.85, 0.85)
	var reach = _get_own_target_radius() + _melee_area_reach() * 0.7
	var steps = 14
	var start = forward.angle() - deg_to_rad(angle_deg) * 0.5
	for i in steps + 1:
		var a = start + deg_to_rad(angle_deg) * float(i) / steps
		fx.add_point(Vector2.RIGHT.rotated(a) * reach)
	fx.z_index = 20
	add_child(fx)
	var tw = fx.create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.25)
	tw.tween_callback(fx.queue_free)


func _perform_attack_with_one_extra(dmg):
	target.take_damage(dmg)
	_apply_on_hit_effect_to(target)

	var extra = null
	var extra_dist = INF
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or body == target or !("team" in body) or body.team == team:
			continue
		var d = body.global_position.distance_to(target.global_position)
		if d <= stats.aoe_radius and d < extra_dist:
			extra_dist = d
			extra = body
	if extra != null:
		extra.take_damage(dmg)
		_apply_on_hit_effect_to(extra)


func _apply_on_hit_effect_to(body):
	if _is_silenced():
		return  # silenciada não aplica efeito nenhum de ataque enquanto durar
	if stats.curses_on_hit and stats.curse_spawn_scene != null and is_instance_valid(body) and "stats" in body and body.stats != null:
		body.set_meta("curse", {"until": GameManager.game_time + stats.curse_duration, "team": team, "scene": stats.curse_spawn_scene, "level": card_level})
		if Regras.on("visual") and "position" in body:
			Fx.ring(get_parent(), body.position, 14.0, Color(0.7, 0.4, 0.95, 0.8), 0.3)
	if !body.has_method("apply_on_hit_effect"):
		return

	if stats.on_hit_effect != UnitData.OnHitEffect.NONE:
		body.apply_on_hit_effect(
			stats.on_hit_effect,
			stats.on_hit_effect_strength,
			stats.on_hit_effect_duration,
			stats.on_hit_effect_tick_interval,
			stats.knockback_distance,
			global_position
		)

	# habilidade de maestria: além do efeito normal acima, aplica esse extra
	# só quando a carta já está no nível máximo (hoje 7, pro jogador)
	if stats.mastery_effect != UnitData.OnHitEffect.NONE and card_level >= PlayerProfile.MASTERY_LEVEL:
		body.apply_on_hit_effect(
			stats.mastery_effect,
			stats.mastery_effect_strength,
			stats.mastery_effect_duration,
			stats.mastery_effect_tick_interval,
			stats.knockback_distance,
			global_position
		)


func _apply_on_hit_to_area(center: Vector2, radius: float):
	if stats.on_hit_effect == UnitData.OnHitEffect.NONE:
		return
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team == team or !can_hit_kind(body):
			continue
		if body.global_position.distance_to(center) <= radius:
			_apply_on_hit_effect_to(body)


## aplica um efeito (atordoar, congelar, lentidão...) em todo inimigo dentro do raio
func _recoil_push(from: Vector2):
	var keep = stats.immune_to_knockback
	stats.immune_to_knockback = false
	apply_knockback(from, stats.recoil_distance)
	stats.immune_to_knockback = keep


func _area_effect(center: Vector2, radius: float, effect, duration: float, strength: float):
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !is_instance_valid(body) or !("team" in body) or body.team == team:
			continue
		if body.global_position.distance_to(center) <= radius and body.has_method("apply_on_hit_effect"):
			body.apply_on_hit_effect(effect, strength, duration, 1.0, 40.0, center)


## o dano em área respeita quem a carta mira: só chão não pega voador (e vice-versa)
func can_hit_kind(body) -> bool:
	var st = body.get("stats") if "stats" in body else null
	if st == null:
		return stats.target_type != UnitData.TargetType.AIR   # torre/base é chão
	var flying = st.unit_type == UnitData.UnitType.AIR
	match stats.target_type:
		UnitData.TargetType.GROUND:
			return !flying
		UnitData.TargetType.AIR:
			return flying
		UnitData.TargetType.BUILDING:
			return st.unit_type == UnitData.UnitType.BUILDING
	return true


func _deal_area_damage(center: Vector2, radius: float, damage: int, by_kind: bool = false):
	if get_parent() != null:
		Fx.ring(get_parent(), get_parent().to_local(center) if get_parent() is Node2D else center, radius, Color(1.0, 0.72, 0.3))
		Sfx.play("explosao", 0.15, -2.0)
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team == team:
			continue
		if by_kind and !can_hit_kind(body):
			continue
		# com os corpos maiores (visual 2.5) a área conta até a BORDA do alvo:
		# senão a abóbora-bomba encostava no alvo e a explosão não chegava no centro dele
		var dist = center.distance_to(_closest_surface_point(body, center)) if Regras.on("visual") else body.global_position.distance_to(center)
		if body.global_position.distance_to(center) <= radius or dist <= radius:
			body.take_damage(damage)
			_report_base_damage(body, damage)


func find_target():
	var previous_target = target
	var bodies = $Area2D.get_overlapping_bodies()
	target = null
	var by_route = Regras.routes()
	if by_route and (enemy_base == null or !is_instance_valid(enemy_base) or enemy_base.is_queued_for_deletion()):
		_refresh_enemy_tower()

	var closest_unit = null
	var closest_unit_dist = INF
	var closest_base = null
	var closest_base_dist = INF

	var sight = stats.detection_range if stats.detection_range > 0 else stats.attack_range

	for body in bodies:
		if !_is_valid_enemy(body):
			continue
		if stats.min_attack_range > 0.0 and stats.move_speed <= 0.0 and _edge_distance(body) < stats.min_attack_range:
			continue   # morteiro parado: quem está colado nele nem vira alvo

		var dist = global_position.distance_to(body.global_position)

		if "stats" in body and body.stats != null and body.stats.forces_aggro:
			if dist <= body.stats.taunt_radius:
				target = body
				return

		var is_base_target = _is_base(body)
		# ROTAS: torre que não é a da minha rota eu passo direto (ela atira em
		# mim, mas não me puxa pro meio)
		if is_base_target and by_route and enemy_base != null and is_instance_valid(enemy_base) and body != enemy_base:
			continue
		# visão medida até a BORDA do alvo, igual ao alcance de ataque
		if _gap_to(body) > max(sight, stats.attack_range):
			continue

		if is_base_target:
			if dist < closest_base_dist:
				closest_base_dist = dist
				closest_base = body
		else:
			if dist < closest_unit_dist:
				closest_unit_dist = dist
				closest_unit = body

	target = closest_unit if closest_unit != null else closest_base

	# avanço estilo Bandida -- dispara na hora que acha um alvo pela
	# primeira vez (não tinha nenhum antes, achou agora), uma vez só na
	# vida da unidade
	# (não começa enquanto ainda está entrando em campo/atordoada: o avanço
	# acabava antes de ela poder andar -- aí quem dispara é o _process_combat)
	if stats.bandit_dash and !_has_dashed and previous_target == null and target != null and !_is_incapacitated():
		_start_bandit_dash()


# inicia o avanço -- fica invulnerável (reaproveita o mesmo mecanismo já
# usado pra invulnerabilidade de nascimento) e mais rápido por um tempo curto
func _start_bandit_dash():
	_has_dashed = true
	_dash_clock = 0.0
	_dash_bonus_pending = stats.dash_damage_mult != 1.0
	_dash_time_remaining = stats.dash_duration
	_spawn_invulnerable_until = GameManager.game_time + stats.dash_duration


func _is_valid_enemy(body) -> bool:
	if body == self or !body.has_method("take_damage") or body.team == team:
		return false

	# invulnerabilidade ao nascer -- ninguém consegue mirar nela por um
	# tempo logo que aparece (diferente do stealth permanente por alcance,
	# essa é só uma janela de tempo desde que ela nasceu)
	if "_spawn_invulnerable_until" in body and body._spawn_invulnerable_until > GameManager.game_time:
		return false

	# invisibilidade: só é um alvo válido se eu estiver perto o bastante
	# pra "revelar" ela
	# ... e só ATÉ ela dar o primeiro golpe: depois que atacou, apareceu pra todo mundo
	# (antes continuava invisível pra sempre pra quem estava longe, tipo atirador)
	if body.has_method("is_hidden") and body.is_hidden():
		return false   # construção escondida: só aparece quando ela mesma acha alvo
	if "stats" in body and body.stats != null and body.stats.can_stealth and !body._has_attacked_before:
		var dist = global_position.distance_to(body.global_position)
		if dist > body.stats.stealth_reveal_range:
			return false

	return _can_target(body)


func _can_target(body) -> bool:
	var body_unit_type = UnitData.UnitType.BUILDING if _is_base(body) else body.stats.unit_type

	match stats.target_type:
		UnitData.TargetType.GROUND:
			return body_unit_type != UnitData.UnitType.AIR
		UnitData.TargetType.AIR:
			return body_unit_type == UnitData.UnitType.AIR
		UnitData.TargetType.BUILDING:
			return body_unit_type == UnitData.UnitType.BUILDING
		_:
			return true


# diferente do _on_area_2d_body_entered (que só reage a QUEM CHEGA na
# área), essa confere periodicamente TODO MUNDO que já está dentro dela --
# cobre o caso de uma unidade que já estava lá, mas foi se aproximando (ou
# o alvo atual foi se afastando) com o tempo, sem nunca "entrar" de novo
func _check_for_closer_target():
	if target == null or !is_instance_valid(target):
		find_target()
		return

	# PROVOCA: quem provoca puxa até quem já está batendo em outro (antes só puxava quem ainda
	# estava escolhendo alvo; a tropa que já tinha começado a bater ignorava a provocação)
	if !("stats" in target) or target.stats == null or !target.stats.forces_aggro:
		for body in $Area2D.get_overlapping_bodies():
			if body != target and _is_valid_enemy(body) and "stats" in body and body.stats != null and body.stats.forces_aggro \
					and global_position.distance_to(body.global_position) <= body.stats.taunt_radius:
				_is_actively_attacking = false
				_windup_left = -1.0
				target = body
				return

	# já está atacando de verdade (dentro do alcance) -- não troca de foco só
	# porque outra coisa ficou mais perto nesse meio tempo. Só troca se o
	# alvo atual sair da área de detecção por completo
	if _is_actively_attacking:
		if !$Area2D.get_overlapping_bodies().has(target):
			find_target()
		return

	var current_dist = global_position.distance_to(target.global_position)

	for body in $Area2D.get_overlapping_bodies():
		if body == target or !_is_valid_enemy(body):
			continue
		if global_position.distance_to(body.global_position) < current_dist:
			find_target()
			return


func _on_area_2d_body_entered(body):
	# sem alvo ainda -- reavalia geral, sem restrição
	if target == null or !is_instance_valid(target):
		find_target()
		return

	# já atacando de verdade -- não abandona o alvo atual só porque uma
	# unidade nova apareceu por perto, mesmo que ela esteja mais próxima
	if _is_actively_attacking:
		return

	# já tenho um alvo, mas ainda estou só me aproximando (não atacando de
	# verdade ainda): só vale a pena reavaliar se essa unidade nova for
	# um inimigo válido E estiver mais perto que o alvo que eu já tinha
	if !_is_valid_enemy(body):
		return

	var new_dist = global_position.distance_to(body.global_position)
	var current_dist = global_position.distance_to(target.global_position)
	if new_dist < current_dist:
		find_target()


func _on_area_2d_body_exited(body):
	if body == target:
		target = null


static var wards: Array = []   # quem está com a CÚPULA ligada no campo


func take_damage(amount, _is_shared_damage: bool = false):
	if amount > 0 and is_hidden():
		return   # escondida debaixo da terra: nem feitiço acerta
	# CÚPULA aliada por perto: leva menos dano (vale a mais forte)
	if amount > 0 and !wards.is_empty():
		var cut = 0.0
		for w in wards:
			if is_instance_valid(w) and w != self and w.team == team and w.current_hp > 0 and global_position.distance_to(w.global_position) <= w.stats.ward_radius:
				cut = maxf(cut, w.stats.ward_reduction)
		if cut > 0.0:
			amount = amount * (1.0 - clampf(cut, 0.0, 0.9))
	# invulnerável logo ao nascer -- nem dano de área/feitiço passa nessa janela
	if _spawn_invulnerable_until > GameManager.game_time:
		return
	# ESQUIVA: golpe de tropa/torre pode passar batido (feitiço sempre pega)
	if amount > 0 and stats.dodge_chance > 0.0 and !has_meta("spell_hit") and randf() < clampf(stats.dodge_chance, 0.0, 0.9):
		if Regras.on("visual"):
			Fx.text(get_parent(), position + Vector2(0, -22), "esquivou!", Color(0.8, 0.95, 1.0), 0.6)
		_dodged += 1
		return

	# imune enquanto se movendo -- só fica vulnerável de verdade parada
	if stats.immune_while_moving and _really_moving:
		return

	if amount > 0:
		if Regras.on("visual"):
			_flash_white()  # pisca BRANCO (vermelho confundia com a cor do time inimigo)
		else:
			_flash_color(Color(1, 0.35, 0.35))  # flash vermelho rápido de "levou hit"

	# marca de vulnerabilidade: multiplica o dano recebido de QUALQUER fonte
	if _marked_until > GameManager.game_time:
		amount *= _mark_multiplier

	# redução de dano fixa, antes de qualquer outra coisa
	if stats.damage_reduction_percent > 0:
		amount *= (1.0 - stats.damage_reduction_percent)

	# marca quando foi o último dano levado -- usado pelo escudo recarregável
	_last_damage_time = GameManager.game_time

	# escudo absorve o que sobrar
	# ESCUDO (igual no Clash): o golpe que QUEBRA o escudo é segurado inteiro -- o que sobra do
	# dano não passa pra vida. Antes passava: tropa de 1 de vida + 1 de escudo morria na bomba.
	if current_shield > 0:
		var broke = amount >= current_shield
		current_shield = maxi(current_shield - int(ceil(amount)), 0)
		if broke and Regras.on("visual") and is_inside_tree():
			Fx.ring(get_parent(), position, 18.0 * _visual_scale, Color(0.6, 0.85, 1.0), 0.3)
			Fx.text(get_parent(), position + Vector2(0, -26.0 * _visual_scale), "ESCUDO!", Color(0.6, 0.85, 1.0), 0.7)
		_refresh_bar()
		return

	current_hp = clamp(current_hp - amount, 0, stats.hp)
	$ProgressBar.value = current_hp
	_refresh_bar()
	if amount > 0 and Regras.on("peso"):
		_hit_squash = clampf(_hit_squash + clampf(amount / maxf(stats.hp, 1.0) * 4.0, 0.35, 1.0), 0.0, 1.0)
	# número de dano: com o visual novo só golpe de verdade ganha número
	# (6 pintinhos bicando enchiam a tela de "25 25 25")
	var number_floor = 15.0
	if Regras.on("visual"):
		number_floor = maxf(45.0, stats.hp * 0.06)
	if amount >= 260.0 and Regras.on("peso"):
		var bs = get_tree().get_first_node_in_group("battle_scene")
		if bs != null and bs.has_method("shake"):
			bs.shake(clampf(amount / 110.0, 2.5, 6.0))
	if amount >= number_floor:
		var hit_at = position + Vector2(0, -18.0 * _visual_scale)
		Fx.number(get_parent(), hit_at, amount, Color(1, 0.93, 0.8) if team == GameManager.Team.ENEMY else Color(1, 0.55, 0.5))
		Fx.burst(get_parent(), position, Color(1, 0.95, 0.85), 4, 70.0, 2.5)
		Sfx.play("golpe" if amount < 150 else "golpe2", 0.15, -3.0 if amount < 60 else 0.0)

	if stats.is_linked and !_is_shared_damage and !linked_units.is_empty():
		var shared_amount = amount * stats.link_share_percent
		for ally in linked_units:
			if is_instance_valid(ally):
				ally.take_damage(shared_amount, true)

	# dano devolvido NÃO é devolvido de novo: duas cartas que devolvem dano
	# brigando entre si entravam num vai-e-volta sem fim (travava o jogo)
	if stats.reflects_damage and !_reflecting and target != null and is_instance_valid(target):
		_reflecting = true
		target.take_damage(amount * stats.reflect_damage_percent)
		_reflecting = false

	# CHOQUE DE VOLTA: quem está batendo nela (de perto) leva choque -- no máximo 1 a cada 0,6s por atacante
	if stats.zaps_attackers and amount > 0 and is_inside_tree():
		for body in get_tree().get_nodes_in_group("units"):
			if !is_instance_valid(body) or !("team" in body) or body.team == team or body.get("target") != self:
				continue
			if global_position.distance_to(body.global_position) > stats.zap_radius:
				continue
			var iid = body.get_instance_id()
			if float(_zap_ready.get(iid, -99.0)) > GameManager.game_time:
				continue
			_zap_ready[iid] = GameManager.game_time + 0.6
			Fx.bolt(get_parent(), body.position, Color(0.6, 0.85, 1.0))
			body.take_damage(stats.zap_damage)
			if is_instance_valid(body):
				body.apply_on_hit_effect(UnitData.OnHitEffect.STUN, 0.0, stats.zap_stun, 1.0, 0.0, global_position)

	if stats.counter_attack_chance > 0 and randf() < stats.counter_attack_chance:
		if target != null and is_instance_valid(target):
			target.take_damage(stats.damage)

	if stats.transforms_at_half_hp and stats.half_hp_scene != null and !_half_transformed and current_hp > 0 and current_hp <= stats.hp * 0.5:
		_half_transformed = true
		call_deferred("_transform_half")
		return

	if current_hp <= 0:
		if stats.can_resurrect and !_has_resurrected:
			_has_resurrected = true
			current_hp = round(stats.hp * stats.resurrect_hp_percent)
			$ProgressBar.value = current_hp
		else:
			die()


func heal(amount):
	var before = current_hp
	current_hp = clamp(current_hp + amount, 0, stats.hp)
	$ProgressBar.value = current_hp
	_refresh_bar()
	if current_hp - before >= 8:
		Fx.number(get_parent(), position + Vector2(0, -18.0 * _visual_scale), current_hp - before, Color(0.45, 1.0, 0.5))


var _flash_active: bool = false
var _white_until := 0.0


## pisca branco por um instante: troca o material do desenho pelo "aceso"
## do mesmo time e devolve logo depois
func _flash_white():
	var sprite: Sprite2D = $Sprite2D
	var mine = team == GameManager.Team.PLAYER
	var now = Time.get_ticks_msec() / 1000.0
	var already = _white_until > now
	_white_until = now + 0.07
	if already:
		return
	sprite.material = Regras.outline_material(mine, true)
	var tw = create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func():
		_white_until = 0.0
		sprite.material = Regras.outline_material(mine, false)
	)


# pisca rapidamente numa cor e depois volta pra cor "de base" atual (que pode
# não ser branco puro, se tiver um status contínuo tipo veneno/congelamento)
func _flash_color(color: Color, duration: float = 0.15):
	_flash_active = true
	modulate = color
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func():
		_flash_active = false
		modulate = _get_status_base_color()
	)


# cor "de repouso" atual, considerando os status contínuos ativos --
# congelamento tem prioridade visual sobre veneno, já que imobiliza também
var _frozen_until: float = -999.0
const FREEZE_IMMUNITY = 1.0


func _get_status_base_color() -> Color:
	if _frozen_until > GameManager.game_time:
		return Color(0.45, 0.75, 1.0)  # azul-gelo -- congelada
	if _deploy_until > GameManager.game_time:
		return Color(1, 1, 1)  # entrando em campo: não é atordoamento, não empalidece
	if _is_incapacitated():
		return Color(0.75, 0.9, 1.0)
	if _rage_until > GameManager.game_time:
		return Color(1.0, 0.62, 0.55)  # avermelhada -- em fúria  # esbranquiçado/pálido -- atordoada (STUN)
	if speed_multiplier < 1.0:
		return Color(0.6, 0.85, 1.0)  # azulado -- lenta (SLOW/FREEZE)
	if _poison_ticks_left > 0:
		return Color(0.55, 1.0, 0.55)  # esverdeado -- envenenada
	return Color(1, 1, 1)  # normal


# reaplica a cor de repouso todo frame -- pega sozinho qualquer mudança de
# status (veneno começou/acabou, congelamento começou/acabou), sem precisar
# disparar isso manualmente em cada lugar que muda esses estados
func _update_status_modulate():
	if _flash_active:
		return
	modulate = _get_status_base_color()


func apply_speed_multiplier(multiplier: float, duration: float):
	speed_multiplier = multiplier
	get_tree().create_timer(duration).timeout.connect(func():
		speed_multiplier = 1.0
	)


func apply_damage_multiplier(multiplier: float, duration: float):
	damage_multiplier = multiplier
	get_tree().create_timer(duration).timeout.connect(func():
		damage_multiplier = 1.0
	)


func _is_incapacitated() -> bool:
	return _incapacitated_until > GameManager.game_time


func _is_rooted() -> bool:
	return _rooted_until > GameManager.game_time


func _is_silenced() -> bool:
	return _silenced_until > GameManager.game_time


# ---------- REFORÇOS (feitiços de ajuda) ----------
# FÚRIA: mais dano, mais velocidade e ataque mais rápido por um tempo
var _rage_until: float = -1.0
var _rage_damage: float = 1.0
var _rage_speed: float = 1.0
var _rage_attack_speed: float = 1.0
var _spell_shield: int = 0
var _spell_shield_until: float = -1.0


func _rage_mult(v: float) -> float:
	return v if _rage_until > GameManager.game_time else 1.0


func apply_rage(damage_mult: float, speed_mult: float, attack_speed_mult: float, duration: float):
	var now = GameManager.game_time
	if _rage_until <= now:
		_rage_damage = 1.0
		_rage_speed = 1.0
		_rage_attack_speed = 1.0
	_rage_damage = max(_rage_damage, damage_mult)
	_rage_speed = max(_rage_speed, speed_mult)
	_rage_attack_speed = max(_rage_attack_speed, attack_speed_mult)
	_rage_until = max(_rage_until, now + duration)


# ESCUDO de feitiço: absorve dano até acabar ou até o tempo passar
func apply_spell_shield(amount: int, duration: float):
	var now = GameManager.game_time
	if _spell_shield_until <= now:
		_spell_shield = 0
	var add = max(amount - _spell_shield, 0)  # reaplicar não empilha infinito
	_spell_shield += add
	current_shield += add
	_spell_shield_until = max(_spell_shield_until, now + duration)


func _process_spell_shield():
	if _spell_shield > 0 and _spell_shield_until <= GameManager.game_time:
		current_shield = max(current_shield - _spell_shield, 0)
		_spell_shield = 0


# PURIFICAR: tira todo efeito ruim (lentidão, fraqueza, atordoar, congelar,
# veneno, raiz, confusão, silêncio, marca)
func cleanse():
	if speed_multiplier < 1.0:
		speed_multiplier = 1.0
	if damage_multiplier < 1.0:
		damage_multiplier = 1.0
	var now = GameManager.game_time
	_incapacitated_until = now
	_rooted_until = now
	_confused_until = now
	_silenced_until = now
	_marked_until = now
	if _frozen_until > now:
		_frozen_until = now  # mantém a imunidade curta depois
	_poison_ticks_left = 0


func apply_silence(duration: float):
	_silenced_until = max(_silenced_until, GameManager.game_time + duration)


func apply_mark(multiplier: float, duration: float):
	_mark_multiplier = multiplier
	_marked_until = max(_marked_until, GameManager.game_time + duration)


## TIRO CARREGADO: zera a carga (no começo e toda vez que é atordoada/congelada/leva choque)
func _reset_charged_shot():
	if stats != null and stats.charged_shot:
		attack_cooldown = stats.attack_speed * _attack_speed_ramp_multiplier / _rage_mult(_rage_attack_speed)
		_windup_left = -1.0
		_charge_primed = true


var _charge_primed := false


func apply_incapacitate(duration: float):
	_incapacitated_until = max(_incapacitated_until, GameManager.game_time + duration)


func apply_root(duration: float):
	_rooted_until = max(_rooted_until, GameManager.game_time + duration)


func apply_confuse(duration: float):
	_confused_until = max(_confused_until, GameManager.game_time + duration)


# EMPURRÃO e PUXÃO são deslizamentos suaves (somam num vetor que a unidade
# vai percorrendo em poucos frames) -- antes eram teletransporte na hora:
# o tornado jogava a unidade de um lado pro outro do centro a cada pulso,
# em vez de concentrar todo mundo no meio
var _forced_move: Vector2 = Vector2.ZERO
const FORCED_MOVE_RATE = 10.0  # fração por segundo (rápido mas visível)


func _mass_factor() -> float:
	# pesado escorrega menos (raiz do peso -- vaca 3.8 anda ~half da galinha)
	return 1.0 / sqrt(max(stats.push_weight, 1.0))


func apply_knockback(from_position: Vector2, distance: float):
	if stats.immune_to_knockback or stats.unit_type == UnitData.UnitType.BUILDING:
		return
	var dir = (global_position - from_position).normalized()
	_forced_move += dir * distance * _mass_factor()


func apply_pull(from_position: Vector2, distance: float):
	if stats.immune_to_pull or stats.unit_type == UnitData.UnitType.BUILDING:
		return
	var to_center = from_position - global_position
	var d = to_center.length()
	if d < 4.0:
		return
	# nunca passa do centro: puxa no máximo 85% do que falta
	var amount = min(distance * _mass_factor(), d * 0.85)
	# substitui (não soma) o puxão anterior -- vários pulsos seguidos não
	# acumulam um "estilingue" que atravessa o centro
	_forced_move = to_center.normalized() * amount


func _process_forced_move(delta):
	if _forced_move.length() < 0.2:
		_forced_move = Vector2.ZERO
		return
	var step = _forced_move * min(1.0, delta * FORCED_MOVE_RATE)
	global_position += step
	_forced_move -= step


func apply_poison(damage_per_tick: float, tick_interval: float, duration: float):
	_poison_damage_per_tick = damage_per_tick
	_poison_tick_interval = max(tick_interval, 0.1)
	_poison_cooldown = 0.0
	_poison_ticks_left = max(1, int(duration / _poison_tick_interval))


func _process_poison(delta):
	if _poison_ticks_left <= 0:
		return
	_poison_cooldown -= delta
	if _poison_cooldown <= 0:
		_poison_cooldown = _poison_tick_interval
		take_damage(_poison_damage_per_tick)
		_poison_ticks_left -= 1


## atordoar/congelar ZERA o alvo: quando a tropa volta, escolhe de novo quem
## está mais perto (igual no Clash: um choque "reseta" o agro)
func _reset_aggro():
	target = null
	_is_actively_attacking = false
	_retarget_check_cooldown = 0.0
	_windup_left = -1.0


func apply_on_hit_effect(effect, strength: float, duration: float, tick_interval: float, knockback_dist: float, from_position: Vector2):
	if stats.immune_to_effect == effect:
		return

	match effect:
		UnitData.OnHitEffect.SLOW:
			apply_speed_multiplier(strength, duration)
		UnitData.OnHitEffect.WEAKNESS:
			apply_damage_multiplier(strength, duration)
		UnitData.OnHitEffect.FREEZE:
			# congela DE VERDADE: não anda nem ataca pela duração (antes era só
			# uma lentidão forte e a unidade continuava andando e batendo)
			# já congelada não prolonga; e depois de descongelar fica
			# FREEZE_IMMUNITY segundos sem poder ser congelada de novo -- senão
			# quem congela rápido (Espírito de Neve) travava o alvo pra sempre
			var now = GameManager.game_time
			if now < _frozen_until or now < _frozen_until + FREEZE_IMMUNITY:
				return
			apply_incapacitate(duration)
			_frozen_until = now + duration
			_reset_aggro()
			_reset_charged_shot()
		UnitData.OnHitEffect.STUN:
			apply_incapacitate(duration)
			_reset_aggro()
			_reset_charged_shot()
		UnitData.OnHitEffect.ROOT:
			apply_root(duration)
		UnitData.OnHitEffect.POISON:
			apply_poison(strength, tick_interval, duration)
		UnitData.OnHitEffect.KNOCKBACK:
			apply_knockback(from_position, knockback_dist)
		UnitData.OnHitEffect.PULL:
			apply_pull(from_position, knockback_dist)
		UnitData.OnHitEffect.SHOCK:
			take_damage(strength)
			apply_incapacitate(duration)
			_reset_charged_shot()
			_flash_color(Color(1, 0.95, 0.3))  # sobrepõe com um flash amarelado, "choque"
		UnitData.OnHitEffect.CONFUSE:
			apply_confuse(duration)
		UnitData.OnHitEffect.SILENCE:
			apply_silence(duration)
		UnitData.OnHitEffect.MARK:
			apply_mark(strength, duration)


# ---------- HABILIDADES PASSIVAS ----------

func _process_heal_aura(delta):
	if _is_silenced():
		return
	_heal_aura_cooldown -= delta
	if _heal_aura_cooldown > 0:
		return
	_heal_aura_cooldown = stats.heal_aura_interval

	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team != team:
			continue
		if !body.has_method("heal"):
			continue
		if body.global_position.distance_to(global_position) <= stats.heal_aura_radius:
			body.heal(stats.heal_aura_amount)


func _process_unit_spawning(delta):
	if _is_silenced():
		return
	if stats.spawn_unit_scene == null:
		return
	_spawn_cooldown -= delta
	if _spawn_cooldown > 0:
		return
	_spawn_cooldown = stats.spawn_interval

	for i in stats.spawn_count:
		_spawn_child(stats.spawn_unit_scene, global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)))


func _process_resource_generation(delta):
	if _is_silenced():
		return
	_resource_gen_cooldown -= delta
	if _resource_gen_cooldown > 0:
		return
	_resource_gen_cooldown = stats.resource_tick_interval
	_grant_gold(stats.resource_per_tick)


func _process_regen(delta):
	_regen_cooldown -= delta
	if _regen_cooldown > 0:
		return
	_regen_cooldown = stats.regen_interval
	heal(stats.regen_amount)


# recarrega o escudo até o valor cheio, sozinho, depois de ficar tempo
# suficiente sem levar dano nenhum
func _process_shield_recharge():
	if current_shield >= stats.shield_amount:
		return
	var time_since_damage = (GameManager.game_time) - _last_damage_time
	if time_since_damage >= stats.shield_recharge_time:
		current_shield = stats.shield_amount


var _half_transformed := false
var _dodged := 0              # quantos golpes já esquivou (teste)


## TRANSFORMAÇÃO na metade da vida: some esta, nasce a outra no mesmo lugar (mesmo nível)
## um tiro (a tropa pode soltar vários por ataque); `side` = deslocado de lado (leque)
func _fire_shot(dmg, side: Vector2):
	if target == null or !is_instance_valid(target):
		return
	var proj = Projectile.new()
	proj.target = target
	proj.buildings_only = stats.target_type == UnitData.TargetType.BUILDING
	proj.impact_fx = stats.impact_fx
	proj.impact_tint = stats.impact_tint
	proj.impact_size = stats.impact_size
	proj.hits = 1 if stats.target_type == UnitData.TargetType.GROUND else (2 if stats.target_type == UnitData.TargetType.AIR else 0)
	proj.damage = dmg
	proj.speed = stats.projectile_speed
	proj.texture = stats.projectile_texture
	proj.is_aoe = stats.is_aoe
	proj.aoe_radius = stats.aoe_radius
	proj.attacker_team = team
	proj.on_hit_effect = stats.on_hit_effect
	proj.on_hit_effect_duration = stats.on_hit_effect_duration
	proj.on_hit_effect_strength = stats.on_hit_effect_strength
	proj.on_hit_effect_tick_interval = stats.on_hit_effect_tick_interval
	proj.knockback_distance = stats.knockback_distance
	proj.can_miss = stats.projectile_can_miss
	proj.launch_angle = stats.projectile_launch_angle
	if stats.projectile_returns:
		proj.returns_to = self
		proj.return_reach = stats.attack_range + 40.0
	proj.pierces = stats.projectile_pierces
	proj.max_targets = stats.projectile_max_targets
	proj.splits = stats.projectile_splits
	proj.split_count = stats.projectile_split_count
	proj.split_range = stats.projectile_split_range
	proj.chains = stats.projectile_chains
	proj.chain_max_targets = stats.projectile_chain_max_targets
	proj.chain_range = stats.projectile_chain_range
	proj.source_card_path = card_data.resource_path if card_data != null else ""
	if Regras.on("visual"):
		proj.scale = Vector2.ONE * clampf(_visual_scale * 0.95, 1.25, 2.2)  # projétil acompanha o tamanho da tropa
	get_parent().add_child(proj)
	proj.global_position = global_position + side


func _transform_half():
	if !is_instance_valid(self) or is_queued_for_deletion():
		return
	var parent = get_parent()
	Fx.puff(parent, position, 2.0)
	Fx.ring(parent, position, 40.0, Color(1.0, 0.9, 0.5), 0.4)
	Fx.text(parent, position + Vector2(0, -26), "TRANSFORMOU!", Color(1.0, 0.9, 0.5), 1.0)
	var child = _spawn_child(stats.half_hp_scene, global_position)
	if child != null and "target" in child:
		child.target = target
	queue_free()


func _do_transform():
	if not is_instance_valid(self):
		return
	_spawn_child(stats.transformed_scene, global_position)
	queue_free()


# aplica o multiplicador do nível de carta em cima dos stats de uma unidade
# recém-criada -- mesma lógica que spawn_unit() (na cena de batalha) já faz
# pra unidade jogada pela mão; aqui replica pra unidade que nasce DE DENTRO
# de outra (spawn contínuo, spawn ao morrer), que antes sempre nascia no
# nível base, ignorando o quanto a carta já tinha evoluído
# ÚNICO jeito de nascer "filhote" (invocar contínuo, ao atacar, ao morrer,
# virar construção): sempre herda time e NÍVEL de quem gerou, e a força
# (vida/dano) escala com esse nível -- igual carta jogada da mão
func _spawn_child(scene: PackedScene, pos: Vector2) -> Node:
	if scene == null:
		return null
	var child = scene.instantiate()
	child.team = team
	if "card_level" in child:
		child.card_level = card_level
		_apply_card_level_to_stats(child)
	get_parent().add_child(child)
	child.global_position = pos
	return child


func _apply_card_level_to_stats(new_unit):
	if new_unit.card_level <= 1 or new_unit.stats == null:
		return
	var mult = PlayerProfile.compute_stat_multiplier(new_unit.card_level)
	if mult == 1.0:
		return
	# duplica o resource antes de alterar, pra não afetar as OUTRAS unidades
	# desse mesmo tipo que compartilham o .tres original
	new_unit.stats = new_unit.stats.duplicate()
	Regras.apply_level(new_unit.stats, mult)


## troca de lado de verdade: time, camadas de colisão, alvo e torre inimiga
## (antes só mudava o "team" e a unidade convertida continuava brigando com quem a converteu)
func convert_to(new_team):
	if stats.unit_type == UnitData.UnitType.BUILDING:
		return
	team = new_team
	target = null
	enemy_base = null
	_configure_physics_layers()
	_refresh_enemy_tower()
	_flash_color(Color(0.8, 0.5, 1.0), 0.4)


func _spawn_clone():
	# a cena vem da carta (as cartas 2.0 são montadas na memória e não têm arquivo de cena;
	# antes isso fazia o clone simplesmente não nascer)
	var clone_scene: PackedScene = card_data.unit_scene if card_data != null and card_data.unit_scene != null else null
	if clone_scene == null and scene_file_path != "":
		clone_scene = load(scene_file_path)
	if clone_scene == null or _is_clone:
		return  # clone não clona de novo

	for i in max(stats.clone_count, 1):
		var clone = clone_scene.instantiate()
		clone._is_clone = true
		clone.card_data = card_data
		clone.card_role = card_role
		clone.team = team
		clone.card_level = card_level
		_apply_card_level_to_stats(clone)  # antes o clone mostrava o nível mas tinha a força do nível 1
		get_parent().add_child(clone)
		# espalha um pouco quando é mais de um clone, senão nascem empilhados
		var offset = Vector2.ZERO if stats.clone_count <= 1 else Vector2(randf_range(-20, 20), randf_range(-20, 20))
		clone.global_position = global_position + offset
		clone.current_hp = round(clone.stats.hp * stats.clone_hp_percent)
		clone.get_node("ProgressBar").value = clone.current_hp


## a tropa não some num corte seco: um "fantasma" do desenho cresce e apaga
func _death_ghost():
	var parent = get_parent()
	var src: Sprite2D = $Sprite2D
	if parent == null or src.texture == null or !(parent is Node2D):
		return
	var ghost = Sprite2D.new()
	ghost.texture = src.texture
	ghost.texture_filter = src.texture_filter
	ghost.flip_h = src.flip_h
	ghost.scale = _base_sprite_scale
	ghost.position = position + _sprite_home
	ghost.z_index = 3
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.85)
	parent.add_child(ghost)
	var tw = ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "scale", _base_sprite_scale * Vector2(1.25, 0.6), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "position:y", ghost.position.y + 10.0 * _visual_scale, 0.22)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(ghost.queue_free)


func die():
	died.emit(team, card_data)
	if Regras.on("peso") and is_inside_tree():
		_death_ghost()
	_death_fx()
	Sfx.play("morte", 0.2)
	if _visual_scale >= 1.0 and randf() < 0.12:
		_say(DEATH_LINES[randi() % DEATH_LINES.size()])
	if card_data != null:
		Fx.burst(get_parent(), position, SpriteForge.main_color(card_data.art_palette), 8, 110.0, 3.0)

	if stats.explodes_on_death:
		_deal_area_damage(global_position, stats.death_explosion_radius, stats.death_explosion_damage)
	# EFEITO AO MORRER: congela / deixa lento os inimigos em volta
	if stats.death_effect != UnitData.OnHitEffect.NONE:
		_area_effect(global_position, stats.death_effect_radius, stats.death_effect, stats.death_effect_duration, stats.death_effect_strength)
		Fx.ring(get_parent(), position, stats.death_effect_radius, Color(0.6, 0.85, 1.0), 0.5)
	# FÚRIA AO MORRER: os aliados em volta ficam com fúria
	if stats.death_rage_duration > 0.0:
		for body in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(body) and body != self and "team" in body and body.team == team and body.has_method("apply_rage") \
					and global_position.distance_to(body.global_position) <= stats.death_effect_radius:
				body.apply_rage(1.35, 1.35, 1.35, stats.death_rage_duration)
		Fx.zone(get_parent(), position, stats.death_effect_radius, Color(0.75, 0.35, 0.9), stats.death_rage_duration)
	# MALDIÇÃO: morreu amaldiçoado = nasce uma tropa pro time de quem amaldiçoou
	if has_meta("curse"):
		var cz: Dictionary = get_meta("curse")
		if float(cz.get("until", 0.0)) >= GameManager.game_time and cz.get("scene") != null and get_parent() != null:
			var turned = (cz["scene"] as PackedScene).instantiate()
			turned.team = cz["team"]
			if "card_level" in turned:
				turned.card_level = int(cz.get("level", 1))
			get_parent().add_child(turned)
			turned.global_position = global_position
			Fx.ring(get_parent(), position, 26.0, Color(0.7, 0.4, 0.95), 0.4)

	if stats.can_clone:
		_spawn_clone()

	if stats.spawns_on_death and stats.death_spawn_scene != null:
		for i in stats.death_spawn_count:
			_spawn_child(stats.death_spawn_scene, global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)))

	if stats.stores_resource:
		# o espaço extra some junto com a unidade (antes ficava pra sempre)
		var battle_scene = get_tree().get_first_node_in_group("battle_scene")
		if battle_scene != null and battle_scene.has_method("add_storage_capacity"):
			battle_scene.add_storage_capacity(team, -stats.storage_capacity_bonus)

	if stats.grants_resource_on_death:
		var opposing_is_player = team != GameManager.Team.PLAYER
		if opposing_is_player:
			GameManager.player_money += stats.death_resource_amount
		else:
			GameManager.enemy_money += stats.death_resource_amount

	queue_free()
