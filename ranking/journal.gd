extends Node

# arrasta os .tres de JournalEntry aqui, do mais novo pro mais antigo --
# autoload não abre no editor de cena normal: acessa via Project Settings >
# Autoload > clica no ícone ao lado do Journal pra abrir o Inspector dele
@export var entries: Array[JournalEntry] = []

# arrasta os .tres de BotQuote aqui -- um por bot que você quer que "fale"
# no jornal, cada um com uma lista de frases possíveis
@export var bot_quotes: Array[BotQuote] = []

# últimas falas de bot dirigidas A VOCÊ, depois de uma partida real (não
# persiste entre sessões, igual a fala ambiente do topo do jornal também
# não persiste -- é conteúdo de "clima", não progresso de jogo)
var player_directed_quotes: Array[String] = []
const MAX_PLAYER_DIRECTED_QUOTES = 5


# chama isso no fim de uma partida REAL (jogador vs bot) -- gera uma fala
# do bot dirigida a você, vitoriosa ou rancorosa, de acordo com quem venceu
func record_player_battle_quote(bot_name: String, player_won: bool):
	var archetype = BotLearning.peek_archetype(bot_name)
	var pool = ArchetypeQuotes.POST_BATTLE_POOLS.get(archetype, null)
	if pool == null:
		return

	var category = "loss" if player_won else "win"  # se você venceu, é o BOT que perdeu -- fala de "loss" dele
	var options = pool.get(category, [])
	if options.is_empty():
		return

	var phrase = options[randi() % options.size()]
	player_directed_quotes.push_front("%s: \"%s\"" % [bot_name, phrase])
	if player_directed_quotes.size() > MAX_PLAYER_DIRECTED_QUOTES:
		player_directed_quotes.resize(MAX_PLAYER_DIRECTED_QUOTES)

const SEEN_COUNT_PATH = "user://journal_seen.cfg"
const BOT_QUOTE_CHANCE = 0.4  # chance de uma fala de bot aparecer na notícia -- não sempre, pra não virar flood


# true se tiver notícia nova que o jogador ainda não abriu o jornal pra ver
# -- útil pra mostrar uma bolinha vermelha no botão do menu, se você quiser
func has_unread() -> bool:
	return entries.size() > _get_seen_count()


# chama isso quando o jogador abre a tela do jornal, marcando tudo como visto
func mark_all_as_read():
	var file = FileAccess.open(SEEN_COUNT_PATH, FileAccess.WRITE)
	file.store_string(str(entries.size()))


# sorteia uma frase -- prioriza um .tres escrito à mão pro bot específico
# (se você tiver feito algum), senão sorteia um bot qualquer do elenco e
# fala com a voz do ARQUÉTIPO dele (cobre todos os bots, sem precisar de
# um .tres por nome)
func get_random_bot_quote() -> String:
	var named_candidates = bot_quotes.filter(func(bq):
		return !bq.phrases.is_empty() or (!bq.pre_phrase_1.is_empty() and !bq.pre_phrase_2.is_empty())
	)

	# metade das vezes tenta o .tres manual primeiro (se existir algum),
	# senão sempre cai pro sistema de arquétipo
	if !named_candidates.is_empty() and randf() < 0.5:
		var chosen_bot: BotQuote = named_candidates[randi() % named_candidates.size()]
		var has_fixed = !chosen_bot.phrases.is_empty()
		var has_template = !chosen_bot.pre_phrase_1.is_empty() and !chosen_bot.pre_phrase_2.is_empty()

		var phrase: String
		if has_template and (!has_fixed or randf() < 0.5):
			phrase = _build_semi_auto_phrase(chosen_bot.pre_phrase_1, chosen_bot.pre_phrase_2, 0.5 if chosen_bot.mention_card else 0.0)
		else:
			phrase = chosen_bot.phrases[randi() % chosen_bot.phrases.size()]

		return "%s: \"%s\"" % [chosen_bot.bot_name, phrase]

	# sistema de arquétipo -- cobre qualquer bot do elenco
	if BotSimulator.roster_names.is_empty():
		return ""

	var bot_name = BotSimulator.roster_names[randi() % BotSimulator.roster_names.size()]
	var archetype = BotLearning.peek_archetype(bot_name)
	var pool = ArchetypeQuotes.POOLS.get(archetype, null)
	if pool == null:
		return ""

	var archetype_phrase = _build_semi_auto_phrase(pool["pre_phrase_1"], pool["pre_phrase_2"], pool.get("mention_chance", 0.3))
	return "%s: \"%s\"" % [bot_name, archetype_phrase]


