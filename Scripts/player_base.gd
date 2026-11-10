extends StaticBody2D

signal destroyed(team)
signal damaged(amount)

# Valor usado apenas antes de uma BaseData ser instalada.
# Assim que install_base_data() roda, o HP passa a vir do base_hp da BaseData.
@export var max_hp: int = 1000
@export var team: GameManager.Team

var hp: int
var base_data: BaseData = null
var _base_cooldown: float = 0.0
var _level_multiplier: float = 1.0


func _ready():
	hp = max_hp
	$ProgressBar.max_value = max_hp
	$ProgressBar.value = hp
	$ProgressBar.theme = ThemeBuilder.game_theme
	$ProgressBar.custom_minimum_size = Vector2(80, 16)
	_update_label()

	add_to_group("damageable")
	add_to_group(
		"player_base" if team == GameManager.Team.PLAYER else "enemy_base"
	)

	# Camada 3: construções.
	# Permite que unidades terrestres e aéreas continuem colidindo
	# fisicamente com a base.
	# CORRIGIDO: era 0b100, que no esquema das unidades é a camada "aérea do
	# jogador" -- terrestre atravessava a base e aérea inimiga batia nela.
	# 0b010000 = LAYER_BUILDING de unit_base.gd
	collision_layer = 0b010000
	collision_mask = 0


# Instala os dados da base escolhida no começo da partida.
func install_base_data(new_base_data: BaseData, level: int = 1):
	base_data = new_base_data
	_base_cooldown = 0.0

	var mult = PlayerProfile.compute_base_stat_multiplier(level)
	_level_multiplier = mult

	max_hp = round(base_data.base_hp * mult)
	hp = max_hp

	$ProgressBar.max_value = max_hp
	$ProgressBar.value = hp
	_update_label()

	# Troca a aparência da base se houver uma textura específica.
	if base_data.base_texture != null:
		$Sprite2D.texture = base_data.base_texture
		if base_data.base_texture is ImageTexture:
			$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # arte do Criador, pixel nítido
		if base_data.base_texture.get_size() == Vector2(48, 48):
			$Sprite2D.scale = Vector2(2.0, 2.0)  # arte 2.0 (48x48)
			$Sprite2D.position = Vector2(0, -14)
		if team == GameManager.Team.ENEMY:
			$Sprite2D.self_modulate = Color(1.0, 0.82, 0.82)  # torres inimigas levemente avermelhadas


# multiplica a vida máxima (usado no 2v2, onde 2 bots atacam a mesma base)
func scale_hp(mult: float):
	max_hp = int(round(max_hp * mult))
	hp = max_hp
	$ProgressBar.max_value = max_hp
	$ProgressBar.value = hp
	_update_label()


func _process(delta):
	if base_data == null:
		return

	match base_data.base_type:
		BaseData.BaseType.CANNON:
			_process_cannon(delta)

		BaseData.BaseType.HEAL:
			_process_heal(delta)

		BaseData.BaseType.AURA:
			_process_aura(delta)

		# Production não faz nada aqui.
		# O efeito dela é aplicado pelo sistema de recursos da batalha.


# ============================================================
# CANHÃO
# ============================================================

func _process_cannon(delta):
	_base_cooldown -= delta

	if _base_cooldown > 0:
		return

	var target = _find_cannon_target()

	if target == null:
		return

	var dmg = int(round(base_data.attack_damage * _level_multiplier))

	# --------------------------------------------------------
	# COM PROJÉTIL VISUAL
	# --------------------------------------------------------

	if base_data.projectile_texture != null:
		var proj = Projectile.new()

		proj.target = target
		proj.damage = dmg
		proj.speed = base_data.projectile_speed
		proj.texture = base_data.projectile_texture

		# Ataque em área
		proj.is_aoe = base_data.is_aoe
		proj.aoe_radius = base_data.aoe_radius

		proj.attacker_team = team

		# Efeitos
		proj.on_hit_effect = base_data.effect
		proj.on_hit_effect_duration = base_data.effect_duration
		proj.on_hit_effect_strength = base_data.effect_strength
		proj.on_hit_effect_tick_interval = base_data.effect_tick_interval
		proj.knockback_distance = base_data.knockback_distance

		get_parent().add_child(proj)
		proj.global_position = global_position

	# --------------------------------------------------------
	# SEM PROJÉTIL VISUAL
	# --------------------------------------------------------

	else:
		_apply_cannon_damage(target, dmg)

	_base_cooldown = base_data.attack_speed


