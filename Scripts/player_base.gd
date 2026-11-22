extends StaticBody2D

signal destroyed(team)
signal damaged(amount)

# Valor usado apenas antes de uma BaseData ser instalada.
# Assim que install_base_data() roda, o HP passa a vir do base_hp da BaseData.
@export var max_hp: int = 1000
@export var team: GameManager.Team

var hp: int
var is_main := false       # a BASE PRINCIPAL (regra "modulos"): caiu, a partida acaba
var module_slot := -1      # 0, 1 ou 2: qual dos módulos do lado é este (-1 = não é módulo)
var module_point := -1     # em qual dos 6 pontos ele está
var _spawn_clock := 0.0
var is_gate := false   # o PORTÃO: a torre da frente (regra "portao"), mais fraca que as de trás
var base_data: BaseData = null
var _base_cooldown: float = 0.0   # cura / aura
var _shot_cooldown: float = 0.0   # tiro (toda torre atira nas regras novas)
var _level_multiplier: float = 1.0
var _basic_proj: Texture2D = null


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
	_shot_cooldown = 0.0
	_basic_proj = null

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
	if is_main:
		# a base principal é a maior coisa do seu lado
		$Sprite2D.scale *= 1.22
		$Sprite2D.position.y *= 1.22
	if is_gate:
		# o portão é menor que as torres de trás: dá pra ver de longe quem é quem
		$Sprite2D.scale *= 0.82
		$Sprite2D.position.y *= 0.82
	if Regras.on("visual"):
		# barra da torre na cor do time (azul = sua, vermelha = do adversário)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Regras.team_color(team == GameManager.Team.PLAYER).darkened(0.12)
		fill.set_corner_radius_all(4)
		$ProgressBar.add_theme_stylebox_override("fill", fill)
		$Sprite2D.material = Regras.outline_material(team == GameManager.Team.PLAYER)


# multiplica a vida máxima (usado no 2v2, onde 2 bots atacam a mesma base)
func scale_hp(mult: float):
	max_hp = Regras.tidy(max_hp * mult)   # vida em número redondo (3890, não 3888)
	hp = max_hp
	$ProgressBar.max_value = max_hp
	$ProgressBar.value = hp
	_update_label()


func _process(delta):
	if base_data == null:
		return
	# regenera sozinha (habilidade de módulo)
	if base_data.regen_per_second > 0 and hp > 0 and hp < max_hp:
		_regen_acc += delta * base_data.regen_per_second
		if _regen_acc >= 1.0:
			var gain = int(_regen_acc)
			_regen_acc -= gain
			hp = mini(hp + gain, max_hp)
			$ProgressBar.value = hp
			_update_label()

	# congelada / atordoada: não faz nada até passar
	if _frozen_until > 0.0:
		if is_frozen():
			return
		_frozen_until = -1.0
		_show_frozen(false)
	if _slow_until > 0.0 and _slow_until <= GameManager.game_time:
		_slow_until = -1.0
		_slow_strength = 0.0

	# regras novas: TODA torre atira (as "de tiro" atiram melhor); o tipo
	# continua dando o bônus dele (cura, aura, produção, capacidade, vida)
	if Regras.tower_shoots(base_data):
		_process_cannon(delta * (1.0 - _slow_strength))   # com lentidão o tempo de recarga anda mais devagar
	# módulo que solta tropa sozinho, de tempos em tempos
	if base_data.spawn_card_id != "":
		_spawn_clock += delta
		if !base_data.spawn_on_hit and _spawn_clock >= maxf(base_data.spawn_cooldown, 1.0):
			_spawn_clock = 0.0
			_spawn_guard()

	match base_data.base_type:
		BaseData.BaseType.HEAL:
			_process_heal(delta)

		BaseData.BaseType.AURA:
			_process_aura(delta)

		# Production não faz nada aqui.
		# O efeito dela é aplicado pelo sistema de recursos da batalha.


