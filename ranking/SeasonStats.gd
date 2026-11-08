extends Node

const SAVE_DIR = "user://profiles/"

# de quanto em quanto tempo tira uma "foto" da taxa de vitória de cada carta,
# pra comparar com a atual e saber se ela tá subindo ou descendo. Ajusta aqui
# pra mudar a frequência de atualização das categorias "em alta"/"em baixa"
const SNAPSHOT_INTERVAL_HOURS = 24.0

var stats: Dictionary = {}       # caminho da carta -> {times_played, wins, losses}
var pair_stats: Dictionary = {}  # "pathA|pathB" (ordenado) -> {wins, losses}
var last_snapshot: Dictionary = {}   # caminho -> win_rate no momento do último snapshot
var last_snapshot_time: float = 0.0


func _get_save_path() -> String:
	return SAVE_DIR + "season_stats_%d.save" % PlayerProfile.active_profile_id


# chama isso depois de escolher/criar/trocar de perfil -- carrega (ou zera)
# as estatísticas de carta DESSE perfil especificamente
func load_for_active_profile():
	stats = {}
	pair_stats = {}
	last_snapshot = {}
	last_snapshot_time = 0.0

	var path = _get_save_path()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data != null:
		stats = data.get("stats", {})
		pair_stats = data.get("pair_stats", {})
		last_snapshot = data.get("last_snapshot", {})
		last_snapshot_time = data.get("last_snapshot_time", 0.0)


func _save():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"stats": stats,
		"pair_stats": pair_stats,
		"last_snapshot": last_snapshot,
		"last_snapshot_time": last_snapshot_time,
	}))


func _ensure_entry(path: String):
	if !stats.has(path):
		stats[path] = {"times_played": 0, "wins": 0, "losses": 0}


func _pair_key(path_a: String, path_b: String) -> String:
	# ordena os dois caminhos antes de juntar, pra "A|B" e "B|A" caírem na
	# mesma chave, não importa a ordem que as cartas apareçam no deck
	var pair = [path_a, path_b]
	pair.sort()
	return pair[0] + "|" + pair[1]


func _ensure_pair_entry(key: String):
	if !pair_stats.has(key):
		pair_stats[key] = {"wins": 0, "losses": 0}


# chama toda vez que QUALQUER carta é jogada, seja pelo jogador ou por um bot
func record_play(card: CardData):
	if card == null:
		return
	_ensure_entry(card.resource_path)
	stats[card.resource_path]["times_played"] += 1
	_save()


# chama no fim de cada partida, com o deck de quem venceu e de quem perdeu --
# cada carta do deck vencedor ganha +1 vitória, cada carta do perdedor +1
# derrota, e cada PAR de cartas do mesmo deck também registra a dupla
func record_match_result(winner_deck: Array, loser_deck: Array):
	_maybe_take_snapshot()

	for card in winner_deck:
		if card == null:
			continue
		_ensure_entry(card.resource_path)
		stats[card.resource_path]["wins"] += 1

	for card in loser_deck:
		if card == null:
			continue
		_ensure_entry(card.resource_path)
		stats[card.resource_path]["losses"] += 1

	_record_pairs(winner_deck, true)
	_record_pairs(loser_deck, false)

	_save()


func _record_pairs(deck: Array, won: bool):
	for i in deck.size():
		if deck[i] == null:
			continue
		for j in range(i + 1, deck.size()):
			if deck[j] == null:
				continue
			var key = _pair_key(deck[i].resource_path, deck[j].resource_path)
			_ensure_pair_entry(key)
			if won:
				pair_stats[key]["wins"] += 1
			else:
				pair_stats[key]["losses"] += 1


# se já passou o intervalo configurado (ou nunca tirou uma foto ainda), tira
# uma agora -- é essa comparação (antes/depois) que dá a tendência de subida
# ou queda de cada carta
func _maybe_take_snapshot():
	var now = Time.get_unix_time_from_system()
	var elapsed_hours = (now - last_snapshot_time) / 3600.0
	if last_snapshot_time <= 0.0 or elapsed_hours >= SNAPSHOT_INTERVAL_HOURS:
		last_snapshot = {}
		for path in stats:
			var entry = stats[path]
			var total = entry["wins"] + entry["losses"]
			last_snapshot[path] = float(entry["wins"]) / total if total > 0 else 0.0
		last_snapshot_time = now


# diferença entre a taxa de vitória atual e a do último snapshot -- positivo
# = subindo, negativo = descendo, 0 = sem mudança (ou sem snapshot ainda)
func get_trend(path: String) -> float:
	var entry = stats.get(path, {"wins": 0, "losses": 0})
	var total = entry["wins"] + entry["losses"]
	var current_rate = float(entry["wins"]) / total if total > 0 else 0.0
	var previous_rate = last_snapshot.get(path, current_rate)
	return current_rate - previous_rate


# lista com uma entrada por carta já registrada: {card, times_played, wins,
# losses, win_rate} -- pronta pra ordenar do jeito que a tela precisar
func get_all_card_stats() -> Array:
	var result = []
	for path in stats:
		if !ResourceLoader.exists(path):
			continue
		var card = load(path)
		var entry = stats[path]
		var total = entry["wins"] + entry["losses"]
		var win_rate = float(entry["wins"]) / total if total > 0 else 0.0
		result.append({
			"card": card,
			"times_played": entry["times_played"],
			"wins": entry["wins"],
			"losses": entry["losses"],
			"win_rate": win_rate,
			"trend": get_trend(path),
		})
	return result


# lista de cartas que existem no jogo mas nunca foram jogadas nessa temporada
func get_forgotten_cards() -> Array:
	var result: Array[CardData] = []
	for card in CardDatabase.all_cards:
		if card == null:
			continue
		var entry = stats.get(card.resource_path, null)
		if entry == null or entry["times_played"] == 0:
			result.append(card)
	return result


# lista de duplas com dados suficientes: {card_a, card_b, wins, losses, win_rate}
func get_all_pair_stats() -> Array:
	var result = []
	for key in pair_stats:
		var paths = key.split("|")
		if paths.size() != 2:
			continue
		if !ResourceLoader.exists(paths[0]) or !ResourceLoader.exists(paths[1]):
			continue
		var entry = pair_stats[key]
		var total = entry["wins"] + entry["losses"]
		var win_rate = float(entry["wins"]) / total if total > 0 else 0.0
		result.append({
			"card_a": load(paths[0]),
			"card_b": load(paths[1]),
			"wins": entry["wins"],
			"losses": entry["losses"],
			"win_rate": win_rate,
			"times_played": total,
		})
	return result


# zera tudo -- chamado quando uma temporada termina e uma nova começa
func reset():
	stats = {}
	pair_stats = {}
	last_snapshot = {}
	last_snapshot_time = 0.0
	_save()
