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
var _charge_distance_accumulated: float = 0.0  # distância andada desde o último ataque, pro golpe carregado
var _has_dashed: bool = false  # se já usou o avanço estilo Bandida (só acontece 1 vez na vida)
var _dash_time_remaining: float = 0.0  # quanto tempo ainda falta do avanço em andamento


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

	if !is_preview and stats.spawns_disguised:
		_apply_disguise()

	if is_preview:
		set_physics_process(false)
		set_process(false)
		$Area2D.monitoring = false
		$CollisionShape2D.disabled = true
		return

	add_to_group("units")  # usado pela separação macia (_apply_soft_separation)
	current_hp = stats.hp
	$ProgressBar.max_value = stats.hp
	$ProgressBar.value = current_hp
	$ProgressBar.theme = ThemeBuilder.game_theme
	$ProgressBar.custom_minimum_size = Vector2(40, 8)  # garante formato de barra alongada, não um quadrado pequeno
	$LevelLabel.text = str(card_level)
	add_to_group("damageable")

	if stats.spawn_invulnerability_duration > 0:
		_spawn_invulnerable_until = GameManager.game_time + stats.spawn_invulnerability_duration

	if stats.initial_stun_duration > 0:
		apply_incapacitate(stats.initial_stun_duration)

	if stats.deals_arrival_damage:
		_deal_area_damage(global_position, stats.arrival_damage_radius, stats.arrival_damage)

	if stats.entrance_rage_duration > 0:
		apply_speed_multiplier(stats.entrance_rage_speed_mult, stats.entrance_rage_duration)
		apply_damage_multiplier(stats.entrance_rage_damage_mult, stats.entrance_rage_duration)

	if stats.entrance_shockwave_damage > 0:
		_deal_area_damage(global_position, stats.entrance_shockwave_radius, stats.entrance_shockwave_damage)

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

	enemy_base = get_tree().get_first_node_in_group(
		"enemy_base" if team == GameManager.Team.PLAYER else "player_base"
	)


func _apply_unit_scale():
	if stats.unit_scale == 1.0:
		return
	$Sprite2D.scale *= stats.unit_scale
	$CollisionShape2D.scale *= stats.unit_scale


func _physics_process(delta):
	if is_preview:
		return

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
		find_target()
		if target != null and stats.pre_attack_speed_boost:
			apply_speed_multiplier(stats.pre_attack_boost_multiplier, stats.pre_attack_boost_duration)

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

	if _in_attack_range(target):
		_try_attack(delta)


func _configure_detection_area():
	var col: CollisionShape2D = $Area2D/CollisionShape2D
	col.shape = col.shape.duplicate()

	var sight = stats.detection_range if stats.detection_range > 0 else stats.attack_range
	var contact_floor = _get_own_target_radius() * 2.0 + 40.0
	col.shape.radius = max(sight, contact_floor)

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


func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()
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
	var my_r = _get_own_target_radius() * SEPARATION_RADIUS_FRACTION
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
		var min_d = my_r + body._get_own_target_radius() * SEPARATION_RADIUS_FRACTION
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

func _move_towards_base():
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
	var speed = stats.move_speed * speed_multiplier * _rage_mult(_rage_speed)
	if _dash_time_remaining > 0:
		speed *= stats.dash_speed_multiplier
	if _formation_speed_cap >= 0.0:
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
	if stats.is_ranged:
		return _edge_distance(body) <= stats.attack_range
	return _gap_to(body) <= max(stats.attack_range, MELEE_MIN_REACH)


func _get_own_target_radius() -> float:
	return _get_target_radius(self)


func _get_min_contact_range(body) -> float:
	return _get_own_target_radius() + _get_target_radius(body)


# ---------- COMBATE ----------

func _try_attack(_delta):
	if attack_cooldown <= 0:
		if is_instance_valid(target):
			_perform_attack()
		attack_cooldown = stats.attack_speed * _attack_speed_ramp_multiplier / _rage_mult(_rage_attack_speed)


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

	return round(dmg)


func _perform_attack():
	_reveal_disguise()

	var dmg = _get_effective_damage()
	var target_killed = false

	if stats.charge_attack:
		if _charge_distance_accumulated >= stats.charge_distance_needed:
			dmg *= stats.charge_damage_multiplier
			if stats.charge_knockback_distance > 0 and target != null and is_instance_valid(target) and "global_position" in target:
				var knockback_dir = (target.global_position - global_position).normalized()
				target.global_position += knockback_dir * stats.charge_knockback_distance
		_charge_distance_accumulated = 0.0  # sempre reseta -- carregado ou não, precisa andar de novo pra carregar o próximo

	if stats.is_ranged:
		var proj = Projectile.new()
		proj.target = target
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
		proj.pierces = stats.projectile_pierces
		proj.max_targets = stats.projectile_max_targets
		proj.splits = stats.projectile_splits
		proj.split_count = stats.projectile_split_count
		proj.split_range = stats.projectile_split_range
		proj.chains = stats.projectile_chains
		proj.chain_max_targets = stats.projectile_chain_max_targets
		proj.chain_range = stats.projectile_chain_range
		proj.source_card_path = card_data.resource_path if card_data != null else ""
		get_parent().add_child(proj)
		proj.global_position = global_position
	elif stats.spin_attack:
		_perform_spin_attack(dmg)
	elif stats.frontal_cone_attack:
		_perform_cone_attack(dmg)
	elif stats.aoe_hits_extra_one:
		_perform_attack_with_one_extra(dmg)
	elif stats.is_aoe:
		_deal_area_damage(target.global_position, stats.aoe_radius, dmg)
		_apply_on_hit_to_area(target.global_position, stats.aoe_radius)
	else:
		var was_alive_before = "current_hp" in target and target.current_hp > 0
		target.take_damage(dmg)
		_report_base_damage(target, dmg)
		_apply_on_hit_effect_to(target)
		if was_alive_before and "current_hp" in target and target.current_hp <= 0:
			target_killed = true

		if _is_base(target) and stats.steals_resource_on_base_hit:
			_steal_resource_from(target)

		# domina o inimigo: converte ele pro meu time em vez de só bater --
		# versão inicial; não converte base, só unidades normais
		if stats.can_convert_enemy and _converted_count < stats.convert_max_targets:
			if !_is_base(target) and "team" in target:
				target.team = team
				_converted_count += 1

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
	if stats.mastery_effect != UnitData.OnHitEffect.NONE and card_level >= PlayerProfile.MAX_CARD_LEVEL:
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
		if body == self or !("team" in body) or body.team == team:
			continue
		if body.global_position.distance_to(center) <= radius:
			_apply_on_hit_effect_to(body)


