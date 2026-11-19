extends RefCounted
class_name PushPlan
## ATAQUE EM BLOCO do bot (Batalha 2.5).
##
## Com a torre defendendo de verdade, carta solta sozinha morre na torre e
## não arranha nada (medido: 15 de 16 partidas com as torres do jogador
## intactas). Então o bot agora faz o que se faz no Clash: JUNTA recurso e
## ataca em bloco numa rota -- tanque na frente, apoio atrás -- e só de vez
## em quando solta uma carta barata pra cutucar.
##
## Uso (a cada decisão proativa, depois de checar a defesa):
##   var d = plan.decide(agora, dinheiro, teto, x2, perfil, árvore, meu_time)
##   d = {"wait": true}                  segurando pra juntar
##   d = {"chip": true}                  pode soltar UMA carta barata (cutucada)
##   d = {"go": true, "lane_x": x, "first": bool}   atacando em bloco nessa rota

const PUSH_SECONDS = 12.0     # janela do ataque: tudo que der pra pagar vai na mesma rota
const PUNISH_OPP_MONEY = 22   # adversário quase sem recurso = não consegue defender: ataca já
const PUNISH_MY_MONEY = 45
const COUNTER_MIN_HP = 700.0  # sobrou tropa da defesa valendo isso de vida: vira contra-ataque
const COUNTER_MY_MONEY = 30
const CHIP_CHANCE = 0.16      # chance de cutucar com carta barata enquanto junta
const CHIP_MAX_COST = 25

var active_until := -1.0
var lane_x := 0.0
var played := 0
var _jitter := randf_range(-16.0, 8.0)   # cada ataque junta um tanto diferente (não vira relógio)


func is_pushing(now: float) -> bool:
	return now < active_until


## depois das duas primeiras cartas do bloco, guarda um troco pra defender
## (bot que despeja tudo fica pelado e toma o troco na outra rota)
func reserve() -> int:
	return 0 if played < 2 else 18


func end():
	active_until = -1.0


## quanto junta antes de atacar. Ataque GRANDE é o que fura torre: a torre
## dá sempre o mesmo dano, então quanto maior o bloco, menor a parte dela
## na defesa. O apressado ataca com um pouco menos, o poupador enche a barra.
func threshold(max_money: int, double_time: bool, profile: AIProfile) -> int:
	var t = 84.0
	if profile != null:
		if profile.decision_interval <= 2.0:
			t -= 12.0
		elif profile.decision_interval >= 4.0:
			t += 5.0
		if profile.prefer_expensive:
			t += 6.0
	if double_time:
		t += 6.0  # no x2 o recurso volta rápido: dá pra encher e despejar
	return int(clampf(t + _jitter, 50.0, float(max_money) - 4.0))


## opp_money: recurso do adversário (-1 = não sei). Contar o recurso do outro
## é a jogada mais básica do Clash: gastou tudo? é a hora de atacar.
func decide(now: float, money: int, max_money: int, double_time: bool, profile: AIProfile, tree: SceneTree, my_team, opp_money: int = -1) -> Dictionary:
	if is_pushing(now):
		return {"go": true, "lane_x": lane_x, "first": false}
	var start = false
	var counter_lane = INF
	if money >= threshold(max_money, double_time, profile):
		start = true
	elif opp_money >= 0 and opp_money <= PUNISH_OPP_MONEY and money >= PUNISH_MY_MONEY:
		start = true  # PUNIÇÃO: ele está sem recurso pra defender
	elif money >= COUNTER_MY_MONEY:
		counter_lane = _counter_lane(tree, my_team)
		start = counter_lane != INF  # CONTRA-ATAQUE: a defesa sobrou viva, vai junto
	if start:
		_jitter = randf_range(-16.0, 8.0)
		active_until = now + PUSH_SECONDS
		lane_x = counter_lane if counter_lane != INF else _pick_lane(tree, my_team)
		played = 0
		return {"go": true, "lane_x": lane_x, "first": counter_lane == INF}
	if randf() < CHIP_CHANCE:
		return {"chip": true}
	return {"wait": true}


