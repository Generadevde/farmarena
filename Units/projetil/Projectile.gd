extends Node2D
class_name Projectile

var target = null
var damage: int = 0
var speed: float = 300.0
var texture: Texture2D

var is_aoe: bool = false
var aoe_radius: float = 60.0
var attacker_team
var source_card_path: String = ""  # pra reportar dano na base por carta, igual ataque direto já faz

var on_hit_effect: int = 0
var on_hit_effect_duration: float = 2.0
var on_hit_effect_strength: float = 0.5
var on_hit_effect_tick_interval: float = 1.0
var knockback_distance: float = 40.0

# atravessa e acerta várias unidades, e/ou se divide ao acertar
var pierces: bool = false
var max_targets: int = 1
var splits: bool = false
var split_count: int = 3
var split_range: float = 150.0

# encadeado: acerta um alvo, depois pula pro mais próximo ainda não atingido
var chains: bool = false
var chain_max_targets: int = 3
var chain_range: float = 150.0

var _hit_targets: Array = []
var _locked_direction: Vector2 = Vector2.ZERO
var _travel_distance: float = 0.0

const HIT_DISTANCE = 10.0
const MAX_TRAVEL_DISTANCE = 700.0  # segurança pra não voar pra sempre se perder o alvo


func _ready():
	if texture != null:
		var sprite = Sprite2D.new()
		sprite.texture = texture
		add_child(sprite)


var origin := Vector2.ZERO
var _origin_set := false


func _physics_process(delta):
	if !_origin_set:
		_origin_set = true
		origin = global_position  # o atirador coloca o projétil em cima dele antes do 1º quadro
	var dir = _locked_direction

	if is_instance_valid(target) and (_hit_targets.is_empty() or chains):
		dir = (target.global_position - global_position).normalized()
		_locked_direction = dir
	elif dir == Vector2.ZERO:
		# perdeu o alvo antes de travar uma direção -- não tem pra onde ir
		queue_free()
		return

	global_position += dir * speed * delta
	rotation = dir.angle()
	_travel_distance += speed * delta

	_check_hits()

	if _travel_distance > MAX_TRAVEL_DISTANCE:
		_finish()
	elif chains:
		if _hit_targets.size() >= chain_max_targets:
			_finish()
	elif !pierces and !_hit_targets.is_empty():
		_finish()
	elif _hit_targets.size() >= max_targets:
		_finish()


func _check_hits():
	for body in get_tree().get_nodes_in_group("damageable"):
		if body in _hit_targets:
			continue
		if !("team" in body) or body.team == attacker_team:
			continue
		if global_position.distance_to(body.global_position) <= HIT_DISTANCE:
			_hit_targets.append(body)
			_apply_hit(body)

			if chains and _hit_targets.size() < chain_max_targets:
				_retarget_to_nearest()
			elif !pierces:
				return


# acha o inimigo mais próximo ainda não atingido e faz o projétil mudar de
# rumo pra ele -- se não sobrar ninguém, encerra ali mesmo
func _retarget_to_nearest():
	var nearest = null
	var nearest_dist = INF

	for body in get_tree().get_nodes_in_group("damageable"):
		if body in _hit_targets:
			continue
		if !("team" in body) or body.team == attacker_team:
			continue
		var dist = global_position.distance_to(body.global_position)
		if dist <= chain_range and dist < nearest_dist:
			nearest_dist = dist
			nearest = body

	if nearest != null:
		target = nearest
	else:
		_finish()


func _apply_hit(body):
	if is_aoe:
		for other in get_tree().get_nodes_in_group("damageable"):
			if !("team" in other) or other.team == attacker_team:
				continue
			if other.global_position.distance_to(body.global_position) <= aoe_radius:
				other.take_damage(damage)
				_apply_effect(other)
				_report_base_damage(other)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
		_apply_effect(body)
		_report_base_damage(body)


# mesma ideia de unit.gd -- se o alvo for base, avisa a cena de batalha pra
# acumular o dano por CARTA (source_card_path, herdado de quem disparou)
func _report_base_damage(body):
	if source_card_path == "":
		return
	if !body.is_in_group("enemy_base") and !body.is_in_group("player_base"):
		return
	var battle = get_tree().get_first_node_in_group("battle_scene")
	if battle != null and battle.has_method("record_base_damage_by_card"):
		battle.record_base_damage_by_card(source_card_path, damage, body.is_in_group("player_base"))


func _apply_effect(body):
	if on_hit_effect == 0:  # UnitData.OnHitEffect.NONE
		return
	if body.has_method("apply_on_hit_effect"):
		body.apply_on_hit_effect(
			on_hit_effect,
			on_hit_effect_strength,
			on_hit_effect_duration,
			on_hit_effect_tick_interval,
			knockback_distance,
			origin  # de onde o tiro saiu: puxão traz pra perto do atirador, empurrão joga pra longe dele
		)


func _finish():
	Fx.burst(get_parent(), position, Color(1, 0.95, 0.8), 4, 60.0, 2.5)
	if is_aoe:
		Fx.ring(get_parent(), position, aoe_radius, Color(1.0, 0.72, 0.3))
	if splits:
		_spawn_splits()
	queue_free()


func _spawn_splits():
	var nearby: Array = []
	for body in get_tree().get_nodes_in_group("damageable"):
		if body in _hit_targets:
			continue
		if !("team" in body) or body.team == attacker_team:
			continue
		if global_position.distance_to(body.global_position) <= split_range:
			nearby.append(body)

	nearby.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	var count = min(split_count, nearby.size())
	for i in count:
		var new_proj = Projectile.new()
		new_proj.target = nearby[i]
		new_proj.damage = damage
		new_proj.speed = speed
		new_proj.texture = texture
		new_proj.attacker_team = attacker_team
		new_proj.source_card_path = source_card_path
		new_proj.on_hit_effect = on_hit_effect
		new_proj.on_hit_effect_duration = on_hit_effect_duration
		new_proj.on_hit_effect_strength = on_hit_effect_strength
		new_proj.on_hit_effect_tick_interval = on_hit_effect_tick_interval
		new_proj.knockback_distance = knockback_distance
		get_parent().add_child(new_proj)
		new_proj.global_position = global_position
