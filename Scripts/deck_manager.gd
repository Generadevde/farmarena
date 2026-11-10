extends Node

signal hand_changed
signal deck_changed

# as 7 cartas de fábrica (configura no Inspector) -- só usadas enquanto o
# perfil ativo ainda não tiver escolhido/salvado um deck próprio
var full_deck: Array[CardData] = []

var draw_queue: Array[CardData] = []  # as 4 cartas que ainda não estão na mão
var hand: Array[CardData] = [null, null, null]


func _ready():
	if full_deck.is_empty():
		full_deck.assign(Catalogo.starter_deck())
	start_deck()
	_warn_if_duplicate_cards()
	PlayerProfile.profile_changed.connect(_load_deck_for_active_profile)
	_load_deck_for_active_profile()


# busca o deck salvo do perfil que acabou de virar ativo -- se ele ainda não
# tiver nenhum salvo (perfil novo), mantém o deck de fábrica do Inspector
func _load_deck_for_active_profile():
	var saved_paths = PlayerProfile.deck_card_paths
	if saved_paths.is_empty():
		return

	var loaded_deck: Array[CardData] = []
	for path in saved_paths:
		var saved_card = Catalogo.find_card(path)
		if saved_card != null:
			loaded_deck.append(saved_card)

	if loaded_deck.size() != full_deck.size():
		return  # deck salvo veio incompleto/corrompido -- não arrisca, mantém o de fábrica

	full_deck = loaded_deck
	start_deck()
	deck_changed.emit()


func _warn_if_duplicate_cards():
	var seen: Dictionary = {}
	for card in full_deck:
		if card == null:
			continue
		if seen.has(card.resource_path):
			push_warning(
				"DeckManager: a carta '%s' aparece mais de uma vez no deck -- só é permitida 1 cópia por carta." %
				card.card_name
			)
		seen[card.resource_path] = true


func start_deck():
	draw_queue = full_deck.duplicate()
	draw_queue.shuffle()

	for i in hand.size():
		hand[i] = draw_queue.pop_front()

	hand_changed.emit()


# troca a carta de uma posição fixa do deck (0 a 6), usado na tela de menu
# pra montar o baralho -- não mexe na mão/fila em jogo, só na composição base.
# Retorna false (e não troca nada) se essa carta já estiver em outro slot,
# já que só é permitida 1 cópia de cada carta por deck
func set_deck_card(index: int, card: CardData) -> bool:
	if index < 0 or index >= full_deck.size():
		return false

	for i in full_deck.size():
		if i != index and full_deck[i] != null and full_deck[i].resource_path == card.resource_path:
			return false

	full_deck[index] = card
	PlayerProfile.save_deck(_deck_to_paths())
	deck_changed.emit()
	return true


func _deck_to_paths() -> Array:
	var paths = []
	for card in full_deck:
		if card != null:
			paths.append(card.resource_path)
	return paths


# chama isso quando uma carta da mão é jogada de verdade (unidade nasceu)
# devolve a CardData jogada, pra quem chamou saber o que gastar/spawnar
func play_card(hand_index: int) -> CardData:
	var played = hand[hand_index]
	if played == null:
		return null

	draw_queue.push_back(played)
	hand[hand_index] = draw_queue.pop_front()

	hand_changed.emit()
	return played