## sobrou tropa minha viva depois de uma defesa (do meu lado, sem inimigo por
## perto)? Devolve a rota dela pra virar contra-ataque; INF se não tem.
func _counter_lane(tree: SceneTree, my_team) -> float:
	var my_line = BattleBrain.base_line(my_team)
	var their_line = BattleBrain.base_line(BattleBrain.other_team(my_team))
	var half = my_line.distance_to(their_line) * 0.5
	var total = 0.0
	var sum_x = 0.0
	for u in tree.get_nodes_in_group("units"):
		if !is_instance_valid(u) or u.stats == null or u.stats.unit_type == UnitData.UnitType.BUILDING:
			continue
		var on_my_half = absf(u.global_position.y - my_line.y) < half
		if u.team != my_team:
			if on_my_half:
				return INF  # ainda tem inimigo do meu lado: não é hora
			continue
		if on_my_half and u.stats.move_speed > 0.0:
			total += float(u.current_hp)
			sum_x += u.global_position.x * float(u.current_hp)
	if total < COUNTER_MIN_HP:
		return INF
	return sum_x / total


## rota do ataque: a torre adversária mais machucada; empate = onde o
## adversário tem menos tropa; empate de novo = sorteio
func _pick_lane(tree: SceneTree, my_team) -> float:
	var foe = BattleBrain.other_team(my_team)
	var towers = BattleBrain.get_bases(tree, foe)
	if towers.is_empty():
		return ArenaBuilder.CENTER.x
	var best = null
	var best_score = INF
	for t in towers:
		if !is_instance_valid(t) or !("hp" in t):
			continue
		var frac = float(t.hp) / maxf(float(t.max_hp), 1.0)
		var guards = 0.0
		for u in tree.get_nodes_in_group("units"):
			if is_instance_valid(u) and u.team == foe and absf(u.global_position.x - t.global_position.x) < 110.0:
				guards += 0.08
		var score = frac + guards + randf() * 0.12
		if score < best_score:
			best_score = score
			best = t
	return best.global_position.x if best != null else ArenaBuilder.CENTER.x


## primeira carta do ataque: o tanque (ou a mais parruda) que der pra pagar
static func pick_leader(affordable: Array) -> CardData:
	var best: CardData = null
	var best_score = -INF
	for c in affordable:
		if c == null or c.is_spell():
			continue
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st == null or st.unit_type == UnitData.UnitType.BUILDING or st.move_speed <= 0.0:
			continue
		var score = float(st.hp) * maxi(1, st.unit_count)
		if c.role == CardData.CardRole.TANQUE:
			score *= 1.6
		if score > best_score:
			best_score = score
			best = c
	return best if best_score >= 900.0 else null


## onde soltar o APOIO: logo atrás do aliado mais parrudo que já está nessa rota
static func support_position(tree: SceneTree, my_team, lane: float, spawn_area: CollisionShape2D, battle: Node, fallback: Vector2) -> Vector2:
	var leader = null
	var best_hp = 0.0
	for u in tree.get_nodes_in_group("units"):
		if !is_instance_valid(u) or u.team != my_team or u.stats == null:
			continue
		if u.stats.unit_type == UnitData.UnitType.BUILDING or absf(u.global_position.x - lane) > 100.0:
			continue
		if float(u.current_hp) > best_hp:
			best_hp = float(u.current_hp)
			leader = u
	if leader == null or best_hp < 500.0:
		return fallback
	var back = (BattleBrain.base_line(my_team) - BattleBrain.base_line(BattleBrain.other_team(my_team))).normalized()
	var pos = leader.global_position + back * randf_range(38.0, 62.0) + Vector2(randf_range(-22.0, 22.0), 0.0)
	return battle._clamp_to_area(pos, spawn_area)
