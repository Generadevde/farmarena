extends RefCounted
class_name Cla
## CLÃS -- cada bot do jogo pertence a um clã; você entra em um e passa a:
##   · pedir cartas (os colegas vão doando aos poucos, e a cada partida)
##   · doar cartas pros pedidos deles (ganha ouro, XP e pontos pro clã)
##   · jogar amistosos contra os membros (sem valer troféu)
##   · encher a "Colheita do clã" junto com eles (baús e um poder raro no topo)
##   · acompanhar o mural e o ranking de clãs
## Tudo fica em Progresso.d["cla"] (por perfil).

const NAMES = ["Unidos do Curral", "Tropa do Brejo", "Os Sem Porteira", "Galo Doido FC", "Fazenda Feliz", "Capivaras Zen",
	"Trator Azul", "Pé de Serra", "Os Butina", "Milho Verde", "Boiada Brava", "Coisa Estranha S/A"]
const REQUEST_CAP = [12, 4, 1, 0]        # cópias por pedido, por raridade (lendária não dá)
const REQUEST_COOLDOWN = 20 * 60          # segundos entre um pedido e outro
const SECONDS_PER_COPY = 75.0             # ritmo das doações dos colegas
const DONATE_GOLD = [6, 30, 120, 0]
const DONATE_XP = [3, 10, 30, 0]
const HARVEST_TIERS = [200, 450, 800]     # pontos do clã -> Saco, Caixote, Baú do Celeiro (+ poder raro)
const CHAT_LINES = ["Bão dia, povo!", "Alguém tem Pintaiada sobrando?", "Perdi pra um Robô Balde de novo...", "Hoje tem torneio, hein.",
	"Quem aí já viu o Mascate hoje?", "Tô quase na próxima arena!", "Esse Jacaré tá forte demais, uai.", "Bora encher a colheita!",
	"Minha vaca caiu no rio. De novo.", "Doei, hein? Depois não reclama.", "Amistoso? Tô online.", "Só mais uma partida e vou dormir. (mentira)"]


static func _d() -> Dictionary:
	var c: Dictionary = Progresso.d["cla"]
	for k in [["nome", ""], ["pedido", {}], ["prox_pedido", 0.0], ["pedidos_bots", []], ["prox_bot", 0.0], ["doacoes", 0],
			["periodo", 0], ["pontos", 0], ["pegos", []], ["chat", []], ["ultimo_tick", 0.0], ["ultimo_chat", 0.0]]:
		if !c.has(k[0]):
			c[k[0]] = k[1]
	return c


static func _now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- quem é de qual clã
static func clan_of(who: String) -> String:
	if who == PlayerProfile.player_name:
		return mine()
	return NAMES[abs(hash(who + "#cla")) % NAMES.size()]


static func mine() -> String:
	return str(_d()["nome"])


