extends Node
class_name BotController

# Bot "extra" do modo 2v2 -- o bot aliado (do seu lado) e o segundo bot
# inimigo. Cada um tem dinheiro, mão de cartas, ritmo e personalidade
# próprios, e usa o mesmo cérebro tático (BattleBrain) do bot principal.
# Compartilha a base e a área de spawn com o parceiro de time.

const STARTING_MONEY = 5
# mesmos valores da cena de batalha (batlhe_scene.gd) -- se mudar lá, muda aqui
const MAX_MONEY = 100
const PRODUCTION_INTERVAL = 0.28   # igual ao da batalha (ritmo do Clash)
const PRODUCTION_PER_TICK = 1
const DOUBLE_TIME_MULT = 2.0

var battle: Node
var profile: AIProfile
var team
var spawn_area: CollisionShape2D
var money: int = STARTING_MONEY
var max_money: int = 100
var hand: Array = []
var queue: Array = []
var lane_x: float = 360.0

var _push_plan := PushPlan.new()
var _push_followup := false
var _production: Timer
var _decision: Timer
var _defense_accum := 0.0
var _label: Label


func setup(p_battle: Node, p_profile: AIProfile, p_team, p_area: CollisionShape2D, lane_fraction: float):
	battle = p_battle
	profile = p_profile
	if CustomContent.zero_on():
		profile = p_profile.duplicate()
		profile.deck.assign(CustomContent.zero_deck(str(p_profile.profile_name)))
	team = p_team
	spawn_area = p_area
	max_money = MAX_MONEY
	var rect = spawn_area.shape.get_rect()
	var left = spawn_area.to_global(rect.position).x
	var right = spawn_area.to_global(rect.position + rect.size).x
	lane_x = lerp(left, right, lane_fraction)


func _ready():
	var shuffled = profile.deck.duplicate()
	shuffled.shuffle()
	var n = mini(Regras.hand_size(), maxi(shuffled.size() - 1, 1))
	hand = shuffled.slice(0, n)
	queue = shuffled.slice(n)

	_production = Timer.new()
	_production.wait_time = PRODUCTION_INTERVAL
	_production.timeout.connect(func(): money = min(money + PRODUCTION_PER_TICK, max_money))
	add_child(_production)
	_production.start()

	_decision = Timer.new()
	_decision.wait_time = max(profile.decision_interval, 0.8)
	_decision.timeout.connect(_decide)
	add_child(_decision)
	_decision.start(randf_range(1.0, 3.0))


# recurso x2 nos minutos finais
func on_double_time():
	_production.wait_time /= DOUBLE_TIME_MULT
	_decision.wait_time = max(0.5, _decision.wait_time / 1.5)


func _process(delta):
	if battle.match_over:
		set_process(false)
		_production.stop()
		_decision.stop()
		return
	_defense_accum += delta
	if _defense_accum >= clamp(profile.decision_interval * 0.4, 0.6, 1.5):
		_defense_accum = 0.0
		_try_defend()


func _affordable(reserve: int) -> Array:
	var out: Array = []
	for c in hand:
		if c != null and money - reserve >= c.cost and battle.ai_can_play(team, c):
			out.append(c)
	return out


func _try_defend() -> bool:
	var mistake = battle._get_mistake_chance() + (0.0 if profile.reacts_to_threats else 0.25)
	var d = BattleBrain.choose_defense(battle.get_tree(), team, _affordable(0), hand, money, max_money, spawn_area, battle, min(mistake, 0.6))
	if d.has("card"):
		_play(d["card"], d["pos"])
		return true
	return d.get("wait", false)


func _decide():
	if battle.match_over or profile.deck.is_empty():
		return
	if _try_defend():
		return
	var reserve = 0 if battle._entered_last_minute else profile.min_money_reserve
	var pool: Array[CardData] = []
	for c in _affordable(reserve):
		pool.append(c)
	# Batalha 2.5: junta recurso e ataca em bloco (mesma regra do bot principal)
	var push: Dictionary = {}
	if Regras.on("torres"):
		_push_plan.arena = 4 if MatchSetup.tournament else ArenaManager.get_player_arena()
		push = _push_plan.decide(battle._get_match_elapsed(), money, max_money, battle._entered_last_minute, profile, battle.get_tree(), team, _opponent_money())
		if push.get("wait", false):
			return
		if push.get("chip", false):
			var cheap: Array[CardData] = []
			for c in pool:
				if c.cost <= PushPlan.CHIP_MAX_COST and !c.is_spell():
					cheap.append(c)
			pool = cheap
		elif push.get("go", false):
			lane_x = float(push["lane_x"])
			pool.clear()
			for c in _affordable(_push_plan.reserve()):
				pool.append(c)
		if pool.is_empty():
			return
	var pushing = push.get("go", false)
	var chosen: CardData = profile.choose_card(pool)
	if push.get("first", false):
		var leader = PushPlan.pick_leader(pool, profile.favorite_card)
		if leader != null:
			chosen = leader
	if chosen == null:
		return
	var pos = Vector2.INF
	if chosen.is_spell():
		pos = BattleBrain.proactive_spell_target(battle.get_tree(), chosen, team)
		if pos == Vector2.INF:
			return
	else:
		var st = DeckBuilder.get_unit_stats(chosen)
		pos = BattleBrain.offensive_position(chosen, st, team, battle.get_tree(), spawn_area, battle, lane_x)
		if pushing and !push.get("first", false) and st != null and st.unit_type != UnitData.UnitType.BUILDING:
			pos = PushPlan.support_position(battle.get_tree(), team, lane_x, spawn_area, battle, pos)
	_play(chosen, pos)
	if pushing:
		_push_plan.played += 1
	if pushing and !_push_followup:
		_push_followup = true
		get_tree().create_timer(1.1, false).timeout.connect(func():
			_push_followup = false
			if is_inside_tree():
				_decide())


## recurso do adversário, quando é um só (1 contra 1 de robôs); -1 = não sei
func _opponent_money() -> int:
	var foes: Array = []
	for c in battle._extra_ai_controllers:
		if is_instance_valid(c) and c != self and c.team != team:
			foes.append(c)
	if foes.size() == 1 and battle.ai_profile == null:
		return int(foes[0].money)
	return -1


func _play(card: CardData, pos: Vector2):
	if card == null or pos == Vector2.INF or money < card.cost:
		return
	money -= card.cost
	var i = hand.find(card)
	if i != -1:
		queue.push_back(card)
		hand[i] = queue.pop_front()
	if card.is_spell():
		battle.cast_spell(card.spell_data, pos, team, card.resource_path)
	else:
		battle.spawn_unit(card.unit_scene, team, pos, card, profile)
	battle._record_action("ally" if team == GameManager.Team.PLAYER else "bot2", card, pos)
	battle.show_bot_play_tag(profile.profile_name, pos, team)
