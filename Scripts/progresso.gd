extends Node
## PROGRESSO 2.0 (autoload "Progresso") -- tudo que o jogador conquista:
##   · cartas que tem + cópias (achou a carta = liberou; cópias + ouro = sobe de nível)
##   · nível do jogador (XP)  · maestria por carta (só visual, pelo uso)
##   · baús de colheita (tempo curto; cada partida jogada adianta o baú)
##   · Feira da roça (ofertas do dia) e o Mascate (aparece de surpresa)
##   · Caminho dos Troféus (prêmio a cada 100 troféus)
##   · 4 baralhos salvos · cartas mais/menos jogadas na temporada
## Um arquivo por perfil: user://profiles/progresso_<id>.json

signal changed
signal rewards_pending  # tem prêmio novo na fila pra mostrar (hub abre o popup)

const SAVE_DIR = "user://profiles/"
const DECK_SLOTS = 4
const DECK_SIZE = 7
const CHEST_SLOTS = 3
const BATTLE_SKIPS_SECONDS = 60  # cada partida jogada adianta o baú que está abrindo

const CHESTS = [
	{"nome": "Saco de Milho", "tempo": 60, "cartas": 3, "ouro": [20, 40], "pesos": [80, 18, 2, 0], "cor": "#d8b060", "garante": -1},
	{"nome": "Caixote da Feira", "tempo": 180, "cartas": 5, "ouro": [50, 90], "pesos": [62, 30, 7, 1], "cor": "#b87840", "garante": 1},
	{"nome": "Baú do Celeiro", "tempo": 480, "cartas": 8, "ouro": [120, 200], "pesos": [48, 34, 15, 3], "cor": "#c84838", "garante": 2},
	{"nome": "Baú Lendário", "tempo": 900, "cartas": 10, "ouro": [300, 500], "pesos": [35, 35, 22, 8], "cor": "#5fe0d0", "garante": 3},
]
const WIN_CHEST_WEIGHTS = [60, 28, 10, 2]

# cópias pra subir do nível L pro L+1 (índice = L-1), por raridade
const COPIES_NEEDED = [
	[2, 4, 8, 15, 25, 40, 60, 90],
	[1, 2, 4, 8, 13, 20, 30, 45],
	[1, 1, 2, 3, 5, 8, 12, 18],
	[1, 1, 1, 2, 2, 3, 4, 5],
]
const COIN_FACTOR = [1.0, 1.5, 2.5, 4.0]
const COPIES_PER_ROLL = [[3, 8], [2, 4], [1, 2], [1, 1]]
const DUPLICATE_GOLD = [5, 20, 100, 500]  # ouro por cópia que sobra de carta no nível máximo
const SHOP_PRICE = [8, 30, 150, 800]      # por cópia
const SHOP_QTY = [10, 5, 2, 1]
const UNLOCK_PRICE = [60, 200, 800, 3000]  # carta que você ainda não tem
const SHOP_CHESTS = [[1, 250], [2, 700]]

const MASTERY_STEPS = [10, 30, 75, 150]
const MASTERY_NAMES = ["", "Bronze", "Prata", "Ouro", "Diamante"]
const MASTERY_COLORS = [Color(0, 0, 0, 0), Color("#c0824a"), Color("#d4dde4"), Color("#ffd23c"), Color("#7ff0ff")]

const ROAD_STEP = 100
const ROAD_MAX = 5000

var d: Dictionary = {}
var _loaded_id := -999


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerProfile.profile_changed.connect(_on_profile_changed)
	_on_profile_changed()


func _on_profile_changed():
	if PlayerProfile.active_profile_id != _loaded_id:
		_load()


func _path() -> String:
	return SAVE_DIR + "progresso_%d.json" % _loaded_id


func _blank() -> Dictionary:
	return {
		"owned": {}, "copies": {}, "uses": {}, "xp": 0,
		"chests": [], "shop": {}, "road": [], "decks": [], "active_deck": 0,
		"streak": 0, "best_streak": 0, "mascate": {}, "pending": [],
		"season": 0, "season_uses": {}, "new": {}, "safra": {}, "torneio": {},
	}


