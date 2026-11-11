extends RefCounted
class_name Assembleia
## ASSEMBLEIA DAS CARTAS -- pedido de mexer numa carta (BUFF ou NERF).
##   · A cada 3 dias abre uma pauta dos bots (escolhida pelos NÚMEROS: a carta
##     que mais vence vai pra nerf, a que mais perde vai pra buff) e você pode
##     abrir UMA pauta sua.
##   · Todo mundo vota. O bot não vota no acaso: pesa a taxa de vitória da
##     carta, o quanto ela é usada, se ELE usa a carta e como ele anda de
##     vitórias. O seu voto vale por 5.
##   · No fim dos 3 dias, pauta com mais "sim" do que "não" passa e a carta
##     muda um pouquinho (2% a 4%, conforme o tipo da carta). No máximo 12%
##     acumulado por carta.
## Tudo fica em Progresso.d["assembleia"] (por perfil).

const PLAYER_WEIGHT = 5
const MAX_TOTAL = 0.12
const HISTORY_MAX = 12
const NEUTRAL_BAND = 0.18   # bot sem opinião forte (vontade perto de zero) fica NEUTRO
## quanto muda por votação: [vida, dano], por papel da carta
const STEP_BY_ROLE = {
	CardData.CardRole.TANQUE: [0.04, 0.02], CardData.CardRole.ENXAME: [0.03, 0.03], CardData.CardRole.PUNICAO: [0.02, 0.04],
	CardData.CardRole.CONTROLE: [0.03, 0.02], CardData.CardRole.SUPORTE: [0.03, 0.02],
}
const STEP_DEFAULT = [0.03, 0.03]
const STEP_SPELL = 0.04

static var _orig: Dictionary = {}    # caminho da carta -> números originais
static var _deck_cache: Array = []   # [nome do bot, [caminhos]]
static var _deck_cache_time := -100.0


static func _d() -> Dictionary:
	if !Progresso.d.has("assembleia") or !(Progresso.d["assembleia"] is Dictionary):
		Progresso.d["assembleia"] = {}
	var a: Dictionary = Progresso.d["assembleia"]
	for k in [["periodo", -1], ["pautas", []], ["ajustes", {}], ["historico", []], ["propos", -1]]:
		if !a.has(k[0]):
			a[k[0]] = k[1]
	return a


static func step_for(card: CardData) -> Array:
	if card.is_spell():
		return [STEP_SPELL, STEP_SPELL]
	if card.role == CardData.CardRole.FINALIZADOR or card.role == CardData.CardRole.CERCO:
		return [0.02, 0.04]
	if card.role == CardData.CardRole.CONSTRUCAO or card.role == CardData.CardRole.INVOCADOR:
		return [0.04, 0.02]
	return STEP_BY_ROLE.get(card.role, STEP_DEFAULT)


## texto do que a pauta faria: "+4% vida, +2% dano"
static func effect_text(card: CardData, kind: String) -> String:
	var st = step_for(card)
	var sign_text = "+" if kind == "buff" else "-"
	if card.is_spell():
		return "%s%d%% na força do feitiço" % [sign_text, int(round(st[0] * 100))]
	return "%s%d%% vida, %s%d%% dano" % [sign_text, int(round(st[0] * 100)), sign_text, int(round(st[1] * 100))]


## texto do ajuste acumulado de uma carta ("" se nunca mexeram)
static func adjust_text(card: CardData) -> String:
	var adj: Dictionary = _d()["ajustes"].get(card.resource_path, {})
	if adj.is_empty():
		return ""
	var hp = int(round((float(adj.get("hp", 1.0)) - 1.0) * 100))
	var dmg = int(round((float(adj.get("dmg", 1.0)) - 1.0) * 100))
	if hp == 0 and dmg == 0:
		return ""
	if card.is_spell():
		return "força %+d%%" % hp
	return "vida %+d%%, dano %+d%%" % [hp, dmg]


# ---------------------------------------------------------------- dados pra decidir voto
static func _decks() -> Array:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _deck_cache_time < 20.0 and !_deck_cache.is_empty():
		return _deck_cache
	_deck_cache = []
	for n in BotSimulator.roster_names:
		var raw: Dictionary = BotLearning._load_raw(str(n))
		_deck_cache.append([str(n), raw.get("deck_paths", [])])
	_deck_cache_time = now
	return _deck_cache


static func card_win_rate(path: String) -> float:
	var e: Dictionary = SeasonStats.stats.get(path, {})
	var total = int(e.get("wins", 0)) + int(e.get("losses", 0))
	return float(e.get("wins", 0)) / total if total >= 3 else 0.5


static func usage_share(path: String) -> float:
	var decks = _decks()
	if decks.is_empty():
		return 0.0
	var n = 0
	for dk in decks:
		if dk[1].has(path):
			n += 1
	return float(n) / decks.size()


