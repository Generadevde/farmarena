extends Node

signal profile_changed

var player_name: String = "Jogador"
var arena_name: String = "Arena 1"
var arena_index: int = 1
var coins: int = 0
var card_levels: Dictionary = {}  # caminho do .tres da carta -> nível (1 = sem upgrade)
var card_usage: Dictionary = {}  # caminho do .tres da carta -> quantas vezes já foi usada em batalha
var total_battles_played: int = 0
var total_battles_won: int = 0
var base_levels: Dictionary = {}  # caminho do .tres da base -> nível (1 = sem upgrade) -- mesmo recurso de upgrade que a carta usa
var base_usage: Dictionary = {}  # caminho do .tres da base -> quantas vezes já foi usada em batalha
var unlocked_cards: Array = []  # caminhos dos .tres das cartas já desbloqueadas
var unlocked_bases: Array = []  # caminhos dos .tres das bases já desbloqueadas
var deck_card_paths: Array = []  # caminhos das 7 cartas escolhidas pro deck -- [] = ainda não escolheu, usa o padrão de fábrica
var equipped_base_path: String = ""  # caminho do .tres da base equipada, "" = a base padrão de nível 1
var recent_opponents: Array = []  # últimos 2 bots enfrentados -- não pode repetir até jogar mais 2 partidas
var daily_missions: Array = []  # cada item: {id, description, type, target, progress, reward_type, reward_amount, reward_nation, claimed}
var daily_missions_date: String = ""  # data (AAAA-MM-DD) de quando as missões atuais foram geradas -- muda o dia, regenera tudo
var nation_xp: Dictionary = {}  # nome da nação -> XP acumulado nela
var free_xp: int = 0  # XP livre -- serve pra desbloquear carta de QUALQUER nação, e é o único jeito de desbloquear carta coringa

# --- upgrade de cartas: precisa de USO EM BATALHA e MOEDA, os dois juntos ---
const UPGRADE_BASE_USES = 10      # usos pro 1º upgrade (nível 1 -> 2)
const UPGRADE_USES_GROWTH = 5     # quanto o uso necessário sobe a cada nível seguinte
const UPGRADE_BASE_COST = 100     # moedas pro 1º upgrade
const UPGRADE_COST_GROWTH = 50    # quanto a moeda necessária sobe a cada nível seguinte

# --- upgrade de BASE: números próprios, diferentes da carta ---
const BASE_UPGRADE_MATCHES = 40        # partidas jogadas pro 1º upgrade (nível 1 -> 2)
const BASE_UPGRADE_MATCHES_GROWTH = 20 # quanto isso sobe a cada nível seguinte
const BASE_UPGRADE_COST = 300          # moedas pro 1º upgrade
const BASE_UPGRADE_COST_GROWTH = 150   # quanto isso sobe a cada nível seguinte
const BASE_LEVEL_BOOST = 0.15  # cada nível soma sempre 15% de estatística -- igual pra carta e pra base
const CARD_LEVEL_BOOST = 0.15  # mesmo valor, mesmo formato -- fixo em vez da tabela variável de antes

const MAX_CARD_LEVEL = 9  # nível 7 = maestria (ganha habilidade bônus, ver UnitData.mastery_effect)

const PROFILES_DIR = "user://profiles/"
const LAST_PROFILE_PATH = "user://last_profile.cfg"

var active_profile_id: int = -1  # -1 = nenhum perfil carregado ainda


func _ready():
	DirAccess.make_dir_recursive_absolute(PROFILES_DIR)
	# não carrega nenhum perfil sozinho aqui -- a tela inicial (profile_setup)
	# decide isso, já que pode ter mais de um perfil salvo pra escolher


# lista todos os perfis salvos (id + nome), sem carregar nenhum deles como ativo
func list_profiles() -> Array:
	var result = []
	var dir = DirAccess.open(PROFILES_DIR)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("profile_") and file_name.ends_with(".save"):
			var file = FileAccess.open(PROFILES_DIR + file_name, FileAccess.READ)
			var data = JSON.parse_string(file.get_as_text())
			if data != null:
				var id = file_name.trim_prefix("profile_").trim_suffix(".save").to_int()
				result.append({"id": id, "name": data.get("player_name", "Jogador")})
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(func(a, b): return a["id"] < b["id"])
	return result


func _get_next_profile_id() -> int:
	var max_id = 0
	for p in list_profiles():
		max_id = max(max_id, p["id"])
	return max_id + 1