func _deal_area_damage(center: Vector2, radius: float, damage: int):
	for body in get_tree().get_nodes_in_group("damageable"):
		if body == self or !("team" in body) or body.team == team:
			continue
		if body.global_position.distance_to(center) <= radius:
			body.take_damage(damage)
			_report_base_damage(body, damage)


func find_target():
	var previous_target = target
	var bodies = $Area2D.get_overlapping_bodies()
	target = null

	var closest_unit = null
	var closest_unit_dist = INF
	var closest_base = null
	var closest_base_dist = INF

	var sight = stats.detection_range if stats.detection_range > 0 else stats.attack_range

	for body in bodies:
		if !_is_valid_enemy(body):
			continue

		var dist = global_position.distance_to(body.global_position)

		if "stats" in body and body.stats != null and body.stats.forces_aggro:
			if dist <= body.stats.taunt_radius:
				target = body
				return

		var is_base_target = _is_base(body)
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
	if stats.bandit_dash and !_has_dashed and previous_target == null and target != null:
		_start_bandit_dash()


# inicia o avanço -- fica invulnerável (reaproveita o mesmo mecanismo já
# usado pra invulnerabilidade de nascimento) e mais rápido por um tempo curto
func _start_bandit_dash():
	_has_dashed = true
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
	if "stats" in body and body.stats != null and body.stats.can_stealth:
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


func take_damage(amount, _is_shared_damage: bool = false):
	# invulnerável logo ao nascer -- nem dano de área/feitiço passa nessa janela
	if _spawn_invulnerable_until > GameManager.game_time:
		return

	# imune enquanto se movendo -- só fica vulnerável de verdade parada
	if stats.immune_while_moving and velocity.length() > 1.0:
		return

	if amount > 0:
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
	if current_shield > 0:
		var absorbed = min(current_shield, amount)
		current_shield -= absorbed
		amount -= absorbed
		if amount <= 0:
			return

	current_hp = clamp(current_hp - amount, 0, stats.hp)
	$ProgressBar.value = current_hp

	if stats.is_linked and !_is_shared_damage and !linked_units.is_empty():
		var shared_amount = amount * stats.link_share_percent
		for ally in linked_units:
			if is_instance_valid(ally):
				ally.take_damage(shared_amount, true)

	if stats.reflects_damage and target != null and is_instance_valid(target):
		target.take_damage(amount * stats.reflect_damage_percent)

	if stats.counter_attack_chance > 0 and randf() < stats.counter_attack_chance:
		if target != null and is_instance_valid(target):
			target.take_damage(stats.damage)

	if current_hp <= 0:
		if stats.can_resurrect and !_has_resurrected:
			_has_resurrected = true
			current_hp = round(stats.hp * stats.resurrect_hp_percent)
			$ProgressBar.value = current_hp
		else:
			die()


func heal(amount):
	current_hp = clamp(current_hp + amount, 0, stats.hp)
	$ProgressBar.value = current_hp


var _flash_active: bool = false


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
		UnitData.OnHitEffect.STUN:
			apply_incapacitate(duration)
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
	new_unit.stats.hp = round(new_unit.stats.hp * mult)
	new_unit.stats.damage = round(new_unit.stats.damage * mult)


func _spawn_clone():
	if scene_file_path == "":
		return
	var clone_scene = load(scene_file_path)

	for i in max(stats.clone_count, 1):
		var clone = clone_scene.instantiate()
		clone.team = team
		clone.card_level = card_level
		_apply_card_level_to_stats(clone)  # antes o clone mostrava o nível mas tinha a força do nível 1
		get_parent().add_child(clone)
		# espalha um pouco quando é mais de um clone, senão nascem empilhados
		var offset = Vector2.ZERO if stats.clone_count <= 1 else Vector2(randf_range(-20, 20), randf_range(-20, 20))
		clone.global_position = global_position + offset
		clone.current_hp = round(clone.stats.hp * stats.clone_hp_percent)
		clone.get_node("ProgressBar").value = clone.current_hp


func die():
	died.emit(team, card_data)

	if stats.explodes_on_death:
		_deal_area_damage(global_position, stats.death_explosion_radius, stats.death_explosion_damage)

	if stats.can_clone:
		_spawn_clone()

	if stats.spawns_on_death and stats.death_spawn_scene != null:
		for i in stats.death_spawn_count:
			_spawn_child(stats.death_spawn_scene, global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)))

	if stats.grants_resource_on_death:
		var opposing_is_player = team != GameManager.Team.PLAYER
		if opposing_is_player:
			GameManager.player_money += stats.death_resource_amount
		else:
			GameManager.enemy_money += stats.death_resource_amount

	queue_free()
