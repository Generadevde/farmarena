extends Node

# lista de nomes de bots que existem no "mundo" -- fonte única, usada tanto
# pelo menu (pra sortear seu adversário) quanto por essa simulação de fundo
@export var roster_names: Array[String] = []

# bases que os bots podem escolher, de acordo com o nível deles e a
# categoria preferida -- mesmos .tres que aparecem na tela de escolher base
@export var available_bases: Array[BaseData] = []

const SIMULATION_INTERVAL_SECONDS = 120.0  # a cada 2 minutos de jogo aberto -- valor normal de produção
const MAX_CATCHUP_TICKS = 25                # teto pra não explodir se ficar dias sumido -- era 10, usuário achou baixo demais
# enquanto o jogo está FECHADO, só conta uma fração dos ticks que teriam
# rodado -- as batalhas "importam menos" quando ninguém está vendo. Era 1/3,
# usuário achou baixo demais -- subiu pra 2/3 (ainda mais devagar que com o
# jogo aberto, mas bem mais perto disso agora)
const OFFLINE_SIMULATION_FACTOR = 2.0 / 3.0

# em vez de um número fixo de partidas por tick, escala com o tamanho do
# elenco -- assim cada bot continua tendo a MESMA densidade de partidas por
# tick não importa se tem 10 ou 300 cadastrados
const MIN_MATCHES_PER_TICK = 4
const MAX_MATCHES_PER_TICK = 200  # segurança, caso o elenco fique gigante mesmo
const PARTICIPATION_FRACTION = 1.0  # fração do elenco que joga em média por tick -- praticamente todo mundo

const LAST_SIM_PATH_PREFIX = "user://last_simulation_profile_"

var _timer: Timer


func _get_last_sim_path() -> String:
	return LAST_SIM_PATH_PREFIX + str(PlayerProfile.active_profile_id) + ".cfg"


func _ready():
	print("DEBUG BotSimulator: autoload iniciou, roster_names tem ", roster_names.size(), " bot(s)")

	# continua rodando mesmo com a árvore pausada (fim de partida, popups)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_timer = Timer.new()
	_timer.wait_time = SIMULATION_INTERVAL_SECONDS
	_timer.autostart = false  # só começa depois que um perfil for carregado
	_timer.timeout.connect(_run_simulation_tick)
	add_child(_timer)
	# NÃO roda _catch_up_on_elapsed_time() aqui -- nesse momento nenhum perfil
	# foi carregado ainda (quem escolhe é a profile_setup). Ver on_profile_loaded()


var _profile_ready: bool = false


# chamado pela profile_setup DEPOIS que perfil + ArenaManager + Leaderboard
# foram carregados -- só agora é seguro simular e salvar resultado
func on_profile_loaded():
	_profile_ready = true
	_catch_up_on_elapsed_time()
	_timer.start()


# no Android o app vai pro segundo plano toda hora (o Godot congela os
# timers) e muitas vezes nem é fechado de verdade -- então ao VOLTAR também
# recupera o tempo que passou fora, não só quando abre do zero
func _notification(what):
	if !_profile_ready:
		return
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_catch_up_on_elapsed_time()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_remember_last_simulation_time()