# cria um perfil novo do zero (zera tudo) e já deixa ele como o ativo
func create_new_profile(new_name: String) -> int:
	player_name = new_name
	arena_name = "Arena 1"
	arena_index = 1
	coins = 0
	card_levels = {}
	card_usage = {}
	base_levels = {}
	base_usage = {}
	unlocked_cards = []
	unlocked_bases = []
	deck_card_paths = []
	equipped_base_path = ""

	active_profile_id = _get_next_profile_id()

	# limpa qualquer arquivo órfão desse ID nos OUTROS sistemas (ranking,
	# temporada, estatística, enquete) -- cobre tanto o caso de uma exclusão
	# futura ter deixado algo pra trás quanto qualquer coisa que já tenha
	# ficado órfã de antes dessa proteção existir. Sem isso, um perfil novo
	# podia "herdar" dado velho de um ID reaproveitado (ex: uma temporada
	# que não era nova de verdade, parecendo que ela não resetou)
	for pattern in ["leaderboard_%d.save", "season_%d.save", "season_stats_%d.save", "polls_%d.save"]:
		var other_path = PROFILES_DIR + pattern % active_profile_id
		if FileAccess.file_exists(other_path):
			DirAccess.remove_absolute(other_path)

	save_profile()
	_remember_last_profile()
	return active_profile_id


# carrega um perfil existente pelo id e passa a usá-lo como o ativo
func load_profile_by_id(id: int):
	var path = PROFILES_DIR + "profile_%d.save" % id
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return

	player_name = data.get("player_name", "Jogador")
	arena_name = data.get("arena_name", "Arena 1")
	arena_index = data.get("arena_index", 1)
	coins = data.get("coins", 0)
	card_levels = data.get("card_levels", {})
	card_usage = data.get("card_usage", {})
	total_battles_played = data.get("total_battles_played", 0)
	total_battles_won = data.get("total_battles_won", 0)
	base_levels = data.get("base_levels", {})
	base_usage = data.get("base_usage", {})
	unlocked_cards = data.get("unlocked_cards", [])
	unlocked_bases = data.get("unlocked_bases", [])
	deck_card_paths = data.get("deck_card_paths", [])
	equipped_base_path = data.get("equipped_base_path", "")
	recent_opponents = data.get("recent_opponents", [])
	daily_missions = data.get("daily_missions", [])
	daily_missions_date = data.get("daily_missions_date", "")
	nation_xp = data.get("nation_xp", {})
	free_xp = data.get("free_xp", 0)

	active_profile_id = id
	_remember_last_profile()
	profile_changed.emit()


