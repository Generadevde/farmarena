extends RefCounted
class_name Gazeta
## A GAZETA DA ROÇA -- o jornal do jogo. Junta dois tipos de notícia:
##   · manchetes calculadas na hora (sequências, carta dominando, líder, turma
##     em alta, clã na frente, novidades da safra);
##   · acontecimentos guardados (recorde de eliminações, torneio vencido,
##     resultado da Assembleia), em Progresso.d["gazeta"].

const EVENTS_MAX = 14
const STREAK_NEWS = 3
const STREAK_BIG = 8


static func _d() -> Dictionary:
	if !Progresso.d.has("gazeta") or !(Progresso.d["gazeta"] is Dictionary):
		Progresso.d["gazeta"] = {}
	var g: Dictionary = Progresso.d["gazeta"]
	for k in [["eventos", []], ["recorde", {}], ["lidas", 0], ["total", 0]]:
		if !g.has(k[0]):
			g[k[0]] = k[1]
	return g


## guarda um acontecimento (aparece no jornal até ser empurrado pelos novos)
static func add_event(tag: String, color: String, title: String, text: String):
	var g = _d()
	g["eventos"].push_front({"tag": tag, "cor": color, "titulo": title, "texto": text, "dia": Time.get_date_string_from_system()})
	while g["eventos"].size() > EVENTS_MAX:
		g["eventos"].pop_back()
	g["total"] = int(g["total"]) + 1


static func unread() -> int:
	var g = _d()
	return maxi(0, int(g["total"]) - int(g["lidas"]))


static func mark_read():
	var g = _d()
	if int(g["lidas"]) != int(g["total"]):
		g["lidas"] = int(g["total"])
		Progresso.save()


## fim de partida de verdade: confere o recorde de eliminações
static func report_match(bot_name: String, player_kills: int, bot_kills: int, player_won: bool):
	var g = _d()
	var rec: Dictionary = g["recorde"]
	var best = int(rec.get("abates", 0))
	var who = ""
	var against = ""
	var kills = 0
	if player_kills >= bot_kills and player_kills > best:
		who = PlayerProfile.player_name
		against = bot_name
		kills = player_kills
	elif bot_kills > best:
		who = bot_name
		against = PlayerProfile.player_name
		kills = bot_kills
	if kills > 0 and kills >= 8:
		g["recorde"] = {"quem": who, "abates": kills, "contra": against}
		add_event("RECORDE", "#d84838", "Novo recorde de eliminações: %d!" % kills, "%s derrubou %d tropas numa partida só contra %s.%s" % [who, kills, against, " O recorde antigo era %d." % best if best > 0 else ""])
	if player_won and player_kills == 0 and bot_kills >= 6:
		add_event("CURIOSO", "#8a6ad8", "Vitória sem derrubar ninguém", "%s venceu %s sem eliminar uma tropa sequer. Foi direto na torre." % [PlayerProfile.player_name, bot_name])


static func _turma_of_deck(paths: Array) -> String:
	var count: Dictionary = {}
	for path in paths:
		var c = Catalogo.find_card(str(path))
		if c != null and c.get_nation_name() != "":
			count[c.get_nation_name()] = int(count.get(c.get_nation_name(), 0)) + 1
	var best = ""
	for k in count:
		if best == "" or count[k] > count[best]:
			best = k
	return best