func _run_simulation_tick():
	if !_profile_ready:
		return
	var match_count = _get_matches_per_tick()

	if roster_names.is_empty():
		print("DEBUG BotSimulator: roster_names está VAZIO -- nenhuma simulação vai rodar. " +
			"Confere se o BotSimulator virou cena (.tscn) e se Roster Names foi preenchido nela.")
		_remember_last_simulation_time()
		return

	# ordena por troféu (a mesma métrica de força que já usamos pro jogador
	# escolher adversário parecido) -- em vez de embaralhar o elenco inteiro
	# sem critério, o forte casa majoritariamente com outro forte, o fraco
	# com outro fraco. Isso evita o "forte farmando o fraco repetidamente"
	# que deixava o troféu disparar sem controle pra um lado só
	var sorted_roster = roster_names.duplicate()
	sorted_roster.sort_custom(func(a, b): return ArenaManager.get_trophies(a) > ArenaManager.get_trophies(b))

	# embaralha só DENTRO de janelas pequenas da lista já ordenada -- assim
	# os pares continuam parecidos em força, mas não travam sempre
	# exatamente nos mesmos dois vizinhos toda vez
	const PAIRING_SHUFFLE_WINDOW = 4
	var i = 0
	while i < sorted_roster.size():
		var window_end = min(i + PAIRING_SHUFFLE_WINDOW, sorted_roster.size())
		var window = sorted_roster.slice(i, window_end)
		window.shuffle()
		for j in window.size():
			sorted_roster[i + j] = window[j]
		i += PAIRING_SHUFFLE_WINDOW

	var pairs_played = 0
	var index = 0
	while pairs_played < match_count and index + 1 < sorted_roster.size():
		simulate_match(sorted_roster[index], sorted_roster[index + 1])
		index += 2
		pairs_played += 1

	print("DEBUG BotSimulator: tick rodou, ", pairs_played, " partida(s) simulada(s) entre ", sorted_roster.size(), " bot(s) no elenco")
	_remember_last_simulation_time()


func _get_matches_per_tick() -> int:
	var by_ratio = int(roster_names.size() * PARTICIPATION_FRACTION / 2.0)
	return clamp(by_ratio, MIN_MATCHES_PER_TICK, MAX_MATCHES_PER_TICK)


# simula uma partida entre dois bots (sem visual nenhum, só matemática) e
# alimenta os MESMOS sistemas que uma partida de verdade alimentaria:
# evolução de deck, ranking e estatísticas de carta da temporada
# o quanto pesa cada ponto de vantagem líquida no confronto carta-a-carta
# (soma de +1/-1 por par que uma categoria vence a outra na teia)
const MATCHUP_WEIGHT = 0.15
# o quanto cada PAR de cartas com afinidade entre si soma na força do deck
const AFFINITY_BONUS_PER_PAIR = 0.5


func simulate_match(bot_a_name: String, bot_b_name: String):
	var profile_a = BotLearning.get_or_create_profile(bot_a_name)
	var profile_b = BotLearning.get_or_create_profile(bot_b_name)

	var power_a = _estimate_power(profile_a) + randf_range(-1.5, 1.5)
	var power_b = _estimate_power(profile_b) + randf_range(-1.5, 1.5)

	# em vez de só comparar a categoria MAIS comum de cada deck, compara
	# TODA carta de A contra TODA carta de B na teia de afinidade -- um
	# retrato bem mais granular do confronto real do que um resumo de
	# "categoria dominante", que jogava fora a informação das outras 6 cartas
	var matchup_net = _compute_matchup_net(profile_a.deck, profile_b.deck)
	power_a += matchup_net * MATCHUP_WEIGHT
	power_b -= matchup_net * MATCHUP_WEIGHT

	var a_won = power_a >= power_b

	# passa [] de cartas do "jogador" -- essa é uma partida entre bots, não
	# queremos poluir a estatística de "carta que o jogador mais usa"
	BotLearning.record_result(bot_a_name, a_won, [])
	BotLearning.record_result(bot_b_name, !a_won, [])

	# crédito de uso aproximado -- essa simulação nunca joga carta por
	# carta de verdade, então sem isso o uso de cada carta nunca saía do
	# zero pra quem só participa da simulação de fundo
	BotLearning.record_simulated_match_usage(bot_a_name, profile_a.deck)
	BotLearning.record_simulated_match_usage(bot_b_name, profile_b.deck)

	var winner_name = bot_a_name if a_won else bot_b_name
	var loser_name = bot_b_name if a_won else bot_a_name
	ArenaManager.record_match_points(winner_name, loser_name)

	if a_won:
		SeasonStats.record_match_result(profile_a.deck, profile_b.deck)
	else:
		SeasonStats.record_match_result(profile_b.deck, profile_a.deck)