## quanto ESTE bot quer um nerf nessa carta (positivo = quer nerf, negativo = quer buff)
static func _nerf_wish(bot: String, deck: Array, path: String, share: float, avg_share: float) -> float:
	var s = (card_win_rate(path) - 0.5) * 4.0        # carta que vence demais incomoda
	s += (share - avg_share) * 3.0                    # carta que todo mundo usa também
	if deck.has(path):
		s -= 0.8                                      # é a carta DELE: defende
	else:
		s += (0.5 - Leaderboard.get_win_rate(bot)) * 1.0 if Leaderboard.get_record(bot)["wins"] + Leaderboard.get_record(bot)["losses"] > 0 else 0.0
	s += (float(abs(hash(bot + path)) % 21) - 10.0) / 100.0  # desempate fixo (não é sorteio: sempre o mesmo)
	return s


## [sim, não, neutros] de uma pauta, contando bots + o seu voto
static func votes(pauta: Dictionary) -> Array:
	var path = str(pauta["path"])
	var want_nerf = str(pauta["tipo"]) == "nerf"
	var decks = _decks()
	var share = usage_share(path)
	var avg_share = float(Progresso.DECK_SIZE) / maxf(1.0, float(CardDatabase.all_cards.size()))
	var yes = 0
	var no = 0
	var neutral = 0
	for dk in decks:
		var wish = _nerf_wish(dk[0], dk[1], path, share, avg_share)
		if absf(wish) < NEUTRAL_BAND:
			neutral += 1   # tanto faz pra ele: não vota
		elif (wish > 0.0) == want_nerf:
			yes += 1
		else:
			no += 1
	var mine = int(pauta.get("voto", 0))
	if mine > 0:
		yes += PLAYER_WEIGHT
	elif mine < 0:
		no += PLAYER_WEIGHT
	else:
		neutral += 1
	return [yes, no, neutral]


# ---------------------------------------------------------------- pautas
static func pautas() -> Array:
	return _d()["pautas"]


static func history() -> Array:
	return _d()["historico"]


static func can_propose() -> bool:
	return int(_d()["propos"]) != SafraTempo.current_period()


static func seconds_left() -> float:
	var period_len = SafraTempo.PERIOD_DAYS * 86400.0
	return period_len - fmod(Time.get_unix_time_from_system(), period_len)


static func propose(card: CardData, kind: String) -> String:
	if card == null:
		return "Escolha uma carta."
	if !can_propose():
		return "Você já abriu uma pauta nestes 3 dias."
	for p in pautas():
		if str(p["path"]) == card.resource_path:
			return "Essa carta já está em votação."
	if _at_limit(card, kind):
		return "Essa carta já chegou no limite de %d%%." % int(MAX_TOTAL * 100)
	pautas().append({"path": card.resource_path, "tipo": kind, "autor": PlayerProfile.player_name, "voto": 1})
	_d()["propos"] = SafraTempo.current_period()
	Progresso.save()
	Progresso.changed.emit()
	return ""


static func vote(index: int, value: int):
	var list = pautas()
	if index < 0 or index >= list.size():
		return
	list[index]["voto"] = clampi(value, -1, 1)
	Progresso.save()
	Progresso.changed.emit()


static func _at_limit(card: CardData, kind: String) -> bool:
	var adj: Dictionary = _d()["ajustes"].get(card.resource_path, {})
	var hp = float(adj.get("hp", 1.0))
	return (kind == "buff" and hp >= 1.0 + MAX_TOTAL - 0.001) or (kind == "nerf" and hp <= 1.0 - MAX_TOTAL + 0.001)


## pauta dos bots: sai dos números da temporada
static func _bot_pauta(period: int) -> Dictionary:
	var want_nerf = period % 2 == 0
	var best: CardData = null
	var best_value = -999.0
	var share_avg = float(Progresso.DECK_SIZE) / maxf(1.0, float(CardDatabase.all_cards.size()))
	for c in CardDatabase.all_cards:
		if c == null or CustomContent.is_spawn_only(c):
			continue
		var kind = "nerf" if want_nerf else "buff"
		if _at_limit(c, kind):
			continue
		var value = (card_win_rate(c.resource_path) - 0.5) * 4.0 + (usage_share(c.resource_path) - share_avg) * 3.0
		if !want_nerf:
			value = -value
		value += float(abs(hash("%d%s" % [period, c.resource_path])) % 100) / 1000.0
		if value > best_value:
			best_value = value
			best = c
	if best == null:
		return {}
	# autor: num nerf, alguém que NÃO usa a carta; num buff, alguém que usa
	var author = ""
	for dk in _decks():
		if dk[1].has(best.resource_path) != want_nerf:
			author = dk[0]
			if abs(hash(dk[0] + str(period))) % 3 == 0:
				break
	if author == "" and !BotSimulator.roster_names.is_empty():
		author = str(BotSimulator.roster_names[period % BotSimulator.roster_names.size()])
	return {"path": best.resource_path, "tipo": "nerf" if want_nerf else "buff", "autor": author, "voto": 0}


