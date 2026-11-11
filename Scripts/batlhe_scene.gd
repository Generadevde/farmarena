extends Node2D

@onready var spawn_player_area = $SpawnPlayerArea/CollisionShape2D
@onready var spawn_enemy_area = $SpawnEnemyArea/CollisionShape2D
@export var selected_card: CardData
@export var ai_profile: AIProfile  # deck e níveis próprios desse bot
var ai_hand: Array = [null, null, null]  # mão do bot -- mesmo padrão do DeckManager do jogador
var ai_draw_queue: Array = []  # cartas do bot que ainda não estão na mão
var selected_hand_index: int = -1
var preview_units: Array = []
var preview_offsets: Array = []  # desvio de cada preview, calculado uma vez só (evita o tremor)
var range_preview: SpellAreaPreview = null  # círculo de alcance da unidade/defesa que está sendo posicionada
var spell_preview: SpellAreaPreview = null  # círculo de área, só existe enquanto um feitiço está selecionado
var player_cards_played_this_match: Array[CardData] = []  # pro BotLearning e SeasonStats
var match_action_log: Array = []  # cada item: {time, side, card_path, x, y} -- pro replay de verdade
var _match_start_time: float = 0.0
var is_replay_mode: bool = false  # true quando está REPRODUZINDO um replay salvo -- desliga input normal, IA normal, e timer normal
var _replay_next_action_index: int = 0
var player_damage_dealt_this_match: int = 0  # pra missão diária de dano acumulado
var player_damage_received_this_match: int = 0  # pra missão diária de dano recebido

const FORMATION_SPACING = 28.0  # distância entre unidades dentro do bloco/cluster
const FORMATION_JITTER = 8.0    # o quanto de bagunça aleatória em cima da grade


# calcula onde a i-ésima unidade de uma leva de "count" deve nascer, em
# relação ao ponto central -- em vez de uma fileira reta, alterna um pouco
# pra frente/trás, dando uma cara de formação de batalha real
# calcula onde a i-ésima unidade de uma leva de "count" deve nascer, em
# relação ao ponto central -- em vez de espalhar numa fileira/zigue-zague
# largo, agrupa num pequeno bloco/grade compacta, tipo um pelotão de verdade
# pisca a barra de recurso em vermelho por um instante -- feedback claro de
# "sem dinheiro ainda" em vez de o clique simplesmente não fazer nada
func _flash_insufficient_funds():
	Sfx.play("erro")
	var bar = _resource_bar
	if bar == null:
		return
	var original_color = bar.modulate
	var tween = create_tween()
	tween.tween_property(bar, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(bar, "modulate", original_color, 0.2)


func _get_formation_offset(i: int, count: int, unit_radius: float = 14.0, formation: int = 0) -> Vector2:
	if count <= 1:
		return Vector2.ZERO

	# nunca deixa o espaçamento ficar menor que o dobro do raio da unidade
	# (com uma margem de 20%) -- senão as unidades nascem se sobrepondo, e
	# o sistema de desvio (avoidance) fica recalculando separação TODO
	# frame até elas se afastarem sozinhas, travando o jogo inteiro por um
	# tempo. É exatamente esse cálculo dinâmico que faltava antes.
	var spacing = max(FORMATION_SPACING, unit_radius * 2.2)

	# 1 = Linha (espalhada na horizontal, todas lado a lado)
	if formation == 1:
		var offset_x = (i - (count - 1) / 2.0) * spacing
		return Vector2(offset_x + randf_range(-FORMATION_JITTER, FORMATION_JITTER), randf_range(-FORMATION_JITTER, FORMATION_JITTER))

	# 2 = Coluna (espalhada na vertical, uma atrás da outra)
	if formation == 2:
		var offset_y = (i - (count - 1) / 2.0) * spacing
		return Vector2(randf_range(-FORMATION_JITTER, FORMATION_JITTER), offset_y + randf_range(-FORMATION_JITTER, FORMATION_JITTER))

	# 3 = Círculo (distribuídas ao redor de um centro, em roda)
	if formation == 3:
		var circle_radius = max(spacing, unit_radius * 2.2) * (count / (2.0 * PI)) if count > 3 else spacing
		var angle = (float(i) / count) * TAU
		return Vector2(cos(angle), sin(angle)) * circle_radius

	# 0 = Grupo (padrão) -- grade quadrada com bagunçadinha orgânica
	var columns = ceil(sqrt(count))
	var rows = ceil(float(count) / columns)

	var col = i % int(columns)
	var row = i / int(columns)

	var offset_x = (col - (columns - 1) / 2.0) * spacing
	var offset_y = (row - (rows - 1) / 2.0) * spacing

	# uma bagunçadinha pequena em cima da grade -- tira a cara de "quadrado
	# perfeito" e deixa mais orgânico, sem perder o agrupamento
	offset_x += randf_range(-FORMATION_JITTER, FORMATION_JITTER)
	offset_y += randf_range(-FORMATION_JITTER, FORMATION_JITTER)

	return Vector2(offset_x, offset_y)

# ajusta esse caminho pro local real da sua cena de menu principal
const MAIN_MENU_SCENE = "res://Scenes/hub.tscn"

var match_over = false  # evita processar o fim da partida duas vezes
var _is_nemesis_match: bool = false  # true se esse bot entrou "afiado" por rixa -- usado só pra saber se adiciona o 🔥 no nome, depois de _show_opponent_name() (que senão sobrescreveria)
var _revenge_until: float = 0.0  # timestamp até quando o modo vingança fica ativo

# ajusta esse valor pro tanto de recurso inicial que uma partida deve começar
const STARTING_MONEY = 5

# raio em torno da base inimiga pra considerar que tem uma "ameaça" chegando
# (usado só por bots com reacts_to_threats = true)
const THREAT_DETECTION_RADIUS = 130.0  # era 250 -- perto demais fazia até bot não-defensivo passar a partida inteira "vendo ameaça" e nunca atacar
# raio bem mais apertado, só pra "base sendo atacada de verdade, agora" --
# TODO arquétipo reage a isso, mesmo os que normalmente ignoram ameaça
const EMERGENCY_DEFENSE_RADIUS = 220.0  # era 60 -- menor que o raio normal (130), o que fazia a "rede de segurança" ser mais fraca que a detecção comum e deixar passar unidade atacando de longe. Agora é sempre maior, cobre ataque à distância também

# --- arena mista: base/spawn iguais em todas, só o MEIO muda por arena ---
# caminho de cada cenário do meio -- %d é o índice da arena (1 a 7)
const ARENA_MIDDLE_SCENE_PATH = "res://arenas/middles/arena_%d_middle.tscn"


# carrega o cenário do meio da arena atual (a do jogador) dentro do
# container reservado pra isso na cena -- se a arena ainda não tiver o
# cenário próprio dela (você falou que vai fazer uma de cada vez), ou se a
# cena nem tiver o container ainda, simplesmente não faz nada, SEM erro
# ancora cada elemento do HUD relativo ao TAMANHO REAL da tela (fração,
# não pixel fixo) -- resolve o corte que acontecia com Stretch Aspect =
# Expand, onde a tela cresce além do tamanho de referência antigo e
# qualquer elemento em posição fixa fica "pra fora" da borda de baixo.
# Cada find_child é opcional -- se algum nó não existir com esse nome
# exato, só pula ele, sem quebrar o resto
func _opp_label() -> Label:
	return find_child("OpponentNameLabel", true, false)


func _setup_hud_anchors():
	# só o necessário funcionalmente -- posição/tamanho de cada elemento
	# fica por conta do usuário, direto no editor
	_resource_bar = find_child("ResourceBar", true, false)
	if _resource_bar != null:
		_resource_bar.theme = ThemeBuilder.game_theme


# fundo desenhado no Criador de Arenas -- cobre a tela toda atrás da
# batalha (pixel grande, sem borrar) e esconde o TileMap padrão
func _apply_custom_arena_background():
	var tex = ArenaManager.get_background(PlayerProfile.arena_index)
	if tex == null:
		return
	var layer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var rect = TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tilemap = find_child("arena", false, false)
	if tilemap != null:
		tilemap.visible = false


func _load_arena_middle_scenery():
	pass  # o fundo (inclusive o do Criador de Arenas) agora é posto pelo ArenaBuilder
	var container = get_tree().get_first_node_in_group("arena_middle_container")
	if container == null:
		# cena ainda não tem o container reservado pro cenário trocável --
		# sem problema, continua com o que já estiver fixo na cena
		return

	var arena_index = PlayerProfile.arena_index
	var path = ARENA_MIDDLE_SCENE_PATH % arena_index

	if !ResourceLoader.exists(path):
		print("DEBUG arena middle: ", path, " ainda não existe -- mantendo o cenário padrão")
		return

	var middle_scene = load(path)
	var middle_instance = middle_scene.instantiate()
	container.add_child(middle_instance)

# --- combo de IA: viés (não regra fixa) pra sequências táticas conhecidas ---
var _last_role_play_time: Dictionary = {}  # categoria (int) -> momento (segundos) que foi jogada por último

# combos conhecidos -- jogar uma carta da categoria X recentemente aumenta
# a chance de jogar uma da categoria Y em seguida. Cada combo tem uma
# lógica própria de por que faz sentido junto:
# tanque -> suporte/enxame: escudo na frente, reforço barato ou cura atrás
# aéreo -> enxame: ameaça no alto, volume barato reforçando por baixo
# cerco -> contra-ataque/tanque: quem ataca a base de longe precisa de
#   proteção, senão morre rápido sem terminar o trabalho
# controle -> finalizador/punição: trava/atordoa o inimigo, aproveita a
#   abertura com dano concentrado
# invocador -> suporte: mantém as invocações vivas por mais tempo
# punição -> enxame: reforça o alvo pontual (mata quem bloqueava), aí o
#   enxame consegue atravessar
# construção -> cerco: a construção segura a atenção/dano, o cerco ataca
#   a base sem pressão
const COMBO_TABLE = {
	CardData.CardRole.TANQUE: [CardData.CardRole.SUPORTE, CardData.CardRole.ENXAME],
	CardData.CardRole.AEREO: [CardData.CardRole.ENXAME],
	CardData.CardRole.CERCO: [CardData.CardRole.CONTRA_ATAQUE, CardData.CardRole.TANQUE],
	CardData.CardRole.CONTROLE: [CardData.CardRole.FINALIZADOR, CardData.CardRole.PUNICAO],
	CardData.CardRole.INVOCADOR: [CardData.CardRole.SUPORTE],
	CardData.CardRole.PUNICAO: [CardData.CardRole.ENXAME],
	CardData.CardRole.CONSTRUCAO: [CardData.CardRole.CERCO],
}
const COMBO_FOLLOWUP_WINDOW = 4.0  # segundos após jogar tanque/aéreo que ainda conta como "seguindo o combo"
const COMBO_FOLLOWUP_CHANCE = 0.6  # nem sempre segue o combo, senão fica óbvio/robótico
const COMBO_HOLD_SPELL_CHANCE = 0.5  # chance de segurar o feitiço na mão se tiver finalizador pronto

# quanto tempo (em segundos) o modo vingança dura depois de a base levar dano
const REVENGE_DURATION = 6.0

# teto do recurso do jogador (usado no teto de produção e no máximo da barra visual)
const MAX_MONEY = 100

# tetos individuais por time -- cada um pode ser aumentado pelo próprio módulo
# de espaço (jogador via PlayerProfile, bot via ai_profile), independentemente
var player_max_money: int = MAX_MONEY
var enemy_max_money: int = MAX_MONEY


# chamado por unidades com stores_resource=true, ao nascerem -- aumenta o
# teto de recurso daquele time. Versão inicial: não remove o bônus se a
# unidade morrer, testa com calma se isso te incomodar no jogo
func add_storage_capacity(unit_team, amount: int):
	if unit_team == GameManager.Team.PLAYER:
		player_max_money += amount
	else:
		enemy_max_money += amount

# a cada quantos segundos o recurso sobe, pros dois lados (antes dos módulos
# de produção entrarem em ação) -- MUDA AQUI pra ajustar a taxa de geração
const BASE_PRODUCTION_INTERVAL = 0.25

# quanto o recurso sobe a cada tick de produção
const PRODUCTION_AMOUNT_PER_TICK = 1

# timer de batalha -- 5 minutos, com boost de produção e agressividade da
# IA no último minuto. Se zerar sem ninguém destruir a base do outro, empata
const BATTLE_DURATION = 300.0
# recurso x2 nos 2 minutos finais (a partir de 1:59) -- antes era 1.5x no 0:59
const LAST_MINUTE_THRESHOLD = 120.0
const LAST_MINUTE_PRODUCTION_MULT = 2.0

var _battle_time_remaining: float = BATTLE_DURATION
var _entered_last_minute: bool = false
var _timer_label: Label  # encontrado pelo nome, se existir na cena (não quebra se não tiver)
var _resource_bar: ProgressBar  # encontrado pelo nome -- não usa mais $ResourceBar fixo, já que ela agora vive dentro do HUD


func _ready():
	MusicPlayer.play_battle_music()

	add_to_group("battle_scene")

	# arena 2.0: campo simétrico, 2 torres por lado, caminhos, câmera
	ArenaBuilder.build(self)
	BattleHud.install(self)  # HUD 2.0 preso na tela (mão, recurso, relógio, adversário)
	_show_intro.call_deferred()

	_setup_hud_anchors()

	if !MatchSetup.replay_data.is_empty():
		_setup_replay_mode()
		return

	_battle_time_remaining = BATTLE_DURATION
	_last_base_damage_time = Time.get_ticks_msec() / 1000.0
	_timer_label = find_child("BattleTimerLabel", true, false)  # opcional -- só atualiza se existir na cena

	_load_arena_middle_scenery()

	# taxa base de produção dos dois lados -- os módulos de produção ajustam
	# em cima disso logo abaixo, ANTES de iniciar os timers (senão o primeiro
	# ciclo da partida ignorava o bônus, só valendo a partir do segundo)
	$ProductionTimer.wait_time = BASE_PRODUCTION_INTERVAL
	$EnemyProductionTimer.wait_time = BASE_PRODUCTION_INTERVAL

	# se o menu escolheu um bot pra essa partida, usa ele -- senão, mantém
	# o que estiver fixo no Inspector (útil pra testar um bot específico direto)
	if MatchSetup.next_ai_profile != null:
		ai_profile = MatchSetup.next_ai_profile
		MatchSetup.next_ai_profile = null

	# usa o deck e o nível de carta REAIS do bot (o que ele já evoluiu de
	# verdade) -- não recalibra mais com base no seu nível, senão o que
	# aparece na batalha nunca bate com o que aparece no raio-x do ranking
	if ai_profile != null:
		if BotLearning.is_nemesis_of_player(ai_profile.profile_name):
			BotLearning.consume_nemesis(ai_profile.profile_name)
			# entra "afiado" -- guardou rancor de perder repetido pra você.
			# Só vale PRA ESSA partida (mexe só na cópia carregada em
			# memória, não no traço salvo do bot) -- decide mais rápido e
			# gasta sem segurar tanto, tipo um modo vingança que já começa
			# ligado desde o primeiro segundo
			ai_profile.decision_interval = max(0.5, ai_profile.decision_interval * 0.6)
			ai_profile.min_money_reserve = 0
			_is_nemesis_match = true
		_start_ai_hand()
		_pick_ai_lane()
		_show_opening_greeting()

	_apply_player_base()
	_apply_ai_base()

	# .start() força o timer a recomeçar já com o wait_time novo (já incluindo
	# o ajuste de módulo acima) -- sem isso, o primeiro ciclo da partida
	# herdava o time_left do valor antigo (o que tava salvo na cena antes),
	# causando um pulo estranho só no começo
	$ProductionTimer.start()
	$EnemyProductionTimer.start()

	# sem isso, cada partida nova herdava o dinheiro que sobrou da anterior
	GameManager.player_money = STARTING_MONEY
	GameManager.enemy_money = STARTING_MONEY

	# reembaralha o baralho e monta uma mão nova toda vez que uma partida começa
	DeckManager.start_deck()

	_connect_base_signals()
	_show_opponent_name()
	if _is_nemesis_match:
		_opp_label().text += " 🔥"
	_apply_ai_decision_speed()

	_is_2v2 = MatchSetup.mode == MatchSetup.MODE_2V2
	MatchSetup.mode = MatchSetup.MODE_1V1  # consome -- a próxima partida volta a ser 1v1 se ninguém pedir
	if _is_2v2:
		_setup_2v2()


# configura a cena pra REPRODUZIR um replay salvo, em vez de rodar uma
# partida normal -- instala as bases exatamente como estavam salvas, esconde
# a mão de cartas (não dá pra interagir), e prepara o tocador do log de ações
func _setup_replay_mode():
	is_replay_mode = true

	var data = MatchSetup.replay_data
	MatchSetup.replay_data = {}  # consome -- a próxima partida normal não deve reentrar em modo replay

	_battle_time_remaining = BATTLE_DURATION
	_timer_label = find_child("BattleTimerLabel", true, false)

	_load_arena_middle_scenery()

	if data.get("player_base_path", "") != "" and ResourceLoader.exists(data["player_base_path"]):
		var player_base_data: BaseData = load(data["player_base_path"])
		_install_base_data_on("player_base", player_base_data, data.get("player_base_level", 1))
	if data.get("bot_base_path", "") != "" and ResourceLoader.exists(data["bot_base_path"]):
		var bot_base_data: BaseData = load(data["bot_base_path"])
		_install_base_data_on("enemy_base", bot_base_data, data.get("bot_base_level", 1))

	GameManager.player_money = STARTING_MONEY
	GameManager.enemy_money = STARTING_MONEY
	$ProductionTimer.start()
	$EnemyProductionTimer.start()

	_connect_base_signals()

	var opponent_label = find_child("OpponentNameLabel", true, false)
	if opponent_label != null:
		opponent_label.text = data.get("bot_name", "?")
		opponent_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
		opponent_label.add_theme_font_size_override("font_size", 20)

	# desliga a decisão automática do bot -- as jogadas dele vêm do log
	# gravado, não de uma IA rodando de novo agora
	$Timer.stop()

	# esconde a mão normal de cartas -- não dá pra jogar carta durante um
	# replay, só assistir. No lugar, mostra o deck completo dos dois lados
	# (bot em cima, jogador embaixo) só como referência visual
	for hand_name in ["Button", "Button2", "Button3"]:
		var hand_button = find_child(hand_name, true, false)
		if hand_button != null:
			hand_button.visible = false

	_build_replay_deck_row(data.get("bot_deck_paths", []), true)
	_build_replay_deck_row(data.get("player_deck_paths", []), false)

	match_action_log = data.get("action_log", [])
	_match_start_time = Time.get_ticks_msec() / 1000.0
	_replay_next_action_index = 0


# roda a cada frame durante o replay -- dispara toda ação do log cujo tempo
# gravado já foi alcançado, na ordem, sem pular nenhuma
func _process_replay_playback():
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _match_start_time
	while _replay_next_action_index < match_action_log.size():
		var action = match_action_log[_replay_next_action_index]
		if float(action["time"]) > elapsed:
			break
		_fire_replay_action(action)
		_replay_next_action_index += 1


func _fire_replay_action(action: Dictionary):
	var card_path = action.get("card_path", "")
	if card_path == "" or !ResourceLoader.exists(card_path):
		return
	var card: CardData = load(card_path)
	var position = Vector2(action.get("x", 0.0), action.get("y", 0.0))
	var side = action.get("side", "")
	var team = GameManager.Team.PLAYER if (side == "player" or side == "ally") else GameManager.Team.ENEMY

	if card.is_spell():
		cast_spell(card.spell_data, position, team, card.resource_path)
	else:
		spawn_unit(card.unit_scene, team, position, card)


# fileira de ícones do deck (só visual, sem interação nenhuma) -- usada
# durante o replay pra mostrar as 7 cartas de cada lado, como se estivessem
# jogando de verdade. is_top decide se fica grudada em cima (bot) ou embaixo (jogador)
func _build_replay_deck_row(deck_paths: Array, is_top: bool):
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_TOP_WIDE if is_top else Control.PRESET_BOTTOM_WIDE)
	add_child(row)

	for card_path in deck_paths:
		if card_path == "" or !ResourceLoader.exists(card_path):
			continue
		var card: CardData = load(card_path)
		if card == null or card.icon == null:
			continue

		var icon_rect = TextureRect.new()
		icon_rect.texture = card.icon
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon_rect)