func _remember_last_profile():
	var file = FileAccess.open(LAST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(str(active_profile_id))


# id do último perfil usado (pra tela inicial oferecer "Continuar como ___"),
# ou -1 se nunca jogou / arquivo não existe
func get_last_active_profile_id() -> int:
	if not FileAccess.file_exists(LAST_PROFILE_PATH):
		return -1
	var file = FileAccess.open(LAST_PROFILE_PATH, FileAccess.READ)
	return file.get_as_text().to_int()


func delete_profile(id: int):
	var path = PROFILES_DIR + "profile_%d.save" % id
	var existed = FileAccess.file_exists(path)
	print("DEBUG delete_profile: id=", id, " caminho=", path, " existia=", existed)
	if existed:
		DirAccess.remove_absolute(path)
		print("DEBUG delete_profile: depois de remover, ainda existe? ", FileAccess.file_exists(path))

	# apaga também os arquivos dos OUTROS sistemas por-perfil (ranking,
	# temporada, estatística de carta, enquete, troféu) -- sem isso, eles
	# ficavam órfãos no disco, e se um perfil FUTURO reaproveitar esse
	# mesmo ID (o que acontece, já que o próximo ID é sempre baseado no
	# maior id que ainda existe), ele "herdava" esse dado velho -- inclusive
	# uma temporada que não era nova de verdade, parecendo que ela "não
	# resetou". Faltava troféu (arenas_%d.save) nessa lista -- adicionado
	for pattern in ["leaderboard_%d.save", "season_%d.save", "season_stats_%d.save", "polls_%d.save", "arenas_%d.save"]:
		var other_path = PROFILES_DIR + pattern % id
		if FileAccess.file_exists(other_path):
			DirAccess.remove_absolute(other_path)

	# apaga TODOS os arquivos de progresso de bot desse perfil -- diferente
	# dos de cima (um arquivo só por padrão), aqui tem UM ARQUIVO POR BOT
	# (profile_<id>_nomedobot.save), então precisa varrer a pasta toda
	# procurando os que começam com o prefixo certo. Essa é a peça que mais
	# fazia perfil novo "herdar" bot evoluído -- ele reaproveitava o ID e
	# achava os arquivos de bot ainda cheios de progresso do perfil antigo
	var bots_dir = DirAccess.open("user://bots/")
	if bots_dir != null:
		var prefix = "profile_%d_" % id
		bots_dir.list_dir_begin()
		var file_name = bots_dir.get_next()
		while file_name != "":
			if file_name.begins_with(prefix) and file_name.ends_with(".save"):
				DirAccess.remove_absolute("user://bots/" + file_name)
			file_name = bots_dir.get_next()
		bots_dir.list_dir_end()

	# se esse era o "último usado" lembrado, esquece essa lembrança também --
	# senão o jogo tentaria continuar num perfil que não existe mais
	if get_last_active_profile_id() == id and FileAccess.file_exists(LAST_PROFILE_PATH):
		DirAccess.remove_absolute(LAST_PROFILE_PATH)

	if active_profile_id == id:
		active_profile_id = -1


func save_profile():
	if active_profile_id < 0:
		return  # nenhum perfil ativo ainda -- nada pra salvar

	var data = {
		"player_name": player_name,
		"arena_name": arena_name,
		"arena_index": arena_index,
		"coins": coins,
		"card_levels": card_levels,
		"card_usage": card_usage,
		"total_battles_played": total_battles_played,
		"total_battles_won": total_battles_won,
		"base_levels": base_levels,
		"base_usage": base_usage,
		"unlocked_cards": unlocked_cards,
		"unlocked_bases": unlocked_bases,
		"deck_card_paths": deck_card_paths,
		"equipped_base_path": equipped_base_path,
		"recent_opponents": recent_opponents,
		"daily_missions": daily_missions,
		"daily_missions_date": daily_missions_date,
		"nation_xp": nation_xp,
		"free_xp": free_xp,
	}
	var file = FileAccess.open(PROFILES_DIR + "profile_%d.save" % active_profile_id, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func get_card_level(card: CardData) -> int:
	return card_levels.get(card.resource_path, 1)


# cartas com custo 0 já vêm liberadas desde o início, sem precisar de
# nenhuma ação -- só as com nation_xp_cost > 0 dependem de desbloqueio manual
func is_card_unlocked(card: CardData) -> bool:
	return Progresso.is_owned(card)  # 2.0: carta liberada = carta que você já achou (baú, Feira, troféus)


# true quando o jogador já tem XP suficiente (nação + livre PODEM SOMAR pra
# cobrir o custo -- não precisa um dos dois sozinho bater o valor inteiro) e
# TODAS as cartas antecessoras dela (se tiver) já estão desbloqueadas. Carta
# coringa (sem nação) só aceita XP livre, nunca XP de nação
func can_unlock_card(card: CardData) -> bool:
	if is_card_unlocked(card):
		return false
	for predecessor in card.predecessor_cards:
		if predecessor != null and !is_card_unlocked(predecessor):
			return false  # precisa desbloquear TODAS as cartas anteriores da cadeia primeiro

	var is_wildcard = card.get_nation_name() == "" or card.get_nation_name() == "Coringa"
	if is_wildcard:
		return free_xp >= card.nation_xp_cost
	return (get_nation_xp(card.get_nation_name()) + free_xp) >= card.nation_xp_cost


func get_unlock_cost(card: CardData) -> int:
	return card.nation_xp_cost


# quanto de cada tipo de XP entraria no desbloqueio dessa carta AGORA, se
# você apertasse -- usa nação primeiro (até o limite que tiver disponível),
# o resto (se precisar) vem do XP livre. Útil pra UI mostrar a combinação
# antes mesmo de desbloquear
func get_unlock_cost_breakdown(card: CardData) -> Dictionary:
	var cost = card.nation_xp_cost
	var is_wildcard = card.get_nation_name() == "" or card.get_nation_name() == "Coringa"
	if is_wildcard:
		return {"nation": 0, "free": cost}

	var nation_available = get_nation_xp(card.get_nation_name())
	var from_nation = min(nation_available, cost)
	var from_free = cost - from_nation
	return {"nation": from_nation, "free": from_free}


# gasta o máximo possível de XP de nação primeiro, e cobre o restante com
# XP livre -- os dois PODEM SOMAR pra fechar o custo total
func unlock_card(card: CardData) -> bool:
	if !can_unlock_card(card):
		return false

	var is_wildcard = card.get_nation_name() == "" or card.get_nation_name() == "Coringa"
	if is_wildcard:
		free_xp -= card.nation_xp_cost
	else:
		var breakdown = get_unlock_cost_breakdown(card)
		nation_xp[card.get_nation_name()] = get_nation_xp(card.get_nation_name()) - breakdown["nation"]
		free_xp -= breakdown["free"]

	unlocked_cards.append(card.resource_path)
	profile_changed.emit()
	save_profile()
	return true


# pula uso E moeda -- só pra teste de desenvolvedor, nunca chamada pelo
# fluxo normal do jogador (esse continua exigindo os dois, upgrade_card())
func dev_force_upgrade_card(card: CardData):
	if is_max_level(card):
		return
	card_levels[card.resource_path] = get_card_level(card) + 1
	profile_changed.emit()
	save_profile()


func get_upgrade_cost(card: CardData) -> int:
	var level_now = get_card_level(card)
	return UPGRADE_BASE_USES + (level_now - 1) * UPGRADE_USES_GROWTH


func get_upgrade_coin_cost(card: CardData) -> int:
	var level_now = get_card_level(card)
	return UPGRADE_BASE_COST + (level_now - 1) * UPGRADE_COST_GROWTH


func is_max_level(card: CardData) -> bool:
	return get_card_level(card) >= MAX_CARD_LEVEL


# chama isso toda vez que o jogador joga essa carta numa partida
func record_card_usage(card: CardData):
	var path = card.resource_path
	card_usage[path] = card_usage.get(path, 0) + 1
	save_profile()
	Progresso.record_use(card)  # maestria + mais jogadas da temporada


func get_card_usage(card: CardData) -> int:
	return card_usage.get(card.resource_path, 0)


# exige uso EM BATALHA suficiente E moeda suficiente, os dois -- retorna
# false se faltar qualquer um dos dois, ou se a carta já estiver no nível máximo
func upgrade_card(card: CardData) -> bool:
	if is_max_level(card):
		return false

	var use_cost = get_upgrade_cost(card)
	var usage = get_card_usage(card)
	if usage < use_cost:
		return false

	var coin_cost = get_upgrade_coin_cost(card)
	if coins < coin_cost:
		return false

	card_usage[card.resource_path] = usage - use_cost
	coins -= coin_cost
	card_levels[card.resource_path] = get_card_level(card) + 1
	profile_changed.emit()
	save_profile()
	return true


func get_base_level(base_data: BaseData) -> int:
	return base_levels.get(base_data.resource_path, 1)


func get_upgrade_cost_base(base_data: BaseData) -> int:
	var level_now = get_base_level(base_data)
	return BASE_UPGRADE_MATCHES + (level_now - 1) * BASE_UPGRADE_MATCHES_GROWTH


func get_upgrade_coin_cost_base(base_data: BaseData) -> int:
	var level_now = get_base_level(base_data)
	return BASE_UPGRADE_COST + (level_now - 1) * BASE_UPGRADE_COST_GROWTH


func is_max_level_base(base_data: BaseData) -> bool:
	return get_base_level(base_data) >= MAX_CARD_LEVEL


# chama isso ao final de toda partida em que essa base foi a equipada
func record_base_usage(base_data: BaseData):
	var path = base_data.resource_path
	base_usage[path] = base_usage.get(path, 0) + 1
	save_profile()


func get_base_usage(base_data: BaseData) -> int:
	return base_usage.get(base_data.resource_path, 0)


# mesmo mecanismo híbrido da carta -- exige uso EM BATALHA suficiente E
# moeda suficiente, os dois, reaproveitando as mesmas constantes de custo
func upgrade_base(base_data: BaseData) -> bool:
	if is_max_level_base(base_data):
		return false

	var use_cost = get_upgrade_cost_base(base_data)
	var usage = get_base_usage(base_data)
	if usage < use_cost:
		return false

	var coin_cost = get_upgrade_coin_cost_base(base_data)
	if coins < coin_cost:
		return false

	base_usage[base_data.resource_path] = usage - use_cost
	coins -= coin_cost
	base_levels[base_data.resource_path] = get_base_level(base_data) + 1
	profile_changed.emit()
	save_profile()
	return true


# multiplicador de stats (hp/dano) pro nível atual dessa carta -- 15% fixo
# por nível, mesmo formato e valor que a base agora usa
static func compute_stat_multiplier(level_now: int) -> float:
	return 1.0 + (level_now - 1) * CARD_LEVEL_BOOST


# curva própria da BASE -- soma 15% fixo por nível, igual a carta agora
static func compute_base_stat_multiplier(level_now: int) -> float:
	return 1.0 + (level_now - 1) * BASE_LEVEL_BOOST


func get_stat_multiplier(card: CardData) -> float:
	return compute_stat_multiplier(get_card_level(card))


# soma o nível de cada carta do deck atual (nível 1 = 1 ponto, nível 2 = 2 pontos, ...)
# usado pra calibrar o quão forte o bot deve ficar nessa partida
func get_deck_total_level_points() -> int:
	var total = 0
	for card in DeckManager.full_deck:
		if card != null:
			total += get_card_level(card)
	return total


# chama isso quando uma partida termina -- distribui XP de nação/livre e ouro
func add_match_result(won: bool, cards_played: Array = []) -> Dictionary:
	var reward = ArenaManager.get_match_reward(arena_index, won)
	award_battle_xp(reward["xp"], cards_played)
	add_coins(reward["gold"])
	return reward


# separado de add_match_result -- essa aqui é chamada em TODO fim de partida
# (vitória, derrota, OU empate), já que empate não passa pelo add_match_result
# (não ganha XP/ouro de propósito), mas ainda conta como partida jogada
func record_battle_played(won: bool):
	total_battles_played += 1
	if won:
		total_battles_won += 1
	save_profile()


func get_win_rate() -> float:
	if total_battles_played == 0:
		return 0.0
	return float(total_battles_won) / total_battles_played


# a carta mais usada em batalha (maior contagem em card_usage) -- null se
# ainda não usou nenhuma
func get_favorite_card() -> CardData:
	if card_usage.is_empty():
		return null
	var best_path = ""
	var best_count = -1
	for path in card_usage:
		if card_usage[path] > best_count:
			best_count = card_usage[path]
			best_path = path
	if best_path == "" or !ResourceLoader.exists(best_path):
		return null
	return load(best_path)


func add_coins(amount: int):
	coins += amount
	profile_changed.emit()
	save_profile()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	profile_changed.emit()
	save_profile()
	return true


func set_arena(new_arena_name: String):
	arena_name = new_arena_name
	profile_changed.emit()
	save_profile()


func set_player_name(new_name: String):
	player_name = new_name
	profile_changed.emit()
	save_profile()


# só pode ser trocada entre partidas, nunca durante uma (quem chama garante isso)
# registra que acabou de enfrentar esse bot -- fica proibido de sortear ele
# de novo até jogar mais 2 partidas (guarda só os últimos 2 nomes)
func record_recent_opponent(bot_name: String):
	recent_opponents.append(bot_name)
	while recent_opponents.size() > 2:
		recent_opponents.pop_front()
	save_profile()


# divide o XP ganho numa partida: 84% vai pras nações das cartas que o
# jogador REALMENTE jogou (proporcional a quantas vezes cada nação foi
# jogada, não pela composição do deck inteiro), 16% sempre vira XP livre.
# Carta coringa jogada (sem nação própria) também tem sua fatia revertida
# pra livre, já que não existe "nação coringa" pra receber XP
func award_battle_xp(total_xp: int, _cards_played: Array):
	# 2.0: o XP da partida vai pro NÍVEL DO JOGADOR (Progresso.on_battle_finished)
	return
	@warning_ignore("unreachable_code")
	var cards_played = _cards_played
	var nation_pool = int(round(total_xp * 0.84))
	var pure_free = total_xp - nation_pool

	if cards_played.is_empty():
		free_xp += total_xp
		profile_changed.emit()
		save_profile()
		return

	var nation_counts: Dictionary = {}
	for card in cards_played:
		if card == null:
			continue
		var n = card.get_nation_name() if card.get_nation_name() != "" else "Coringa"
		nation_counts[n] = nation_counts.get(n, 0) + 1

	var total_plays = cards_played.size()
	for nation_name in nation_counts:
		var share = int(round(nation_pool * float(nation_counts[nation_name]) / total_plays))
		if nation_name == "Coringa":
			free_xp += share
		else:
			nation_xp[nation_name] = nation_xp.get(nation_name, 0) + share

	free_xp += pure_free
	profile_changed.emit()
	save_profile()


func get_nation_xp(nation_name: String) -> int:
	return nation_xp.get(nation_name, 0)


# confere se o dia mudou desde a última vez -- se sim, gera um conjunto
# novo de missões (as antigas, mesmo não completadas, são substituídas)
func _check_and_reset_daily_missions():
	var today = Time.get_date_string_from_system()
	# também regenera se tiver menos de 3 (antes só existia 1 modelo de missão)
	if daily_missions_date != today or daily_missions.size() < MISSION_COUNT_PER_DAY:
		daily_missions_date = today
		_generate_daily_missions()
		save_profile()


const MISSION_COUNT_PER_DAY = 3

# missões sorteadas na hora (quantidade e recompensa aleatórias) -- somam
# com as que estiverem cadastradas no MissionDatabase
func _random_mission_templates() -> Array[MissionData]:
	var out: Array[MissionData] = []
	var unit_cards = CardDatabase.all_cards.filter(func(c): return c != null and !c.is_spell())
	var my_cards: Array = []
	for path in deck_card_paths:
		if ResourceLoader.exists(path):
			my_cards.append(load(path))
	if my_cards.is_empty():
		my_cards = unit_cards
	var defs = [
		[MissionData.MissionType.WIN_BATTLES, "Vença {target} partida(s)", randi_range(1, 3), 70],
		[MissionData.MissionType.PLAY_CARDS, "Jogue {target} cartas", randi_range(3, 6) * 5, 3],
		[MissionData.MissionType.PLAY_BATTLES, "Jogue {target} partidas", randi_range(2, 5), 35],
		[MissionData.MissionType.USE_SPELL, "Use {target} feitiços", randi_range(3, 8), 12],
		[MissionData.MissionType.DEAL_DAMAGE, "Cause {target} de dano na base inimiga", randi_range(3, 10) * 500, 0.03],
		[MissionData.MissionType.RECEIVE_DAMAGE, "Aguente {target} de dano na sua base", randi_range(2, 6) * 500, 0.03],
		[MissionData.MissionType.WIN_STREAK, "Vença {target} seguidas", randi_range(2, 3), 90],
		[MissionData.MissionType.PLAY_SPECIFIC_CARD, "Jogue {card} {target} vezes", randi_range(3, 6), 15],
		[MissionData.MissionType.KILL_SPECIFIC_UNIT, "Derrote {target}x a unidade {card}", randi_range(2, 5), 20],
	]
	if !nation_xp.is_empty():
		defs.append([MissionData.MissionType.PLAY_NATION_CARDS, "Jogue {target} cartas da nação {nation}", randi_range(5, 12), 8])
	for d in defs:
		var m = MissionData.new()
		m.type = d[0]
		m.description_template = d[1]
		m.target = d[2]
		if m.type == MissionData.MissionType.PLAY_SPECIFIC_CARD:
			if my_cards.is_empty():
				continue
			m.target_card = my_cards[randi() % my_cards.size()]
		elif m.type == MissionData.MissionType.KILL_SPECIFIC_UNIT:
			if unit_cards.is_empty():
				continue
			m.target_card = unit_cards[randi() % unit_cards.size()]
		if m.type == MissionData.MissionType.PLAY_NATION_CARDS:
			m.reward_type = MissionData.RewardType.NATION_XP
		else:
			m.reward_type = MissionData.RewardType.COINS if randf() < 0.6 else MissionData.RewardType.FREE_XP
		var amount = m.target * d[3]
		if m.reward_type != MissionData.RewardType.COINS:
			amount *= 0.6
		m.reward_amount = int(round(clamp(amount, 30, 400) / 5.0)) * 5
		out.append(m)
	return out


func _generate_daily_missions():
	var pool: Array[MissionData] = _random_mission_templates()
	for template in MissionDatabase.all_missions:
		if template == null:
			continue
		# missão de nação específica só entra no sorteio se o jogador já
		# tiver alguma nação com XP registrado -- senão não tem nação
		# nenhuma pra preencher o {nation} da descrição
		if template.type == MissionData.MissionType.PLAY_NATION_CARDS and nation_xp.is_empty():
			continue
		# missão de carta/unidade específica precisa ter uma carta configurada
		# no template -- senão não tem o que rastrear
		if template.type in [MissionData.MissionType.PLAY_SPECIFIC_CARD, MissionData.MissionType.KILL_SPECIFIC_UNIT] and template.target_card == null:
			continue
		pool.append(template)

	var missions = []
	var chosen_templates: Array[MissionData] = []

	for i in min(MISSION_COUNT_PER_DAY, pool.size()):
		var picked = _weighted_pick(pool, chosen_templates)
		if picked == null:
			break
		chosen_templates.append(picked)

		var nation_for_mission = ""
		if picked.type == MissionData.MissionType.PLAY_NATION_CARDS:
			var known_nations = nation_xp.keys()
			nation_for_mission = known_nations[randi() % known_nations.size()]

		var card_path = ""
		var card_name = ""
		if picked.target_card != null:
			card_path = picked.target_card.resource_path
			card_name = picked.target_card.card_name

		var description = picked.description_template
		description = description.replace("{target}", str(picked.target))
		description = description.replace("{nation}", nation_for_mission)
		description = description.replace("{card}", card_name)

		missions.append({
			"id": "%d_%d" % [picked.type, i],  # único o bastante dentro de um único dia
			"description": description,
			"type": picked.type,
			"target": picked.target,
			"progress": 0,
			"reward_type": picked.reward_type,
			"reward_amount": picked.reward_amount,
			"reward_nation": nation_for_mission,
			"target_card_path": card_path,
			"claimed": false,
		})

	daily_missions = missions


# sorteio com peso, sem repetir template já escolhido nesse dia
func _weighted_pick(pool: Array[MissionData], already_chosen: Array[MissionData]) -> MissionData:
	var candidates = pool.filter(func(m): return m not in already_chosen)
	if candidates.is_empty():
		return null

	var total_weight = 0.0
	for m in candidates:
		total_weight += max(m.weight, 0.01)

	var roll = randf() * total_weight
	var accumulated = 0.0
	for m in candidates:
		accumulated += max(m.weight, 0.01)
		if roll <= accumulated:
			return m
	return candidates[-1]


func _add_mission_progress(mission_type: MissionData.MissionType, amount: int, nation_filter: String = "", card_path_filter: String = ""):
	for mission in daily_missions:
		if mission["claimed"] or mission["type"] != mission_type:
			continue
		if mission_type == MissionData.MissionType.PLAY_NATION_CARDS and mission["reward_nation"] != nation_filter:
			continue
		if mission_type in [MissionData.MissionType.PLAY_SPECIFIC_CARD, MissionData.MissionType.KILL_SPECIFIC_UNIT] and mission.get("target_card_path", "") != card_path_filter:
			continue
		mission["progress"] = min(mission["progress"] + amount, mission["target"])
	save_profile()


func record_mission_battle_win():
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.WIN_BATTLES, 1)


func record_mission_cards_played(cards_played: Array):
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.PLAY_CARDS, cards_played.size())
	for card in cards_played:
		if card == null:
			continue
		if card.get_nation_name() != "":
			_add_mission_progress(MissionData.MissionType.PLAY_NATION_CARDS, 1, card.get_nation_name())
		_add_mission_progress(MissionData.MissionType.PLAY_SPECIFIC_CARD, 1, "", card.resource_path)


