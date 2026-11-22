extends Node2D
class_name SpellEffect

var spell: SpellData
var caster_team
var power: float = 1.0  # multiplicador do nível da carta (dano/cura/escudo/invocados)
var level: int = 1
var source_card_path: String = ""  # pra reportar dano na base por carta, igual unit.gd/projectile.gd já fazem

var _tick_timer: float = 0.0
var _elapsed: float = 0.0
var _summon_timer: float = 0.0


func _ready():
	if spell.ground_effect_texture != null:
		var visual = Sprite2D.new()
		visual.texture = spell.ground_effect_texture
		add_child(visual)

	if spell.rolls:
		# rola pra frente, pro lado do adversário (o campo do jogador é o de baixo)
		_roll_dir = Vector2(0, -1) if caster_team == GameManager.Team.PLAYER else Vector2(0, 1)
		_rolling = true
		Sfx.play("torre_dano", 0.1, -2.0, 0.7)
		return
	_cast_fx()
	if !(spell.rolls and spell.summon_at_end):
		_summon_units()
	if spell.clones_allies:
		_clone_allies()
	_apply_tick()  # aplica imediatamente ao ser lançado

	if spell.duration <= 0:
		queue_free()  # instantâneo: aplica uma vez e desaparece
	else:
		_tick_timer = spell.tick_interval


var _rolling := false
var _roll_dir := Vector2.ZERO
var _rolled := 0.0
var _roll_hit := {}


func _roll(delta):
	var step = spell.roll_speed * delta
	position += _roll_dir * step
	_rolled += step
	for body in get_tree().get_nodes_in_group("damageable"):
		if !is_instance_valid(body) or !("team" in body) or body.team == caster_team or _roll_hit.has(body.get_instance_id()):
			continue
		if "stats" in body and body.stats != null and body.stats.unit_type == UnitData.UnitType.AIR:
			continue   # rola pelo chão: voador passa por cima
		var d = body.global_position - global_position
		if absf(d.x) <= spell.radius and absf(d.y) <= 26.0:
			_roll_hit[body.get_instance_id()] = true
			_apply_effect(body)
	queue_redraw()
	if _rolled >= spell.roll_distance:
		if spell.summon_at_end:
			_summon_units()   # BARRIL: abre no fim da rolagem
		queue_free()


func _draw():
	if !_rolling:
		return
	var w = spell.radius
	var col = spell.fx_color if spell.fx_color.a > 0.0 else Color("#8a5a34")
	draw_rect(Rect2(-w, -9, w * 2.0, 18), col)
	draw_rect(Rect2(-w, -9, w * 2.0, 18), col.darkened(0.45), false, 3.0)
	for i in 5:
		var x = -w + fmod(_rolled * 0.6 + i * w * 0.4, w * 2.0)
		draw_line(Vector2(x, -9), Vector2(x, 9), col.darkened(0.3), 2.0)


func _process(delta):
	if _rolling:
		_roll(delta)
		return
	if spell.duration <= 0:
		return

	_elapsed += delta
	if _elapsed >= spell.duration:
		queue_free()
		return

	if spell.summon_interval > 0.0 and spell.summon_scene != null:
		_summon_timer += delta
		if _summon_timer >= spell.summon_interval:
			_summon_timer = 0.0
			var ang = randf() * TAU
			_spawn_one(Vector2.RIGHT.rotated(ang) * randf_range(0.2, 0.9) * spell.radius)

	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = spell.tick_interval
		_apply_tick()


func _body_hp(body) -> float:
	if "current_hp" in body and body.current_hp != null:
		return float(body.current_hp)
	return float(body.hp) if "hp" in body else 0.0


func _apply_tick():
	if spell.picks_strongest > 0:
		# escolhe os alvos: só os N inimigos de mais vida dentro do raio
		var list: Array = []
		for body in get_tree().get_nodes_in_group("damageable"):
			if is_instance_valid(body) and ("team" in body) and body.team != caster_team \
					and body.global_position.distance_to(global_position) <= spell.radius:
				list.append(body)
		list.sort_custom(func(a, b): return _body_hp(a) > _body_hp(b))
		for body in list.slice(0, spell.picks_strongest):
			Fx.ring(get_parent(), body.position, 22.0, Color(1, 1, 0.6, 0.9), 0.3)
			_apply_effect(body)
		return
	if spell.splits_damage:
		# VAZIO: conta quantos inimigos tem na área antes de bater
		_split_count = 0
		for b2 in get_tree().get_nodes_in_group("damageable"):
			if "team" in b2 and b2.team != caster_team and b2.global_position.distance_to(global_position) <= spell.radius:
				_split_count += 1
		_split_count = maxi(_split_count, 1)
	for body in get_tree().get_nodes_in_group("damageable"):
		if !("team" in body):
			continue

		var is_ally = body.team == caster_team
		# reforço (fúria/escudo/purificar) sempre vale em aliado
		if is_ally and not spell.affects_allies and not _has_ally_buff():
			continue
		if not is_ally and not spell.affects_enemies:
			continue

		if body.global_position.distance_to(global_position) <= spell.radius:
			_apply_effect(body)