func _apply_player_base():
	var base_data = PlayerProfile.get_equipped_base()
	if base_data == null:
		return  # ainda não escolheu nenhuma -- base fica com o HP padrão genérico

	_install_base_data_on("player_base", base_data, MatchSetup.TOURNAMENT_LEVEL if MatchSetup.tournament else Progresso.tower_level())
	PlayerProfile.record_base_usage(base_data)

	if base_data.base_type == BaseData.BaseType.PRODUCTION:
		$ProductionTimer.wait_time *= (1.0 - base_data.production_speed_boost)
	elif base_data.base_type == BaseData.BaseType.CAPACITY:
		player_max_money += base_data.capacity_bonus

	if base_data.gives_initial_boost:
		_apply_initial_boost($ProductionTimer, base_data, true)


func _apply_ai_base():
	if ai_profile == null or ai_profile.equipped_base == null:
		return
	var base_data = ai_profile.equipped_base

	# nível de base de verdade agora -- upado com o mesmo custo híbrido
	# (ouro + partidas jogadas) que o jogador usa, não mais uma aproximação
	_install_base_data_on("enemy_base", base_data, MatchSetup.TOURNAMENT_LEVEL if MatchSetup.tournament else Progresso.bot_tower_level(ai_profile))

	if base_data.base_type == BaseData.BaseType.PRODUCTION:
		$EnemyProductionTimer.wait_time *= (1.0 - base_data.production_speed_boost)
	elif base_data.base_type == BaseData.BaseType.CAPACITY:
		enemy_max_money += base_data.capacity_bonus

	if base_data.gives_initial_boost:
		_apply_initial_boost($EnemyProductionTimer, base_data, false)


# dinheiro de largada na hora, e/ou produção mais rápida por um tempo que
# reverte sozinha depois -- compartilhada entre jogador e bot, só muda o
# money/timer que cada lado passa
func _apply_initial_boost(production_timer: Timer, base_data: BaseData, is_player: bool):
	if base_data.initial_money_boost > 0:
		if is_player:
			GameManager.player_money += base_data.initial_money_boost
		else:
			GameManager.enemy_money += base_data.initial_money_boost

	if base_data.initial_boost_duration > 0 and base_data.initial_production_speed_mult != 1.0:
		production_timer.wait_time /= base_data.initial_production_speed_mult
		get_tree().create_timer(base_data.initial_boost_duration).timeout.connect(func():
			if is_instance_valid(production_timer):
				production_timer.wait_time *= base_data.initial_production_speed_mult
		)


func _install_base_data_on(group_name: String, base_data: BaseData, level: int = 1):
	# as DUAS torres do lado usam a base equipada; cada uma com uma fração da vida
	for base_node in get_tree().get_nodes_in_group(group_name):
		base_node.install_base_data(base_data, level)
		base_node.scale_hp(ArenaBuilder.TOWER_HP_FRACTION * (0.6 if MatchSetup.rule == 2 else 1.0))


func _show_opponent_name():
	if ai_profile == null:
		return
	_opp_label().text = "%s   🏆 %d\n%s" % [ai_profile.profile_name, ArenaManager.get_trophies(ai_profile.profile_name), Cla.clan_of(ai_profile.profile_name)]
	if MatchSetup.friendly:
		_opp_label().text += "  ·  AMISTOSO"
	_opp_label().add_theme_font_override("font", ThemeDB.fallback_font)
	_opp_label().add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	_opp_label().add_theme_font_size_override("font_size", 20)
	_opp_label().add_theme_color_override("font_outline_color", ThemeBuilder.COLOR_PANEL_BG)
	_opp_label().add_theme_constant_override("outline_size", 4)


func _apply_ai_decision_speed():
	if ai_profile == null:
		return
	$Timer.wait_time = ai_profile.decision_interval