func _load():
	_loaded_id = PlayerProfile.active_profile_id
	d = _blank()
	if _loaded_id >= 0 and FileAccess.file_exists(_path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if parsed is Dictionary:
			for k in parsed:
				d[k] = parsed[k]
	_ensure_defaults()
	changed.emit()


func _ensure_defaults():
	# cartas iniciais (arena 0) sempre liberadas
	for c in CardDatabase.all_cards:
		if c != null and c.unlock_arena <= 0 and !CustomContent.is_spawn_only(c) and !_is_safra(c):
			d["owned"][c.resource_path] = true
	# 4 baralhos -- o 1º herda o baralho atual
	var decks: Array = d["decks"]
	while decks.size() < DECK_SLOTS:
		decks.append([])
	for i in DECK_SLOTS:
		decks[i] = _valid_deck(decks[i])
	d["active_deck"] = clampi(int(d["active_deck"]), 0, DECK_SLOTS - 1)
	if _loaded_id >= 0:
		_apply_active_deck()


func _is_safra(c: CardData) -> bool:
	return c.has_meta("safra")


func _valid_deck(paths: Array) -> Array:
	var out: Array = []
	for p in paths:
		var c = Catalogo.find_card(str(p))
		if c != null and is_owned(c) and !out.has(c.resource_path) and out.size() < DECK_SIZE:
			out.append(c.resource_path)
	# completa com o baralho inicial e depois com qualquer carta que tenha
	var fill: Array = Catalogo.starter_deck() + owned_cards()
	for c in fill:
		if out.size() >= DECK_SIZE:
			break
		if !out.has(c.resource_path):
			out.append(c.resource_path)
	return out


func save():
	if _loaded_id < 0:
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f = FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


func _commit():
	save()
	changed.emit()


# ================================================================ cartas
func pool() -> Array:
	## cartas que podem cair/aparecer na Feira agora (pela arena do jogador)
	var arena = ArenaManager.get_player_arena()
	var out: Array = []
	for c in CardDatabase.all_cards:
		if c != null and !CustomContent.is_spawn_only(c) and c.unlock_arena <= arena:
			out.append(c)
	return out


func is_owned(c: CardData) -> bool:
	return c != null and d["owned"].has(c.resource_path)


func owned_cards() -> Array:
	var out: Array = []
	for c in CardDatabase.all_cards:
		if is_owned(c):
			out.append(c)
	return out


func is_new(c: CardData) -> bool:
	return d["new"].has(c.resource_path)


func clear_new(c: CardData):
	if d["new"].erase(c.resource_path):
		save()


func copies(c: CardData) -> int:
	return int(d["copies"].get(c.resource_path, 0))


func level(c: CardData) -> int:
	return PlayerProfile.get_card_level(c)


func copies_needed(c: CardData) -> int:
	var lv = level(c)
	if lv >= PlayerProfile.MAX_CARD_LEVEL:
		return 0
	return COPIES_NEEDED[Catalogo.rarity_of(c)][clampi(lv - 1, 0, 7)]


func upgrade_cost(c: CardData) -> int:
	return int(round(PlayerProfile.get_upgrade_coin_cost(c) * COIN_FACTOR[Catalogo.rarity_of(c)]))


func can_upgrade(c: CardData) -> bool:
	return is_owned(c) and level(c) < PlayerProfile.MAX_CARD_LEVEL and copies(c) >= copies_needed(c) and PlayerProfile.coins >= upgrade_cost(c)


func upgrade(c: CardData) -> bool:
	if !can_upgrade(c):
		return false
	var need = copies_needed(c)
	var cost = upgrade_cost(c)
	d["copies"][c.resource_path] = copies(c) - need
	PlayerProfile.card_levels[c.resource_path] = level(c) + 1
	PlayerProfile.spend_coins(cost)
	add_xp(10 + 5 * level(c))
	_commit()
	return true


## dá cópias de uma carta (libera se for nova). Devolve o que aconteceu.
func give_card(c: CardData, amount: int) -> Dictionary:
	var result = {"tipo": "carta", "path": c.resource_path, "qtd": amount, "nova": false, "ouro": 0}
	if !is_owned(c):
		d["owned"][c.resource_path] = true
		d["new"][c.resource_path] = true
		result["nova"] = true
		amount -= 1
	if amount > 0:
		if level(c) >= PlayerProfile.MAX_CARD_LEVEL:
			result["ouro"] = amount * DUPLICATE_GOLD[Catalogo.rarity_of(c)]
			PlayerProfile.add_coins(result["ouro"])
		else:
			d["copies"][c.resource_path] = copies(c) + amount
	return result


# ================================================================ maestria (só visual)
func uses(c: CardData) -> int:
	return int(d["uses"].get(c.resource_path, 0)) if c != null else 0


func mastery(c: CardData) -> int:
	var u = uses(c)
	var m = 0
	for step in MASTERY_STEPS:
		if u >= step:
			m += 1
	return m


func mastery_progress(c: CardData) -> Array:
	## [usos, próximo degrau] -- próximo = 0 se já está no máximo
	var m = mastery(c)
	return [uses(c), MASTERY_STEPS[m] if m < MASTERY_STEPS.size() else 0]


func record_use(c: CardData):
	if c == null:
		return
	_check_season()
	var before = mastery(c)
	var bonus = 2 if c.resource_path == card_of_the_day_path() else 1
	d["uses"][c.resource_path] = uses(c) + bonus
	d["season_uses"][c.resource_path] = int(d["season_uses"].get(c.resource_path, 0)) + 1
	if mastery(c) > before:
		_push({"tipo": "maestria", "path": c.resource_path, "nivel": mastery(c)})
	save()


## carta do dia: maestria em dobro -- incentivo pra variar o baralho
func card_of_the_day_path() -> String:
	var owned = owned_cards()
	if owned.is_empty():
		return ""
	var day = Time.get_date_string_from_system()
	return owned[abs(hash(day + "carta")) % owned.size()].resource_path


func _check_season():
	if int(d["season"]) != SeasonManager.season_number:
		d["season"] = SeasonManager.season_number
		d["season_uses"] = {}


## [[carta, usos]...] da temporada, do mais pro menos jogado (só cartas que você tem)
func season_ranking() -> Array:
	_check_season()
	var out: Array = []
	for c in owned_cards():
		out.append([c, int(d["season_uses"].get(c.resource_path, 0))])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


# ================================================================ nível do jogador
func xp_for_level(lv: int) -> int:
	return 100 + 60 * (lv - 1)


func player_level() -> int:
	var lv = 1
	var left = int(d["xp"])
	while left >= xp_for_level(lv):
		left -= xp_for_level(lv)
		lv += 1
	return lv


func level_progress() -> Array:
	## [xp dentro do nível, xp que o nível pede]
	var lv = 1
	var left = int(d["xp"])
	while left >= xp_for_level(lv):
		left -= xp_for_level(lv)
		lv += 1
	return [left, xp_for_level(lv)]


func add_xp(amount: int):
	if amount <= 0:
		return
	var before = player_level()
	d["xp"] = int(d["xp"]) + amount
	var after = player_level()
	for lv in range(before + 1, after + 1):
		var gold = 80 + 40 * lv
		PlayerProfile.add_coins(gold)
		_push({"tipo": "nivel", "nivel": lv, "ouro": gold})
		_push_chest_open(mini(1 + lv / 6, 3))
	save()


# ================================================================ baús
func chests() -> Array:
	return d["chests"]


func has_free_slot() -> bool:
	return d["chests"].size() < CHEST_SLOTS


func add_chest(type: int) -> bool:
	if !has_free_slot():
		return false
	d["chests"].append({"tipo": type, "inicio": 0.0, "pulado": 0.0})
	_commit()
	return true


func roll_win_chest_type() -> int:
	var type = _weighted(WIN_CHEST_WEIGHTS)
	if int(d["streak"]) >= 3:
		type = mini(type + 1, 3)  # sequência de vitórias = baú melhor
	return type


func unlocking_index() -> int:
	for i in d["chests"].size():
		if float(d["chests"][i]["inicio"]) > 0.0:
			return i
	return -1


func start_chest(index: int) -> bool:
	if index < 0 or index >= d["chests"].size() or unlocking_index() != -1:
		return false
	d["chests"][index]["inicio"] = Time.get_unix_time_from_system()
	_commit()
	return true


func chest_remaining(index: int) -> float:
	var ch = d["chests"][index]
	var total = float(CHESTS[int(ch["tipo"])]["tempo"])
	if float(ch["inicio"]) <= 0.0:
		return total
	return maxf(0.0, total - (Time.get_unix_time_from_system() - float(ch["inicio"])) - float(ch["pulado"]))


func chest_ready(index: int) -> bool:
	return float(d["chests"][index]["inicio"]) > 0.0 and chest_remaining(index) <= 0.0


## abre o baú pronto e devolve a lista de prêmios (pra animação)
func open_chest(index: int) -> Array:
	if index < 0 or index >= d["chests"].size() or !chest_ready(index):
		return []
	var type = int(d["chests"][index]["tipo"])
	d["chests"].remove_at(index)
	var loot = roll_chest(type)
	add_xp(5 + 5 * type)
	_commit()
	return loot


func roll_chest(type: int) -> Array:
	var def = CHESTS[type]
	var loot: Array = []
	var gold = randi_range(def["ouro"][0], def["ouro"][1])
	PlayerProfile.add_coins(gold)
	loot.append({"tipo": "ouro", "ouro": gold})
	var cards = pool()
	if cards.is_empty():
		return loot
	var by_card: Dictionary = {}
	for i in int(def["cartas"]):
		var rarity = _weighted(def["pesos"])
		if i == 0 and int(def["garante"]) > 0:
			rarity = maxi(rarity, int(def["garante"]))
		var c = _pick_of_rarity(cards, rarity)
		if c == null:
			continue
		var range_q = COPIES_PER_ROLL[Catalogo.rarity_of(c)]
		by_card[c] = int(by_card.get(c, 0)) + randi_range(range_q[0], range_q[1])
	for c in by_card:
		loot.append(give_card(c, by_card[c]))
	return loot


func _pick_of_rarity(cards: Array, rarity: int) -> CardData:
	if cards.is_empty():
		return null
	for r in range(rarity, -1, -1):
		var options = cards.filter(func(c): return Catalogo.rarity_of(c) == r)
		if !options.is_empty():
			# carta que você ainda NÃO tem aparece com mais chance -- acelera a coleção
			var missing = options.filter(func(c): return !is_owned(c))
			if !missing.is_empty() and randf() < 0.45:
				return missing[randi() % missing.size()]
			return options[randi() % options.size()]
	return cards[randi() % cards.size()]


static func _weighted(weights: Array) -> int:
	var total = 0
	for w in weights:
		total += int(w)
	var roll = randi() % maxi(total, 1)
	for i in weights.size():
		roll -= int(weights[i])
		if roll < 0:
			return i
	return 0


# fila de prêmios pra mostrar (nível novo, maestria, baú instantâneo...)
func _push(reward: Dictionary):
	d["pending"].append(reward)
	rewards_pending.emit()


func _push_chest_open(type: int):
	_push({"tipo": "bau", "bau": type, "itens": roll_chest(type)})


func pop_pending() -> Array:
	var out: Array = d["pending"].duplicate(true)
	d["pending"] = []
	if !out.is_empty():
		save()
	return out


# ================================================================ fim de partida
## chamado pela batalha. Devolve um resumo pro placar: {"bau": tipo ou -1, "mascate": bool, "sequencia": n}
func on_battle_finished(won: bool, ranked: bool, xp_gain: int) -> Dictionary:
	var summary = {"bau": -1, "sem_espaco": false, "mascate": false, "sequencia": 0}
	add_xp(xp_gain)
	# trabalho na roça adianta o baú
	var idx = unlocking_index()
	if idx != -1:
		d["chests"][idx]["pulado"] = float(d["chests"][idx]["pulado"]) + BATTLE_SKIPS_SECONDS
	if ranked:
		d["streak"] = int(d["streak"]) + 1 if won else 0
		d["best_streak"] = maxi(int(d["best_streak"]), int(d["streak"]))
	summary["sequencia"] = int(d["streak"])
	if won and !MatchSetup.tournament:
		if has_free_slot():
			var type = roll_win_chest_type()
			d["chests"].append({"tipo": type, "inicio": 0.0, "pulado": 0.0})
			summary["bau"] = type
		else:
			summary["sem_espaco"] = true
			var consolation = 15 + 5 * ArenaManager.get_player_arena()
			PlayerProfile.add_coins(consolation)
	Safra.on_battle(won)
	if randf() < 0.22 and !mascate_active():
		_spawn_mascate()
		summary["mascate"] = true
	_commit()
	return summary


# ================================================================ Feira
func shop() -> Dictionary:
	var today = Time.get_date_string_from_system()
	if str(d["shop"].get("dia", "")) != today:
		_roll_shop(today)
	return d["shop"]


func _roll_shop(today: String):
	var cards = pool()
	cards.shuffle()
	var offers: Array = []
	var wanted = [0, 0, 1, 1, 2]  # 2 comuns, 2 raras, 1 épica (ou o que tiver)
	for rarity in wanted:
		var c = _pick_of_rarity(cards.filter(func(x): return !offers.any(func(o): return o["path"] == x.resource_path)), rarity)
		if c == null:
			continue
		offers.append(_make_offer(c, 1.0))
	d["shop"] = {"dia": today, "ofertas": offers, "gratis": false, "baus": [false, false]}
	save()


func _make_offer(c: CardData, price_mult: float) -> Dictionary:
	var r = Catalogo.rarity_of(c)
	if is_owned(c):
		return {"path": c.resource_path, "qtd": SHOP_QTY[r], "preco": int(round(SHOP_PRICE[r] * SHOP_QTY[r] * price_mult)), "vendido": false}
	return {"path": c.resource_path, "qtd": 1, "preco": int(round(UNLOCK_PRICE[r] * price_mult)), "vendido": false}


func buy_offer(offer: Dictionary) -> Dictionary:
	if offer.get("vendido", false) or PlayerProfile.coins < int(offer["preco"]):
		return {}
	var c = Catalogo.find_card(str(offer["path"]))
	if c == null:
		return {}
	PlayerProfile.spend_coins(int(offer["preco"]))
	offer["vendido"] = true
	var result = give_card(c, int(offer["qtd"]))
	_commit()
	return result


func claim_daily_gift() -> Array:
	var s = shop()
	if s["gratis"]:
		return []
	s["gratis"] = true
	var loot = roll_chest(0)
	_commit()
	return loot


func buy_shop_chest(slot: int) -> Array:
	var s = shop()
	if slot < 0 or slot >= SHOP_CHESTS.size() or s["baus"][slot] or PlayerProfile.coins < SHOP_CHESTS[slot][1]:
		return []
	PlayerProfile.spend_coins(SHOP_CHESTS[slot][1])
	s["baus"][slot] = true
	var loot = roll_chest(SHOP_CHESTS[slot][0])
	_commit()
	return loot


# ---------------------------------------------------------------- Mascate
func mascate_active() -> bool:
	return float(d["mascate"].get("ate", 0.0)) > Time.get_unix_time_from_system()


func mascate_seconds_left() -> float:
	return maxf(0.0, float(d["mascate"].get("ate", 0.0)) - Time.get_unix_time_from_system())


func _spawn_mascate():
	var cards = pool()
	var offers: Array = []
	var fancy = cards.filter(func(c): return Catalogo.rarity_of(c) >= 2)
	if fancy.is_empty():
		fancy = cards
	if !fancy.is_empty():
		offers.append(_make_offer(fancy[randi() % fancy.size()], 0.5))
	if !cards.is_empty():
		offers.append(_make_offer(cards[randi() % cards.size()], 0.6))
	d["mascate"] = {"ate": Time.get_unix_time_from_system() + 300.0, "ofertas": offers, "surpresas": 3}


func mascate_offers() -> Array:
	return d["mascate"].get("ofertas", []) if mascate_active() else []


const SURPRISE_PRICE = 80


func mascate_surprises_left() -> int:
	return int(d["mascate"].get("surpresas", 0)) if mascate_active() else 0


## caixa surpresa do Mascate: pode vir uma mixaria... ou uma lendária
func buy_surprise() -> Dictionary:
	if mascate_surprises_left() <= 0 or PlayerProfile.coins < SURPRISE_PRICE:
		return {}
	PlayerProfile.spend_coins(SURPRISE_PRICE)
	d["mascate"]["surpresas"] = mascate_surprises_left() - 1
	var roll = randf()
	var result: Dictionary
	if roll < 0.30:
		var gold = randi_range(10, 50)
		PlayerProfile.add_coins(gold)
		result = {"tipo": "ouro", "ouro": gold, "fala": "Ih... só tinha isso no fundo da caixa."}
	elif roll < 0.55:
		var gold2 = randi_range(120, 260)
		PlayerProfile.add_coins(gold2)
		result = {"tipo": "ouro", "ouro": gold2, "fala": "Opa! Dinheiro esquecido!"}
	else:
		var rarity = _weighted([45, 35, 16, 4])
		var c = _pick_of_rarity(pool(), rarity)
		if c == null:
			return {"tipo": "ouro", "ouro": 0, "fala": "A caixa veio vazia. Coisas da vida."}
		var q = COPIES_PER_ROLL[Catalogo.rarity_of(c)]
		result = give_card(c, randi_range(q[0], q[1]) * 2)
		result["fala"] = "Essa aí caiu do caminhão."
	_commit()
	return result


# ================================================================ Caminho dos Troféus
func road_milestones() -> Array:
	## [{trofeus, premio{...}, liberado, pego}]
	var out: Array = []
	var mine = ArenaManager.get_trophies(PlayerProfile.player_name)
	var t = ROAD_STEP
	while t <= ROAD_MAX:
		out.append({"trofeus": t, "premio": road_reward(t), "liberado": mine >= t, "pego": d["road"].has(t) or d["road"].has(float(t))})
		t += ROAD_STEP
	return out


func road_reward(trophies: int) -> Dictionary:
	for i in range(2, ArenaManager.max_arena + 1):
		var th = int(ArenaManager.arenas[i]["trophy_threshold"])
		if trophies >= th and trophies - th < ROAD_STEP:
			return {"tipo": "bau", "bau": 3 if i >= 5 else 2, "arena": i}
	var n = trophies / ROAD_STEP
	match n % 5:
		1:
			return {"tipo": "ouro", "ouro": 60 + n * 12}
		2:
			return {"tipo": "bau", "bau": 0}
		3:
			return {"tipo": "ouro", "ouro": 90 + n * 15}
		4:
			return {"tipo": "bau", "bau": 1}
	return {"tipo": "bau", "bau": 2}


func road_claimable() -> int:
	var n = 0
	for m in road_milestones():
		if m["liberado"] and !m["pego"]:
			n += 1
	return n


func claim_road(trophies: int) -> Array:
	if d["road"].has(trophies) or d["road"].has(float(trophies)) or ArenaManager.get_trophies(PlayerProfile.player_name) < trophies:
		return []
	d["road"].append(trophies)
	var reward = road_reward(trophies)
	var loot: Array = []
	if reward["tipo"] == "ouro":
		PlayerProfile.add_coins(int(reward["ouro"]))
		loot.append({"tipo": "ouro", "ouro": int(reward["ouro"])})
	else:
		loot = roll_chest(int(reward["bau"]))
	_commit()
	return loot


func is_base_unlocked(b: BaseData) -> bool:
	return b != null and b.unlock_arena <= ArenaManager.get_player_arena()


# ================================================================ baralhos
func active_deck() -> int:
	return int(d["active_deck"])


func deck_paths(slot: int) -> Array:
	return d["decks"][clampi(slot, 0, DECK_SLOTS - 1)]


func deck_cards(slot: int) -> Array:
	var out: Array = []
	for p in deck_paths(slot):
		var c = Catalogo.find_card(str(p))
		if c != null:
			out.append(c)
	return out


func deck_average_cost(slot: int) -> float:
	var cards = deck_cards(slot)
	if cards.is_empty():
		return 0.0
	var total = 0
	for c in cards:
		total += c.cost
	return float(total) / cards.size()


func set_active_deck(slot: int):
	d["active_deck"] = clampi(slot, 0, DECK_SLOTS - 1)
	_apply_active_deck()
	_commit()


## troca a carta da posição `index` do baralho `slot`. Se a carta já estava
## em outra posição do mesmo baralho, as duas trocam de lugar.
func set_deck_card(slot: int, index: int, c: CardData) -> bool:
	if c == null or !is_owned(c) or CustomContent.is_spawn_only(c):
		return false
	var paths: Array = deck_paths(slot)
	if index < 0 or index >= paths.size():
		return false
	var other = paths.find(c.resource_path)
	if other == index:
		return false
	if other != -1:
		paths[other] = paths[index]
	paths[index] = c.resource_path
	if slot == active_deck():
		_apply_active_deck()
	_commit()
	return true


func _apply_active_deck():
	var cards = deck_cards(active_deck())
	if cards.size() != DECK_SIZE:
		return
	DeckManager.full_deck.assign(cards)
	DeckManager.start_deck()
	DeckManager.deck_changed.emit()
	if PlayerProfile.deck_card_paths != deck_paths(active_deck()):
		PlayerProfile.deck_card_paths = deck_paths(active_deck()).duplicate()
		PlayerProfile.save_profile()


# ================================================================ Torneio da Roça (modo desafio)
# 8 competidores, mata-mata: quartas -> semi -> final. Perdeu, tá fora.
# Cartas todas no mesmo nível, uma regra especial sorteada por torneio e
# adversários cada vez mais fortes. 1 entrada grátis por dia; depois, ouro.
const TOURNAMENT_ROUNDS = ["Quartas de final", "Semifinal", "FINAL"]
const TOURNAMENT_FEE = 150
const TOURNAMENT_PRIZES = [
	{"ouro": 60, "bau": 0},
	{"ouro": 120, "bau": 1},
	{"ouro": 300, "bau": 2},
]


func tournament() -> Dictionary:
	return d["torneio"]


func tournament_active() -> bool:
	return bool(d["torneio"].get("ativo", false))


func tournament_free_today() -> bool:
	return str(d["torneio"].get("dia_gratis", "")) != Time.get_date_string_from_system()


func tournament_cups() -> int:
	return int(d["torneio"].get("tacas", 0))


func can_enter_tournament() -> bool:
	return !tournament_active() and (tournament_free_today() or PlayerProfile.coins >= TOURNAMENT_FEE)


func enter_tournament() -> bool:
	if !can_enter_tournament():
		return false
	var t: Dictionary = d["torneio"]
	if tournament_free_today():
		t["dia_gratis"] = Time.get_date_string_from_system()
	else:
		PlayerProfile.spend_coins(TOURNAMENT_FEE)
	# adversários: do mais perto do seu troféu pro mais forte (a final é contra o melhor)
	var mine = ArenaManager.get_trophies(PlayerProfile.player_name)
	var roster: Array = BotSimulator.roster_names.duplicate()
	roster.sort_custom(func(a, b): return ArenaManager.get_trophies(a) < ArenaManager.get_trophies(b))
	var above = roster.filter(func(n): return ArenaManager.get_trophies(n) >= mine)
	var below = roster.filter(func(n): return ArenaManager.get_trophies(n) < mine)
	below.reverse()
	var ordered: Array = above + below
	var picks: Array = []
	for i in [0, mini(4, ordered.size() - 1), mini(10, ordered.size() - 1)]:
		if ordered.size() > 0 and !picks.has(ordered[i]):
			picks.append(ordered[i])
	while picks.size() < 3 and !roster.is_empty():
		var extra = roster[randi() % roster.size()]
		if !picks.has(extra) or roster.size() < 3:
			picks.append(extra)
	# figurantes da chave (os outros 4 da tabela, só pra mostrar)
	var others: Array = []
	for n in roster:
		if !picks.has(n) and others.size() < 4:
			others.append(n)
	t["ativo"] = true
	t["rodada"] = 0
	t["oponentes"] = picks
	t["figurantes"] = others
	t["regra"] = randi() % MatchSetup.RULE_NAMES.size()
	t["arena"] = randi_range(1, 7)
	_commit()
	return true


func tournament_opponent() -> String:
	var t = d["torneio"]
	var list: Array = t.get("oponentes", [])
	var r = int(t.get("rodada", 0))
	return str(list[r]) if r < list.size() else ""


func start_tournament_match(tree: SceneTree):
	if !tournament_active():
		return
	var t = d["torneio"]
	MatchSetup.start_tournament_match(tree, tournament_opponent(), int(t.get("regra", 0)), int(t.get("arena", 1)))


## chamado no fim da partida de torneio; devolve o texto do placar
func tournament_result(won: bool) -> String:
	var t: Dictionary = d["torneio"]
	if !tournament_active():
		return ""
	var r = int(t.get("rodada", 0))
	var text: String
	if won:
		var prize = TOURNAMENT_PRIZES[clampi(r, 0, 2)]
		PlayerProfile.add_coins(int(prize["ouro"]))
		_push({"tipo": "bau", "bau": int(prize["bau"]), "itens": [{"tipo": "ouro", "ouro": int(prize["ouro"])}] + roll_chest(int(prize["bau"]))})
		if r >= 2:
			t["ativo"] = false
			t["tacas"] = tournament_cups() + 1
			add_xp(150)
			text = "CAMPEÃO! 🏆 taça nº %d" % tournament_cups()
		else:
			t["rodada"] = r + 1
			text = "Passou! Agora: %s" % TOURNAMENT_ROUNDS[r + 1]
	else:
		t["ativo"] = false
		text = "Eliminado nas %s" % TOURNAMENT_ROUNDS[r].to_lower() if r < 2 else "Vice-campeão. Quase!"
	t["ultimo"] = text
	_commit()
	return text