var _split_count := 1


## CLONE: copia cada tropa aliada no raio, com 1 de vida, do ladinho dela
func _clone_allies():
	var battle = get_tree().get_first_node_in_group("battle_scene")
	for body in get_tree().get_nodes_in_group("units"):
		if !is_instance_valid(body) or !("team" in body) or body.team != caster_team or body.stats == null:
			continue
		if body.stats.unit_type == UnitData.UnitType.BUILDING or body.get("_is_clone") or body.global_position.distance_to(global_position) > spell.radius:
			continue
		var cd: CardData = body.card_data
		var sc: PackedScene = cd.unit_scene if cd != null and cd.unit_scene != null else (load(body.scene_file_path) if body.scene_file_path != "" else null)
		if sc == null:
			continue
		var c = sc.instantiate()
		c._is_clone = true
		c.card_data = cd
		c.team = caster_team
		c.card_level = body.card_level
		(battle if battle != null else get_parent()).add_child(c)
		c.global_position = body.global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		c.current_hp = 1
		c.modulate = Color(0.6, 0.85, 1.0, 0.85)   # cópia: azulada
		if c.has_node("ProgressBar"):
			c.get_node("ProgressBar").value = 1
		Fx.ring(c.get_parent(), c.position, 16.0, Color(0.6, 0.85, 1.0), 0.3)


func _has_ally_buff() -> bool:
	return spell.rage_damage_mult > 1.0 or spell.rage_speed_mult > 1.0 or spell.rage_attack_speed_mult > 1.0 \
		or spell.shield_amount > 0 or spell.cleanses


func _apply_effect(body):
	var on_ally = "team" in body and body.team == caster_team
	var harms = !on_ally or spell.affects_allies  # dano/efeito ruim só em quem o feitiço afeta
	if spell.damage > 0 and harms and body.has_method("take_damage"):
		var dmg = spell.damage * power

		# feitiço batendo direto na base causa só uma fração do dano original
		# (configurável por feitiço em SpellData.base_damage_multiplier) --
		# sem isso, um feitiço forte "snipando" a base direto fica MUITO
		# desbalanceado. Aplica pra TODO feitiço, de uma vez só, aqui na
		# função compartilhada (não precisa mexer feitiço por feitiço)
		if body.is_in_group("player_base") or body.is_in_group("enemy_base"):
			dmg *= spell.base_damage_multiplier
			_report_base_damage(body, dmg)
		elif spell.building_damage_mult != 1.0 and "stats" in body and body.stats != null and body.stats.unit_type == UnitData.UnitType.BUILDING:
			dmg *= maxf(spell.building_damage_mult, 0.0)
		if spell.splits_damage and _split_count > 1:
			dmg /= float(_split_count)

		body.set_meta("spell_hit", true)    # feitiço não dá pra esquivar
		body.take_damage(dmg)
		if is_instance_valid(body):
			body.remove_meta("spell_hit")

	if spell.heal_amount > 0 and (on_ally or spell.affects_enemies) and body.has_method("heal"):
		body.heal(spell.heal_amount * power)

	# reforços (só em aliado de verdade)
	var is_ally = "team" in body and body.team == caster_team
	if is_ally and body.has_method("apply_rage"):
		var buff_time = spell.buff_duration
		if buff_time <= 0:
			buff_time = spell.tick_interval * 1.5 if spell.duration > 0 else 6.0
		elif spell.duration <= 0:
			# NÍVEL: fúria e escudo de feitiço instantâneo duram mais a cada nível
			# (a Pinga da Braba não tem dano pra crescer -- antes evoluir não mudava nada)
			buff_time *= Regras.effect_time_mult(power)
		if spell.rage_damage_mult > 1.0 or spell.rage_speed_mult > 1.0 or spell.rage_attack_speed_mult > 1.0:
			body.apply_rage(spell.rage_damage_mult, spell.rage_speed_mult, spell.rage_attack_speed_mult, buff_time)
		if spell.shield_amount > 0:
			body.apply_spell_shield(int(round(spell.shield_amount * power)), buff_time)
		if spell.cleanses:
			body.cleanse()

	if spell.status_effect == UnitData.OnHitEffect.NONE or !harms:
		return
	if !body.has_method("apply_on_hit_effect"):
		return

	# duração do status: se o feitiço é instantâneo, usa um valor fixo razoável;
	# se ele fica na área, usa um pouco mais que o próprio tick (mesmo truque de
	# antes, evita o efeito "piscar" entre uma reaplicação e outra)
	var status_duration = spell.tick_interval * 1.5 if spell.duration > 0 else 2.0
	if spell.status_effect_duration > 0:
		status_duration = spell.status_effect_duration  # duração escolhida no Criador
		if spell.duration <= 0:
			status_duration *= Regras.effect_time_mult(power)  # NÍVEL: congela/marca por mais tempo

	body.apply_on_hit_effect(
		spell.status_effect,
		spell.status_effect_strength,
		status_duration,
		spell.tick_interval,
		spell.knockback_distance,
		global_position
	)