# embaralha o deck do bot numa mão de 3 + fila de 4, igual o jogador --
# sem isso, o bot escolhia direto do deck inteiro toda vez, podendo repetir
# a mesma carta em ticks seguidos sem nenhuma rotação
func _start_ai_hand():
	ai_draw_queue = ai_profile.deck.duplicate()
	ai_draw_queue.shuffle()
	for i in ai_hand.size():
		ai_hand[i] = ai_draw_queue.pop_front()


var damage_to_player_base_by_card: Dictionary = {}  # card_path -> dano acumulado nessa partida
var _last_base_damage_time: float = 0.0  # timestamp do último dano em qualquer base -- usado pra detectar "travamento" (ninguém progredindo)
var damage_to_enemy_base_by_card: Dictionary = {}   # mesma coisa, base do outro lado


# chamado de dentro de unit.gd/projectile.gd toda vez que um ataque atinge
# uma base -- acumula quanto cada CARTA (não unidade individual) já causou
# na base, pra saber depois "qual carta mais machucou" (usado pelo bot pra
# aprender contra-carta). Não faz nada durante replay -- reassistir não deve
# re-registrar isso, mesma trava anti-exploit de sempre
func record_base_damage_by_card(card_path: String, amount: float, hit_player_base: bool):
	if is_replay_mode or card_path == "":
		return
	var dict = damage_to_player_base_by_card if hit_player_base else damage_to_enemy_base_by_card
	dict[card_path] = dict.get(card_path, 0.0) + amount
	_last_base_damage_time = Time.get_ticks_msec() / 1000.0

	# reação por emoji -- levou um golpe pesado de uma vez só na própria
	# base (não acumulado aos poucos), mostra choque/preocupação
	if !hit_player_base and ai_profile != null:
		var enemy_base = get_tree().get_first_node_in_group("enemy_base")
		if enemy_base != null and "max_hp" in enemy_base and enemy_base.max_hp > 0:
			if amount >= enemy_base.max_hp * 0.12:
				_maybe_show_bot_emote(["😰"], 0.5)


# grava uma jogada no log do replay -- não grava nada se já estiver
# REPRODUZINDO um replay (senão ia gravar o replay do replay)
func _record_action(side: String, card: CardData, position: Vector2):
	if is_replay_mode or card == null:
		return
	match_action_log.append({
		"time": (Time.get_ticks_msec() / 1000.0) - _match_start_time,
		"side": side,
		"card_path": card.resource_path,
		"x": position.x,
		"y": position.y,
	})


func _connect_base_signals():
	for t in get_tree().get_nodes_in_group("player_base"):
		t.destroyed.connect(_on_base_destroyed)
		t.damaged.connect(_on_player_base_damaged)
	for t in get_tree().get_nodes_in_group("enemy_base"):
		t.destroyed.connect(_on_base_destroyed)
		t.damaged.connect(_on_enemy_base_damaged)


# ---------------------------------------------------------------- torres
# 2 torres por lado: ganha quem derrubar AS DUAS. Se o tempo acabar, ganha
# quem derrubou mais torres; empatou nisso, ganha quem tirou mais vida no
# total (soma da vida que sobrou nas torres de cada um)
var towers_destroyed = {GameManager.Team.PLAYER: 0, GameManager.Team.ENEMY: 0}


func _alive_towers(team) -> Array:
	var group = "player_base" if team == GameManager.Team.PLAYER else "enemy_base"
	return get_tree().get_nodes_in_group(group).filter(func(t): return is_instance_valid(t) and !t.is_queued_for_deletion() and t.hp > 0)


func _tower_health_fraction(team) -> float:
	var group = "player_base" if team == GameManager.Team.PLAYER else "enemy_base"
	var total = 0.0
	for t in get_tree().get_nodes_in_group(group):
		if is_instance_valid(t) and !t.is_queued_for_deletion() and t.max_hp > 0:
			total += float(t.hp) / t.max_hp
	return total / 2.0


func _on_base_destroyed(team):
	if match_over:
		return
	towers_destroyed[team] += 1
	if _alive_towers(team).is_empty():
		_end_match(team)
		return
	_show_tower_down_banner(team)


func _show_tower_down_banner(team):
	var l = Label.new()
	l.text = "🏚 Torre do bot derrubada!" if team == GameManager.Team.ENEMY else "🏚 Sua torre caiu!"
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.4) if team == GameManager.Team.ENEMY else Color(1, 0.5, 0.45))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = to_local(ArenaBuilder.CENTER) + Vector2(-220, -30)
	l.custom_minimum_size = Vector2(440, 0)
	l.z_index = 100
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.15)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


# tempo acabou: decide pelas torres derrubadas e depois pela vida
func _resolve_time_up():
	var down_mine = towers_destroyed[GameManager.Team.PLAYER]
	var down_bot = towers_destroyed[GameManager.Team.ENEMY]
	if down_bot != down_mine:
		_end_match(GameManager.Team.ENEMY if down_bot > down_mine else GameManager.Team.PLAYER)
		return
	var mine = _tower_health_fraction(GameManager.Team.PLAYER)
	var bot = _tower_health_fraction(GameManager.Team.ENEMY)
	if abs(mine - bot) < 0.01:
		_end_match_as_draw()
	else:
		_end_match(GameManager.Team.ENEMY if bot < mine else GameManager.Team.PLAYER)


# ativa o "modo vingança" por um tempo, se o bot tiver essa estratégia ligada
# -- e acumula o dano causado na base inimiga, pra missão diária de dano
func _on_enemy_base_damaged(amount):
	if ai_profile != null and ai_profile.revenge_mode:
		_revenge_until = Time.get_ticks_msec() / 1000.0 + REVENGE_DURATION
	player_damage_dealt_this_match += amount


# acumula o dano recebido na própria base, pra missão diária de "receber dano"
func _on_player_base_damaged(amount):
	player_damage_received_this_match += amount


func _in_revenge_mode() -> bool:
	return _revenge_until > 0.0 and Time.get_ticks_msec() / 1000.0 < _revenge_until


func _show_replay_ended_screen():
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(240, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "🎬 Fim do Replay"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Assistir de novo não altera suas conquistas."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	vbox.add_child(subtitle)
	vbox.add_child(HSeparator.new())

	var continue_button = Button.new()
	continue_button.text = "Voltar"
	continue_button.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	)
	vbox.add_child(continue_button)


# fim de partida: `team` = lado que PERDEU
# ================================================================ SAIR DA PARTIDA
var _leave_layer: CanvasLayer = null


## quantos troféus custa sair agora (metade de uma derrota); 0 se a partida não vale troféu
func leave_penalty() -> int:
	if ai_profile == null or _is_2v2 or MatchSetup.tournament or MatchSetup.friendly or is_replay_mode:
		return 0
	return int(ceil(ArenaManager.loss_points_for(ai_profile.profile_name, PlayerProfile.player_name) / 2.0))


## botão da setinha: pergunta antes, com a partida pausada
func ask_leave():
	if match_over or _leave_layer != null:
		return
	if is_replay_mode:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	var was_paused = get_tree().paused
	get_tree().paused = true
	_leave_layer = CanvasLayer.new()
	_leave_layer.layer = 95
	_leave_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_leave_layer)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leave_layer.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = ThemeBuilder.game_theme
	_leave_layer.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title = Label.new()
	title.text = "Sair da partida?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	box.add_child(title)
	var info = Label.new()
	var penalty = leave_penalty()
	if MatchSetup.daily:
		info.text = "Sair conta como DERROTA: gasta uma das 3 tentativas do Desafio do Dia."
	elif MatchSetup.tournament:
		info.text = "No torneio, sair conta como DERROTA."
	elif penalty > 0:
		info.text = "Você perde 🏆 %d troféus (metade de uma derrota) e a sequência de vitórias. Não ganha ouro nem baú." % penalty
	else:
		info.text = "Esta partida não vale troféu. Você só não ganha os prêmios."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	box.add_child(info)
	var stay = Button.new()
	stay.text = "Continuar jogando"
	stay.custom_minimum_size.y = 76
	stay.add_theme_font_size_override("font_size", 26)
	stay.pressed.connect(_cancel_leave.bind(was_paused))
	box.add_child(stay)
	var go = Button.new()
	go.text = "Sair mesmo assim"
	go.custom_minimum_size.y = 60
	go.add_theme_font_size_override("font_size", 20)
	go.modulate = Color(1.0, 0.7, 0.65)
	go.pressed.connect(_confirm_leave)
	box.add_child(go)


func _cancel_leave(was_paused: bool):
	if _leave_layer != null:
		_leave_layer.queue_free()
		_leave_layer = null
	get_tree().paused = was_paused


func _confirm_leave():
	if match_over:
		return
	match_over = true
	$Timer.stop()
	var penalty = leave_penalty()
	if penalty > 0:
		ArenaManager.apply_penalty(PlayerProfile.player_name, penalty)
		Progresso.d["streak"] = 0
		Progresso.save()
	if MatchSetup.daily:
		Progresso.daily_result(false)
	elif MatchSetup.tournament:
		Progresso.tournament_result(false)
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _end_match(team):
	if match_over:
		return
	match_over = true
	$Timer.stop()
	get_tree().paused = true  # congela tudo (unidade, física) na hora que a base cai -- só a tela de resultado (marcada como PROCESS_MODE_ALWAYS) continua respondendo

	if is_replay_mode:
		_show_replay_ended_screen()
		return

	var player_won = team == GameManager.Team.ENEMY  # a base destruída era do time inimigo

	# reação por emoji de fim de partida -- vitória (zombando) ou derrota
	# (chateado/bravo), sorteando entre as opções, nem sempre disparando
	if ai_profile != null:
		if player_won:
			_maybe_show_bot_emote(["😞", "😡"], 0.6)
		else:
			_maybe_show_bot_emote(["😂🫵"], 0.6)

	# captura o "antes" de ouro/xp/troféu, pra saber o delta exato depois --
	# mais simples e seguro que mudar a assinatura das funções que já
	# processam isso (evita risco de quebrar quem já chama elas hoje)
	var coins_before = PlayerProfile.coins
	var trophies_before = ArenaManager.get_trophies(PlayerProfile.player_name)
	var nation_xp_before = PlayerProfile.nation_xp.duplicate(true)
	var free_xp_before = PlayerProfile.free_xp

	var match_reward = PlayerProfile.add_match_result(player_won, player_cards_played_this_match)
	var xp_gained = match_reward["xp"]
	PlayerProfile.record_battle_played(player_won)
	PlayerProfile.record_mission_cards_played(player_cards_played_this_match)
	PlayerProfile.record_mission_battle_played()
	PlayerProfile.record_mission_win_streak(player_won)
	PlayerProfile.record_mission_damage_dealt(player_damage_dealt_this_match)
	PlayerProfile.record_mission_damage_received(player_damage_received_this_match)
	if player_won:
		PlayerProfile.record_mission_battle_win()

	# 2v2 é amistoso: dá ouro/XP/missão normalmente, mas NÃO mexe em troféu
	# nem no aprendizado dos bots (seria injusto com eles -- era 2 contra 2)
	if ai_profile != null and !_is_2v2 and !MatchSetup.tournament and !MatchSetup.friendly:
		BotLearning.record_result(ai_profile.profile_name, !player_won, player_cards_played_this_match, true)

		if player_won:
			# bot perdeu -- descobre qual carta do jogador mais machucou a
			# base dele (enemy_base, do ponto de vista dessa cena), pra ele
			# aprender a reagir com uma contra-carta da próxima vez
			var culprit_path = ""
			var culprit_damage = 0.0
			for path in damage_to_enemy_base_by_card:
				if damage_to_enemy_base_by_card[path] > culprit_damage:
					culprit_damage = damage_to_enemy_base_by_card[path]
					culprit_path = path
			if culprit_path != "" and ResourceLoader.exists(culprit_path):
				BotLearning.record_loss_culprit(ai_profile.profile_name, load(culprit_path))

		var winner_name = PlayerProfile.player_name if player_won else ai_profile.profile_name
		var loser_name = ai_profile.profile_name if player_won else PlayerProfile.player_name
		ArenaManager.record_match_points(winner_name, loser_name)
		Journal.record_player_battle_quote(ai_profile.profile_name, player_won)

		var player_deck = DeckManager.full_deck
		var bot_deck = ai_profile.deck
		if player_won:
			SeasonStats.record_match_result(player_deck, bot_deck)
		else:
			SeasonStats.record_match_result(bot_deck, player_deck)

	var coins_gained = PlayerProfile.coins - coins_before
	var trophies_gained = ArenaManager.get_trophies(PlayerProfile.player_name) - trophies_before

	# delta de XP por nação -- só entra no dicionário quem realmente ganhou
	# algo nessa partida (evita listar toda nação que o jogador já tem,
	# a maioria delas não teve nenhum ganho agora)
	var nation_xp_gained: Dictionary = {}
	for nation_name in PlayerProfile.nation_xp:
		var before = nation_xp_before.get(nation_name, 0)
		var delta = PlayerProfile.nation_xp[nation_name] - before
		if delta > 0:
			nation_xp_gained[nation_name] = delta
	var free_xp_gained = PlayerProfile.free_xp - free_xp_before

	_show_result_screen(player_won, coins_gained, xp_gained, trophies_gained, nation_xp_gained, free_xp_gained)