func record_mission_spell_used():
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.USE_SPELL, 1)


# chamado uma vez por unidade INIMIGA destruída (o time que morreu é do
# inimigo) -- credita como "matou" pro jogador, não importa qual unidade
# sua especificamente deu o golpe final
func record_mission_unit_killed(card_data: CardData):
	if card_data == null:
		return
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.KILL_SPECIFIC_UNIT, 1, "", card_data.resource_path)


# chamado ao FIM de toda partida, não importa se ganhou ou perdeu
func record_mission_battle_played():
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.PLAY_BATTLES, 1)


func record_mission_damage_dealt(amount: int):
	if amount <= 0:
		return
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.DEAL_DAMAGE, amount)


func record_mission_damage_received(amount: int):
	if amount <= 0:
		return
	_check_and_reset_daily_missions()
	_add_mission_progress(MissionData.MissionType.RECEIVE_DAMAGE, amount)


# diferente das outras -- progresso de vitória seguida pode CAIR pra 0, não
# só subir. Por isso não usa _add_mission_progress (que só soma), define o
# valor direto
func record_mission_win_streak(won: bool):
	_check_and_reset_daily_missions()
	for mission in daily_missions:
		if mission["claimed"] or mission["type"] != MissionData.MissionType.WIN_STREAK:
			continue
		if won:
			mission["progress"] = min(mission["progress"] + 1, mission["target"])
		else:
			mission["progress"] = 0  # perdeu -- sequência quebrou, começa de novo
	save_profile()