# INVOCAÇÃO: nasce(m) unidade(s) no lugar do feitiço, pro time de quem lançou
func _summon_units():
	if spell.summon_scene == null or spell.summon_count <= 0:
		return
	if spell.summon_in_line and spell.summon_count > 1:
		# muralha: fila de um lado a outro do círculo
		var span = maxf(spell.radius, 30.0)
		for i in spell.summon_count:
			_spawn_one(Vector2(lerpf(-span, span, float(i) / float(spell.summon_count - 1)), 0.0))
		return
	for i in spell.summon_count:
		_spawn_one(Vector2.ZERO if spell.summon_count == 1 else Vector2.RIGHT.rotated(TAU * i / spell.summon_count) * min(spell.radius * 0.5, 28.0))


func _spawn_one(offset: Vector2):
	var battle = get_tree().get_first_node_in_group("battle_scene")
	var u = spell.summon_scene.instantiate()
	u.team = caster_team
	if "card_level" in u:
		u.card_level = level
	if power != 1.0 and "stats" in u and u.stats != null:
		u.stats = u.stats.duplicate()
		Regras.apply_level(u.stats, power)
	if battle != null:
		battle.add_child(u)
	else:
		get_parent().add_child(u)
	u.global_position = global_position + offset


# mesma ideia de unit.gd/projectile.gd -- avisa a cena de batalha pra
# acumular o dano por CARTA, usado depois pro bot aprender contra-carta e
# pra detecção de partida travada
func _report_base_damage(body, amount: float):
	if source_card_path == "":
		return
	var battle = get_tree().get_first_node_in_group("battle_scene")
	if battle != null and battle.has_method("record_base_damage_by_card"):
		battle.record_base_damage_by_card(source_card_path, amount, body.is_in_group("player_base"))


# visual do feitiço: cor própria (fx_color) ou uma cor padrão pelo que ele faz
func _cast_fx():
	var parent = get_parent()
	var col: Color = spell.fx_color
	if col.a <= 0.0:
		if spell.heal_amount > 0:
			col = Color(0.4, 0.95, 0.5)
		elif spell.status_effect == UnitData.OnHitEffect.FREEZE:
			col = Color(0.6, 0.85, 1.0)
		elif spell.damage > 0:
			col = Color(1.0, 0.6, 0.25)
		else:
			col = Color(1, 1, 0.8)
	col.a = 1.0
	if spell.fx_tint > 0:
		col = SpellData.TINT_COLORS[clampi(spell.fx_tint, 0, SpellData.TINT_COLORS.size() - 1)]
	elif spell.fx_style > 0 and spell.fx_color.a <= 0.0:
		col = Fx.STYLE_COLORS[clampi(spell.fx_style, 0, Fx.STYLE_COLORS.size() - 1)]   # cada estilo tem a sua cor, se você não escolher outra
	if spell.fx_sound > 0:
		var snd = str(SpellData.SOUND_IDS[clampi(spell.fx_sound, 0, SpellData.SOUND_IDS.size() - 1)])
		if snd != "":
			Sfx.play(snd)
	elif spell.heal_amount > 0:
		Sfx.play("cura")
	elif spell.status_effect == UnitData.OnHitEffect.FREEZE:
		Sfx.play("gelo")
	elif spell.rage_damage_mult > 1.0 or spell.shield_amount > 0:
		Sfx.play("furia")
	elif spell.status_effect == UnitData.OnHitEffect.SLOW or spell.status_effect == UnitData.OnHitEffect.PULL:
		Sfx.play("lama")
	elif spell.damage > 0 and spell.radius <= 60.0:
		Sfx.play("raio")
	elif spell.damage > 0:
		Sfx.play("explosao")
	else:
		Sfx.play("carta")
	if spell.fx_style > 0:
		Fx.styled(parent, position, spell.radius, col, spell.fx_style, spell.duration, spell.fx_power)
	elif spell.duration > 0:
		Fx.zone(parent, position, spell.radius, col, spell.duration)
	else:
		Fx.ring(parent, position, spell.radius, col, 0.45)
		if spell.damage > 0 and spell.radius <= 60.0:
			Fx.bolt(parent, position, col)
		Fx.burst(parent, position, col, 14, spell.radius * 2.2, 4.0)
		if spell.status_effect == UnitData.OnHitEffect.FREEZE or spell.buff_duration > 0:
			Fx.zone(parent, position, spell.radius, col, 0.8)