func _show_result_screen(player_won: bool, coins_gained: int, xp_gained: int, trophies_gained: int, nation_xp_gained: Dictionary, free_xp_gained: int, is_draw: bool = false):
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	if is_draw:
		title.text = "EMPATE"
	else:
		title.text = "VITÓRIA!" if player_won else "DERROTA..."
	Sfx.play("vitoria" if (player_won and !is_draw) else "derrota", 0.0, 2.0)
	var remaining_mine = _alive_towers(GameManager.Team.PLAYER).size()
	var jokes: Array
	if is_draw:
		jokes = ["Ninguém arredou o pé.", "Empate é quando os dois perdem tempo."]
	elif player_won:
		jokes = ["Passou o trator!", "Vitória suada, mas é vitória.", "Hoje tem churrasco.", "Nem a vaca viu de onde veio."] if remaining_mine >= 2 else ["Ufa. Foi por um fio de cabelo de bode.", "Ganhou, mas o celeiro ficou torto."]
	else:
		jokes = ["Voltou pro sítio de mãos vazias.", "A cerca não aguentou.", "Dia de cão. De vaca. De tudo.", "Amanhã a gente planta de novo."]
	var joke = Label.new()
	joke.text = jokes[randi() % jokes.size()]
	joke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joke.add_theme_font_size_override("font_size", 20)
	joke.modulate = Color(1, 1, 1, 0.8)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override(
		"font_color",
		Color(0.85, 0.85, 0.85) if is_draw else (Color(1, 0.85, 0.2) if player_won else Color(1, 0.35, 0.35))
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(joke)
	vbox.add_child(HSeparator.new())

	vbox.add_child(_build_reward_row("💰 Ouro", "+%d" % coins_gained, ThemeBuilder.COLOR_GOLD))
	vbox.add_child(_build_reward_row("⭐ XP", "+%d" % xp_gained, ThemeBuilder.COLOR_STAT_VALUE))

	# quebra do XP por nação -- cada uma com um quadradinho da própria cor
	# (ícone entra depois, quando você criar; por enquanto usa a mesma cor
	# já configurada no NationData, ou o cinza padrão se ainda não tiver nada)
	for nation_name in nation_xp_gained:
		vbox.add_child(_build_nation_xp_row(nation_name, nation_xp_gained[nation_name]))
	if free_xp_gained > 0:
		vbox.add_child(_build_nation_xp_row("Livre", free_xp_gained))

	var trophy_text = "+%d" % trophies_gained if trophies_gained >= 0 else str(trophies_gained)
	var trophy_color = Color(0.5, 0.85, 0.5) if trophies_gained >= 0 else Color(0.85, 0.45, 0.45)
	vbox.add_child(_build_reward_row("🏆 Troféus", trophy_text, trophy_color))

	# 2.0: nível do jogador, baú de colheita, sequência e Mascate
	var level_before = Progresso.player_level()
	var prog = Progresso.on_battle_finished(player_won and !is_draw, ai_profile != null and !_is_2v2 and !MatchSetup.tournament and !MatchSetup.friendly, xp_gained)
	for power_text in prog.get("poderes", []):
		vbox.add_child(_build_reward_row("⚡ Poder", power_text, Color(0.8, 0.9, 1.0)))
	if MatchSetup.friendly:
		vbox.add_child(_build_reward_row("🤝 Amistoso", "não vale troféu nem baú", Color(0.8, 0.8, 0.8)))
	if ai_profile != null and !is_replay_mode:
		Gazeta.report_match(ai_profile.profile_name, _kills_player, _kills_enemy, player_won and !is_draw)
	if MatchSetup.daily:
		vbox.add_child(_build_reward_row("📅 Desafio do Dia", Progresso.daily_result(player_won and !is_draw), Color(0.6, 1.0, 0.55)))
	elif MatchSetup.tournament:
		var t_text = Progresso.tournament_result(player_won and !is_draw)
		vbox.add_child(_build_reward_row("🏟 Torneio", t_text, Color(1, 0.85, 0.3)))
	if Progresso.player_level() > level_before:
		vbox.add_child(_build_reward_row("⬆ Subiu de nível!", "Nível %d" % Progresso.player_level(), Color(0.5, 1.0, 0.6)))
	if int(prog["bau"]) >= 0:
		var chest_def = Progresso.CHESTS[int(prog["bau"])]
		vbox.add_child(_build_reward_row("🎁 Ganhou", chest_def["nome"], Color.html(chest_def["cor"])))
	elif prog["sem_espaco"]:
		vbox.add_child(_build_reward_row("🎁 Baús cheios", "abra um pra ganhar outro", Color(0.8, 0.8, 0.8)))
	if int(prog["sequencia"]) >= 2:
		vbox.add_child(_build_reward_row("🔥 Sequência", "%d vitórias%s" % [int(prog["sequencia"]), " (baú melhor!)" if int(prog["sequencia"]) >= 3 else ""], Color(1, 0.6, 0.25)))
	if prog["mascate"]:
		vbox.add_child(_build_reward_row("🧳 O Mascate apareceu!", "corre na Feira (5 min)", Color(0.9, 0.7, 1.0)))

	vbox.add_child(HSeparator.new())

	var replay_button = Button.new()
	replay_button.text = "Salvar Replay"
	replay_button.pressed.connect(func():
		_save_match_replay(player_won)
		replay_button.text = "Replay salvo!"
		replay_button.disabled = true
	)
	vbox.add_child(replay_button)

	replay_button.custom_minimum_size.y = 52
	var continue_button = Button.new()
	continue_button.custom_minimum_size.y = 64
	continue_button.add_theme_font_size_override("font_size", 24)
	continue_button.text = "Continuar"
	continue_button.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	)
	vbox.add_child(continue_button)


func _build_reward_row(label_text: String, value_text: String, value_color: Color) -> Control:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_font_override("font", ThemeDB.fallback_font)
	value.add_theme_color_override("font_color", value_color)
	row.add_child(value)
	return row


# uma linha de XP de nação -- quadradinho colorido (a cor do NationData
# dela, se já tiver cadastrado) no lugar do ícone, que ainda não existe
func _build_nation_xp_row(nation_name: String, amount: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var nation_data = NationDatabase.get_nation_data(nation_name) if nation_name != "Livre" else null
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(14, 14)
	if nation_name == "Livre":
		color_rect.color = Color(0.85, 0.85, 0.85)
	elif nation_data != null:
		color_rect.color = nation_data.color
	else:
		color_rect.color = Color(0.6, 0.6, 0.6)
	row.add_child(color_rect)

	var label = Label.new()
	label.text = nation_name
	label.add_theme_font_size_override("font_size", 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = "+%d XP" % amount
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_VALUE)
	row.add_child(value)

	return row


# versão inicial -- só guarda o essencial (quem jogou, resultado, cartas
# usadas por cada lado). A versão completa (assistir o replay de verdade,
# com o passo a passo da partida) é um item separado, ainda por fazer
func _save_match_replay(player_won: bool):
	var player_base = PlayerProfile.get_equipped_base()
	var bot_base = ai_profile.equipped_base if ai_profile != null else null

	var replay_data = {
		"date": Time.get_datetime_string_from_system(),
		"player_name": PlayerProfile.player_name,
		"bot_name": ai_profile.profile_name if ai_profile != null else "?",
		"player_won": player_won,
		"player_deck": DeckManager.full_deck.map(func(c): return c.card_name if c != null else ""),
		"bot_deck": ai_profile.deck.map(func(c): return c.card_name if c != null else "") if ai_profile != null else [],
		"player_deck_paths": DeckManager.full_deck.map(func(c): return c.resource_path if c != null else ""),
		"bot_deck_paths": ai_profile.deck.map(func(c): return c.resource_path if c != null else "") if ai_profile != null else [],
		"player_base_path": player_base.resource_path if player_base != null else "",
		"bot_base_path": bot_base.resource_path if bot_base != null else "",
		"player_base_level": (MatchSetup.TOURNAMENT_LEVEL if MatchSetup.tournament else Progresso.tower_level()) if player_base != null else 1,
		"bot_base_level": (MatchSetup.TOURNAMENT_LEVEL if MatchSetup.tournament else Progresso.bot_tower_level(ai_profile)) if ai_profile != null else 1,
		"action_log": match_action_log,
	}
	var replays = []
	if FileAccess.file_exists("user://replays.json"):
		var file = FileAccess.open("user://replays.json", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Array:
			replays = parsed
	replays.append(replay_data)
	var out_file = FileAccess.open("user://replays.json", FileAccess.WRITE)
	out_file.store_string(JSON.stringify(replays))


func _process(delta):
	_update_resource_bar()
	_update_battle_timer(delta)
	_poll_ai_defense(delta)

	if is_replay_mode:
		_process_replay_playback()

	if spell_preview != null:
		spell_preview.global_position = get_global_mouse_position()
	if range_preview != null:
		range_preview.global_position = get_global_mouse_position()

	if preview_units.is_empty():
		return

	var mouse_pos = get_global_mouse_position()
	var valid = can_spawn(mouse_pos)
	var color = Color(0.5, 1, 0.5, 0.5) if valid else Color(1, 0.3, 0.3, 0.5)
	var count = preview_units.size()

	for i in count:
		preview_units[i].global_position = mouse_pos + preview_offsets[i]
		preview_units[i].modulate = color


func _update_battle_timer(delta):
	if match_over:
		return

	_battle_time_remaining = max(0.0, _battle_time_remaining - delta)

	if _timer_label != null:
		var minutes = int(_battle_time_remaining) / 60
		var seconds = int(_battle_time_remaining) % 60
		_timer_label.text = "%d:%02d" % [minutes, seconds]
		if _entered_last_minute:
			_timer_label.text += "  x2"
			_timer_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85))

	# entrando nos 2 minutos finais: recurso x2 pros dois lados + IA mais
	# agressiva -- só dispara UMA vez. DIVIDE o wait_time atual (em vez de
	# sobrescrever com o valor base), pra não apagar o bônus de produção da base
	_process_cow_rain(delta)
	if !_entered_last_minute and (_battle_time_remaining < LAST_MINUTE_THRESHOLD or MatchSetup.rule == 1):
		_entered_last_minute = true
		MusicPlayer.play_final_music()  # trilha acelerada nos 2 minutos finais
		$ProductionTimer.wait_time /= LAST_MINUTE_PRODUCTION_MULT
		$EnemyProductionTimer.wait_time /= LAST_MINUTE_PRODUCTION_MULT
		for extra_timer in _extra_production_timers:
			if is_instance_valid(extra_timer):
				extra_timer.wait_time /= LAST_MINUTE_PRODUCTION_MULT
		if ai_profile != null:
			$Timer.wait_time = max(0.3, $Timer.wait_time / 1.5)
		for extra_ai in _extra_ai_controllers:
			if is_instance_valid(extra_ai):
				extra_ai.on_double_time()

	if _battle_time_remaining <= 0.0:
		_resolve_time_up()