# ============================================================
# CANHÃO
# ============================================================

# ---- a Casa Grande DORME (igual a torre do rei do Clash): não atira até levar dano
# ou perder um módulo. Sem isso, quem atacava um módulo da frente apanhava do módulo
# E da Casa Grande ao mesmo tempo, e a partida de quem está começando não acabava
# (medido: 11 de 24 partidas sem nenhuma torre cair).
var asleep := false
var _zzz: Label


func set_asleep(v: bool):
	asleep = v
	if v and !is_instance_valid(_zzz):
		_zzz = Label.new()
		_zzz.text = "💤"
		_zzz.add_theme_font_size_override("font_size", 30)
		_zzz.position = Vector2(18, -112)
		_zzz.z_index = 50
		_zzz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_zzz)
	elif !v and is_instance_valid(_zzz):
		_zzz.queue_free()
		_zzz = null


func wake():
	if !asleep:
		return
	set_asleep(false)
	_shot_cooldown = 0.5   # um instante pra reagir
	if is_inside_tree() and hp > 0:
		Fx.text(get_parent(), position + Vector2(0, -84), "ACORDOU!", Color(1.0, 0.9, 0.4), 1.2)
		Sfx.play("torre_dano", 0.1, -1.0, 1.4)


func _shot_range() -> float:
	if is_main and Regras.modules():
		return Regras.main_range()
	return Regras.tower_range(base_data) * (Regras.gate_range_share() if is_gate else 1.0)


func _shot_texture() -> Texture2D:
	if base_data.projectile_texture != null:
		return base_data.projectile_texture
	if !Regras.on("torres"):
		return null
	if _basic_proj == null:
		_basic_proj = SpriteForge.projectile("milho", {})
	return _basic_proj


