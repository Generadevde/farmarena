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

## PODE ERRAR: o tiro vai reto pra onde o alvo ESTAVA quando saiu. Se o alvo andou, erra.
var can_miss: bool = false
## BUMERANGUE: vai reto até return_reach da dona atravessando, depois volta pra ela acertando de novo
var returns_to: Node2D = null
var return_reach := 200.0
var _boomerang_back := false
var _boomerang_dir := Vector2.ZERO
var _boomerang_start := Vector2.ZERO
## ÂNGULO DE SAÍDA (graus): 0 = tiro reto; quanto maior, mais alto o arco (tiro de morteiro).
var launch_angle: float = 0.0
var _aim_point := Vector2.INF
var _aim_total := 0.0
var _sprite: Sprite2D = null

var _hit_targets: Array = []
var _locked_direction: Vector2 = Vector2.ZERO
var _travel_distance: float = 0.0

const HIT_DISTANCE = 10.0
const MAX_TRAVEL_DISTANCE = 700.0  # segurança pra não voar pra sempre se perder o alvo


func _ready():
	if texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = texture
		add_child(_sprite)


var origin := Vector2.ZERO
var _origin_set := false


func _physics_process(delta):
	if !_origin_set:
		_origin_set = true
		origin = global_position  # o atirador coloca o projétil em cima dele antes do 1º quadro
	var dir = _locked_direction
	if returns_to != null:
		_boomerang(delta)
		return
	if _aim_point == Vector2.INF and is_instance_valid(target):
		_aim_point = target.global_position          # onde o alvo estava na hora do disparo
		_aim_total = maxf(global_position.distance_to(_aim_point), 1.0)
	# arco: o desenho sobe e desce no caminho (o tiro em si continua na linha do chão)
	if launch_angle > 0.5 and _sprite != null and _aim_total > 0.0:
		var prog = clampf(_travel_distance / _aim_total, 0.0, 1.0)
		var top = minf(_aim_total * tan(deg_to_rad(clampf(launch_angle, 0.0, 80.0))) * 0.25, 120.0)
		_sprite.position = Vector2(0, -sin(prog * PI) * top).rotated(-rotation)
	if can_miss and _hit_targets.is_empty() and _aim_point != Vector2.INF:
		# vai reto pro ponto; chegando lá acerta quem estiver em cima, ou erra
		var to_aim = _aim_point - global_position
		var step = speed * delta
		if to_aim.length() <= step + 1.0:
			global_position = _aim_point
			_travel_distance = _aim_total
			var best = null
			var best_d = HIT_DISTANCE + 10.0
			for body in get_tree().get_nodes_in_group("damageable"):
				if !("team" in body) or body.team == attacker_team or !_allowed(body):
					continue
				var dd = global_position.distance_to(body.global_position)
				if dd <= best_d:
					best_d = dd
					best = body
			if best == null:
				Fx.puff(get_parent(), position, 0.5)       # errou: poeirinha no chão
				queue_free()
				return
			_hit_targets.append(best)
			_apply_hit(best)
			if chains and _hit_targets.size() < chain_max_targets:
				_retarget_to_nearest()
			elif splits:
				_spawn_splits()
				queue_free()
			elif !pierces:
				queue_free()
			return
		dir = to_aim.normalized()
		_locked_direction = dir
		global_position += dir * step
		rotation = dir.angle()
		_travel_distance += step
		if pierces:
			_check_hits()
		return

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


## quem atira só em construção não acerta tropa (nem a que está no caminho, nem na corrente)
var buildings_only := false


func _allowed(body) -> bool:
	if !buildings_only:
		return true
	return !("stats" in body) or body.stats == null or body.stats.unit_type == UnitData.UnitType.BUILDING


func _boomerang(delta):
	if _boomerang_dir == Vector2.ZERO:
		_boomerang_start = global_position
		_boomerang_dir = (target.global_position - global_position).normalized() if is_instance_valid(target) else Vector2.UP
	var step = speed * delta
	rotation += 18.0 * delta   # gira no ar
	if !_boomerang_back:
		global_position += _boomerang_dir * step
		if global_position.distance_to(_boomerang_start) >= return_reach:
			_boomerang_back = true
			_hit_targets.clear()      # na volta acerta todo mundo de novo
	else:
		if !is_instance_valid(returns_to):
			queue_free()
			return
		var to_home = returns_to.global_position - global_position
		if to_home.length() <= step + 8.0:
			queue_free()
			return
		global_position += to_home.normalized() * step
	for body in get_tree().get_nodes_in_group("damageable"):
		if body in _hit_targets or !("team" in body) or body.team == attacker_team or !_allowed(body):
			continue
		if global_position.distance_to(body.global_position) <= HIT_DISTANCE + 10.0:
			_hit_targets.append(body)
			_apply_hit(body)


func _check_hits():
	for body in get_tree().get_nodes_in_group("damageable"):
		if body in _hit_targets:
			continue
		if !("team" in body) or body.team == attacker_team:
			continue
		if !_allowed(body):
			continue
		# tiro teleguiado acerta o ALVO dele, não quem estiver no caminho (antes a tropa
		# encostada no atirador "comia" o tiro que era pra torre). Só o que atravessa pega o caminho
		if !pierces and is_instance_valid(target) and body != target:
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
		if !("team" in body) or body.team == attacker_team or !_allowed(body):
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
			if !("team" in other) or other.team == attacker_team or !_allowed(other):
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
		if !("team" in body) or body.team == attacker_team or !_allowed(body):
			continue
		if global_position.distance_to(body.global_position) <= split_range:
			nearby.append(body)

	nearby.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	var count = min(split_count, nearby.size())
	# os grãos que não têm inimigo por perto pra acertar voam abertos em leque e somem
	# (só visual) -- assim dá pra ver o tiro se dividindo mesmo contra um alvo só
	var forward = _locked_direction if _locked_direction != Vector2.ZERO else Vector2.UP
	for k in range(count, split_count):
		if texture == null:
			break
		var frag = Sprite2D.new()
		frag.texture = texture
		frag.position = position
		frag.z_index = 25
		get_parent().add_child(frag)
		var spread = forward.rotated(deg_to_rad(-55.0 + 110.0 * (k + 0.5) / split_count))
		frag.rotation = spread.angle()
		var tw = frag.create_tween()
		tw.set_parallel(true)
		tw.tween_property(frag, "position", position + spread * 70.0, 0.3)
		tw.tween_property(frag, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(frag.queue_free)
	for i in count:
		var new_proj = Projectile.new()
		new_proj.target = nearby[i]
		new_proj.damage = damage
		new_proj.speed = speed
		new_proj.texture = texture
		new_proj.attacker_team = attacker_team
		new_proj.buildings_only = buildings_only
		new_proj.launch_angle = launch_angle
		new_proj.source_card_path = source_card_path
		new_proj.on_hit_effect = on_hit_effect
		new_proj.on_hit_effect_duration = on_hit_effect_duration
		new_proj.on_hit_effect_strength = on_hit_effect_strength
		new_proj.on_hit_effect_tick_interval = on_hit_effect_tick_interval
		new_proj.knockback_distance = knockback_distance
		get_parent().add_child(new_proj)
		new_proj.global_position = global_position
