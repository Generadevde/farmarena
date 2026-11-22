extends RefCounted
class_name Historico
## Histórico de partidas (igual o do Clash): as últimas batalhas com resultado, placar,
## troféus e os dois baralhos. Fica guardado junto do progresso.

const MAX = 40


static func list() -> Array:
	if !Progresso.d.has("partidas") or !(Progresso.d["partidas"] is Array):
		Progresso.d["partidas"] = []
	return Progresso.d["partidas"]


static func _deck_entry(cards: Array, level_of: Callable) -> Array:
	var out: Array = []
	for c in cards:
		if c != null and c.resource_path != "":
			out.append([c.resource_path, int(level_of.call(c))])
	return out


## result: 1 vitória, 0 derrota, -1 empate
static func record(result: int, trophies_delta: int, score_mine: int, score_bot: int, seconds: float, bot: AIProfile, my_deck: Array, bot_snapshot: Array = []):
	var mode = "Normal"
	if MatchSetup.mode == MatchSetup.MODE_2V2:
		mode = "2 contra 2"
	elif MatchSetup.tournament:
		mode = "Torneio"
	elif MatchSetup.friendly:
		mode = "Teste (nível 1)" if MatchSetup.teste else "Amistoso"
	elif MatchSetup.daily:
		mode = "Desafio do Dia"
	var e := {"t": int(Time.get_unix_time_from_system()), "res": result, "tr": trophies_delta,
		"tr_meu": int(ArenaManager.get_trophies(PlayerProfile.player_name)),
		"placar": [score_mine, score_bot], "dur": int(seconds), "modo": mode,
		"regra": str(MatchSetup.RULE_NAMES[MatchSetup.rule]) if MatchSetup.rule > 0 else "",
		"meu": _deck_entry(my_deck, func(c): return MatchSetup.fixed_level() if MatchSetup.fixed_level() > 0 else PlayerProfile.get_card_level(c)),
		"bot": "", "tr_bot": 0, "dele": []}
	if bot != null:
		e["bot"] = bot.profile_name
		e["tr_bot"] = int(ArenaManager.get_trophies(bot.profile_name))
		# o baralho que ele USOU (foto do começo da partida): depois de perder o bot pode trocar carta,
		# e antes aparecia o baralho novo aqui
		e["dele"] = bot_snapshot if !bot_snapshot.is_empty() else _deck_entry(bot.deck, func(c): return bot.get_card_level(c))
	var l = list()
	l.push_front(e)
	while l.size() > MAX:
		l.pop_back()
	Progresso.save()


static func ago(t: int) -> String:
	var s = maxi(int(Time.get_unix_time_from_system()) - t, 0)
	if s < 90:
		return "agora há pouco"
	if s < 3600:
		return "há %d min" % int(s / 60)
	if s < 86400:
		return "há %d h" % int(s / 3600)
	return "há %d dia(s)" % int(s / 86400)