static func members(clan: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for n in BotSimulator.roster_names:
		if !seen.has(n) and clan_of(n) == clan:
			out.append(n)
		seen[n] = true
	if clan != "" and mine() == clan:
		out.append(PlayerProfile.player_name)
	out.sort_custom(func(a, b): return ArenaManager.get_trophies(a) > ArenaManager.get_trophies(b))
	return out


static func score(clan: String) -> int:
	var total = 0
	for n in members(clan):
		total += ArenaManager.get_trophies(n)
	return total


## [[nome, troféus somados, nº de membros]...] do maior pro menor
static func ranking() -> Array:
	var out: Array = []
	for c in NAMES:
		out.append([c, score(c), members(c).size()])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


static func fake_donations(who: String) -> int:
	return abs(hash(who + "#doa")) % 60 + SafraTempo.current_period() % 7


static func join(clan: String):
	var c = _d()
	c["nome"] = clan
	c["pedidos_bots"] = []
	c["chat"] = []
	c["periodo"] = SafraTempo.current_period()
	c["pontos"] = 0
	c["pegos"] = []
	say("%s entrou no clã. Bem-vindo(a)!" % PlayerProfile.player_name)
	Progresso._commit()


static func leave():
	var c = _d()
	c["nome"] = ""
	c["pedido"] = {}
	c["pedidos_bots"] = []
	Progresso._commit()


static func say(text: String):
	var c = _d()
	c["chat"].append(text)
	while c["chat"].size() > 14:
		c["chat"].pop_front()
	c["ultimo_chat"] = _now()


static func _random_member() -> String:
	var list = members(mine()).filter(func(n): return n != PlayerProfile.player_name)
	return str(list[randi() % list.size()]) if !list.is_empty() else "Alguém"


# ---------------------------------------------------------------- tempo passando (doações chegando, pedidos novos, mural)
## devolve true se algo mudou (pra tela se redesenhar)
static func tick(battles: int = 0) -> bool:
	if mine() == "":
		return false
	var c = _d()
	var changed = false
	var now = _now()
	_check_period()
	# seu pedido: colegas doando
	var req: Dictionary = c["pedido"]
	if !req.is_empty() and int(req["got"]) < int(req["cap"]):
		var card = Catalogo.find_card(str(req["path"]))
		var gained = int((now - float(req["t"])) / SECONDS_PER_COPY) + battles * 2
		gained = mini(gained, int(req["cap"]) - int(req["got"]))
		if card != null and gained > 0:
			req["got"] = int(req["got"]) + gained
			req["t"] = now
			Progresso.give_card(card, gained)
			say("%s doou %dx %s pra você." % [_random_member(), gained, card.card_name])
			changed = true
	# pedidos dos colegas
	if c["pedidos_bots"].size() < 3 and now >= float(c["prox_bot"]):
		var options = Progresso.owned_cards().filter(func(x): return Catalogo.rarity_of(x) <= 1 and !CustomContent.is_spawn_only(x))
		if !options.is_empty():
			var pick: CardData = options[randi() % options.size()]
			if !c["pedidos_bots"].any(func(r): return r["path"] == pick.resource_path):
				c["pedidos_bots"].append({"quem": _random_member(), "path": pick.resource_path, "falta": 4 if Catalogo.rarity_of(pick) == 0 else 1})
				changed = true
		c["prox_bot"] = now + 150.0
	# mural
	if now - float(c["ultimo_chat"]) > 240.0:
		say("%s: %s" % [_random_member(), CHAT_LINES[randi() % CHAT_LINES.size()]])
		changed = true
	if changed:
		Progresso.save()
	return changed


# ---------------------------------------------------------------- pedir
static func can_request() -> bool:
	var c = _d()
	return mine() != "" and _now() >= float(c["prox_pedido"])


static func request_wait() -> float:
	return maxf(0.0, float(_d()["prox_pedido"]) - _now())


static func current_request() -> Dictionary:
	return _d()["pedido"]


static func request(card: CardData) -> bool:
	var cap = REQUEST_CAP[Catalogo.rarity_of(card)]
	if !can_request() or cap <= 0 or !Progresso.is_owned(card):
		return false
	var c = _d()
	c["pedido"] = {"path": card.resource_path, "got": 0, "cap": cap, "t": _now()}
	c["prox_pedido"] = _now() + REQUEST_COOLDOWN
	say("%s pediu %s." % [PlayerProfile.player_name, card.card_name])
	Progresso._commit()
	return true


# ---------------------------------------------------------------- doar
static func bot_requests() -> Array:
	return _d()["pedidos_bots"]


static func donate(index: int) -> Dictionary:
	var c = _d()
	if index < 0 or index >= c["pedidos_bots"].size():
		return {}
	var r: Dictionary = c["pedidos_bots"][index]
	var card = Catalogo.find_card(str(r["path"]))
	if card == null or Progresso.copies(card) < 1:
		return {}
	var rar = Catalogo.rarity_of(card)
	Progresso.d["copies"][card.resource_path] = Progresso.copies(card) - 1
	PlayerProfile.add_coins(DONATE_GOLD[rar])
	Progresso.add_xp(DONATE_XP[rar])
	c["doacoes"] = int(c["doacoes"]) + 1
	add_points(2)
	r["falta"] = int(r["falta"]) - 1
	say("%s doou 1x %s pra %s." % [PlayerProfile.player_name, card.card_name, str(r["quem"])])
	if int(r["falta"]) <= 0:
		c["pedidos_bots"].remove_at(index)
	Progresso._commit()
	return {"ouro": DONATE_GOLD[rar], "xp": DONATE_XP[rar]}


# ---------------------------------------------------------------- colheita do clã (a cada 3 dias)
static func _check_period():
	var c = _d()
	if int(c["periodo"]) != SafraTempo.current_period():
		c["periodo"] = SafraTempo.current_period()
		c["pontos"] = 0
		c["pegos"] = []


static func add_points(n: int):
	if mine() == "":
		return
	_check_period()
	_d()["pontos"] = int(_d()["pontos"]) + n


## pontos do clã inteiro: os seus + o que os colegas vão fazendo ao longo dos 3 dias
static func harvest_points() -> int:
	_check_period()
	var start = float(SafraTempo.current_period()) * SafraTempo.PERIOD_DAYS * 86400.0
	var elapsed = clampf((_now() - start) / (SafraTempo.PERIOD_DAYS * 86400.0), 0.0, 1.0)
	return int(_d()["pontos"]) + int(elapsed * 520.0)


static func harvest_claimable(tier: int) -> bool:
	return mine() != "" and harvest_points() >= HARVEST_TIERS[tier] and !(_d()["pegos"].has(tier) or _d()["pegos"].has(float(tier)))


static func harvest_claimed(tier: int) -> bool:
	return _d()["pegos"].has(tier) or _d()["pegos"].has(float(tier))


static func claim_harvest(tier: int) -> Array:
	if !harvest_claimable(tier):
		return []
	_d()["pegos"].append(tier)
	var loot = Progresso.roll_chest(tier)
	if tier == 2:
		loot.append({"tipo": "poder", "id": Progresso.grant_power("", false)})
	Progresso._commit()
	return loot


static func on_battle(won: bool):
	if mine() == "":
		return
	add_points(15 if won else 5)
	tick(1)


# ---------------------------------------------------------------- amistoso
static func start_friendly(tree: SceneTree, bot_name: String):
	MatchSetup.clear_special()
	MatchSetup.friendly = true
	MatchSetup.mode = MatchSetup.MODE_1V1
	MatchSetup.next_ai_profile = BotLearning.get_or_create_profile(bot_name)
	tree.change_scene_to_file(MatchSetup.BATTLE_SCENE)