static func _close(pauta: Dictionary, period: int):
	var card = Catalogo.find_card(str(pauta["path"]))
	if card == null:
		return
	var v = votes(pauta)
	var passed = v[0] > v[1]
	if passed:
		var st = step_for(card)
		var dir = 1.0 if str(pauta["tipo"]) == "buff" else -1.0
		var adj: Dictionary = _d()["ajustes"].get(card.resource_path, {"hp": 1.0, "dmg": 1.0})
		adj["hp"] = clampf(float(adj.get("hp", 1.0)) + dir * st[0], 1.0 - MAX_TOTAL, 1.0 + MAX_TOTAL)
		adj["dmg"] = clampf(float(adj.get("dmg", 1.0)) + dir * st[1], 1.0 - MAX_TOTAL, 1.0 + MAX_TOTAL)
		_d()["ajustes"][card.resource_path] = adj
	var hist: Array = _d()["historico"]
	hist.push_front({"periodo": period, "carta": card.card_name, "tipo": str(pauta["tipo"]), "autor": str(pauta["autor"]), "sim": v[0], "nao": v[1], "neutros": v[2], "passou": passed, "efeito": effect_text(card, str(pauta["tipo"]))})
	while hist.size() > HISTORY_MAX:
		hist.pop_back()
	Gazeta.add_event("ASSEMBLEIA", "#7a5ab0", "%s em %s foi %s" % ["BUFF" if str(pauta["tipo"]) == "buff" else "NERF", card.card_name, "APROVADO" if passed else "recusado"], "Placar: %d a favor, %d contra, %d neutros. Pedido de %s.%s" % [v[0], v[1], v[2], str(pauta["autor"]), " Mudança: " + effect_text(card, str(pauta["tipo"])) + "." if passed else ""])
	Progresso._push({"tipo": "assembleia", "carta": card.resource_path, "texto": "%s em %s: %s (%d a %d)" % ["BUFF" if str(pauta["tipo"]) == "buff" else "NERF", card.card_name, "APROVADO" if passed else "recusado", v[0], v[1]] + ("  ·  %d neutros" % v[2] if v[2] > 0 else "")})


## chama ao abrir o menu e ao carregar o perfil: fecha as pautas vencidas,
## abre a dos bots do período e aplica os ajustes nas cartas
static func sync():
	var a = _d()
	var now = SafraTempo.current_period()
	if int(a["periodo"]) != now:
		if int(a["periodo"]) >= 0:
			for p in a["pautas"]:
				_close(p, int(a["periodo"]))
		a["periodo"] = now
		a["pautas"] = []
		var bp = _bot_pauta(now)
		if !bp.is_empty():
			a["pautas"].append(bp)
		Progresso.save()
	apply_all()


# ---------------------------------------------------------------- aplicar nos números das cartas
static func _stats_of(card: CardData) -> UnitData:
	var st = Catalogo.unit_stats(card)
	return st if st != null else DeckBuilder.get_unit_stats(card)


static func apply_all():
	var adjusts: Dictionary = _d()["ajustes"]
	# primeiro devolve tudo que já foi mexido ao original (troca de perfil)
	for path in _orig:
		var c0 = Catalogo.find_card(str(path))
		if c0 != null:
			_set_numbers(c0, _orig[path], 1.0, 1.0)
	for path in adjusts:
		var c = Catalogo.find_card(str(path))
		if c == null:
			continue
		if !_orig.has(path):
			_orig[path] = _read_numbers(c)
		_set_numbers(c, _orig[path], float(adjusts[path].get("hp", 1.0)), float(adjusts[path].get("dmg", 1.0)))


static func _read_numbers(c: CardData) -> Dictionary:
	if c.is_spell():
		var sp = c.spell_data
		return {"damage": sp.damage, "heal": sp.heal_amount, "shield": sp.shield_amount}
	var st = _stats_of(c)
	return {"hp": st.hp, "damage": st.damage} if st != null else {}


static func _set_numbers(c: CardData, base: Dictionary, hp_mult: float, dmg_mult: float):
	if base.is_empty():
		return
	if c.is_spell():
		var sp = c.spell_data
		sp.damage = int(round(float(base["damage"]) * hp_mult))
		sp.heal_amount = int(round(float(base["heal"]) * hp_mult))
		sp.shield_amount = int(round(float(base["shield"]) * hp_mult))
		return
	var st = _stats_of(c)
	if st != null:
		st.hp = int(round(float(base["hp"]) * hp_mult))
		st.damage = int(round(float(base["damage"]) * dmg_mult))