# timer zerou sem ninguém destruir a base do outro -- empata a partida.
# de propósito NÃO mexe em troféu/ouro/estatística de nenhum dos dois lados
# (nem ganha nem perde), só mostra o resultado e volta pro menu
func _end_match_as_draw():
	if match_over:
		return
	match_over = true
	$Timer.stop()
	get_tree().paused = true

	if is_replay_mode:
		_show_replay_ended_screen()
		return

	# mesma recompensa de uma DERROTA (nenhum lado destruiu a base do
	# outro, então nenhum ganha o bônus de vitória) -- mesmo padrão de
	# antes/depois usado no fim normal, pra saber o delta exato
	var coins_before = PlayerProfile.coins
	var trophies_before = ArenaManager.get_trophies(PlayerProfile.player_name)
	var nation_xp_before = PlayerProfile.nation_xp.duplicate(true)
	var free_xp_before = PlayerProfile.free_xp

	var match_reward = PlayerProfile.add_match_result(false, player_cards_played_this_match)
	var xp_gained = match_reward["xp"]

	PlayerProfile.record_battle_played(false)
	PlayerProfile.record_mission_cards_played(player_cards_played_this_match)
	PlayerProfile.record_mission_battle_played()
	PlayerProfile.record_mission_win_streak(false)  # empate não é vitória -- quebra a sequência
	PlayerProfile.record_mission_damage_dealt(player_damage_dealt_this_match)
	PlayerProfile.record_mission_damage_received(player_damage_received_this_match)

	var coins_gained = PlayerProfile.coins - coins_before
	var trophies_gained = ArenaManager.get_trophies(PlayerProfile.player_name) - trophies_before

	var nation_xp_gained: Dictionary = {}
	for nation_name in PlayerProfile.nation_xp:
		var before = nation_xp_before.get(nation_name, 0)
		var delta = PlayerProfile.nation_xp[nation_name] - before
		if delta > 0:
			nation_xp_gained[nation_name] = delta
	var free_xp_gained = PlayerProfile.free_xp - free_xp_before

	_show_result_screen(false, coins_gained, xp_gained, trophies_gained, nation_xp_gained, free_xp_gained, true)


func _update_resource_bar():
	if _resource_bar == null:
		return

	_resource_bar.max_value = player_max_money

	if GameManager.player_money >= player_max_money:
		_resource_bar.value = player_max_money
		return

	# fração de progresso até o próximo ponto de recurso, baseada no tempo
	# real restante do timer -- é isso que faz a barra encher de forma
	# contínua, em vez de pular só quando o número inteiro muda
	var fraction = clamp(1.0 - ($ProductionTimer.time_left / $ProductionTimer.wait_time), 0.0, 1.0)
	_resource_bar.value = GameManager.player_money + fraction * PRODUCTION_AMOUNT_PER_TICK


# toda vez que QUALQUER unidade morre (jogador ou inimigo) -- só credita a
# missão diária de "matar unidade X" quando é o time INIMIGO que morreu,
# já que é o jogador quem tem missão diária, não o bot
var _kills_player := 0   # tropas inimigas derrubadas (pro recorde do jornal)
var _kills_enemy := 0


func _on_unit_died(dead_unit_team, dead_unit_card_data):
	if dead_unit_team == GameManager.Team.ENEMY:
		_kills_player += 1
		PlayerProfile.record_mission_unit_killed(dead_unit_card_data)
	else:
		_kills_enemy += 1

	# reação por emoji -- se foi uma unidade IMPORTANTE do próprio bot que
	# morreu (danger_level alto), mostra frustração. Só reage à própria
	# perda, não à do jogador (o bot "comemorar" toda morte seria demais)
	if dead_unit_team == GameManager.Team.ENEMY and ai_profile != null:
		if dead_unit_card_data != null and dead_unit_card_data.danger_level >= 6:
			_maybe_show_bot_emote(["😤"], 0.5)

	# e o oposto -- se foi uma unidade IMPORTANTE do JOGADOR que morreu, o
	# bot reage com surpresa/satisfação de ter conseguido isso
	if dead_unit_team == GameManager.Team.PLAYER and ai_profile != null:
		if dead_unit_card_data != null and dead_unit_card_data.danger_level >= 6:
			_maybe_show_bot_emote(["🫢"], 0.4)


# mostra um emoji reagindo, num cantinho perto da base do bot -- some
# sozinho depois de um tempo. Usado pra dar vida em tempo real durante o
# combate (diferente do bot_quote.gd, que só comenta DEPOIS da partida)
const BOT_EMOTE_COOLDOWN = 6.0  # não deixa reagir de novo rápido demais, senão fica poluído/bobo
var _last_bot_emote_time: float = -999.0

# sorteia UM emoji da lista, e só mostra numa fração das vezes (chance) --
# de propósito não dispara sempre, senão fica repetitivo/robótico. Cada
# gatilho abaixo usa isso, com sua própria chance
# saudação de início de partida -- espera um pouquinho (não seria natural
# aparecer no frame exato zero), e sorteia entre um punhado de emoji neutros/
# animados. Chamada SEM await lá no _ready(), então roda em paralelo sem
# travar o resto da inicialização da cena
func _show_opening_greeting():
	await get_tree().create_timer(randf_range(1.0, 2.5)).timeout
	if ai_profile == null or match_over:
		return
	_maybe_show_bot_emote(["🐱", "😁", "🐻‍❄️", "😃", "🫠", "🙂"], 0.35)


func _maybe_show_bot_emote(options: Array, chance: float):
	if options.is_empty() or randf() >= chance:
		return
	_show_bot_emote(options[randi() % options.size()])


func _show_bot_emote(emoji: String):
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_bot_emote_time < BOT_EMOTE_COOLDOWN:
		return
	_last_bot_emote_time = now

	var enemy_base = get_tree().get_first_node_in_group("enemy_base")
	if enemy_base == null:
		return

	var label = Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	label.global_position = enemy_base.global_position + Vector2(-14, -50)

	# fica parado e bem visível por um tempo antes de começar a subir e
	# desaparecer -- assim "dura mais" de verdade, não só estica o fade
	var tween = create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "position:y", label.position.y - 30, 1.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.8)
	tween.tween_callback(label.queue_free)


# ================================================================ TELA DE "VERSUS" antes da partida
var _intro_layer: CanvasLayer


func _intro_label(parent: Node, text: String, font_size: int, color: Color = Color(1, 1, 1), plain_font: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if plain_font:
		l.add_theme_font_override("font", ThemeDB.fallback_font)
	parent.add_child(l)
	return l


func _intro_side(parent: Node, who: String, color: Color, extra: String = ""):
	_intro_label(parent, who + extra, 38, color)
	_intro_label(parent, "🏆 %d   ·   %s" % [ArenaManager.get_trophies(who), Cla.clan_of(who) if Cla.clan_of(who) != "" else "sem clã"], 22, Color(1, 0.95, 0.8), true)


func _show_intro():
	if MatchSetup.skip_intro or OS.get_environment("CI_MODE") != "" or is_replay_mode or ai_profile == null or match_over:
		return
	_intro_layer = CanvasLayer.new()
	_intro_layer.layer = 90
	_intro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_intro_layer)
	var bg = Button.new()  # a tela inteira é um botão: tocar começa a partida
	bg.flat = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.pressed.connect(_close_intro)
	var shade = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(shade)
	_intro_layer.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.theme = ThemeBuilder.game_theme
	_intro_layer.add_child(center)
	var col = VBoxContainer.new()
	col.custom_minimum_size.x = 620
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var kind = "⚔ BATALHA"
	if MatchSetup.tournament:
		kind = "🏟 " + Progresso.tournament_stage_text() if !MatchSetup.daily else "📅 DESAFIO DO DIA · vitória %d de %d" % [Progresso.daily_wins() + 1, Progresso.DAILY_WINS]
	elif MatchSetup.friendly:
		kind = "🤝 AMISTOSO DE CLÃ"
	elif _is_2v2:
		kind = "👥 2 CONTRA 2"
	_intro_label(col, kind, 26, ThemeBuilder.COLOR_GOLD)
	var arena_i = MatchSetup.arena_override if MatchSetup.arena_override > 0 else ArenaManager.get_player_arena()
	var arena_info = ArenaManager.get_arena_info(arena_i)
	_intro_label(col, "%s %s" % [arena_info.get("emoji", ""), arena_info.get("name", "")], 18, Color(0.85, 0.8, 0.7))

	_intro_side(col, ai_profile.profile_name, Color(1.0, 0.5, 0.45))
	if _is_2v2 and MatchSetup.second_enemy_ai_profile != null:
		_intro_side(col, MatchSetup.second_enemy_ai_profile.profile_name, Color(1.0, 0.5, 0.45))
	_intro_label(col, "VS", 64, Color(1, 0.9, 0.4))
	_intro_side(col, PlayerProfile.player_name, Color(0.5, 0.8, 1.0))
	if _is_2v2 and MatchSetup.ally_ai_profile != null:
		_intro_side(col, MatchSetup.ally_ai_profile.profile_name, Color(0.5, 0.8, 1.0), "  (aliado)")

	var box = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(box)
	var inner = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	var notes: Array = []
	if MatchSetup.rule > 0:
		_intro_label(inner, "🌪 Modificador: " + MatchSetup.RULE_NAMES[MatchSetup.rule], 24, Color(1, 0.8, 1.0))
		_intro_label(inner, MatchSetup.RULE_TEXT[MatchSetup.rule], 17, Color(1, 1, 1), true)
	else:
		_intro_label(inner, "Batalha normal", 24, Color(0.75, 1.0, 0.75))
		_intro_label(inner, "Sem modificador. Recurso em dobro a partir de 1:59.", 17, Color(1, 1, 1), true)
	if MatchSetup.tournament:
		if MatchSetup.daily:
			notes.append("Você joga com o BARALHO DO DIA (emprestado)")
		notes.append("Cartas e torres no nível %d" % MatchSetup.TOURNAMENT_LEVEL)
		notes.append("Não vale troféu")
	elif MatchSetup.friendly or _is_2v2:
		notes.append("Não vale troféu")
	if !MatchSetup.tournament and ai_profile != null:
		notes.append("🏰 Torres: você nv %d · rival nv %d" % [Progresso.tower_level(), Progresso.bot_tower_level(ai_profile)])
	for power in [["ouro2", "Ouro em dobro ligado"], ["xp2", "XP em dobro ligado"], ["sorte", "Ferradura: baú melhor se vencer"]]:
		if Progresso.power_battles(power[0]) > 0:
			notes.append("⚡ " + power[1])
	if int(Progresso.d["streak"]) >= 2 and !MatchSetup.tournament and !MatchSetup.friendly:
		notes.append("🔥 Sequência de %d vitórias" % int(Progresso.d["streak"]))
	if !notes.is_empty():
		_intro_label(inner, "  ·  ".join(notes), 16, Color(1, 0.9, 0.6), true)
	_intro_label(col, "toque pra começar", 18, Color(1, 1, 1, 0.7))

	get_tree().paused = true
	get_tree().create_timer(4.0, true, false, true).timeout.connect(_close_intro)


func _close_intro():
	if _intro_layer == null or !is_instance_valid(_intro_layer):
		return
	_intro_layer.queue_free()
	_intro_layer = null
	if !match_over:
		get_tree().paused = false
	Sfx.play("carta")


var _spawning_companions := false
var _cow_rain_timer := 12.0


# regra "Chuva de vaca": cai uma vaca num ponto aleatório e acerta os DOIS lados
func _process_cow_rain(delta: float):
	if MatchSetup.rule != 3 or match_over:
		return
	_cow_rain_timer -= delta
	if _cow_rain_timer > 0.0:
		return
	_cow_rain_timer = randf_range(14.0, 22.0)
	var cow = Catalogo.card("vaca_cadente")
	if cow == null:
		return
	var sp: SpellData = cow.spell_data.duplicate()
	sp.summon_count = 0
	sp.base_damage_multiplier = 0.0
	var pos = ArenaBuilder.CENTER + Vector2(randf_range(-220, 220), randf_range(-330, 330))
	cast_spell(sp, pos, GameManager.Team.PLAYER)
	cast_spell(sp, pos, GameManager.Team.ENEMY)
	Fx.text(self, to_local(pos) + Vector2(0, -40), "MUUU!", Color(1, 0.9, 0.5), 1.2)
	Sfx.play("vaca", 0.1, 2.0)