# resgata a recompensa de uma missão já completa (progress >= target) e
# ainda não resgatada -- devolve false se não estiver pronta pra resgatar
func claim_mission_reward(mission_id: String) -> bool:
	for mission in daily_missions:
		if mission["id"] != mission_id:
			continue
		if mission["claimed"] or mission["progress"] < mission["target"]:
			return false

		match mission["reward_type"]:
			MissionData.RewardType.COINS:
				add_coins(mission["reward_amount"])
			_:
				Progresso.add_xp(int(mission["reward_amount"]))  # 2.0: XP de missão sobe o nível do jogador

		mission["claimed"] = true
		profile_changed.emit()
		save_profile()
		return true
	return false


func set_equipped_base(base_data: BaseData):
	equipped_base_path = base_data.resource_path if base_data != null else ""
	profile_changed.emit()
	save_profile()


func get_equipped_base() -> BaseData:
	if equipped_base_path != "" and ResourceLoader.exists(equipped_base_path):
		return load(equipped_base_path)

	# ainda não escolheu nenhuma base -- cai pra primeira disponível em vez
	# de devolver null (sem isso, o jogador podia entrar numa partida sem
	# base nenhuma instalada, o que quebra qualquer código que espere
	# base_data preenchido)
	if !BotSimulator.available_bases.is_empty():
		var default_base = BotSimulator.available_bases[0]
		set_equipped_base(default_base)
		return default_base

	return null


