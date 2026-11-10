extends RefCounted
class_name Registro
## REGISTRO DAS TEMPORADAS -- guarda, a cada temporada que termina, a tabela
## inteira (você e todos os bots: pontos, vitórias, derrotas, troféus), a sua
## colocação e as cartas que você mais usou. Um arquivo por perfil.

const MAX_SEASONS = 30


static func _path() -> String:
	return "user://profiles/registro_%d.json" % PlayerProfile.active_profile_id


static func entries() -> Array:
	if FileAccess.file_exists(_path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if parsed is Array:
			return parsed
	return []


## retrato da temporada ATUAL (mesmo formato do que fica guardado)
static func snapshot() -> Dictionary:
	var me = PlayerProfile.player_name
	var names: Array = BotSimulator.roster_names.duplicate()
	for n in Leaderboard.season_points:
		if !names.has(n):
			names.append(n)
	if !names.has(me):
		names.append(me)
	var rank: Array = []
	var seen: Dictionary = {}
	for n in names:
		if seen.has(n):
			continue
		seen[n] = true
		var rec = Leaderboard.get_record(n)
		rank.append([n, Leaderboard.get_season_points(n), int(rec.get("wins", 0)), int(rec.get("losses", 0)), ArenaManager.get_trophies(n)])
	rank.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else a[4] > b[4])
	var pos = 1
	var mine = [me, 0, 0, 0, 0]
	for i in rank.size():
		if rank[i][0] == me:
			pos = i + 1
			mine = rank[i]
	var cards: Array = []
	for e in Progresso.season_ranking().slice(0, 3):
		if e[1] > 0:
			cards.append([e[0].card_name, e[1]])
	return {
		"temporada": SeasonManager.season_number,
		"fim": Time.get_date_string_from_system(),
		"ranking": rank,
		"jogador": {"pos": pos, "pontos": mine[1], "v": mine[2], "d": mine[3], "trofeus": mine[4],
			"arena": ArenaManager.get_player_arena(), "nivel": Progresso.player_level(), "tacas": Progresso.tournament_cups(), "cartas": cards},
	}


## chamado pelo SeasonManager logo ANTES de zerar a temporada
static func close_season():
	if PlayerProfile.active_profile_id < 0:
		return
	var list = entries()
	list.append(snapshot())
	while list.size() > MAX_SEASONS:
		list.pop_front()
	var f = FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(list))


## [[nome, títulos]...] -- quem mais ganhou temporada
static func hall_of_fame() -> Array:
	var titles: Dictionary = {}
	for e in entries():
		var rank: Array = e.get("ranking", [])
		if !rank.is_empty():
			titles[str(rank[0][0])] = int(titles.get(str(rank[0][0]), 0)) + 1
	var out: Array = []
	for n in titles:
		out.append([n, titles[n]])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


## [[temporada, posição, pontos, vitórias, derrotas]...] de um participante
static func history_of(who: String) -> Array:
	var out: Array = []
	for e in entries():
		var rank: Array = e.get("ranking", [])
		for i in rank.size():
			if str(rank[i][0]) == who:
				out.append([int(e["temporada"]), i + 1, int(rank[i][1]), int(rank[i][2]), int(rank[i][3])])
	out.reverse()
	return out