# carta com unidades diferentes juntas: os acompanhantes nascem logo atrás
func _spawn_companions(team, spawn_position, card_data: CardData, level_profile: AIProfile):
	_spawning_companions = true
	var total = 0
	for comp in card_data.companions:
		total += int(comp.get("count", 1))
	var back = 30.0 if team == GameManager.Team.PLAYER else -30.0
	var k = 0
	for comp in card_data.companions:
		for j in int(comp.get("count", 1)):
			var off = Vector2((k - (total - 1) * 0.5) * 24.0, back)
			spawn_unit(comp["scene"], team, spawn_position + off, card_data, level_profile)
			k += 1
	_spawning_companions = false


func spawn_unit(unit_scene, team, spawn_position, card_data: CardData = null, level_profile: AIProfile = null):
	if card_data != null and !card_data.companions.is_empty() and !_spawning_companions:
		_spawn_companions(team, spawn_position, card_data, level_profile)
	# instancia a primeira unidade só pra descobrir quantas essa carta deve spawnar
	var first_unit = unit_scene.instantiate()
	var count = 1
	if first_unit.stats != null:
		count = first_unit.stats.unit_count

	# cada time consulta a própria fonte de progresso: o jogador usa o
	# PlayerProfile (progresso salvo dele); o inimigo usa o AIProfile
	# configurado nessa partida (deck e níveis daquele bot específico)
	var mult = 1.0
	var level = 1

	if card_data != null:
		if level_profile != null:
			# bot extra do 2v2 -- usa o nível de carta DELE
			mult = level_profile.get_stat_multiplier(card_data)
			level = level_profile.get_card_level(card_data)
		elif team == GameManager.Team.PLAYER:
			mult = PlayerProfile.get_stat_multiplier(card_data)
			level = PlayerProfile.get_card_level(card_data)
		elif team == GameManager.Team.ENEMY and ai_profile != null:
			mult = ai_profile.get_stat_multiplier(card_data)
			level = ai_profile.get_card_level(card_data)

	# estrelas (carta lapidada com cristal): +3% cada, pra você e pro bot
	if card_data != null:
		if level_profile != null:
			mult *= 1.0 + Progresso.STAR_BOOST * level_profile.get_stars(card_data)
		elif team == GameManager.Team.PLAYER:
			mult *= Progresso.star_mult(card_data)
		elif ai_profile != null:
			mult *= 1.0 + Progresso.STAR_BOOST * ai_profile.get_stars(card_data)

	if MatchSetup.tournament:
		level = MatchSetup.TOURNAMENT_LEVEL  # torneio: todo mundo no mesmo nível
		mult = PlayerProfile.compute_stat_multiplier(level)

	var spawned_units: Array = []
	var _debug_start_time = Time.get_ticks_usec()
	var unit_radius = first_unit._get_own_target_radius() if first_unit.has_method("_get_own_target_radius") else 14.0

	for i in count:
		var unit = first_unit if i == 0 else unit_scene.instantiate()
		unit.team = team
		unit.card_level = level
		if card_data != null:
			unit.card_role = card_data.role
			unit.card_danger_level = card_data.danger_level
			unit.card_data = card_data

		unit.died.connect(_on_unit_died)

		if mult != 1.0 and unit.stats != null:
			# duplica o resource antes de alterar, pra não afetar as OUTRAS unidades
			# desse mesmo tipo que compartilham o .tres original
			unit.stats = unit.stats.duplicate()
			unit.stats.hp = round(unit.stats.hp * mult)
			unit.stats.damage = round(unit.stats.damage * mult)

		var offset = _get_formation_offset(i, count, unit_radius, first_unit.stats.spawn_formation if first_unit.stats != null else 0)
		var raw_position = spawn_position + offset

		# trava CADA unidade dentro da área válida do time dela -- sem isso,
		# só o clique central era conferido, e uma formação espalhada podia
		# nascer com alguma unidade da ponta fora da área (sem navegação
		# válida, ficando parada pra sempre). EXCETO se a carta tiver
		# can_spawn_anywhere -- aí a intenção é justamente nascer fora da
		# área normal, então não trava nada
		if unit.stats != null and unit.stats.can_spawn_anywhere:
			unit.global_position = raw_position
		else:
			var team_area = spawn_player_area if team == GameManager.Team.PLAYER else spawn_enemy_area
			unit.global_position = _clamp_to_area(raw_position, team_area)

		add_child(unit)
		spawned_units.append(unit)

		# reforço aéreo: fica "pousando" por um tempo -- não anda nem ataca,
		# mas continua atacável normalmente (mesmo mecanismo de STUN/FREEZE,
		# só que reaproveitado aqui pra simular o avião descendo)
		if unit.stats != null and unit.stats.landing_duration > 0:
			unit.apply_incapacitate(unit.stats.landing_duration)
			unit.modulate = Color(1, 1, 1, 0.6)  # levemente transparente enquanto pousa, sinal visual claro
			var landing_tween = create_tween()
			landing_tween.tween_property(unit, "modulate", Color(1, 1, 1, 1), unit.stats.landing_duration)

	var _debug_elapsed_ms = (Time.get_ticks_usec() - _debug_start_time) / 1000.0

	# vincula as unidades da mesma leva entre si, se a carta tiver essa habilidade
	if first_unit.stats != null and first_unit.stats.is_linked:
		for unit in spawned_units:
			unit.linked_units = spawned_units.filter(func(u): return u != unit)


func can_spawn(pos, area = spawn_player_area):
	var shape = area.shape
	var local_pos = area.to_local(pos)
	return shape.get_rect().has_point(local_pos)


# instancia a unidade só pra espiar o stats dela (sem entrar na árvore de
# verdade) e conferir se ela pode nascer em qualquer lugar do mapa
func _card_allows_spawn_anywhere(card_data: CardData) -> bool:
	if card_data.unit_scene == null:
		return false
	var temp = card_data.unit_scene.instantiate()
	var allows = temp.stats != null and temp.stats.can_spawn_anywhere
	temp.queue_free()
	return allows


func _is_base(body) -> bool:
	return body.is_in_group("enemy_base") or body.is_in_group("player_base")


func _random_point_in_area(area: CollisionShape2D) -> Vector2:
	var rect = area.shape.get_rect()
	var local_point = Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)
	return area.to_global(local_point)


func _is_building_card(card: CardData) -> bool:
	if card.unit_scene == null:
		return false
	var temp = card.unit_scene.instantiate()
	var is_building = temp.stats != null and temp.stats.unit_type == UnitData.UnitType.BUILDING
	temp.queue_free()
	return is_building


# constrói perto do centro da própria área de spawn, em vez de qualquer
# canto aleatório -- construção não anda, a posição é permanente e importa
# de verdade. Arquétipo Estrutural fica ainda mais centralizado/protegido;
# os outros têm mais variação ao redor do centro, mas continuam mais perto
# do meio do que o sorteio totalmente aberto de antes
func _get_building_placement(area: CollisionShape2D, archetype: int) -> Vector2:
	var rect = area.shape.get_rect()
	var center_local = rect.position + rect.size / 2.0
	var spread_fraction = 0.15 if archetype == AIProfile.Archetype.ESTRUTURAL else 0.35
	var spread = rect.size * spread_fraction
	var local_point = Vector2(
		center_local.x + randf_range(-spread.x, spread.x),
		center_local.y + randf_range(-spread.y, spread.y)
	)
	return area.to_global(local_point)


# feitiço ofensivo (sem ameaça pra reagir): procura o maior aglomerado de
# unidades inimigas perto uma da outra e mira ali -- se não tiver nenhum
# aglomerado (campo vazio), mira direto na base oposta. Sempre com uma
# pitada de aleatoriedade (chance de ignorar tudo isso e mirar num ponto
# qualquer), pra não ficar 100% previsível
# mira só em TROPA de verdade -- nunca ponto aleatório, nunca a base, nunca
# mapa vazio. Procura o maior aglomerado; se só tiver uma unidade sozinha,
# mira nela mesma. Se não tiver NENHUMA tropa inimiga em campo, devolve
# Vector2.INF como sinal de "sem alvo válido agora" -- quem chama essa
# função decide não gastar o feitiço à toa nesse caso
# viés (não regra fixa) que favorece sequências táticas conhecidas -- não
# precisa seguir sempre, só ter mais chance de acontecer quando dá certo:
# 1) tanque jogado recentemente puxa suporte ou enxame em seguida
# 2) segura o feitiço na mão se tiver um finalizador pronto pra jogar --
#    prefere desenvolver o ataque primeiro, guardando o feitiço pra fechar
const OPENING_WINDOW_SECONDS = 12.0  # primeiros segundos da partida -- janela onde a "assinatura" de abertura do arquétipo entra em ação


func _get_match_elapsed() -> float:
	return BATTLE_DURATION - _battle_time_remaining


# alguns arquétipos têm um jeito reconhecível de abrir a partida -- dá pra
# cada confronto uma "sensação" diferente logo de cara, sem mexer em nada
# estrutural. Só atua na janela de abertura, e só quando a escolha já não
# veio de uma defesa contra ameaça real (essa sempre tem prioridade)
func _apply_opening_signature(chosen: CardData, affordable: Array[CardData]) -> CardData:
	if ai_profile == null or _get_match_elapsed() > OPENING_WINDOW_SECONDS:
		return chosen

	match ai_profile.archetype:
		AIProfile.Archetype.IMPULSIVO, AIProfile.Archetype.ATACA_TUDO:
			# abre rápido e barato -- não segura nada, quer ação já
			if affordable.is_empty():
				return chosen
			var cheapest = affordable[0]
			for card in affordable:
				if card.cost < cheapest.cost:
					cheapest = card
			return cheapest

		AIProfile.Archetype.PERFECCIONISTA, AIProfile.Archetype.POUPADOR, AIProfile.Archetype.ACUMULADOR:
			# segura o início -- só joga se for algo que realmente valha a
			# pena (carta mais cara), senão prefere não jogar nada ainda
			if chosen != null and chosen.cost < 40:  # custo vai de 0 a 100
				return null

	return chosen


const STALEMATE_IMPATIENCE_SECONDS = 22.0  # quanto tempo sem dano em qualquer base até os impacientes começarem a forçar jogada


const MISTAKE_CHANCE_BASE_ARENA = 0.15  # chance de "perder o timing" na Arena 1
const MISTAKE_CHANCE_DECAY_PER_ARENA = 0.025  # reduz um pouco a cada arena acima da 1


# curva de dificuldade suave -- bot em arena baixa perde o timing de defesa
# de vez em quando (não é "burrice", é só reagir um pouco depois da conta),
# e isso vai sumindo conforme a arena sobe, até ficar bem raro nas altas
func _get_mistake_chance() -> float:
	if ai_profile == null:
		return 0.0
	var bot_arena = ArenaManager.get_participant_arena(ai_profile.profile_name)
	var chance = MISTAKE_CHANCE_BASE_ARENA - (bot_arena - 1) * MISTAKE_CHANCE_DECAY_PER_ARENA
	return clamp(chance, 0.0, MISTAKE_CHANCE_BASE_ARENA)


func _is_impatient_archetype() -> bool:
	if ai_profile == null:
		return false
	return ai_profile.archetype == AIProfile.Archetype.IMPULSIVO or ai_profile.archetype == AIProfile.Archetype.ATACA_TUDO


# se ninguém tomou dano de base há um tempo (partida "travada", sem
# ninguém progredindo), arquétipos impacientes começam a forçar alguma
# jogada -- mesmo que não fosse a escolha "ideal" deles nesse momento.
# Diferente do último minuto (que é igual pra todo mundo), esse é só pra
# quem tem personalidade de propósito impaciente
func _apply_stalemate_impatience(chosen: CardData, affordable: Array[CardData]) -> CardData:
	if chosen != null or !_is_impatient_archetype() or affordable.is_empty():
		return chosen

	var since_damage = (Time.get_ticks_msec() / 1000.0) - _last_base_damage_time
	if since_damage < STALEMATE_IMPATIENCE_SECONDS:
		return chosen

	return affordable[randi() % affordable.size()]


