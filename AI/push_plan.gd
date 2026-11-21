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

# ---------------------------------------------------------------- PLANO DE JOGO
## Cada bot joga por um PLANO, decidido pelo arquétipo dele. O plano muda QUANDO ele
## ataca, COM QUE carta abre, POR ONDE vai e o quanto cutuca -- não é só velocidade.
enum Fam { BLOCO, CERCO, CORRERIA, COMBO, CONTRA, CAOS }
const FAM_NAMES = ["Tanque e apoio", "Cerco", "Correria", "Combo", "Contra-ataque", "Caos"]
const FAM_TEXT = [
	"Junta bastante recurso, solta o mais parrudo na frente e o apoio logo atrás.",
	"Planta construção primeiro e ataca devagar, pelo lado onde ela está.",
	"Não junta: solta carta barata sem parar, quase sempre pelo mesmo lado.",
	"Guarda duas cartas certas e só ataca quando tem as duas na mão.",
	"Quase nunca ataca primeiro: defende e vira o jogo com a tropa que sobrou.",
	"Imprevisível de propósito: muda de lado, de tamanho de ataque e de ideia.",
]
const FAM_OF = {
	AIProfile.Archetype.AGRESSIVO: Fam.CORRERIA, AIProfile.Archetype.ATACA_TUDO: Fam.CORRERIA, AIProfile.Archetype.IMPULSIVO: Fam.CORRERIA,
	AIProfile.Archetype.ENXAMEADOR: Fam.CORRERIA, AIProfile.Archetype.BABY: Fam.CORRERIA, AIProfile.Archetype.MINIMALISTA: Fam.CORRERIA,
	AIProfile.Archetype.ESTRUTURAL: Fam.CERCO, AIProfile.Archetype.TERRITORIAL: Fam.CERCO, AIProfile.Archetype.PASSIVO: Fam.CERCO,
	AIProfile.Archetype.COMBINADOR: Fam.COMBO, AIProfile.Archetype.ANALITICO: Fam.COMBO, AIProfile.Archetype.METAGAMER: Fam.COMBO,
	AIProfile.Archetype.EMBOSCADA: Fam.COMBO,
	AIProfile.Archetype.REATIVO_PURO: Fam.CONTRA, AIProfile.Archetype.VINGATIVO: Fam.CONTRA, AIProfile.Archetype.OPORTUNISTA: Fam.CONTRA,
	AIProfile.Archetype.CAOTICO: Fam.CAOS, AIProfile.Archetype.CURIOSO: Fam.CAOS, AIProfile.Archetype.APOSTADOR: Fam.CAOS,
}   # os outros (Poupador, Acumulador, Boomer, Provocador, Perfeccionista, Metrônomo) = Tanque e apoio


static func family_of(profile: AIProfile) -> int:
	if profile == null:
		return Fam.BLOCO
	return int(FAM_OF.get(profile.archetype, Fam.BLOCO))


var fam := -1                 # plano deste bot (resolvido na primeira decisão)
var hand: Array = []          # mão atual (quem chama atualiza antes de decide); o Combo e o Cerco olham
var home_side := 0.0          # lado da casa do bot de Correria: -1 esquerda, +1 direita
var combo: Array = []         # [carta que puxa, parceira] do bot de Combo
var _want_building := false


static var forced := {}       # laboratório: time -> plano forçado (pra medir um plano contra o outro)


func _setup(profile: AIProfile, my_team = null):
	fam = int(forced.get(my_team, family_of(profile)))
	home_side = -1.0 if (profile != null and hash(profile.profile_name) % 2 == 0) else 1.0
	combo = pick_combo(profile)