# soma +1 pra cada par (carta de A, carta de B) em que a de A vence a de B
# na teia de afinidade, -1 pro inverso -- confronto carta a carta completo,
# não só a categoria mais comum de cada lado
func _compute_matchup_net(deck_a: Array[CardData], deck_b: Array[CardData]) -> float:
	var net = 0.0
	for card_a in deck_a:
		if card_a == null:
			continue
		for card_b in deck_b:
			if card_b == null:
				continue
			if CardData.role_beats(card_a.role, card_b.role):
				net += 1.0
			elif CardData.role_beats(card_b.role, card_a.role):
				net -= 1.0
	return net


# estimativa de "força" de um bot -- não é uma batalha de verdade simulada
# tick a tick (isso exigiria rodar toda a física da batalha sem tela, bem
# mais caro); é uma aproximação a partir da força de combate real de cada
# carta do deck (HP, dano por segundo, alcance), já considerando o nível
# atual do bot naquela carta, mais um tempero pela estratégia dele
func _estimate_power(profile: AIProfile) -> float:
	var total = 0.0

	for card in profile.deck:
		if card == null:
			continue
		total += _estimate_card_power(card) * profile.get_stat_multiplier(card)

	if !profile.deck.is_empty():
		total /= profile.deck.size()  # média por carta, mantém a escala comparável

	# quantas jogadas o bot consegue fazer ao longo de uma partida inteira,
	# comparado a um ritmo de referência -- decisão mais rápida realmente
	# põe mais força em campo ao longo do tempo, não é mais só um bônus fixo
	var turns = MATCH_DURATION_SECONDS / max(profile.decision_interval, 0.5)
	var reference_turns = MATCH_DURATION_SECONDS / REFERENCE_DECISION_INTERVAL
	var tempo_multiplier = clamp(turns / reference_turns, 0.6, 1.6)
	total *= tempo_multiplier

	total -= profile.min_money_reserve * 0.15
	if profile.prefer_expensive:
		total += 0.5

	total += _count_affinity_pairs(profile.deck) * AFFINITY_BONUS_PER_PAIR

	# a base escolhida também conta -- canhão/cura/aura/produção/espaço, cada
	# um contribui do jeito próprio dele
	if profile.equipped_base != null:
		total += _estimate_base_power(profile.equipped_base)

	return total


# contribuição da base escolhida na força total -- cada tipo funcional
# soma de um jeito diferente, do mesmo jeito que já faz de verdade na
# partida real (canhão = dano ao longo do tempo, cura = sustento, etc)
func _estimate_base_power(base_data: BaseData) -> float:
	var power = (base_data.base_hp - 1000) * 0.01

	match base_data.base_type:
		BaseData.BaseType.CANNON:
			var dps = base_data.attack_damage / max(base_data.attack_speed, 0.1)
			power += dps * 0.5
		BaseData.BaseType.HEAL:
			power += (base_data.heal_amount / max(base_data.heal_interval, 0.1)) * 0.3
		BaseData.BaseType.AURA:
			if base_data.effect != UnitData.OnHitEffect.NONE:
				power += 1.0
		BaseData.BaseType.PRODUCTION:
			power += base_data.production_speed_boost * 5.0
		BaseData.BaseType.CAPACITY:
			power += base_data.capacity_bonus * 0.02

	return power


# conta quantos PARES de cartas do deck têm afinidade entre si -- um deck
# "comboado" (várias cartas que combinam) sai um pouco mais forte que um
# deck com a mesma força bruta, mas sem sinergia nenhuma entre as peças
func _count_affinity_pairs(deck: Array[CardData]) -> int:
	var pairs = 0
	for i in deck.size():
		if deck[i] == null:
			continue
		for j in range(i + 1, deck.size()):
			if deck[j] == null:
				continue
			if CardData.has_affinity(deck[i].role, deck[j].role):
				pairs += 1
	return pairs


