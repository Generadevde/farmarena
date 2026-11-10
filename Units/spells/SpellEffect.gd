extends Node2D
class_name SpellEffect

var spell: SpellData
var caster_team
var source_card_path: String = ""  # pra reportar dano na base por carta, igual unit.gd/projectile.gd já fazem

var _tick_timer: float = 0.0
var _elapsed: float = 0.0


func _ready():
	if spell.ground_effect_texture != null:
		var visual = Sprite2D.new()
		visual.texture = spell.ground_effect_texture
		add_child(visual)

	_cast_fx()
	_summon_units()
	_apply_tick()  # aplica imediatamente ao ser lançado

	if spell.duration <= 0:
		queue_free()  # instantâneo: aplica uma vez e desaparece
	else:
		_tick_timer = spell.tick_interval


func _process(delta):
	if spell.duration <= 0:
		return

	_elapsed += delta
	if _elapsed >= spell.duration:
		queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = spell.tick_interval
		_apply_tick()


func _apply_tick():
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


func _has_ally_buff() -> bool:
	return spell.rage_damage_mult > 1.0 or spell.rage_speed_mult > 1.0 or spell.rage_attack_speed_mult > 1.0 \
		or spell.shield_amount > 0 or spell.cleanses


func _apply_effect(body):
	var on_ally = "team" in body and body.team == caster_team
	var harms = !on_ally or spell.affects_allies  # dano/efeito ruim só em quem o feitiço afeta
	if spell.damage > 0 and harms and body.has_method("take_damage"):
		var dmg = spell.damage

		# feitiço batendo direto na base causa só uma fração do dano original
		# (configurável por feitiço em SpellData.base_damage_multiplier) --
		# sem isso, um feitiço forte "snipando" a base direto fica MUITO
		# desbalanceado. Aplica pra TODO feitiço, de uma vez só, aqui na
		# função compartilhada (não precisa mexer feitiço por feitiço)
		if body.is_in_group("player_base") or body.is_in_group("enemy_base"):
			dmg *= spell.base_damage_multiplier
			_report_base_damage(body, dmg)

		body.take_damage(dmg)

	if spell.heal_amount > 0 and (on_ally or spell.affects_enemies) and body.has_method("heal"):
		body.heal(spell.heal_amount)

	# reforços (só em aliado de verdade)
	var is_ally = "team" in body and body.team == caster_team
	if is_ally and body.has_method("apply_rage"):
		var buff_time = spell.buff_duration
		if buff_time <= 0:
			buff_time = spell.tick_interval * 1.5 if spell.duration > 0 else 6.0
		if spell.rage_damage_mult > 1.0 or spell.rage_speed_mult > 1.0 or spell.rage_attack_speed_mult > 1.0:
			body.apply_rage(spell.rage_damage_mult, spell.rage_speed_mult, spell.rage_attack_speed_mult, buff_time)
		if spell.shield_amount > 0:
			body.apply_spell_shield(spell.shield_amount, buff_time)
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
	var battle = get_tree().get_first_node_in_group("battle_scene")
	for i in spell.summon_count:
		var u = spell.summon_scene.instantiate()
		u.team = caster_team
		var offset = Vector2.ZERO if spell.summon_count == 1 else Vector2.RIGHT.rotated(TAU * i / spell.summon_count) * min(spell.radius * 0.5, 28.0)
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
	if spell.duration > 0:
		Fx.zone(parent, position, spell.radius, col, spell.duration)
	else:
		Fx.ring(parent, position, spell.radius, col, 0.45)
		if spell.damage > 0 and spell.radius <= 60.0:
			Fx.bolt(parent, position, col)
		Fx.burst(parent, position, col, 14, spell.radius * 2.2, 4.0)
		if spell.status_effect == UnitData.OnHitEffect.FREEZE or spell.buff_duration > 0:
			Fx.zone(parent, position, spell.radius, col, 0.8)