## lista de notícias pra tela: [{tag, cor, titulo, texto, grande}]
static func headlines() -> Array:
	var out: Array = []
	# ---- sequências
	var best_bot = ""
	var best_streak = 0
	for n in BotSimulator.roster_names:
		var st = Leaderboard.get_win_streak(str(n))
		if st > best_streak:
			best_streak = st
			best_bot = str(n)
	if best_streak >= STREAK_NEWS:
		var big = best_streak >= STREAK_BIG
		out.append({"tag": "SEQUÊNCIA", "cor": "#e07a28", "grande": big,
			"titulo": "%s venceu %d partidas seguidas%s" % [best_bot, best_streak, "!" if big else ""],
			"texto": ("Ninguém segura. " if big else "") + "Está com 🏆 %d troféus%s." % [ArenaManager.get_trophies(best_bot), " pelo clã " + Cla.clan_of(best_bot) if Cla.clan_of(best_bot) != "" else ""]})
	var mine = Leaderboard.get_win_streak(PlayerProfile.player_name)
	if mine >= STREAK_NEWS:
		out.append({"tag": "VOCÊ", "cor": "#3c8848", "titulo": "%s está com %d vitórias seguidas" % [PlayerProfile.player_name, mine], "texto": "A vizinhança já está comentando."})
	# ---- carta dominando
	var stats = SeasonStats.get_all_card_stats().filter(func(e): return e["card"] != null and e["wins"] + e["losses"] >= 5)
	if !stats.is_empty():
		stats.sort_custom(func(a, b): return a["win_rate"] > b["win_rate"])
		var top = stats[0]
		var share = int(round(Assembleia.usage_share(top["card"].resource_path) * 100))
		if top["win_rate"] >= 0.58:
			out.append({"tag": "META", "cor": "#b03a8a", "grande": top["win_rate"] >= 0.68,
				"titulo": "%s está dominando o cenário" % top["card"].card_name,
				"texto": "Vence %d%% das partidas em que aparece e está em %d%% dos baralhos. Já tem gente pedindo nerf na Assembleia." % [int(round(top["win_rate"] * 100)), share], "carta": top["card"].resource_path})
		var worst = stats[-1]
		if worst["win_rate"] <= 0.42 and worst != top:
			out.append({"tag": "META", "cor": "#6a7480", "titulo": "%s anda em baixa" % worst["card"].card_name,
				"texto": "Só %d%% de vitórias nesta temporada. Será que merece um buff?" % int(round(worst["win_rate"] * 100)), "carta": worst["card"].resource_path})
	# ---- turma (nação) em alta e campeã
	var decks = Assembleia._decks()
	var turma_count: Dictionary = {}
	for dk in decks:
		var t = _turma_of_deck(dk[1])
		if t != "":
			turma_count[t] = int(turma_count.get(t, 0)) + 1
	var seasons = Registro.entries()
	if !seasons.is_empty():
		var last: Dictionary = seasons[-1]
		var rank: Array = last.get("ranking", [])
		if !rank.is_empty():
			var champ = str(rank[0][0])
			var champ_turma = ""
			for dk in decks:
				if dk[0] == champ:
					champ_turma = _turma_of_deck(dk[1])
			if champ == PlayerProfile.player_name:
				champ_turma = _turma_of_deck(Progresso.deck_paths(Progresso.active_deck()))
			out.append({"tag": "CAMPEONATO", "cor": "#c8a020", "grande": true,
				"titulo": ("A turma %s conquistou a temporada %d" % [champ_turma, int(last.get("temporada", 0))]) if champ_turma != "" else ("%s conquistou a temporada %d" % [champ, int(last.get("temporada", 0))]),
				"texto": "%s levantou a taça com %d pontos%s." % [champ, int(rank[0][1]), ", jogando com o baralho quase todo de " + champ_turma if champ_turma != "" else ""]})
	if !turma_count.is_empty():
		var lead = ""
		for k in turma_count:
			if lead == "" or turma_count[k] > turma_count[lead]:
				lead = k
		out.append({"tag": "TURMAS", "cor": "#3c6cb8", "titulo": "%s é a turma mais usada" % lead,
			"texto": "%d de %d jogadores montaram o baralho em volta dela." % [int(turma_count[lead]), decks.size()]})
	# ---- líder e clãs
	var names: Array = BotSimulator.roster_names.duplicate()
	names.append(PlayerProfile.player_name)
	names.sort_custom(func(a, b): return ArenaManager.get_trophies(a) > ArenaManager.get_trophies(b))
	if !names.is_empty():
		out.append({"tag": "RANKING", "cor": "#a05a28", "titulo": "%s lidera com 🏆 %d" % [str(names[0]), ArenaManager.get_trophies(str(names[0]))],
			"texto": "Você está em %dº de %d." % [names.find(PlayerProfile.player_name) + 1, names.size()]})
	var clans = Cla.ranking()
	if !clans.is_empty() and int(clans[0][1]) > 0:
		out.append({"tag": "CLÃS", "cor": "#487a78", "titulo": "%s na frente entre os clãs" % str(clans[0][0]), "texto": "%d pontos de colheita nestes 3 dias." % int(clans[0][1])})
	# ---- recorde
	var rec: Dictionary = _d()["recorde"]
	if !rec.is_empty():
		out.append({"tag": "RECORDE", "cor": "#d84838", "titulo": "Recorde de eliminações: %d" % int(rec.get("abates", 0)), "texto": "É de %s, contra %s." % [str(rec.get("quem", "")), str(rec.get("contra", ""))]})
	# ---- safra
	var news_cards = Safra.current_cards()
	if !news_cards.is_empty():
		out.append({"tag": "SAFRA", "cor": "#58a040", "titulo": "Chegou carta nova: %s" % " e ".join(news_cards.map(func(c): return c.card_name)),
			"texto": "Colhidas nesta safra. Já estão nos baús de quem alcançou a arena delas.", "carta": news_cards[0].resource_path})
	# ---- assembleia
	for pa in Assembleia.pautas():
		var pc = Catalogo.find_card(str(pa["path"]))
		if pc != null:
			var vt = Assembleia.votes(pa)
			out.append({"tag": "ASSEMBLEIA", "cor": "#7a5ab0", "titulo": "%s pede %s em %s" % [str(pa["autor"]), "BUFF" if str(pa["tipo"]) == "buff" else "NERF", pc.card_name],
				"texto": "Placar agora: %d a favor, %d contra, %d neutros." % [vt[0], vt[1], vt[2]], "carta": pc.resource_path})
	return out


static func events() -> Array:
	return _d()["eventos"]