## as duas cartas do combo: a mais parruda que anda + a melhor companheira (apoio, área ou atirador)
static func pick_combo(profile: AIProfile) -> Array:
	if profile == null:
		return []
	var lead: CardData = null
	var lead_score = 0.0
	for c in profile.deck:
		if c == null or c.is_spell():
			continue
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st == null or st.unit_type == UnitData.UnitType.BUILDING or st.move_speed <= 0.0:
			continue
		var sc = float(st.hp) * maxi(1, st.unit_count) * (2.0 if c == profile.favorite_card else 1.0)
		if sc > lead_score:
			lead_score = sc
			lead = c
	if lead == null:
		return []
	var mate: CardData = null
	var mate_score = -INF
	for c in profile.deck:
		if c == null or c == lead or c.cost + lead.cost > 85:
			continue
		var k = Catalogo.kind_of(c)
		var sc = float(c.cost) * 0.02
		if k in ["apoio", "area", "atirador"]:
			sc += 2.0
		elif c.is_spell() and c.spell_data != null and BattleBrain.has_ally_buff(c.spell_data):
			sc += 2.5
		elif c.is_spell() or k == "construcao":
			sc -= 2.0
		if sc > mate_score:
			mate_score = sc
			mate = c
	return [lead, mate] if mate != null else []


func chip_chance() -> float:
	return [0.10, 0.08, 0.28, 0.12, 0.0, 0.22][fam] if fam >= 0 else CHIP_CHANCE


func chip_max_cost() -> int:
	return [25, 25, 30, 25, 25, 35][fam] if fam >= 0 else CHIP_MAX_COST


func push_seconds() -> float:
	return [14.0, 12.0, 9.0, 12.0, 10.0, 9.0][fam] if fam >= 0 else PUSH_SECONDS


