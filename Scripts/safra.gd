extends Node
## SAFRA (autoload) -- o "auto-criador": a cada 3 dias o sítio colhe 2 cartas
## novas (geradas por peças, no estilo de uma turma) e 1 missão especial.
##   · as cartas entram nos baús, na Feira e nos baralhos dos bots
##   · você ganha 1 das duas de amostra; a missão libera a outra + um baú
## As cartas não ficam salvas em arquivo: cada safra é refeita igualzinha a
## partir do número do período (semente fixa). Só a lista de períodos é salva.

const PERIOD_DAYS = 3
const SAVE_PATH = "user://safra.json"
const MAX_PERIODS = 15           # guarda as últimas 15 safras (30 cartas)
const MISSION_WINS = 3
const ROLES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]  # sem Invocador (depende de outras cartas)

var periods: Array = []
var _by_period: Dictionary = {}  # período -> [CardData, CardData]


func _ready():
	_load()
	var now = current_period()
	if periods.is_empty():
		periods.append(now)
	elif now > int(periods[-1]):
		# no máximo 2 safras atrasadas de uma vez (voltou depois de muito tempo)
		var first = maxi(int(periods[-1]) + 1, now - 1)
		for p in range(first, now + 1):
			periods.append(p)
	while periods.size() > MAX_PERIODS:
		periods.pop_front()
	_save()
	for p in periods:
		_build_period(int(p))


static func current_period() -> int:
	return SafraTempo.current_period()


func days_to_next() -> float:
	var next_start = float(current_period() + 1) * PERIOD_DAYS * 86400.0
	return maxf(0.0, (next_start - Time.get_unix_time_from_system()) / 86400.0)


func _load():
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary and parsed.get("periods") is Array:
			periods = parsed["periods"]


func _save():
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"periods": periods}))


var _towers: Dictionary = {}   # período -> torre gerada naquela safra


func current_tower() -> BaseData:
	return _towers.get(int(periods[-1]), null) if !periods.is_empty() else null


var _sigs: Dictionary = {}  # período -> ["raridade|papel", "especial:x"] das cartas dele


## "tipo" da carta gerada: raridade + papel (e a receita especial, se for uma)
func _signature(gen: Dictionary) -> Array:
	var def: Dictionary = gen["def"]
	var score = 0
	for pair in (Catalogo.spell_abilities(gen["spell"]) if gen["spell"] != null else Catalogo.unit_abilities(gen["stats"])):
		score += int(pair[1])
	var out: Array = ["%d|%s" % [Catalogo.rarity_from_score(score, int(def.get("raridade", 0))), str(def.get("papel", ""))]]
	if str(def.get("especial", "")) != "":
		out.append("especial:" + str(def["especial"]))
	return out


## é carta da safra ATUAL? (novidade)
func is_novelty(c: CardData) -> bool:
	return c != null and current_cards().has(c)