# o quanto pesa cada ponto de eficiência (força ÷ custo) na força final da
# carta -- prêmia carta barata bem desenhada, sem fazer "custo alto" ganhar
# sozinho (é o oposto do viés antigo)
const EFFICIENCY_FACTOR = 0.5

# duração aproximada de uma partida de verdade, em segundos -- usada só
# pra estimar quantas jogadas cabem numa partida, não é usada como timer real
const MATCH_DURATION_SECONDS = 180.0
# ponto de "ritmo neutro" -- decisão nesse valor não ganha nem perde nada no
# multiplicador de ritmo; mais rápido que isso ganha, mais lento perde
const REFERENCE_DECISION_INTERVAL = 2.75


# força de combate "crua" de uma carta, sem considerar nível ainda (isso é
# aplicado depois, multiplicando pelo get_stat_multiplier do profile)
func _estimate_card_power(card: CardData) -> float:
	var raw_power: float

	if card.is_spell():
		# feitiços não têm hp/dano fixos do mesmo jeito que uma unidade --
		# usa uma estimativa simples baseada no dano dele, se tiver
		var spell = card.spell_data
		raw_power = 5.0
		if spell != null and spell.damage > 0:
			raw_power += spell.damage * 0.05
	elif card.unit_scene == null:
		raw_power = 1.0
	else:
		# instancia só pra espiar o stats (mesmo truque já usado em outros
		# lugares do projeto), sem nunca entrar na árvore de cena de verdade
		var temp = card.unit_scene.instantiate()
		var stats = temp.stats
		temp.queue_free()

		if stats == null:
			raw_power = 1.0
		else:
			var dps = stats.damage / max(stats.attack_speed, 0.1)
			# alcance pesando bem mais que antes (era 0.01, quase invisível)
			var range_bonus = stats.attack_range * 0.15
			var count_mult = stats.unit_count
			raw_power = (stats.hp * 0.3 + dps * 3.0 + range_bonus) * count_mult

	# bônus de eficiência: quanto mais força por custo, maior o multiplicador
	# -- uma carta de custo 2 ganha mais empurrão que uma de custo 8, mas
	# nenhuma delas fica fraca só por ser cara (ainda depende da força crua)
	var efficiency_mult = 1.0 + (EFFICIENCY_FACTOR / max(card.cost, 1))
	return raw_power * efficiency_mult


func _catch_up_on_elapsed_time():
	var last_time = _get_last_simulation_time()
	var now = Time.get_unix_time_from_system()

	if last_time <= 0:
		_remember_last_simulation_time()
		return

	var elapsed = now - last_time
	# guarda a sobra fracionária -- antes, sair por 3 min (1,0 tick) dava 0
	# tick e o relógio era zerado, então várias saídas curtas nunca somavam nada
	var exact_ticks = (elapsed / SIMULATION_INTERVAL_SECONDS) * OFFLINE_SIMULATION_FACTOR + _catchup_remainder
	var ticks_missed = int(exact_ticks)
	_catchup_remainder = exact_ticks - ticks_missed
	ticks_missed = min(ticks_missed, MAX_CATCHUP_TICKS)

	if ticks_missed <= 0:
		_remember_last_simulation_time()
		return

	print("DEBUG BotSimulator: recuperando ", ticks_missed, " tick(s) de tempo fora")
	for i in ticks_missed:
		_run_simulation_tick()
	_remember_last_simulation_time()
	_timer.start()  # reinicia a contagem do tick normal a partir de agora


var _catchup_remainder: float = 0.0


func _get_last_simulation_time() -> float:
	var path = _get_last_sim_path()
	if not FileAccess.file_exists(path):
		return 0.0
	var file = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text().to_float()


func _remember_last_simulation_time():
	var file = FileAccess.open(_get_last_sim_path(), FileAccess.WRITE)
	file.store_string(str(Time.get_unix_time_from_system()))