func _apply_combo_bias(chosen: CardData, affordable: Array[CardData]) -> CardData:
	if chosen == null:
		return chosen

	for trigger_role in COMBO_TABLE:
		var last_play = _last_role_play_time.get(trigger_role, -999.0)
		var since_play = Time.get_ticks_msec() / 1000.0 - last_play
		# Combinador puxa mais forte pro combo -- é a identidade dele,
		# então a chance dele é maior que o padrão dos outros arquétipos
		var followup_chance = 0.9 if (ai_profile != null and ai_profile.archetype == AIProfile.Archetype.COMBINADOR) else COMBO_FOLLOWUP_CHANCE
		if since_play < COMBO_FOLLOWUP_WINDOW and randf() < followup_chance:
			var followup_roles: Array = COMBO_TABLE[trigger_role]
			var followups: Array[CardData] = []
			for card in affordable:
				if card.role in followup_roles:
					followups.append(card)
			if !followups.is_empty():
				return followups[randi() % followups.size()]

	if chosen.is_spell() and randf() < COMBO_HOLD_SPELL_CHANCE:
		var has_finisher = false
		for card in affordable:
			if card.role == CardData.CardRole.FINALIZADOR:
				has_finisher = true
				break
		if has_finisher:
			var non_spell_options: Array[CardData] = []
			for card in affordable:
				if !card.is_spell():
					non_spell_options.append(card)
			if !non_spell_options.is_empty():
				return non_spell_options[randi() % non_spell_options.size()]

	return chosen


func _get_offensive_spell_target(caster_team) -> Vector2:
	# se a base oposta estiver bem fraca, prioriza terminar o serviço --
	# não 100% das vezes (senão fica óbvio/robótico demais), mas na maioria
	var opposing_base_group = "player_base" if caster_team == GameManager.Team.ENEMY else "enemy_base"
	var target_base = null
	for t in get_tree().get_nodes_in_group(opposing_base_group):
		if target_base == null or t.hp < target_base.hp:
			target_base = t  # a torre mais fraca
	if target_base != null and "hp" in target_base and "max_hp" in target_base and target_base.max_hp > 0:
		var hp_fraction = float(target_base.hp) / target_base.max_hp
		if hp_fraction < 0.3 and randf() < 0.7:
			return target_base.global_position

	var all_targets: Array = []
	for body in get_tree().get_nodes_in_group("damageable"):
		if !("team" in body) or body.team == caster_team or _is_base(body):
			continue
		all_targets.append(body)

	if all_targets.is_empty():
		return Vector2.INF

	var best_center = null
	var best_count = 0
	for body in all_targets:
		var nearby_count = 0
		for other in all_targets:
			if other != body and body.global_position.distance_to(other.global_position) <= 80.0:
				nearby_count += 1
		if nearby_count > best_count:
			best_count = nearby_count
			best_center = body.global_position

	if best_center != null:
		return best_center

	# nenhum aglomerado (só tem unidade sozinha, sem vizinho perto) --
	# mira na primeira tropa que achou mesmo assim, nunca no vazio
	return all_targets[0].global_position


# true se alguma unidade do jogador estiver perto o bastante da base inimiga
# pra ser considerada uma ameaça (usado pelos bots defensivos/reativos)
# true se alguma unidade de um time específico estiver perto o bastante de
# uma base específica -- função genérica, usada tanto pelo bot (ameaça na
# base dele) quanto pelo observador de comportamento (ameaça na sua própria)
func _has_threat_near_base(base_group: String, threat_team) -> bool:
	return _get_nearest_threat(base_group, threat_team) != null


# devolve a unidade inimiga mais perto da base indicada, dentro do raio de
# ameaça -- ou null se não tiver nenhuma. Diferente de _has_threat_near_base
# (só diz "tem ameaça, sim/não"), essa dá a POSIÇÃO e a CATEGORIA de quem tá
# atacando, pra IA conseguir escolher a carta certa e defender no lugar certo
func _get_nearest_threat(base_group: String, threat_team, radius: float = THREAT_DETECTION_RADIUS) -> Node:
	var towers = get_tree().get_nodes_in_group(base_group)
	if towers.is_empty():
		return null

	var closest = null
	var closest_dist = radius

	for body in get_tree().get_nodes_in_group("damageable"):
		if !("team" in body) or body.team != threat_team:
			continue
		for base_node in towers:
			var dist = body.global_position.distance_to(base_node.global_position)
			if dist <= closest_dist:
				closest_dist = dist
				closest = body

	return closest


func _has_incoming_threat() -> bool:
	return _has_threat_near_base("enemy_base", GameManager.Team.PLAYER)


func _on_timer_timeout():
	if match_over:
		return
	if ai_profile == null or ai_profile.deck.is_empty():
		return

	# nunca gasta a reserva mínima configurada pra esse bot -- exceto se estiver
	# no modo vingança (levou dano recente e ignora a reserva por um tempo)
	# ou nos minutos finais (x2, todo mundo joga tudo que tem no fim)
	var reserve = 0 if (_in_revenge_mode() or _entered_last_minute) else ai_profile.min_money_reserve
	var spendable = GameManager.enemy_money - reserve

	var affordable: Array[CardData] = []
	var affordable_ignoring_reserve: Array[CardData] = []
	for card in ai_hand:
		if card == null:
			continue
		if spendable >= card.cost:
			affordable.append(card)
		if GameManager.enemy_money >= card.cost:
			affordable_ignoring_reserve.append(card)

	# 1) DEFESA -- lê o campo inteiro (BattleBrain). Defesa ignora a reserva:
	# a reserva existe justamente pra ter dinheiro na hora de defender.
	# Bot que "não reage por personalidade" ainda defende, mas com mais erro
	var mistake = _get_mistake_chance()
	if !ai_profile.reacts_to_threats:
		mistake = min(0.5, mistake + 0.25)
	var defense = BattleBrain.choose_defense(get_tree(), GameManager.Team.ENEMY, affordable_ignoring_reserve,
		ai_hand, GameManager.enemy_money, enemy_max_money, spawn_enemy_area, self, mistake)
	if BattleBrain.debug_log:
		print("IA turno: $", GameManager.enemy_money, " reserva=", reserve, " mão=", ai_hand.map(func(c): return (c.card_name + ":" + str(c.cost)) if c else "null"), " pagáveis=", affordable.size(), " defesa=", defense.keys())
	if defense.get("wait", false):
		return  # segurando dinheiro pra carta certa de defesa
	if defense.has("card"):
		_ai_play_card(defense["card"], defense["pos"])
		return

	# 2) JOGADA PROATIVA -- personalidade do bot + vieses de combo/abertura
	var chosen: CardData = ai_profile.choose_card(affordable)
	chosen = _apply_combo_bias(chosen, affordable)
	chosen = _apply_opening_signature(chosen, affordable)
	chosen = _apply_stalemate_impatience(chosen, affordable)

	if chosen == null:
		return

	var target_pos: Vector2 = Vector2.INF
	if chosen.is_spell() and chosen.spell_data != null and BattleBrain.is_summon_spell(chosen.spell_data):
		# feitiço de invocação: joga como se fosse tropa, na frente do campo dele
		target_pos = BattleBrain.offensive_position(chosen, null, GameManager.Team.ENEMY, get_tree(), spawn_enemy_area, self, _ai_lane_x)
	elif chosen.is_spell():
		# feitiço só sai se gerar valor de verdade -- senão tenta outra carta
		target_pos = BattleBrain.proactive_spell_target(get_tree(), chosen, GameManager.Team.ENEMY)
		if target_pos == Vector2.INF:
			var non_spells: Array[CardData] = []
			for card in affordable:
				if !card.is_spell():
					non_spells.append(card)
			if non_spells.is_empty():
				return  # guarda o feitiço (e o dinheiro) pra depois
			chosen = ai_profile.choose_card(non_spells)
			if chosen == null:
				return

	if !chosen.is_spell():
		var stats = DeckBuilder.get_unit_stats(chosen)
		if _card_allows_spawn_anywhere(chosen) and randf() < 0.6:
			target_pos = _choose_offensive_anywhere_position()
		elif _is_building_card(chosen):
			target_pos = _get_building_placement(spawn_enemy_area, ai_profile.archetype)
		else:
			target_pos = BattleBrain.offensive_position(chosen, stats, GameManager.Team.ENEMY, get_tree(), spawn_enemy_area, self, _ai_lane_x)
			if randf() < 0.15:
				_pick_ai_lane()  # de vez em quando muda de rota

	_ai_play_card(chosen, target_pos)


var _ai_lane_x: float = 360.0

# ---------------------------------------------------------------- 2v2
const TWO_V_TWO_BASE_HP_MULT = 1.6  # 2 atacando a mesma base -- mais vida pra partida não acabar em 1 minuto
var _is_2v2: bool = false
var _extra_ai_controllers: Array = []
var _extra_production_timers: Array = []  # reservado (os bots extras têm timer próprio)


func _setup_2v2():
	var ally: AIProfile = MatchSetup.ally_ai_profile
	var enemy2: AIProfile = MatchSetup.second_enemy_ai_profile
	MatchSetup.ally_ai_profile = null
	MatchSetup.second_enemy_ai_profile = null

	# o bot principal ataca por uma rota; o segundo inimigo pela outra
	var rect = spawn_enemy_area.shape.get_rect()
	var left = spawn_enemy_area.to_global(rect.position).x
	var right = spawn_enemy_area.to_global(rect.position + rect.size).x
	var main_frac = inverse_lerp(left, right, _ai_lane_x) if right != left else 0.5
	var second_frac = 0.78 if main_frac < 0.5 else 0.22

	if ally != null and !ally.deck.is_empty():
		var c = BotController.new()
		c.name = "AllyBot"
		c.setup(self, ally, GameManager.Team.PLAYER, spawn_player_area, [0.22, 0.78][randi() % 2])
		add_child(c)
		_extra_ai_controllers.append(c)
	if enemy2 != null and !enemy2.deck.is_empty():
		var c2 = BotController.new()
		c2.name = "EnemyBot2"
		c2.setup(self, enemy2, GameManager.Team.ENEMY, spawn_enemy_area, second_frac)
		add_child(c2)
		_extra_ai_controllers.append(c2)

	for group in ["player_base", "enemy_base"]:
		var b = get_tree().get_first_node_in_group(group)
		if b != null and b.has_method("scale_hp"):
			b.scale_hp(TWO_V_TWO_BASE_HP_MULT)

	var label = find_child("OpponentNameLabel", true, false)
	if label != null:
		var enemy_names = ai_profile.profile_name if ai_profile != null else "?"
		if enemy2 != null:
			enemy_names += " + " + enemy2.profile_name
		label.text = "👥 " + enemy_names
	var ally_label = Label.new()
	ally_label.text = "🤝 Aliado: " + (ally.profile_name if ally != null else "—")
	ally_label.add_theme_font_size_override("font_size", 18)
	ally_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	ally_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	ally_label.add_theme_constant_override("outline_size", 4)
	var player_base = get_tree().get_first_node_in_group("player_base")
	if player_base != null:
		ally_label.position = player_base.global_position + Vector2(-80, 50)
	add_child(ally_label)


# nome flutuante rápido de quem jogou (só nos bots do 2v2, pra você saber
# se foi seu aliado ou qual dos dois inimigos)
func show_bot_play_tag(bot_name: String, pos: Vector2, team):
	var l = Label.new()
	l.text = bot_name
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0) if team == GameManager.Team.PLAYER else Color(1.0, 0.6, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-30, -40)
	l.z_index = 50
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "position:y", l.position.y - 25, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
var _ai_defense_accum: float = 0.0


# checagem de defesa mais frequente que a decisão normal do bot -- ele não
# precisa esperar o "turno" dele (2-3s) pra reagir a um ataque chegando.
# O intervalo ainda depende do ritmo do bot (bot lento reage mais devagar)
func _poll_ai_defense(delta):
	if match_over or is_replay_mode or ai_profile == null or ai_profile.deck.is_empty():
		return
	_ai_defense_accum += delta
	var interval = clamp(ai_profile.decision_interval * 0.4, 0.6, 1.5)
	if _ai_defense_accum < interval:
		return
	_ai_defense_accum = 0.0
	var affordable: Array[CardData] = []
	for card in ai_hand:
		if card != null and GameManager.enemy_money >= card.cost:
			affordable.append(card)
	var mistake = _get_mistake_chance() + (0.0 if ai_profile.reacts_to_threats else 0.3)
	var defense = BattleBrain.choose_defense(get_tree(), GameManager.Team.ENEMY, affordable,
		ai_hand, GameManager.enemy_money, enemy_max_money, spawn_enemy_area, self, min(mistake, 0.6))
	if defense.has("card"):
		_ai_play_card(defense["card"], defense["pos"])