# Aplica o dano do canhão quando não existe projétil visual.
#
# Se for AOE:
# - o alvo principal recebe dano;
# - todos os inimigos dentro do raio da explosão também recebem dano.
#
# O centro da explosão é a posição do alvo atingido,
# e não a posição da base.
func _apply_cannon_damage(target, dmg):
	if target == null:
		return

	if base_data.is_aoe:
		for other in get_tree().get_nodes_in_group("damageable"):

			if other == self:
				continue

			if !("team" in other):
				continue

			if other.team == team:
				continue

			if !is_instance_valid(other):
				continue

			if target.global_position.distance_to(other.global_position) <= base_data.aoe_radius:
				if other.has_method("take_damage"):
					other.take_damage(dmg)

				_apply_base_effect_to(other)

	else:
		if target.has_method("take_damage"):
			target.take_damage(dmg)

		_apply_base_effect_to(target)


# Procura o inimigo mais próximo dentro do alcance do canhão.
func _find_cannon_target():
	var closest = null
	var closest_dist = INF

	for body in get_tree().get_nodes_in_group("damageable"):

		if body == self:
			continue

		if !("team" in body):
			continue

		if body.team == team:
			continue

		if !is_instance_valid(body):
			continue

		var dist = global_position.distance_to(body.global_position)

		if dist <= base_data.attack_range and dist < closest_dist:
			closest_dist = dist
			closest = body

	return closest


# ============================================================
# CURA
# ============================================================

func _process_heal(delta):
	_base_cooldown -= delta

	if _base_cooldown > 0:
		return

	_base_cooldown = base_data.heal_interval

	for body in get_tree().get_nodes_in_group("damageable"):

		if body == self:
			continue

		if !("team" in body):
			continue

		if body.team != team:
			continue

		if !body.has_method("heal"):
			continue

		if global_position.distance_to(body.global_position) <= base_data.heal_radius:
			body.heal(base_data.heal_amount * _level_multiplier)


# ============================================================
# AURA
# ============================================================

# Aplica o efeito configurado em todos os inimigos
# que estiverem dentro do raio da aura.
func _process_aura(delta):

	if base_data.effect == UnitData.OnHitEffect.NONE:
		return

	_base_cooldown -= delta

	if _base_cooldown > 0:
		return

	_base_cooldown = base_data.aura_tick_interval

	for body in get_tree().get_nodes_in_group("damageable"):

		if body == self:
			continue

		if !("team" in body):
			continue

		if body.team == team:
			continue

		if !is_instance_valid(body):
			continue

		if global_position.distance_to(body.global_position) <= base_data.aura_radius:
			_apply_base_effect_to(body)


# ============================================================
# EFEITOS
# ============================================================

func _apply_base_effect_to(body):

	if base_data.effect == UnitData.OnHitEffect.NONE:
		return

	if !body.has_method("apply_on_hit_effect"):
		return

	body.apply_on_hit_effect(
		base_data.effect,
		base_data.effect_strength,
		base_data.effect_duration,
		base_data.effect_tick_interval,
		base_data.knockback_distance,
		global_position
	)


# ============================================================
# DANO DA BASE
# ============================================================

func take_damage(amount):
	hp = clamp(hp - amount, 0, max_hp)
	if amount >= 15:
		Fx.number(get_parent(), position + Vector2(0, -40), amount, Color(1, 0.8, 0.35))
		Sfx.play("torre_dano", 0.1, -2.0)
		_shake()

	$ProgressBar.value = hp
	_update_label()

	damaged.emit(amount)

	if hp <= 0:
		die()


# ============================================================
# INTERFACE
# ============================================================

func _update_label():
	$HPLabel.text = str(hp) + " / " + str(max_hp)


# ============================================================
# MORTE
# ============================================================

var _shaking := false


func _shake():
	if _shaking or !has_node("Sprite2D"):
		return
	_shaking = true
	var sprite = $Sprite2D
	var home = sprite.position
	var tw = create_tween()
	for i in 3:
		tw.tween_property(sprite, "position", home + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	tw.tween_property(sprite, "position", home, 0.03)
	tw.tween_callback(func(): _shaking = false)


func die():
	var parent = get_parent()
	Fx.ring(parent, position, 90.0, Color(1.0, 0.75, 0.3), 0.6)
	Fx.puff(parent, position, 3.0)
	Fx.burst(parent, position, Color(0.75, 0.5, 0.3), 22, 200.0, 5.0)
	Fx.text(parent, position + Vector2(0, -30), "TORRE CAIU!", Color(1, 0.85, 0.3), 1.6)
	Sfx.play("torre_cai", 0.0, 3.0)
	destroyed.emit(team)
	queue_free()