func _process_cannon(delta):
	if asleep:
		return
	_shot_cooldown -= delta

	if _shot_cooldown > 0:
		return

	var target = _find_cannon_target()

	if target == null:
		return

	var is_cannon = base_data.base_type == BaseData.BaseType.CANNON
	var dmg = int(round(Regras.tower_damage(base_data) * _level_multiplier * (Regras.gate_damage_share() if is_gate else 1.0)))
	# dano que cresce no MESMO alvo (torre "inferno")
	if base_data.ramp_per_shot > 0.0:
		if target == _ramp_target:
			_ramp_mult = minf(_ramp_mult + base_data.ramp_per_shot, maxf(base_data.ramp_max_mult, 1.0))
		else:
			_ramp_target = target
			_ramp_mult = 1.0
		dmg = int(round(dmg * _ramp_mult))
	var shot_tex = _shot_texture()
	_recoil()
	# VÁRIOS ALVOS: os outros alvos da rajada levam o tiro direto (sem projétil)
	if base_data.extra_targets > 0:
		_skip_targets = [target]
		for i in base_data.extra_targets:
			var other = _find_closest_enemy()
			if other == null:
				break
			_skip_targets.append(other)
			Fx.ring(get_parent(), other.position, 12.0, Color(1.0, 0.9, 0.5), 0.2)
			_apply_cannon_damage(other, _shot_damage_on(other, dmg))
		_skip_targets = []
	dmg = _shot_damage_on(target, dmg)

	# --------------------------------------------------------
	# COM PROJÉTIL VISUAL
	# --------------------------------------------------------

	if base_data.beam_attack:
		var heat_t = clampf((_ramp_mult - 1.0) / maxf(base_data.ramp_max_mult - 1.0, 0.01), 0.0, 1.0) if base_data.ramp_per_shot > 0.0 else 0.0
		Fx.beam(get_parent(), position + Vector2(0, -26), target.position if target.get_parent() == get_parent() else get_parent().to_local(target.global_position),
			_beam_color(heat_t), 2.5 + 5.5 * heat_t, maxf(Regras.tower_interval(base_data) * 1.25, 0.2))
		_apply_cannon_damage(target, dmg)
	elif shot_tex != null:
		var proj = Projectile.new()

		proj.target = target
		proj.damage = dmg
		proj.speed = maxf(base_data.projectile_speed, 380.0) if Regras.on("torres") else base_data.projectile_speed
		proj.texture = shot_tex

		# Ataque em área (só torre "de tiro")
		proj.is_aoe = base_data.is_aoe and is_cannon
		proj.aoe_radius = base_data.aoe_radius

		proj.attacker_team = team
		proj.can_miss = base_data.projectile_can_miss
		proj.launch_angle = base_data.projectile_launch_angle
		proj.pierces = base_data.projectile_pierces
		proj.max_targets = base_data.projectile_max_targets
		proj.splits = base_data.projectile_splits
		proj.split_count = base_data.projectile_split_count
		proj.split_range = base_data.projectile_split_range
		proj.chains = base_data.projectile_chains
		proj.chain_max_targets = base_data.projectile_chain_max_targets
		proj.chain_range = base_data.projectile_chain_range

		# Efeitos: o tiro básico das outras torres é só dano (o efeito delas é a aura)
		if is_cannon:
			proj.on_hit_effect = base_data.effect
			proj.on_hit_effect_duration = base_data.effect_duration
			proj.on_hit_effect_strength = base_data.effect_strength
			proj.on_hit_effect_tick_interval = base_data.effect_tick_interval
			proj.knockback_distance = base_data.knockback_distance

		if Regras.on("visual"):
			proj.scale = Vector2(1.9, 1.9)  # tiro da torre bem visível
		get_parent().add_child(proj)
		proj.global_position = global_position
		if Regras.on("torres"):
			# sai do alto da torre, com um estalinho: dá pra ver e ouvir a torre defendendo
			proj.global_position = global_position + Vector2(0, -26)
			Fx.burst(get_parent(), position + Vector2(0, -30), Color(1.0, 0.9, 0.5), 3, 60.0, 2.5)
			Sfx.play("tiro", 0.12, -7.0)

	# --------------------------------------------------------
	# SEM PROJÉTIL VISUAL
	# --------------------------------------------------------

	else:
		_apply_cannon_damage(target, dmg)

	_shot_cooldown = Regras.tower_interval(base_data)


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


var _locked_target = null   # alvo travado da torre


## Efeitos na TORRE: só atordoar/congelar fazem algo -- ela solta o alvo
## travado, fica um instante sem atirar e depois escolhe de novo o inimigo
## mais perto. É o jeito de "resetar o agro" da torre (igual o choque do Clash).
func apply_on_hit_effect(effect, _strength: float, duration: float, _tick_interval: float = 1.0, _knockback_dist: float = 0.0, _from_position: Vector2 = Vector2.ZERO):
	if effect == UnitData.OnHitEffect.STUN or effect == UnitData.OnHitEffect.FREEZE:
		# CONGELADA / ATORDOADA: a torre PARA de verdade pelo tempo todo do efeito -- não atira,
		# não cura, não solta aura nem tropa. (Antes ela só perdia o alvo e ficava no máximo 1s
		# sem atirar: o feitiço de gelo parecia não funcionar em módulo nem no Celeiro.)
		_locked_target = null
		_frozen_until = maxf(_frozen_until, GameManager.game_time + maxf(duration, 0.1))
		_frozen_ice = effect == UnitData.OnHitEffect.FREEZE
		_shot_cooldown = maxf(_shot_cooldown, 0.25)   # ao descongelar leva um instante pra mirar de novo
		_show_frozen(true)
	elif effect == UnitData.OnHitEffect.SLOW and _strength > 0.0:
		# LENTIDÃO: atira mais devagar enquanto durar
		_slow_until = maxf(_slow_until, GameManager.game_time + maxf(duration, 0.1))
		_slow_strength = clampf(maxf(_slow_strength, _strength), 0.0, 0.8)