func _pick_ai_lane():
	var rect = spawn_enemy_area.shape.get_rect()
	var left = spawn_enemy_area.to_global(rect.position).x
	var right = spawn_enemy_area.to_global(rect.position + rect.size).x
	var lanes = [lerp(left, right, 0.22), lerp(left, right, 0.5), lerp(left, right, 0.78)]
	_ai_lane_x = lanes[randi() % lanes.size()]


# paga, gira a mão e joga de fato -- SÓ chamada quando já existe alvo/posição
# válida (antes o dinheiro e a carta eram consumidos ANTES de saber se o
# feitiço tinha alvo, e às vezes o bot "gastava" sem lançar nada)
func _ai_play_card(chosen: CardData, target_pos: Vector2):
	if BattleBrain.debug_log:
		print("IA tenta: ", chosen.card_name if chosen else "null", " pos=", target_pos, " $", GameManager.enemy_money)
	if chosen == null or target_pos == Vector2.INF or GameManager.enemy_money < chosen.cost:
		return
	GameManager.enemy_money -= chosen.cost
	SeasonStats.record_play(chosen)

	if chosen.role in COMBO_TABLE:
		_last_role_play_time[chosen.role] = Time.get_ticks_msec() / 1000.0

	if ai_profile != null:
		BotLearning.record_card_played(ai_profile.profile_name, chosen)

	var hand_index = ai_hand.find(chosen)
	if hand_index != -1:
		ai_draw_queue.push_back(chosen)
		ai_hand[hand_index] = ai_draw_queue.pop_front()

	if chosen.is_spell():
		cast_spell(chosen.spell_data, target_pos, GameManager.Team.ENEMY, chosen.resource_path)
	else:
		spawn_unit(chosen.unit_scene, GameManager.Team.ENEMY, target_pos, chosen)
	_record_action("bot", chosen, target_pos)


# escolhe, entre as cartas pagáveis, uma que vence a categoria da ameaça na
# teia de afinidades -- devolve null se nenhuma bater (aí quem chamou cai
# pra escolha normal do bot)
func _choose_counter_card(affordable: Array[CardData], threat_role: int, threat_danger: int = 3) -> CardData:
	var counters: Array[CardData] = []
	for card in affordable:
		if CardData.role_beats(card.role, threat_role):
			counters.append(card)

	if !counters.is_empty():
		# ameaça pouco perigosa: qualquer contra-categoria serve, escolhe à toa
		# (mantém a variedade que já existia antes)
		if threat_danger < 6:
			return counters[randi() % counters.size()]

		# ameaça séria: entre as que já contra-categorizam, pega a MAIS FORTE
		# em vez de qualquer uma -- não é hora de mandar a mais fraquinha
		var strongest = counters[0]
		var strongest_power = BotSimulator._estimate_card_power(strongest)
		for card in counters:
			var power = BotSimulator._estimate_card_power(card)
			if power > strongest_power:
				strongest = card
				strongest_power = power
		return strongest

	# não tem contra-categoria nenhuma disponível AGORA -- se a ameaça for
	# muito perigosa (nível alto), ainda assim manda a carta mais forte que
	# der pra pagar, em vez de simplesmente desistir e jogar carta qualquer
	if threat_danger >= 8 and !affordable.is_empty():
		var emergency_pick = affordable[0]
		var emergency_power = BotSimulator._estimate_card_power(emergency_pick)
		for card in affordable:
			var power = BotSimulator._estimate_card_power(card)
			if power > emergency_power:
				emergency_pick = card
				emergency_power = power
		return emergency_pick

	return null


# posição de defesa: o mais perto possível da ameaça, mas sem sair da área
# de spawn válida do bot (clamp simples nos dois eixos)
func _defensive_spawn_position(threat: Node) -> Vector2:
	return _clamp_to_area(threat.global_position, spawn_enemy_area)


# posição ofensiva pra carta que permite jogar em qualquer lugar -- prioriza
# sobretudo perto da BASE do jogador (mais agressivo), com chance menor de
# ser perto de alguma unidade dele em campo (pra "flanquear"/reforçar um
# combate já em andamento). Sem base nem unidade nenhuma em campo (raro),
# cai pra um ponto qualquer dentro da própria área do jogador
func _choose_offensive_anywhere_position() -> Vector2:
	var towers = get_tree().get_nodes_in_group("player_base")
	var player_base = towers[randi() % towers.size()] if !towers.is_empty() else null

	if player_base != null and randf() < 0.7:
		return player_base.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	var player_units: Array = []
	for unit in get_tree().get_nodes_in_group("damageable"):
		if "team" in unit and unit.team == GameManager.Team.PLAYER and !unit.is_in_group("player_base"):
			player_units.append(unit)

	if !player_units.is_empty():
		var target_unit = player_units[randi() % player_units.size()]
		return target_unit.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	if player_base != null:
		return player_base.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	return _random_point_in_area(spawn_player_area)


# trava uma posição dentro dos limites de uma área de spawn -- usado tanto
# pra defesa da IA quanto pra garantir que NENHUMA unidade de uma formação
# (mesmo as das pontas, mais espalhadas) nasça fora da área válida
func _clamp_to_area(pos: Vector2, area) -> Vector2:
	var local_pos = area.to_local(pos)
	var shape = area.shape

	if shape is RectangleShape2D:
		var rect = shape.get_rect()
		local_pos.x = clamp(local_pos.x, rect.position.x, rect.position.x + rect.size.x)
		local_pos.y = clamp(local_pos.y, rect.position.y, rect.position.y + rect.size.y)

	return area.to_global(local_pos)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_confirm_placement_at(get_global_mouse_position())


# tenta confirmar o posicionamento da carta selecionada nessa posição --
# devolve true se conseguiu (gastou o custo e colocou/lançou de verdade).
# Chamada tanto pelo toque clássico no campo (_unhandled_input acima)
# quanto pelo soltar o dedo no arrastar (ver card_button.gd)
func try_confirm_placement_at(click_pos: Vector2) -> bool:
	if is_replay_mode or match_over:
		return false
	if selected_card == null:
		return false
	if GameManager.player_money < selected_card.cost:
		_flash_insufficient_funds()
		return false

	# captura o estado ANTES de gastar, pro observador de comportamento
	var money_before = GameManager.player_money
	var hand_before = DeckManager.hand.duplicate()
	var was_threatened = _has_threat_near_base("player_base", GameManager.Team.ENEMY)

	if selected_card.is_spell():
		GameManager.player_money -= selected_card.cost
		cast_spell(selected_card.spell_data, click_pos, GameManager.Team.PLAYER, selected_card.resource_path)
	else:
		# impede unidade de nascer fora da área -- exceto se a carta
		# tiver can_spawn_anywhere (ex: reforço que cai em qualquer lugar)
		var spawn_allowed = can_spawn(click_pos)
		var allows_anywhere = _card_allows_spawn_anywhere(selected_card)

		if !spawn_allowed and !allows_anywhere:
			return false

		GameManager.player_money -= selected_card.cost
		spawn_unit(
			selected_card.unit_scene,
			GameManager.Team.PLAYER,
			click_pos,
			selected_card
		)

	PlayerBehaviorProfiler.record_play(selected_card, money_before, hand_before, was_threatened)
	player_cards_played_this_match.append(selected_card)
	_record_action("player", selected_card, click_pos)
	PlayerProfile.record_card_usage(selected_card)
	SeasonStats.record_play(selected_card)

	if selected_hand_index >= 0:
		DeckManager.play_card(selected_hand_index)
	selected_card = null
	selected_hand_index = -1
	for p in preview_units:
		p.queue_free()
	preview_units.clear()
	preview_offsets.clear()
	if range_preview != null:
		range_preview.queue_free()
		range_preview = null
	if spell_preview != null:
		spell_preview.queue_free()
		spell_preview = null

	return true


func _on_production_timer_timeout():
	GameManager.player_money = min(GameManager.player_money + PRODUCTION_AMOUNT_PER_TICK, player_max_money)


func _on_enemy_production_timer_timeout():
	GameManager.enemy_money = min(GameManager.enemy_money + PRODUCTION_AMOUNT_PER_TICK, enemy_max_money)


func select_card(card_data: CardData, hand_index: int = -1):
	selected_card = card_data
	selected_hand_index = hand_index

	for p in preview_units:
		p.queue_free()
	preview_units.clear()
	preview_offsets.clear()

	if spell_preview != null:
		spell_preview.queue_free()
		spell_preview = null

	if range_preview != null:
		range_preview.queue_free()
		range_preview = null

	if card_data.is_spell():
		spell_preview = SpellAreaPreview.new()
		spell_preview.radius = card_data.spell_data.radius if card_data.spell_data != null else 80.0
		if card_data.spell_data != null and (card_data.spell_data.affects_allies or !card_data.spell_data.affects_enemies):
			spell_preview.color = Color(0.4, 1.0, 0.5)  # feitiço de aliado = verde
		add_child(spell_preview)
		return

	var first = card_data.unit_scene.instantiate()
	# círculo de alcance: até onde a defesa/atirador acerta (ou até onde cura)
	if first.stats != null:
		var reach = 0.0
		var ring_color = Color(1.0, 0.85, 0.3)
		if first.stats.is_ranged and first.stats.damage > 0:
			reach = first.stats.attack_range + 14.0
		elif first.stats.can_heal_allies:
			reach = first.stats.heal_aura_radius
			ring_color = Color(0.4, 1.0, 0.5)
		elif first.stats.forces_aggro:
			reach = first.stats.taunt_radius
			ring_color = Color(1.0, 0.5, 0.5)
		if reach > 0.0:
			range_preview = SpellAreaPreview.new()
			range_preview.radius = reach
			range_preview.color = ring_color
			range_preview.fill = 0.08
			add_child(range_preview)
	var count = 1
	if first.stats != null:
		count = first.stats.unit_count

	var _debug_start_time = Time.get_ticks_usec()
	var unit_radius = first._get_own_target_radius() if first.has_method("_get_own_target_radius") else 14.0

	for i in count:
		var unit = first if i == 0 else card_data.unit_scene.instantiate()
		unit.is_preview = true
		add_child(unit)
		unit.modulate = Color(0.5, 1, 0.5, 0.5)
		preview_units.append(unit)
		preview_offsets.append(_get_formation_offset(i, count, unit_radius, first.stats.spawn_formation if first.stats != null else 0))

	var _debug_elapsed_ms = (Time.get_ticks_usec() - _debug_start_time) / 1000.0
	print("DEBUG select_card: prévia de ", count, " unidade(s) levou ", _debug_elapsed_ms, "ms")


func cast_spell(spell_data: SpellData, position: Vector2, caster_team, source_card_path: String = ""):
	var effect = SpellEffect.new()
	effect.spell = spell_data
	effect.caster_team = caster_team
	effect.source_card_path = source_card_path
	# nível da carta também vale pra feitiço (antes subir de nível um
	# feitiço não mudava NADA na batalha)
	var sp_card: CardData = Catalogo.find_card(source_card_path) if source_card_path != "" else null
	var sp_level = 1
	if MatchSetup.tournament:
		sp_level = MatchSetup.TOURNAMENT_LEVEL
	elif sp_card != null:
		if caster_team == GameManager.Team.PLAYER:
			sp_level = PlayerProfile.get_card_level(sp_card)
		elif ai_profile != null:
			sp_level = ai_profile.get_card_level(sp_card)
	effect.level = sp_level
	effect.power = PlayerProfile.compute_stat_multiplier(sp_level)
	if sp_card != null and !MatchSetup.tournament:
		if caster_team == GameManager.Team.PLAYER:
			effect.power *= Progresso.star_mult(sp_card)
		elif ai_profile != null:
			effect.power *= 1.0 + Progresso.STAR_BOOST * ai_profile.get_stars(sp_card)
	# posiciona ANTES de entrar na cena: o SpellEffect aplica o efeito já no
	# _ready -- antes ele "explodia" na posição (0,0) e só depois era movido,
	# então feitiço instantâneo (raio, gelo...) não acertava onde você mirou
	effect.position = to_local(position)
	add_child(effect)

	if caster_team == GameManager.Team.PLAYER and !is_replay_mode:
		PlayerProfile.record_mission_spell_used()
