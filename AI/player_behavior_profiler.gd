extends Node

# ---- dados acumulados entre partidas (um arquivo por perfil de jogador) ----
var total_plays: int = 0
var reserve_sum: float = 0.0          # soma do dinheiro que sobrou depois de cada jogada
var expensive_choice_count: int = 0   # quantas vezes jogou a carta mais cara que podia pagar
var threat_play_count: int = 0        # quantas vezes jogou com ameaça perto da própria base
var interval_sum: float = 0.0         # soma dos intervalos entre uma jogada e outra
var card_play_counts: Dictionary = {} # resource_path da carta -> quantas vezes foi jogada

var _last_play_time: float = -1.0

const SAVE_DIR = "user://profiles/"


func _get_save_path() -> String:
	return SAVE_DIR + "behavior_%d.save" % PlayerProfile.active_profile_id


# chama isso depois de escolher/criar/trocar de perfil -- carrega os dados
# de comportamento DESSE perfil específico (cada perfil tem o próprio "reflexo")
func load_for_active_profile():
	total_plays = 0
	reserve_sum = 0.0
	expensive_choice_count = 0
	threat_play_count = 0
	interval_sum = 0.0
	card_play_counts = {}
	_last_play_time = -1.0

	var path = _get_save_path()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return

	total_plays = data.get("total_plays", 0)
	reserve_sum = data.get("reserve_sum", 0.0)
	expensive_choice_count = data.get("expensive_choice_count", 0)
	threat_play_count = data.get("threat_play_count", 0)
	interval_sum = data.get("interval_sum", 0.0)
	card_play_counts = data.get("card_play_counts", {})


# chamado pela cena de batalha toda vez que o JOGADOR (não o bot) joga uma
# carta -- vai registrando o padrão real de escolhas, partida após partida
func record_play(card: CardData, money_before: int, hand_at_time: Array, near_own_base_threat: bool):
	total_plays += 1
	reserve_sum += max(money_before - card.cost, 0)

	# preferência por carta cara: compara com as outras opções pagáveis na mão
	var affordable: Array = []
	for c in hand_at_time:
		if c != null and c.cost <= money_before:
			affordable.append(c)

	if !affordable.is_empty():
		var most_expensive = affordable[0]
		for c in affordable:
			if c.cost > most_expensive.cost:
				most_expensive = c
		if card == most_expensive:
			expensive_choice_count += 1

	if near_own_base_threat:
		threat_play_count += 1

	var now = Time.get_ticks_msec() / 1000.0
	if _last_play_time > 0:
		interval_sum += now - _last_play_time
	_last_play_time = now

	var path = card.resource_path
	card_play_counts[path] = card_play_counts.get(path, 0) + 1

	_save()


# monta um AIProfile novo, estimando os parâmetros a partir do que já observou
func build_ai_profile() -> AIProfile:
	var profile = AIProfile.new()
	profile.profile_name = "Seu Reflexo"

	if total_plays == 0:
		return profile  # ainda sem dados -- devolve um perfil neutro, sem quebrar nada

	profile.min_money_reserve = int(reserve_sum / total_plays)
	profile.prefer_expensive = (float(expensive_choice_count) / total_plays) > 0.5
	profile.reacts_to_threats = (float(threat_play_count) / total_plays) > 0.5
	profile.decision_interval = clamp(interval_sum / max(total_plays - 1, 1), 1.0, 8.0)

	var best_path = ""
	var best_count = 0
	for path in card_play_counts:
		if card_play_counts[path] > best_count:
			best_count = card_play_counts[path]
			best_path = path
	if best_path != "" and ResourceLoader.exists(best_path):
		profile.favorite_card = load(best_path)

	return profile


func _save():
	var data = {
		"total_plays": total_plays,
		"reserve_sum": reserve_sum,
		"expensive_choice_count": expensive_choice_count,
		"threat_play_count": threat_play_count,
		"interval_sum": interval_sum,
		"card_play_counts": card_play_counts,
	}
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