# junta um pedaço de cada lista (início + meio), e opcionalmente emenda uma
# carta no final (nome + taxa de vitória, se já tiver dado suficiente) --
# mention_chance decide a PROBABILIDADE de emendar a carta, não sempre
# (assim nem toda fala menciona carta, fica menos repetitivo)
func _build_semi_auto_phrase(pre_phrase_1: Array, pre_phrase_2: Array, mention_chance: float) -> String:
	var p1 = pre_phrase_1[randi() % pre_phrase_1.size()]
	var p2 = pre_phrase_2[randi() % pre_phrase_2.size()]
	var phrase = p1 + " " + p2

	if randf() < mention_chance:
		var mention = _pick_random_card_mention()
		if mention != "":
			phrase += " " + mention

	return phrase


func _pick_random_card_mention() -> String:
	if CardDatabase.all_cards.is_empty():
		return ""

	var card = CardDatabase.all_cards[randi() % CardDatabase.all_cards.size()]

	for entry in SeasonStats.get_all_card_stats():
		if entry["card"].resource_path == card.resource_path and entry["wins"] + entry["losses"] >= 3:
			return "%s (%d%% de vitórias)" % [card.card_name, round(entry["win_rate"] * 100)]

	return card.card_name


func _get_seen_count() -> int:
	if not FileAccess.file_exists(SEEN_COUNT_PATH):
		return 0
	var file = FileAccess.open(SEEN_COUNT_PATH, FileAccess.READ)
	return file.get_as_text().to_int()


# quantas vitórias seguidas já contam como "sequência" digna de virar notícia
const STREAK_NEWS_THRESHOLD = 3
# quantas partidas uma carta precisa ter pra entrar na conta de "carta do meta"
const MIN_GAMES_FOR_META_CARD = 5


# gera frases dinâmicas a partir do estado atual do jogo (ranking, sequências,
# estatística de carta) -- não fica salvo em lugar nenhum, é recalculado toda
# vez que o jornal é aberto, então está sempre atual
func generate_auto_news() -> Array[String]:
	var news: Array[String] = []

	var poll_result = PollManager.get_last_poll_result_text()
	if poll_result != "":
		news.append(poll_result)

	for bot_name in BotSimulator.roster_names:
		var streak = Leaderboard.get_win_streak(bot_name)
		if streak >= STREAK_NEWS_THRESHOLD:
			news.append("%s venceu %d vezes seguidas!" % [bot_name, streak])

	var player_streak = Leaderboard.get_win_streak(PlayerProfile.player_name)
	if player_streak >= STREAK_NEWS_THRESHOLD:
		news.append("Você está numa sequência de %d vitórias!" % player_streak)

	var ranking = Leaderboard.get_ranking()
	if !ranking.is_empty():
		news.append("%s lidera o ranking com %d pontos." % [ranking[0]["name"], ranking[0]["score"]])

	var card_stats = SeasonStats.get_all_card_stats()
	var qualified = card_stats.filter(func(s): return s["wins"] + s["losses"] >= MIN_GAMES_FOR_META_CARD)

	if !qualified.is_empty():
		var by_win_rate = qualified.duplicate()
		by_win_rate.sort_custom(func(a, b): return a["win_rate"] > b["win_rate"])
		var best = by_win_rate[0]
		news.append("%s é a carta do meta atual: %d%% de vitórias." % [best["card"].card_name, round(best["win_rate"] * 100)])

	if !card_stats.is_empty():
		var by_played = card_stats.duplicate()
		by_played.sort_custom(func(a, b): return a["times_played"] > b["times_played"])
		var most_played = by_played[0]
		news.append("%s é a carta mais jogada da temporada, com %d partidas." % [most_played["card"].card_name, most_played["times_played"]])

	return news
