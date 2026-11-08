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
		if is_ally and not spell.affects_allies:
			continue
		if not is_ally and not spell.affects_enemies:
			continue

		if body.global_position.distance_to(global_position) <= spell.radius:
			_apply_effect(body)


func _apply_effect(body):
	if spell.damage > 0 and body.has_method("take_damage"):
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

	if spell.heal_amount > 0 and body.has_method("heal"):
		body.heal(spell.heal_amount)

	if spell.status_effect == UnitData.OnHitEffect.NONE:
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


# mesma ideia de unit.gd/projectile.gd -- avisa a cena de batalha pra
# acumular o dano por CARTA, usado depois pro bot aprender contra-carta e
# pra detecção de partida travada
func _report_base_damage(body, amount: float):
	if source_card_path == "":
		return
	var battle = get_tree().get_first_node_in_group("battle_scene")
	if battle != null and battle.has_method("record_base_damage_by_card"):
		battle.record_base_damage_by_card(source_card_path, amount, body.is_in_group("player_base"))
