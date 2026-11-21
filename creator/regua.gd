extends RefCounted
class_name Regua
## A RÉGUA do Criador: o "padrão" de cada TIPO de carta, medido nas cartas do
## próprio jogo (mediana por tipo). Serve pra duas coisas:
##  1) preencher uma carta com números coerentes pro tipo e custo escolhidos;
##  2) avisar quando a carta que você está mexendo foge do padrão.
## Não tem tabela escrita à mão: se você mexer nas cartas do jogo, a régua acompanha.

const KIND_ORDER = ["lutador", "tanque", "matador", "bando", "atirador", "area", "voador", "ariete", "apoio", "construcao"]
const FALLBACK = {"hp_c": 25.0, "dps_c": 3.0, "n": 1.0, "vel": 45.0, "alc": 15.0, "int": 1.2, "raio": 45.0, "peso": 1.0, "cartas": 0}

static var _std: Dictionary = {}


static func clear():
	_std = {}
	_spell_std = {}


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


## padrão de um tipo: {hp_c: vida total por custo, dps_c: dano por segundo total por custo,
## n: quantidade, vel, alc, int (tempo entre golpes), raio, peso, cartas: quantas entraram na conta}
static func standard(kind: String) -> Dictionary:
	if _std.is_empty():
		var acc := {}
		for c in CardDatabase.all_cards:
			if c == null or c.is_spell() or c.cost <= 0 or CustomContent.is_custom(c) or CustomContent.is_spawn_only(c):
				continue
			var st: UnitData = DeckBuilder.get_unit_stats(c)
			if st == null:
				continue
			var k = Catalogo.kind_from(st)
			if !acc.has(k):
				acc[k] = {"hp_c": [], "dps_c": [], "n": [], "vel": [], "alc": [], "int": [], "raio": [], "peso": []}
			var n = maxi(st.unit_count, 1)
			acc[k]["hp_c"].append(float(st.hp) * n / c.cost)
			acc[k]["dps_c"].append(st.damage / maxf(st.attack_speed, 0.1) * n / c.cost)
			acc[k]["n"].append(float(n))
			acc[k]["vel"].append(st.move_speed)
			acc[k]["alc"].append(st.attack_range)
			acc[k]["int"].append(st.attack_speed)
			acc[k]["peso"].append(st.push_weight)
			if st.aoe_radius > 0.0:
				acc[k]["raio"].append(st.aoe_radius)
		for k in acc:
			var d := {"cartas": acc[k]["hp_c"].size()}
			for key in acc[k]:
				d[key] = _median(acc[k][key])
			if d["raio"] <= 0.0:
				d["raio"] = 45.0
			_std[k] = d
	return _std.get(kind, _std.get("lutador", FALLBACK))


static func _nice(v: float) -> int:
	if v < 200.0:
		return int(maxf(round(v / 5.0) * 5.0, 5.0))
	if v < 1000.0:
		return int(round(v / 10.0) * 10.0)
	return int(round(v / 50.0) * 50.0)


## números coerentes pra uma carta do tipo `kind` com custo `cost`: {propriedade: valor}
static func suggest(kind: String, cost: int) -> Dictionary:
	var s = standard(kind)
	var n = maxi(1, int(round(s["n"])))
	if kind == "bando":
		n = maxi(n, 4)
	var interval = snappedf(clampf(s["int"], 0.4, 4.0), 0.1)
	if kind == "construcao" and s["dps_c"] <= 0.0:
		interval = 1.0
	var out := {
		"hp": _nice(s["hp_c"] * cost / n),
		"damage": _nice(s["dps_c"] * cost / n * interval) if s["dps_c"] > 0.0 else 0,
		"attack_speed": interval,
		"move_speed": snappedf(s["vel"], 5.0),
		"attack_range": snappedf(maxf(s["alc"], 15.0), 5.0),
		"unit_count": n,
		"push_weight": snappedf(maxf(s["peso"], 0.3), 0.1),
		"unit_type": 0, "target_type": 0, "is_ranged": false, "is_aoe": false, "can_heal_allies": false, "duration": 0.0,
	}
	match kind:
		"atirador":
			out["is_ranged"] = true
			out["attack_range"] = maxf(out["attack_range"], 100.0)
			out["target_type"] = int(UnitData.TargetType.ALL)
		"voador":
			out["unit_type"] = int(UnitData.UnitType.AIR)
			out["target_type"] = int(UnitData.TargetType.ALL)
			out["is_ranged"] = out["attack_range"] >= 60.0
		"ariete":
			out["target_type"] = int(UnitData.TargetType.BUILDING)
		"area":
			out["is_aoe"] = true
			out["aoe_radius"] = snappedf(maxf(s["raio"], 40.0), 5.0)
		"apoio":
			out["can_heal_allies"] = true
			out["heal_aura_amount"] = maxi(5, int(round(cost * 0.6)))
			out["heal_aura_radius"] = 90.0
		"construcao":
			out["unit_type"] = int(UnitData.UnitType.BUILDING)
			out["move_speed"] = 0.0
			out["duration"] = 35.0
			out["is_ranged"] = out["damage"] > 0
			out["target_type"] = int(UnitData.TargetType.ALL)
	return out