var _frozen_until := -1.0
var _frozen_ice := true
var _frozen_shown := false
var _slow_until := -1.0
var _slow_strength := 0.0


func is_frozen() -> bool:
	return _frozen_until > GameManager.game_time


func _show_frozen(on: bool):
	if on == _frozen_shown:
		return
	_frozen_shown = on
	var sp = get_node_or_null("Sprite2D")
	if sp != null:
		sp.modulate = (Color(0.55, 0.8, 1.0) if _frozen_ice else Color(1.0, 0.95, 0.55)) if on else Color(1, 1, 1)
	if on and is_inside_tree():
		Fx.ring(get_parent(), position, 34.0, Color(0.6, 0.85, 1.0) if _frozen_ice else Color(1.0, 0.9, 0.4), 0.4)
		Fx.text(get_parent(), position + Vector2(0, -44), "CONGELADA" if _frozen_ice else "ATORDOADA", Color(0.7, 0.9, 1.0) if _frozen_ice else Color(1.0, 0.9, 0.4), 0.9)


## A torre TRAVA no alvo: continua atirando no mesmo até ele morrer ou sair do
## alcance. Antes ela escolhia "o mais perto" a cada tiro, então quando a
## tropa fraca passava na frente do tanque a torre largava o tanque -- e o
## combo "tanque na frente, apoio atrás" não funcionava.
func _find_cannon_target():
	if _locked_target != null and is_instance_valid(_locked_target) and !_locked_target.is_queued_for_deletion() \
			and _locked_target.is_inside_tree() and ("team" in _locked_target) and _locked_target.team != team \
			and global_position.distance_to(_locked_target.global_position) <= _shot_range():
		return _locked_target
	_locked_target = _find_closest_enemy()
	return _locked_target


# Procura o inimigo mais próximo dentro do alcance do canhão.
func _find_closest_enemy():
	var closest = null
	var closest_dist = INF
	var shot_range = _shot_range()

	for body in get_tree().get_nodes_in_group("damageable"):

		if body == self:
			continue

		if !("team" in body):
			continue

		if body.team == team:
			continue

		if !is_instance_valid(body):
			continue
		if body in _skip_targets:
			continue   # já escolhido nesta rajada (torre de vários alvos)
		if body.has_method("is_hidden") and body.is_hidden():
			continue   # armadilha armada / construção escondida: a torre não vê
		# QUEM este módulo acerta: chão, ar ou os dois
		if base_data != null and base_data.targets != 0 and "stats" in body and body.stats != null:
			var flying = body.stats.unit_type == UnitData.UnitType.AIR
			if (base_data.targets == 1 and flying) or (base_data.targets == 2 and !flying):
				continue

		var dist = global_position.distance_to(body.global_position)

		if dist <= shot_range and dist < closest_dist:
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

func _beam_color(heat_t: float) -> Color:
	var c = Color(1.0, 0.75, 0.3)
	if base_data.beam_tint > 0:
		c = SpellData.TINT_COLORS[clampi(base_data.beam_tint, 1, SpellData.TINT_COLORS.size() - 1)]
	if base_data.beam_heats_red:
		c = c.lerp(Color(1.0, 0.3, 0.15), heat_t)
	c.a = 1.0
	return c


var _skip_targets: Array = []
var _ramp_target = null
var _ramp_mult := 1.0
var _regen_acc := 0.0


## executa alvo fraco: o tiro sai multiplicado em quem está com pouca vida
func _shot_damage_on(victim, dmg: int) -> int:
	if base_data == null or base_data.execute_threshold <= 0.0 or victim == null or !is_instance_valid(victim):
		return dmg
	var frac = 1.0
	if "current_hp" in victim and "stats" in victim and victim.stats != null:
		frac = float(victim.current_hp) / maxf(float(victim.stats.hp), 1.0)
	return int(round(dmg * base_data.execute_damage_mult)) if frac <= base_data.execute_threshold else dmg


