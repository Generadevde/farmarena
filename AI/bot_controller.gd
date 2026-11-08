extends Node
class_name BotController

# Bot "extra" do modo 2v2 -- o bot aliado (do seu lado) e o segundo bot
# inimigo. Cada um tem dinheiro, mão de cartas, ritmo e personalidade
# próprios, e usa o mesmo cérebro tático (BattleBrain) do bot principal.
# Compartilha a base e a área de spawn com o parceiro de time.

const HAND_SIZE = 3
const STARTING_MONEY = 5
# mesmos valores da cena de batalha (batlhe_scene.gd) -- se mudar lá, muda aqui
const MAX_MONEY = 100
const PRODUCTION_INTERVAL = 0.25
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

var _production: Timer
var _decision: Timer
var _defense_accum := 0.0
var _label: Label


func setup(p_battle: Node, p_profile: AIProfile, p_team, p_area: CollisionShape2D, lane_fraction: float):
	battle = p_battle
	profile = p_profile
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
	hand = shuffled.slice(0, HAND_SIZE)
	queue = shuffled.slice(HAND_SIZE)

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
		if c != null and money - reserve >= c.cost:
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
	var chosen: CardData = profile.choose_card(pool)
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
	_play(chosen, pos)


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