## cartas que podem sair numa cutucada (ou a construção que o Cerco quer plantar)
func chip_pool(pool: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for c in pool:
		if c == null:
			continue
		if _want_building:
			if is_building(c):
				out.append(c)
		elif c.cost <= chip_max_cost() and !c.is_spell():
			out.append(c)
	return out


static func is_building(c: CardData) -> bool:
	if c == null or c.is_spell():
		return false
	var st: UnitData = DeckBuilder.get_unit_stats(c)
	return st != null and st.unit_type == UnitData.UnitType.BUILDING


func _own_buildings(tree: SceneTree, my_team) -> Array:
	var out: Array = []
	for u in tree.get_nodes_in_group("units"):
		if is_instance_valid(u) and u.team == my_team and u.stats != null and u.stats.unit_type == UnitData.UnitType.BUILDING:
			out.append(u)
	return out


## o plano mexe na carta escolhida: o Combo abre com a dele e emenda a parceira,
## o Caos abre com qualquer coisa. null = espera (a parceira ainda não dá pra pagar)
func shape(chosen: CardData, pool: Array, push: Dictionary) -> CardData:
	if !push.get("go", false):
		return chosen
	if fam == Fam.COMBO and combo.size() == 2:
		if push.get("first", false) and combo[0] in pool:
			return combo[0]
		if played == 1 and combo[1] in hand:
			return combo[1] if combo[1] in pool else null
	elif fam == Fam.CAOS and push.get("first", false) and !pool.is_empty():
		return pool[randi() % pool.size()]
	elif fam == Fam.CORRERIA and push.get("first", false):
		# abre com a mais rápida que der pra pagar, não com a mais parruda
		var best: CardData = null
		var best_speed = 0.0
		for c in pool:
			var st: UnitData = DeckBuilder.get_unit_stats(c) if (c != null and !c.is_spell()) else null
			if st != null and st.unit_type != UnitData.UnitType.BUILDING and st.move_speed > best_speed:
				best_speed = st.move_speed
				best = c
		if best != null:
			return best
	return chosen


var active_until := -1.0
var lane_x := 0.0
var played := 0
var _jitter := randf_range(-16.0, 8.0)   # cada ataque junta um tanto diferente (não vira relógio)
var arena := 4                           # 1..7: arena da partida. Bot de arena baixa ataca menor e pune menos
var _no_punish_until := -1.0


func is_pushing(now: float) -> bool:
	return now < active_until


## depois das duas primeiras cartas do bloco, guarda um troco pra defender
## (bot que despeja tudo fica pelado e toma o troco na outra rota)
func reserve() -> int:
	if fam == Fam.CONTRA:
		return 0 if played < 1 else 26   # contra-ataque nunca fica pelado
	if fam == Fam.CORRERIA or fam == Fam.CAOS:
		return 0 if played < 2 else 8
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
	t += (clampf(arena, 1.0, 12.0) - 6.5) * 2.2  # arena 1: ataques menores (-12); arena 12: maiores (+12)
	match fam:
		Fam.BLOCO:
			t += 6.0                       # enche mais: o bloco dele é o maior
		Fam.CERCO:
			t += 2.0
		Fam.CORRERIA:
			t -= 22.0                      # junta pouco: ataca menor e toda hora
		Fam.CONTRA:
			return max_money - 4           # só ataca por conta própria com a barra cheia
		Fam.CAOS:
			t += _chaos                    # cada ataque de um tamanho
	return int(clampf(t + _jitter, 38.0, float(max_money) - 4.0))


## opp_money: recurso do adversário (-1 = não sei). Contar o recurso do outro
## é a jogada mais básica do Clash: gastou tudo? é a hora de atacar.
func decide(now: float, money: int, max_money: int, double_time: bool, profile: AIProfile, tree: SceneTree, my_team, opp_money: int = -1) -> Dictionary:
	if fam < 0:
		_setup(profile, my_team)
	_want_building = false
	if is_pushing(now):
		if fam == Fam.CAOS and randf() < 0.18:
			lane_x = _family_lane(tree, my_team)   # muda de lado no meio do ataque
		return {"go": true, "lane_x": lane_x, "first": false}
	# CERCO: antes de pensar em atacar, quer construção de pé (até 2)
	if fam == Fam.CERCO and money >= 30 and _own_buildings(tree, my_team).size() < 2:
		for c in hand:
			if c != null and c.cost <= money and is_building(c):
				_want_building = true
				return {"chip": true, "build": true}
	var start = false
	var counter_lane = INF
	var combo_ready = false
	if fam == Fam.COMBO and combo.size() == 2 and combo[0] in hand and combo[1] in hand:
		combo_ready = money >= combo[0].cost + combo[1].cost - 8   # a parceira sai 1s depois: o recurso que falta pinga
	if combo_ready:
		start = true
	elif fam == Fam.COMBO and combo.size() == 2 and money < max_money - 5 and now < _combo_patience:
		pass   # segurando pelas duas cartas (com paciência: depois de um tempo ataca do jeito comum)
	elif money >= threshold(max_money, double_time, profile):
		start = true
	elif opp_money >= 0 and opp_money <= PUNISH_OPP_MONEY and money >= PUNISH_MY_MONEY and now >= _no_punish_until:
		# PUNIÇÃO: ele está sem recurso pra defender. Bot de arena baixa nem sempre percebe
		if randf() < clampf(0.2 + clampi(arena, 1, 12) * 0.07, 0.3, 0.95):
			start = true
		else:
			_no_punish_until = now + 7.0
	elif money >= (20 if fam == Fam.CONTRA else COUNTER_MY_MONEY):
		counter_lane = _counter_lane(tree, my_team)
		start = counter_lane != INF  # CONTRA-ATAQUE: a defesa sobrou viva, vai junto
	if start:
		_jitter = randf_range(-16.0, 8.0)
		_chaos = randf_range(-30.0, 10.0)
		_combo_patience = now + 26.0
		active_until = now + push_seconds()
		lane_x = counter_lane if counter_lane != INF else _family_lane(tree, my_team)
		played = 0
		return {"go": true, "lane_x": lane_x, "first": counter_lane == INF}
	if randf() < chip_chance():
		return {"chip": true}
	return {"wait": true}


var _chaos := 0.0
var _combo_patience := 26.0


## rota pelo plano: a Correria insiste no lado da casa, o Cerco vai pelo lado da
## construção dele, o Caos sorteia; os outros escolhem a melhor (torre fraca, pouca guarda)
func _family_lane(tree: SceneTree, my_team) -> float:
	var towers = BattleBrain.get_bases(tree, BattleBrain.other_team(my_team))
	var xs: Array = []
	for t in towers:
		if is_instance_valid(t) and "hp" in t:
			var gate = "is_gate" in t and t.is_gate
			xs.append(ArenaBuilder.CENTER.x if gate else ArenaBuilder.CENTER.x + ArenaBuilder.BRIDGE_X * signf(t.global_position.x - ArenaBuilder.CENTER.x))
	if xs.is_empty():
		return _pick_lane(tree, my_team)
	if fam == Fam.CAOS:
		return float(xs[randi() % xs.size()])
	var want = INF
	if fam == Fam.CORRERIA and randf() < 0.8:
		want = ArenaBuilder.CENTER.x + ArenaBuilder.BRIDGE_X * home_side
	elif fam == Fam.CERCO:
		var b = _own_buildings(tree, my_team)
		if !b.is_empty():
			want = b[randi() % b.size()].global_position.x
	if want == INF:
		return _pick_lane(tree, my_team)
	var best = float(xs[0])
	for x in xs:
		if absf(float(x) - want) < absf(best - want):
			best = float(x)
	return best


## 3 ROTAS: cada torre do adversário é o fim de uma rota (portão = meio, as de
## trás = os lados). Pesa a vida que falta, quanta tropa dele está naquela
## rota e QUANTAS TORRES atiram em quem chega lá: no portão atiram as 3; numa
## torre de trás, ela e o portão. Sem a última conta o bot ia sempre no meio
func _pick_route(tree: SceneTree, _my_team, foe, towers: Array) -> float:
	var gate_up = false
	var backs_up = 0
	for t in towers:
		if "is_gate" in t and t.is_gate:
			gate_up = true
		else:
			backs_up += 1
	var best_x = ArenaBuilder.CENTER.x
	var best_score = INF
	for t in towers:
		if !is_instance_valid(t) or !("hp" in t):
			continue
		var is_gate = "is_gate" in t and t.is_gate
		var x = ArenaBuilder.CENTER.x if is_gate else ArenaBuilder.CENTER.x + ArenaBuilder.BRIDGE_X * signf(t.global_position.x - ArenaBuilder.CENTER.x)
		var frac = float(t.hp) / maxf(float(t.max_hp), 1.0)
		var guards = 0.0
		for u in tree.get_nodes_in_group("units"):
			if is_instance_valid(u) and u.team == foe and absf(u.global_position.x - x) < 80.0:
				guards += 0.08
		var cover = 0.16 * backs_up if is_gate else (0.16 if gate_up else 0.0)
		var score = frac + guards + cover + randf() * 0.22
		if score < best_score:
			best_score = score
			best_x = x
	return best_x


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
	if total < (350.0 if fam == Fam.CONTRA else COUNTER_MIN_HP):
		return INF
	return sum_x / total


## rota do ataque: a torre adversária mais machucada; empate = onde o
## adversário tem menos tropa; empate de novo = sorteio
func _pick_lane(tree: SceneTree, my_team) -> float:
	var foe = BattleBrain.other_team(my_team)
	var towers = BattleBrain.get_bases(tree, foe)
	if towers.is_empty():
		return ArenaBuilder.CENTER.x
	if Regras.routes() and BattleBrain.smart(my_team):
		return _pick_route(tree, my_team, foe, towers)
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
static func pick_leader(affordable: Array, favorite: CardData = null) -> CardData:
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
		if favorite != null and c == favorite:
			score = maxf(score * 2.5, 950.0)   # a favorita puxa o ataque sempre que der
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