func take_damage(amount):
	if base_data != null and amount > 0:
		var armor = base_data.damage_reduction_percent
		if !is_main and module_point >= 0 and Regras.modules():
			armor += Regras.point_armor(module_point)   # frente 10%, lado 5%
		if armor > 0.0:
			amount = amount * (1.0 - clampf(armor, 0.0, 0.9))
		# devolve parte do dano pra quem está batendo de perto
		if base_data.reflect_percent > 0.0 and !_reflecting:
			_reflecting = true
			for body in get_tree().get_nodes_in_group("units"):
				if is_instance_valid(body) and "team" in body and body.team != team and body.get("target") == self \
						and body.stats != null and !body.stats.is_ranged and global_position.distance_to(body.global_position) <= 110.0:
					body.take_damage(int(round(amount * base_data.reflect_percent)))
			_reflecting = false
	hp = clamp(hp - amount, 0, max_hp)
	if asleep and amount > 0:
		wake()
	# módulo de guarda: apanhou, solta tropa (com um intervalo mínimo)
	if base_data != null and base_data.spawn_on_hit and base_data.spawn_card_id != "" and hp > 0 and amount > 0 \
			and _spawn_clock >= maxf(base_data.spawn_cooldown, 1.0):
		_spawn_clock = 0.0
		_spawn_guard()
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
var _recoiling := false


## tranquinho da torre a cada tiro (dá pra VER que ela está defendendo)
func _recoil():
	if _recoiling or _shaking or !has_node("Sprite2D") or !Regras.on("torres"):
		return
	_recoiling = true
	var sprite = $Sprite2D
	var base_scale = sprite.scale
	var tw = create_tween()
	tw.tween_property(sprite, "scale", base_scale * Vector2(1.06, 0.94), 0.05)
	tw.tween_property(sprite, "scale", base_scale, 0.09)
	tw.tween_callback(func(): _recoiling = false)


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


## solta a tropa do módulo, do lado dele que olha pro rio
func _spawn_guard():
	var card: CardData = Catalogo.card(base_data.spawn_card_id)
	var bs = get_tree().get_first_node_in_group("battle_scene")
	if card == null or bs == null or card.unit_scene == null:
		return
	var toward = 1.0 if team == GameManager.Team.ENEMY else -1.0
	bs.spawn_unit(card.unit_scene, team, global_position + Vector2(randf_range(-20.0, 20.0), 55.0 * toward), card)
	Fx.text(get_parent(), position + Vector2(0, -40), "+ " + card.card_name, Color(0.7, 1.0, 0.7), 1.2)


var _reflecting := false


func die():
	if base_data != null and base_data.death_explosion_damage > 0:
		Fx.ring(get_parent(), position, base_data.death_explosion_radius, Color(1.0, 0.5, 0.2), 0.6)
		for body in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(body) and "team" in body and body.team != team and global_position.distance_to(body.global_position) <= base_data.death_explosion_radius:
				body.take_damage(int(round(base_data.death_explosion_damage * _level_multiplier)))
	var bs0 = get_tree().get_first_node_in_group("battle_scene")
	if bs0 != null and bs0.has_method("on_tower_lost"):
		bs0.on_tower_lost(self)   # tira da partida o que este módulo dava (recurso, capacidade...)
	var parent = get_parent()
	Fx.ring(parent, position, 90.0, Color(1.0, 0.75, 0.3), 0.6)
	Fx.puff(parent, position, 3.0)
	Fx.burst(parent, position, Color(0.75, 0.5, 0.3), 22, 200.0, 5.0)
	Fx.text(parent, position + Vector2(0, -30), "TORRE CAIU!", Color(1, 0.85, 0.3), 1.6)
	Sfx.play("torre_cai", 0.0, 3.0)
	var bs = get_tree().get_first_node_in_group("battle_scene")
	if bs != null and bs.has_method("shake"):
		bs.shake(9.0, 0.45)
	destroyed.emit(team)
	queue_free()