func is_base_unlocked(base_data: BaseData) -> bool:
	return Progresso.is_base_unlocked(base_data) or CustomContent.is_custom(base_data)  # 2.0: torre libera pela arena


# mesma regra de can_unlock_card -- nação + livre PODEM SOMAR pra cobrir o
# custo, e TODAS as bases antecessoras (se tiver) precisam estar
# desbloqueadas primeiro
func can_unlock_base(base_data: BaseData) -> bool:
	if is_base_unlocked(base_data):
		return false
	for predecessor in base_data.predecessor_bases:
		if predecessor != null and !is_base_unlocked(predecessor):
			return false

	var is_wildcard = base_data.get_nation_name() == "" or base_data.get_nation_name() == "Coringa"
	if is_wildcard:
		return free_xp >= base_data.nation_xp_cost
	return (get_nation_xp(base_data.get_nation_name()) + free_xp) >= base_data.nation_xp_cost


func get_unlock_cost_base(base_data: BaseData) -> int:
	return base_data.nation_xp_cost


func get_unlock_cost_breakdown_base(base_data: BaseData) -> Dictionary:
	var cost = base_data.nation_xp_cost
	var is_wildcard = base_data.get_nation_name() == "" or base_data.get_nation_name() == "Coringa"
	if is_wildcard:
		return {"nation": 0, "free": cost}

	var nation_available = get_nation_xp(base_data.get_nation_name())
	var from_nation = min(nation_available, cost)
	var from_free = cost - from_nation
	return {"nation": from_nation, "free": from_free}


func unlock_base(base_data: BaseData) -> bool:
	if !can_unlock_base(base_data):
		return false

	var is_wildcard = base_data.get_nation_name() == "" or base_data.get_nation_name() == "Coringa"
	if is_wildcard:
		free_xp -= base_data.nation_xp_cost
	else:
		var breakdown = get_unlock_cost_breakdown_base(base_data)
		nation_xp[base_data.get_nation_name()] = get_nation_xp(base_data.get_nation_name()) - breakdown["nation"]
		free_xp -= breakdown["free"]

	unlocked_bases.append(base_data.resource_path)
	profile_changed.emit()
	save_profile()
	return true


# chama isso do DeckManager toda vez que o jogador troca uma carta do deck --
# persiste a escolha, pra não voltar pro deck de fábrica ao reabrir o jogo
func save_deck(paths: Array):
	deck_card_paths = paths
	save_profile()