## quanto as habilidades de dano/proteção valem a mais na "Força" (na mesma unidade do
## _raw_power: vida x 0,3 + dano por segundo x 3). É uma ESTIMATIVA: conta o caso comum de cada
## habilidade (ex.: pulso pegando 2 inimigos, aura reforçando 1 aliado do mesmo porte).
static func ability_power(st: UnitData) -> float:
	var n = maxi(st.unit_count, 1)
	var dps = st.damage / maxf(st.attack_speed, 0.1)
	var raw = CardGenerator._raw_power(st)
	var extra_dps = 0.0
	var extra = 0.0
	if st.pulses:
		extra_dps += float(st.pulse_damage) / maxf(st.pulse_interval, 0.5) * 2.0
	if st.leaves_trail and st.move_speed > 0.0:
		extra_dps += float(st.trail_damage) * 2.0 * 0.5
	if st.jump_attack:
		extra_dps += float(st.jump_damage) / maxf(st.jump_cooldown, 0.8) * 1.5
	if st.rider_attack:
		extra_dps += float(st.rider_damage) / maxf(st.rider_interval, 0.2) * maxi(st.rider_count, 1)
	if st.grows_over_time:
		extra_dps += dps * (st.grow_max_mult - 1.0) * 0.4
	if st.late_boost_after > 0.0:
		extra_dps += dps * (st.late_boost_damage_mult - 1.0) * 0.5
	if st.bandit_dash and st.dash_damage_mult > 1.0:
		extra_dps += dps * (st.dash_damage_mult - 1.0) * (0.3 if st.dash_repeats else 0.1)
	if st.charge_attack:
		extra_dps += dps * (st.charge_damage_multiplier - 1.0) * 0.15
	if st.aura_buff:
		extra += raw * (maxf(st.aura_damage_mult, 1.0) - 1.0 + (maxf(st.aura_attack_speed_mult, 1.0) - 1.0) + (maxf(st.aura_speed_mult, 1.0) - 1.0) * 0.3)
	if st.ward_allies:
		extra += raw * clampf(st.ward_reduction, 0.0, 0.9) * 0.8
	if st.repairs_buildings:
		extra += float(st.repair_amount) / maxf(st.repair_interval, 0.3) * 10.0 * 0.3
	if st.is_trap:
		extra += float(st.trap_damage) * 0.6
	if st.blinks or st.pre_attack_speed_boost or (st.charge_attack and st.charge_speed_mult > 1.0):
		extra += raw * 0.08   # chega antes: vale um pouco
	return (extra_dps * 3.0) * n + extra


## como os números `st` (custo `cost`) ficam perto do padrão do tipo dele, em %:
## {"kind", "vida", "dano", "geral"}  (100 = no padrão)
static func compare(st: UnitData, cost: int) -> Dictionary:
	var kind = Catalogo.kind_from(st)
	var s = standard(kind)
	var n = maxi(st.unit_count, 1)
	var c = maxf(float(cost), 1.0)
	var vida = float(st.hp) * n / maxf(s["hp_c"] * c, 1.0) * 100.0
	var dano = (st.damage / maxf(st.attack_speed, 0.1) * n) / maxf(s["dps_c"] * c, 0.01) * 100.0 if s["dps_c"] > 0.0 else 100.0
	var geral = (CardGenerator._raw_power(st) + ability_power(st)) / maxf(CardGenerator.power_per_cost() * c, 1.0) * 100.0
	return {"kind": kind, "vida": int(round(vida)), "dano": int(round(dano)), "geral": int(round(geral))}


# ---------------------------------------------------------------- feitiços
static var _spell_std: Dictionary = {}


## quantas vezes o feitiço bate (1 se for instantâneo)
static func spell_pulses(sp: SpellData) -> int:
	return int(maxf(1.0, sp.duration / maxf(0.05, sp.tick_interval))) if sp.duration > 0.0 else 1


## padrão dos feitiços do jogo: dano total por custo, cura total por custo e raio (medianas)
static func spell_standard() -> Dictionary:
	if _spell_std.is_empty():
		var dmg: Array = []
		var heal: Array = []
		var rad: Array = []
		for c in CardDatabase.all_cards:
			if c == null or !c.is_spell() or c.cost <= 0 or c.spell_data == null or CustomContent.is_custom(c):
				continue
			var sp: SpellData = c.spell_data
			var n = spell_pulses(sp)
			if sp.damage > 0:
				dmg.append(float(sp.damage) * n / c.cost)
			if sp.heal_amount > 0:
				heal.append(float(sp.heal_amount) * n / c.cost)
			rad.append(sp.radius)
		_spell_std = {"dmg_c": _median(dmg), "cura_c": _median(heal), "raio": _median(rad), "cartas": rad.size(), "de_dano": dmg.size(), "de_cura": heal.size()}
	return _spell_std


## {"dano", "cura", "raio"} em % do padrão (-1 = o feitiço não tem isso)
static func spell_compare(sp: SpellData, cost: int) -> Dictionary:
	var s = spell_standard()
	var c = maxf(float(cost), 1.0)
	var n = spell_pulses(sp)
	return {
		"dano": int(round(sp.damage * n / maxf(s["dmg_c"] * c, 0.01) * 100.0)) if (sp.damage > 0 and s["dmg_c"] > 0.0) else -1,
		"cura": int(round(sp.heal_amount * n / maxf(s["cura_c"] * c, 0.01) * 100.0)) if (sp.heal_amount > 0 and s["cura_c"] > 0.0) else -1,
		"raio": int(round(sp.radius / maxf(s["raio"], 1.0) * 100.0)),
	}