func _build_period(p: int):
	_sigs[p] = []
	var list: Array = []
	var used_turmas: Array = []
	CardGenerator.fixed_power = 15.0  # força fixa: carta de safra antiga não muda quando o jogo ganha carta nova
	for n in 2:
		var rng = RandomNumberGenerator.new()
		rng.seed = hash("safra_%d_%d" % [p, n])
		var turma = CardGenerator.random_turma(rng)
		if used_turmas.has(turma):
			turma = CardGenerator.random_turma(rng)
		used_turmas.append(turma)
		# NÃO REPETE: se saiu, por exemplo, uma "Normal de enxame", as próximas 3
		# safras não trazem outra Normal de enxame (nem a mesma receita especial)
		var recent: Array = []
		for back in range(1, 4):
			recent.append_array(_sigs.get(p - back, []))
		recent.append_array(_sigs.get(p, []))
		var gen: Dictionary = {}
		var sig: Array = []
		for attempt in 14:
			var kind = 2 if (n == 1 and rng.randf() < 0.35) else 1
			var role = ROLES[rng.randi() % ROLES.size()]
			gen = CardGenerator.generate_def(rng.randi(), turma, kind, role, 0)
			sig = _signature(gen)
			if !sig.any(func(x): return recent.has(x)):
				break
		if !_sigs.has(p):
			_sigs[p] = []
		_sigs[p].append_array(sig)
		var def: Dictionary = gen["def"]
		for existing in CardDatabase.all_cards:
			if existing != null and existing.card_name == def["nome"]:
				def["nome"] = "%s %s" % [def["nome"], CardGenerator.FUNNY_SUFFIXES[rng.randi() % CardGenerator.FUNNY_SUFFIXES.size()]]
				break
		def["desc"] = "Colhida na safra nº %d." % p
		var card = Catalogo.build_card(def, "%ssafra_%d_%d.tres" % [Catalogo.PATH_PREFIX, p, n], gen["stats"], gen["spell"])
		card.set_meta("safra", p)
		list.append(card)
		if !CardDatabase.all_cards.has(card):
			CardDatabase.all_cards.append(card)
	CardGenerator.fixed_power = 0.0
	_by_period[p] = list
	# TORRE NOVA: uma a cada 2 safras, na mesma frequência de raridade das cartas
	if p % 2 == 0 and !_towers.has(p):
		var bdef = CardGenerator.generate_base_def(p)
		for existing_b in BotSimulator.available_bases:
			if existing_b != null and existing_b.base_name == bdef["nome"]:
				bdef["nome"] += " II"
		bdef["desc"] = "Erguida na safra nº %d." % p
		var tower = Catalogo.build_base(bdef, "%ssafra_torre_%d.tres" % [Catalogo.PATH_PREFIX, p])
		tower.set_meta("safra", p)
		_towers[p] = tower
		if !BotSimulator.available_bases.has(tower):
			BotSimulator.available_bases.append(tower)
	DeckBuilder.clear_cache()


func all_cards() -> Array:
	var out: Array = []
	for p in periods:
		out.append_array(_by_period.get(int(p), []))
	return out


func current_cards() -> Array:
	return _by_period.get(int(periods[-1]), []) if !periods.is_empty() else []


# ---------------------------------------------------------------- por perfil (amostra + missão)
func _state() -> Dictionary:
	var s: Dictionary = Progresso.d["safra"]
	if !s.has("dadas"):
		s["dadas"] = []
	return s


## chamado pelo menu: entrega a amostra da safra nova e arma a missão
func sync_profile():
	if periods.is_empty() or PlayerProfile.active_profile_id < 0:
		return
	var p = int(periods[-1])
	var s = _state()
	if s["dadas"].has(p) or s["dadas"].has(float(p)):
		return
	s["dadas"].append(p)
	var cards = current_cards()
	if cards.is_empty():
		return
	var result = Progresso.give_card(cards[0], 1)
	s["missao"] = {"periodo": p, "prog": 0, "pego": false}
	Progresso._push({"tipo": "safra", "itens": [result]})
	Progresso.save()


func mission() -> Dictionary:
	var s = _state()
	var m = s.get("missao", {})
	if m.is_empty() or periods.is_empty() or int(m.get("periodo", -1)) != int(periods[-1]):
		return {}
	return m


func mission_text() -> String:
	var cards = current_cards()
	if cards.is_empty():
		return ""
	return "Vença %d partidas com %s no baralho" % [MISSION_WINS, cards[0].card_name]


func mission_ready() -> bool:
	var m = mission()
	return !m.is_empty() and !m["pego"] and int(m["prog"]) >= MISSION_WINS


func on_battle(won: bool):
	var m = mission()
	if m.is_empty() or m["pego"] or !won:
		return
	var cards = current_cards()
	if cards.is_empty() or !DeckManager.full_deck.has(cards[0]):
		return
	m["prog"] = int(m["prog"]) + 1
	Progresso.save()


## prêmio: a OUTRA carta da safra + um Caixote da Feira
func claim_mission() -> Array:
	if !mission_ready():
		return []
	var m = mission()
	m["pego"] = true
	var loot: Array = []
	var cards = current_cards()
	if cards.size() > 1:
		loot.append(Progresso.give_card(cards[1], 1))
	loot.append_array(Progresso.roll_chest(1))
	Progresso._commit()
	return loot


func status_text() -> String:
	var txt = "A cada %d dias o sítio colhe 2 cartas novas e 1 missão especial. Elas entram nos baús, na Feira e nos baralhos dos bots.\n\n" % PERIOD_DAYS
	txt += "Safras colhidas até agora: %d  ·  próxima em %.1f dia(s)" % [periods.size(), days_to_next()]
	return txt
