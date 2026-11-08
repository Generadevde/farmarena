extends Control

# ajusta esse caminho pro local real da sua cena de menu principal
const MAIN_MENU_SCENE = "res://Scenes/main_menu.tscn"

# todas as cartas que o jogador tem disponíveis (arrasta os .tres aqui no Inspector)
@export var available_cards: Array[CardData] = []

# todas as bases disponíveis pra escolher (arrasta os .tres aqui) --
# aparecem bloqueadas na tela até o nível de desbloqueio de cada uma
@export var available_bases: Array[BaseData] = []

const TARGET_TYPE_NAMES = {
	UnitData.TargetType.GROUND: "Terrestres",
	UnitData.TargetType.AIR: "Aéreos",
	UnitData.TargetType.ALL: "Todos",
	UnitData.TargetType.BUILDING: "Construções",
}

var _viewing_bases: bool = false
var _selected_nation: String = ""  # "" = mostrando a lista de nações; senão, mostrando as cartas/bases dessa nação
# índice SEPARADO pro carrossel de cartas e pro de bases -- antes era um só
# compartilhado, e trocar nação numa aba mexia/estragava a outra
var _card_carousel_index: int = 0
var _base_carousel_index: int = 0
var _carousel_is_base: bool = false
var _nation_carousel_index: int:
	get:
		return _base_carousel_index if _carousel_is_base else _card_carousel_index
	set(value):
		if _carousel_is_base:
			_base_carousel_index = value
		else:
			_card_carousel_index = value
var _line_summon_links: Dictionary = {}  # texto da linha -> CardData vinculada, só pras linhas de invocação (o resto não é clicável)
var _scroll_container: ScrollContainer
var _module_grid: GridContainer
var _collection_grid: Container
var _collection_toggle_label: Label


func _ready():
	MusicPlayer.play_menu_music()
	theme = ThemeBuilder.game_theme

	# procura os nós pelo NOME em qualquer lugar da árvore, não por caminho
	# fixo -- assim continua funcionando mesmo se a cena for reorganizada
	# depois (envolvida em outro container, etc), sem precisar de correção
	# de caminho toda vez que isso acontecer
	_scroll_container = find_child("ScrollContainer", true, false)
	_module_grid = find_child("ModuleGrid", true, false)
	_collection_grid = find_child("CollectionGrid", true, false)

	add_to_group("library_menu")
	# inclui as bases criadas no Criador (e qualquer outra que os bots usem)
	var merged: Array[BaseData] = []
	for b in available_bases:
		merged.append(b)
	for b in CustomContent.custom_bases:
		if !merged.has(b):
			merged.append(b)
	available_bases = merged
	_build_collection_toggle()
	_refresh_collection_visibility()


# setinha de trocar entre coleção de carta e de base -- mesmo princípio das
# setinhas de trocar arena no ranking, só que aqui alterna qual dos dois
# containers já existentes na cena fica visível
func _build_collection_toggle():
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)

	# tenta inserir logo depois da fileira do Deck Atual (o HBoxContainer
	# dentro do VBoxContainer), com um espaço visual entre os dois -- se
	# não achar essa estrutura, cai pro topo da raiz como antes (fallback)
	var vbox_container = find_child("VBoxContainer", true, false)
	var deck_row = find_child("HBoxContainer", true, false)

	if vbox_container != null and deck_row != null and deck_row.get_parent() == vbox_container:
		# rótulo "DECK ATUAL:" logo ANTES da fileira de slots
		var deck_title = Label.new()
		deck_title.text = "DECK ATUAL:"
		deck_title.add_theme_font_size_override("font_size", 16)
		vbox_container.add_child(deck_title)
		vbox_container.move_child(deck_title, deck_row.get_index())

		var spacer = Control.new()
		spacer.custom_minimum_size.y = 24  # espaço visual entre o deck atual e o título da coleção

		var insert_index = deck_row.get_index() + 1
		vbox_container.add_child(spacer)
		vbox_container.move_child(spacer, insert_index)
		vbox_container.add_child(header)
		vbox_container.move_child(header, insert_index + 1)
	else:
		add_child(header)
		move_child(header, 0)

	var prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.pressed.connect(func():
		_viewing_bases = !_viewing_bases
		_selected_nation = ""  # troca de cartas/bases sempre volta pra lista de nações
		_refresh_collection_visibility()
	)
	header.add_child(prev_button)

	var toggle_label = Label.new()
	toggle_label.name = "CollectionToggleLabel"
	toggle_label.add_theme_font_size_override("font_size", 18)
	header.add_child(toggle_label)
	_collection_toggle_label = toggle_label

	var next_button = Button.new()
	next_button.text = "▶"
	next_button.pressed.connect(func():
		_viewing_bases = !_viewing_bases
		_selected_nation = ""  # troca de cartas/bases sempre volta pra lista de nações
		_refresh_collection_visibility()
	)
	header.add_child(next_button)


func _refresh_collection_visibility():
	_scroll_container.visible = !_viewing_bases
	_module_grid.visible = _viewing_bases
	if _collection_toggle_label != null:
		_collection_toggle_label.text = "Coleção de Bases" if _viewing_bases else "Coleção de Cartas"
	_build_collection_grid()
	_build_base_grid()


func _build_collection_grid():
	# CollectionGrid é o container vertical que recebe o carrossel de nações
	# em cima, e a grade de cartas da nação CENTRALIZADA no carrossel embaixo
	# -- os dois juntos, sem precisar clicar pra "entrar" numa nação
	var container = _collection_grid
	for child in container.get_children():
		child.queue_free()

	var cards = available_cards if !available_cards.is_empty() else CardDatabase.all_cards

	var nations = _build_nation_list(container, cards, Callable(), _build_collection_grid)
	if nations.is_empty():
		return

	_selected_nation = nations[_nation_carousel_index]

	var nation_cards = cards.filter(func(c): return c != null and _card_nation_matches(c, _selected_nation))
	var unlocked_count = nation_cards.filter(func(c): return PlayerProfile.is_card_unlocked(c)).size()

	var nation_title = Label.new()
	nation_title.text = "%s — %d/%d" % [_selected_nation, unlocked_count, nation_cards.size()]
	nation_title.add_theme_font_size_override("font_size", 18)
	nation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(nation_title)

	# colunas por TIER, estilo World of Tanks -- tier 1 numa coluna, tier 2
	# na próxima, etc, com rolagem lateral se tiver muitas. Isso resolve a
	# bagunça de linha cruzando pra todo lado que a grade simples (quebrando
	# linha a cada N cartas) tinha -- agora a linha sempre flui numa
	# direção só (esquerda pra direita, tier crescente)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var grid_wrapper = Control.new()
	scroll.add_child(grid_wrapper)

	var columns_row = HBoxContainer.new()
	columns_row.add_theme_constant_override("separation", 50)  # espaço maior entre tiers, pra caber a seta sem colidir
	grid_wrapper.add_child(columns_row)

	var card_buttons: Dictionary = {}  # resource_path da carta -> botão dela, pra desenhar linha até a predecessora depois

	var nation_card_list: Array[CardData] = []
	for card in cards:
		if card != null and _card_nation_matches(card, _selected_nation):
			nation_card_list.append(card)

	var cards_by_tier: Dictionary = {}  # tier(int) -> Array[CardData]
	for card in nation_card_list:
		if !cards_by_tier.has(card.tier):
			cards_by_tier[card.tier] = []
		cards_by_tier[card.tier].append(card)

	var tiers_sorted = cards_by_tier.keys()
	tiers_sorted.sort()

	for tier in tiers_sorted:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 20)
		columns_row.add_child(column)

		var tier_label = Label.new()
		tier_label.text = "Tier %d" % tier
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_size_override("font_size", 14)
		tier_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
		column.add_child(tier_label)

		for card in cards_by_tier[tier]:
			var button = CollectionCardButton.new()
			button.card = card
			column.add_child(button)
			card_buttons[card.resource_path] = button

	var line_overlay = Control.new()
	line_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # nunca atrapalha o clique nos botões por baixo
	grid_wrapper.add_child(line_overlay)  # adicionado DEPOIS das colunas -- fica por cima delas

	# desenha uma linha (com uma pontinha de seta) de cada carta até TODAS
	# as predecessoras dela -- usa POSIÇÃO GLOBAL (não a relativa ao pai
	# direto), já que agora o botão fica mais aninhado (dentro de uma
	# coluna, dentro da fileira de colunas) e a posição relativa simples
	# não bateria mais com a camada de desenho
	line_overlay.draw.connect(func():
		for card in nation_card_list:
			if !card_buttons.has(card.resource_path):
				continue
			var successor_button = card_buttons[card.resource_path]
			for predecessor in card.predecessor_cards:
				if predecessor == null or !card_buttons.has(predecessor.resource_path):
					continue
				var predecessor_button = card_buttons[predecessor.resource_path]
				var from_pos = predecessor_button.global_position - line_overlay.global_position + predecessor_button.size / 2.0
				var to_pos = successor_button.global_position - line_overlay.global_position + successor_button.size / 2.0

				line_overlay.draw_line(from_pos, to_pos, ThemeBuilder.COLOR_GOLD, 3.0)

				# ponta de seta em TRIÂNGULO PREENCHIDO, fina -- aponta de
				# quem É PRECISO pra quem PRECISA
				var dir = (to_pos - from_pos).normalized()
				var perp = Vector2(-dir.y, dir.x)
				var arrow_tip = to_pos - dir * 22.0
				var arrow_base_center = arrow_tip - dir * 22.0
				var triangle = PackedVector2Array([
					arrow_tip,
					arrow_base_center + perp * 6.0,
					arrow_base_center - perp * 6.0,
				])
				line_overlay.draw_colored_polygon(triangle, ThemeBuilder.COLOR_GOLD)
	)

	# o layout das colunas só fica pronto de verdade um frame depois de
	# adicionar os botões -- espera esse frame, depois alinha o wrapper e a
	# camada de desenho pro tamanho de verdade, e só então desenha
	await get_tree().process_frame
	grid_wrapper.custom_minimum_size = columns_row.size
	line_overlay.size = columns_row.size
	line_overlay.position = Vector2.ZERO
	line_overlay.queue_redraw()


# "" e "Coringa" contam como a mesma coisa -- item sem nação própria.
# Aceita tanto CardData quanto BaseData (os dois têm campo .get_nation_name())
func _card_nation_matches(item, nation_name: String) -> bool:
	var item_nation = item.get_nation_name() if item.get_nation_name() != "" else "Coringa"
	return item_nation == nation_name


# monta a lista vertical de nações -- um botão por nação distinta encontrada
# entre os itens (carta ou base), mais "Coringa" se existir algum sem nação
# própria. on_select é chamado com o nome escolhido quando o jogador toca
# paleta de cor de fallback -- usada em ciclo pras nações que ainda não têm
# um NationData cadastrado (ou que não têm ícone preenchido nele), só pra
# cada uma ter uma cor distinta de cara, mesmo antes de você criar os ícones
const _FALLBACK_COLORS = [
	Color(0.42, 0.65, 0.28),  # verde
	Color(0.29, 0.48, 0.75),  # azul
	Color(0.75, 0.32, 0.28),  # vermelho
	Color(0.85, 0.68, 0.22),  # amarelo
	Color(0.58, 0.35, 0.68),  # roxo
]


func _build_nation_list(container: Control, items: Array, on_select: Callable, rebuild_callback: Callable) -> Array:
	var is_base_list = rebuild_callback == Callable(self, "_build_base_grid")
	_carousel_is_base = is_base_list
	var nations: Array = []
	for item in items:
		if item == null:
			continue
		var n = item.get_nation_name() if item.get_nation_name() != "" else "Coringa"
		if n not in nations:
			nations.append(n)
	nations.sort()

	if nations.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(nenhuma nação cadastrada ainda)"
		container.add_child(empty_label)
		return []

	_nation_carousel_index = clamp(_nation_carousel_index, 0, nations.size() - 1)

	# pré-computa carta representante + desbloqueadas/total de cada nação
	# de uma vez só, reaproveitado pelos até 3 cartões visíveis no carrossel
	var nation_info: Dictionary = {}
	for item in items:
		if item == null:
			continue
		var n = item.get_nation_name() if item.get_nation_name() != "" else "Coringa"
		if !nation_info.has(n):
			nation_info[n] = {"representative": item, "unlocked": 0, "total": 0}
		nation_info[n]["total"] += 1
		if item is CardData and PlayerProfile.is_card_unlocked(item):
			nation_info[n]["unlocked"] += 1

	var carousel_row = HBoxContainer.new()
	carousel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel_row.add_theme_constant_override("separation", 4)
	container.add_child(carousel_row)

	var prev_button = Button.new()
	prev_button.text = "◀"
	prev_button.custom_minimum_size = Vector2(56, 56)
	prev_button.pressed.connect(func():
		_carousel_is_base = is_base_list
		_nation_carousel_index = (_nation_carousel_index - 1 + nations.size()) % nations.size()
		rebuild_callback.call()
	)
	carousel_row.add_child(prev_button)

	# nação anterior espiando do lado -- só visual, menor e meio
	# transparente, não clicável (só a do meio é)
	if nations.size() > 1:
		var peek_index = (_nation_carousel_index - 1 + nations.size()) % nations.size()
		carousel_row.add_child(_build_nation_peek_card(nations[peek_index], nation_info.get(nations[peek_index], {})))

	var current_name = nations[_nation_carousel_index]
	var current_info = nation_info.get(current_name, {})
	carousel_row.add_child(_build_nation_button(
		current_name, _nation_carousel_index, on_select,
		current_info.get("representative"), current_info.get("unlocked", 0), current_info.get("total", 0)
	))

	if nations.size() > 1:
		var next_peek_index = (_nation_carousel_index + 1) % nations.size()
		carousel_row.add_child(_build_nation_peek_card(nations[next_peek_index], nation_info.get(nations[next_peek_index], {})))

	var next_button = Button.new()
	next_button.text = "▶"
	next_button.custom_minimum_size = Vector2(56, 56)
	next_button.pressed.connect(func():
		_carousel_is_base = is_base_list
		_nation_carousel_index = (_nation_carousel_index + 1) % nations.size()
		rebuild_callback.call()
	)
	carousel_row.add_child(next_button)

	return nations


# versão pequena e não-clicável do cartão de nação -- só pra "espiar" o
# vizinho do carrossel, dando a dica visual de que tem mais coisa pros lados
func _build_nation_peek_card(nation_name: String, info: Dictionary) -> Control:
	var peek = _build_nation_button(nation_name, 0, func(_n): pass, info.get("representative"), info.get("unlocked", 0), info.get("total", 0))
	peek.custom_minimum_size *= 0.65
	peek.modulate.a = 0.45
	peek.disabled = true
	peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return peek


# um "cartão" por nação -- ícone (ou quadrado colorido de fallback) em cima,
# nome e XP embaixo. Fica pronto pra receber o ícone de verdade assim que
# você criar o NationData dela, sem precisar mexer em mais nada aqui
func _build_nation_button(nation_name: String, fallback_index: int, on_select: Callable, representative, unlocked_count: int, total_count: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(140, 116)  # largura era 0 antes -- por isso os cartões ficavam sobrepostos, sem espaço reservado
	if on_select.is_valid():
		button.pressed.connect(on_select.bind(nation_name))

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	button.add_child(vbox)

	var nation_data = NationDatabase.get_nation_data(nation_name) if nation_name != "Coringa" else null
	var banner_color = Color(0.85, 0.85, 0.85) if nation_name == "Coringa" else (nation_data.color if nation_data != null else _FALLBACK_COLORS[fallback_index % _FALLBACK_COLORS.size()])

	# moldura colorida de fundo -- dá o "tema" da nação mesmo antes de ter
	# ícone próprio, e continua visível como borda mesmo depois de ter
	var banner = PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 56)
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = banner_color.darkened(0.2)
	banner_style.border_color = banner_color
	banner_style.set_border_width_all(3)
	banner_style.set_corner_radius_all(6)
	banner.add_theme_stylebox_override("panel", banner_style)
	vbox.add_child(banner)

	# dentro da moldura: ícone próprio da nação, se já preencheu no NationData
	# -- senão, fica só a moldura colorida mesmo, sem ícone nenhum, esperando
	# você preencher o ícone lá no resource quando estiver pronto
	if nation_data != null and nation_data.icon != null:
		var icon_rect = TextureRect.new()
		icon_rect.texture = nation_data.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		banner.add_child(icon_rect)

	var name_label = Label.new()
	name_label.text = nation_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true  # nunca vaza pra fora do cartão, mesmo com nome de nação comprido
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_label)

	var xp_amount = PlayerProfile.free_xp if nation_name == "Coringa" else PlayerProfile.get_nation_xp(nation_name)
	var xp_label = Label.new()
	xp_label.text = "%d XP" % xp_amount
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.clip_text = true
	xp_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(xp_label)

	# desbloqueadas/total -- só faz sentido pra carta (base ainda não tem
	# desbloqueio por nação implementado), então só mostra nesse caso
	if total_count > 0 and representative is CardData:
		var progress_label = Label.new()
		progress_label.text = "%d/%d" % [unlocked_count, total_count]
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.add_theme_font_size_override("font_size", 11)
		progress_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_LABEL)
		vbox.add_child(progress_label)

	return button


func _build_base_grid():
	var container: Container = _module_grid
	for child in container.get_children():
		child.queue_free()

	var nations = _build_nation_list(container, available_bases, Callable(), _build_base_grid)
	if nations.is_empty():
		return

	_selected_nation = nations[_nation_carousel_index]

	var nation_title = Label.new()
	nation_title.text = _selected_nation
	nation_title.add_theme_font_size_override("font_size", 18)
	nation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(nation_title)

	# mesma ideia de colunas por tier que a grade de cartas já usa
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var grid_wrapper = Control.new()
	scroll.add_child(grid_wrapper)

	var columns_row = HBoxContainer.new()
	columns_row.add_theme_constant_override("separation", 50)
	grid_wrapper.add_child(columns_row)

	var base_buttons: Dictionary = {}  # resource_path da base -> botão dela, pra desenhar linha até a predecessora depois

	var nation_base_list: Array[BaseData] = []
	for base_data in available_bases:
		if base_data != null and _card_nation_matches(base_data, _selected_nation):
			nation_base_list.append(base_data)

	var bases_by_tier: Dictionary = {}  # tier(int) -> Array[BaseData]
	for base_data in nation_base_list:
		if !bases_by_tier.has(base_data.tier):
			bases_by_tier[base_data.tier] = []
		bases_by_tier[base_data.tier].append(base_data)

	var tiers_sorted = bases_by_tier.keys()
	tiers_sorted.sort()

	for tier in tiers_sorted:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 20)
		columns_row.add_child(column)

		var tier_label = Label.new()
		tier_label.text = "Tier %d" % tier
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_size_override("font_size", 14)
		tier_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
		column.add_child(tier_label)

		for base_data in bases_by_tier[tier]:
			var button = BaseSelectButton.new()
			button.base_data = base_data
			column.add_child(button)
			base_buttons[base_data.resource_path] = button

	var line_overlay = Control.new()
	line_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_wrapper.add_child(line_overlay)  # adicionado DEPOIS das colunas -- fica por cima delas

	# mesma linha dourada com seta que a grade de cartas já tem, ligando
	# cada base à(s) predecessora(s) dela -- posição GLOBAL, mesmo motivo
	# da grade de cartas (botão fica mais aninhado agora, dentro de coluna)
	line_overlay.draw.connect(func():
		for base_data in nation_base_list:
			if !base_buttons.has(base_data.resource_path):
				continue
			var successor_button = base_buttons[base_data.resource_path]
			for predecessor in base_data.predecessor_bases:
				if predecessor == null or !base_buttons.has(predecessor.resource_path):
					continue
				var predecessor_button = base_buttons[predecessor.resource_path]
				var from_pos = predecessor_button.global_position - line_overlay.global_position + predecessor_button.size / 2.0
				var to_pos = successor_button.global_position - line_overlay.global_position + successor_button.size / 2.0

				line_overlay.draw_line(from_pos, to_pos, ThemeBuilder.COLOR_GOLD, 3.0)

				var dir = (to_pos - from_pos).normalized()
				var perp = Vector2(-dir.y, dir.x)
				var arrow_tip = to_pos - dir * 22.0
				var arrow_base_center = arrow_tip - dir * 22.0
				var triangle = PackedVector2Array([
					arrow_tip,
					arrow_base_center + perp * 6.0,
					arrow_base_center - perp * 6.0,
				])
				line_overlay.draw_colored_polygon(triangle, ThemeBuilder.COLOR_GOLD)
	)

	await get_tree().process_frame
	grid_wrapper.custom_minimum_size = columns_row.size
	line_overlay.size = columns_row.size
	line_overlay.position = Vector2.ZERO
	line_overlay.queue_redraw()

	_refresh_base_grid_highlight()


# troca a base escolhida -- só é chamado aqui na biblioteca, nunca durante
# uma partida, então já respeita a regra de "só muda entre partidas". Não
# deixa escolher uma base ainda bloqueada pro nível do jogador.
func equip_base(base_data: BaseData):
	if base_data.resource_path == "":
		push_warning(
			"BaseData '%s' não tem resource_path -- provavelmente foi criado " %
			base_data.base_name +
			"embutido no Inspector, sem nunca ser salvo como um arquivo .tres " +
			"separado. Salva ele como recurso externo (botão direito no campo " +
			"Resource -> Save As) e tenta de novo."
		)
		return

	if !PlayerProfile.is_base_unlocked(base_data):
		return  # o botão já vem desabilitado nesse caso, isso é só uma segunda trava de segurança

	PlayerProfile.set_equipped_base(base_data)
	_refresh_base_grid_highlight()


func _refresh_base_grid_highlight():
	# os botões ficam aninhados (scroll/colunas), não são filhos diretos
	for button in _module_grid.find_children("*", "", true, false):
		if button is BaseSelectButton:
			var is_equipped = button.base_data.resource_path == PlayerProfile.equipped_base_path
			button.modulate = Color(1, 1, 0.6) if is_equipped else Color(1, 1, 1)


func _on_back_button_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# instancia a cena da unidade só pra ler o UnitData já atribuído nela, e descarta na hora
func _get_unit_stats(card: CardData) -> UnitData:
	if card.unit_scene == null:
		return null
	return DeckBuilder.get_unit_stats(card)  # com cache -- instanciar toda hora pesava no celular


func _build_unit_lines(card: CardData, stats: UnitData) -> Array[String]:
	var mult = PlayerProfile.get_stat_multiplier(card)
	var lines: Array[String] = []
	lines.append("Custo: %d" % card.cost)
	lines.append("HP: %d" % round(stats.hp * mult))
	lines.append("Dano: %d" % round(stats.damage * mult))
	lines.append("Velocidade: %.0f" % stats.move_speed)
	lines.append("Vel. de ataque: %.1fs" % stats.attack_speed)
	lines.append("Alcance: %.0f" % stats.attack_range)
	lines.append("Ataca: " + TARGET_TYPE_NAMES.get(stats.target_type, "?"))

	if stats.unit_count > 1:
		lines.append("Quantidade: %d" % stats.unit_count)

	if stats.unit_type == UnitData.UnitType.BUILDING and stats.duration > 0:
		lines.append("Duração: %.0fs" % stats.duration)

	if stats.is_aoe:
		lines.append("Dano em área (raio %.0f)" % stats.aoe_radius)

	lines.append_array(_build_special_ability_lines(stats))

	return lines


const ON_HIT_EFFECT_NAMES = {
	UnitData.OnHitEffect.SLOW: "Lentidão",
	UnitData.OnHitEffect.WEAKNESS: "Fraqueza",
	UnitData.OnHitEffect.FREEZE: "Congela",
	UnitData.OnHitEffect.POISON: "Veneno",
	UnitData.OnHitEffect.STUN: "Atordoa",
	UnitData.OnHitEffect.KNOCKBACK: "Empurra",
	UnitData.OnHitEffect.SHOCK: "Choque",
	UnitData.OnHitEffect.CONFUSE: "Confunde",
	UnitData.OnHitEffect.PULL: "Puxa",
	UnitData.OnHitEffect.ROOT: "Enraíza",
}


# monta as linhas de qualquer habilidade especial ativa nessa unidade --
# reaproveitado tanto pra unidades normais quanto construções
# acha o nome de exibição de uma unidade a partir da CENA dela --
# UnitData não guarda nome próprio (o nome vive na CardData), então procura
# na base de cartas qual carta usa essa cena como unit_scene
func _get_spawned_unit_card(scene: PackedScene) -> CardData:
	if scene == null:
		return null
	for card in CardDatabase.all_cards:
		if card != null and card.unit_scene != null and card.unit_scene.resource_path == scene.resource_path:
			return card
	return null


func _build_special_ability_lines(stats: UnitData) -> Array[String]:
	var lines: Array[String] = []

	if stats.on_hit_effect != UnitData.OnHitEffect.NONE:
		var name_str = ON_HIT_EFFECT_NAMES.get(stats.on_hit_effect, "?")
		lines.append("%s ao acertar (%.0fs)" % [name_str, stats.on_hit_effect_duration])

	if stats.can_heal_allies:
		lines.append("Cura %d ao redor a cada %.0fs" % [stats.heal_aura_amount, stats.heal_aura_interval])

	if stats.spawns_units:
		var spawned_card = _get_spawned_unit_card(stats.spawn_unit_scene)
		var spawned_name = spawned_card.card_name if spawned_card != null else "unidade"
		var spawn_line = "Gera %dx %s a cada %.0fs" % [stats.spawn_count, spawned_name, stats.spawn_interval]
		lines.append(spawn_line)
		if spawned_card != null:
			_line_summon_links[spawn_line] = spawned_card

	if stats.spawns_on_death:
		var death_spawned_card = _get_spawned_unit_card(stats.death_spawn_scene)
		var death_spawned_name = death_spawned_card.card_name if death_spawned_card != null else "unidade"
		var death_spawn_line = "Gera %dx %s ao morrer" % [stats.death_spawn_count, death_spawned_name]
		lines.append(death_spawn_line)
		if death_spawned_card != null:
			_line_summon_links[death_spawn_line] = death_spawned_card

	if stats.generates_resource:
		lines.append("Gera %d de recurso a cada %.0fs" % [stats.resource_per_tick, stats.resource_tick_interval])

	if stats.stores_resource:
		lines.append("Aumenta a capacidade de recurso em %d" % stats.storage_capacity_bonus)

	if stats.first_attack_bonus:
		lines.append("Bônus de x%.1f no primeiro ataque" % stats.first_attack_multiplier)

	if stats.ramping_damage:
		lines.append("Dano cresce com o tempo (até x%.1f)" % stats.ramping_damage_max_multiplier)

	if stats.ramping_attack_speed:
		lines.append("Ataca cada vez mais rápido com o tempo")

	if stats.pre_attack_speed_boost:
		lines.append("Acelera por um instante antes de atacar")

	if stats.has_shield:
		lines.append("Escudo: absorve %d de dano" % stats.shield_amount)

	if stats.has_temp_shield:
		lines.append("Escudo temporário: %d de dano por %.0fs" % [stats.temp_shield_amount, stats.temp_shield_duration])

	if stats.damage_reduction_percent > 0:
		lines.append("Reduz todo dano recebido em %d%%" % round(stats.damage_reduction_percent * 100))

	if stats.is_linked:
		lines.append("Vínculo: repassa %d%% do dano às unidades da mesma leva" % round(stats.link_share_percent * 100))

	if stats.can_resurrect:
		lines.append("Ressuscita uma vez com %d%% do HP" % round(stats.resurrect_hp_percent * 100))

	if stats.forces_aggro:
		lines.append("Provoca inimigos num raio de %.0f" % stats.taunt_radius)

	if stats.immune_to_effect != UnitData.OnHitEffect.NONE:
		lines.append("Imune a " + ON_HIT_EFFECT_NAMES.get(stats.immune_to_effect, "?"))

	if stats.immune_to_knockback:
		lines.append("Imune a empurrão")

	if stats.immune_to_pull:
		lines.append("Imune a puxão")

	if stats.lifesteal_percent > 0:
		lines.append("Vampirismo: cura %d%% do dano causado" % round(stats.lifesteal_percent * 100))

	if stats.counter_attack_chance > 0:
		lines.append("Chance de contra-atacar: %d%%" % round(stats.counter_attack_chance * 100))

	if stats.reflects_damage:
		lines.append("Reflete %d%% do dano recebido" % round(stats.reflect_damage_percent * 100))

	if stats.passive_regen:
		lines.append("Regenera %d de HP a cada %.0fs" % [stats.regen_amount, stats.regen_interval])

	if stats.heals_on_kill:
		lines.append("Cura %d HP a cada abate" % stats.heal_on_kill_amount)

	if stats.converts_kills_to_gold:
		lines.append("Ganha %d de recurso a cada abate" % stats.gold_per_kill)

	if stats.steals_resource_on_base_hit:
		lines.append("Rouba %d de recurso ao acertar a base" % stats.resource_steal_amount)

	if stats.summons_on_attack:
		if stats.attack_summon_chance > 0 and stats.attack_summon_scene != null:
			var summon_card = _get_spawned_unit_card(stats.attack_summon_scene)
			var summon_name = summon_card.card_name if summon_card != null else "unidade"
			var summon_line = "Invoca %s ao atacar (%d%% de chance)" % [summon_name, round(stats.attack_summon_chance * 100)]
			lines.append(summon_line)
			if summon_card != null:
				_line_summon_links[summon_line] = summon_card

	if stats.continuous_attack:
		lines.append("Ataque contínuo: %.0f de dano/s" % stats.continuous_damage_per_second)

	if stats.spin_attack:
		lines.append("Ataque giratório: acerta tudo ao redor")

	if stats.frontal_cone_attack:
		lines.append("Ataque em cone (%.0f°) na frente" % stats.cone_angle_degrees)

	if stats.aoe_hits_extra_one:
		lines.append("Acerta o alvo e mais um inimigo próximo")

	if stats.projectile_pierces:
		lines.append("Projétil atravessa e atinge até %d alvos" % stats.projectile_max_targets)

	if stats.projectile_splits:
		lines.append("Projétil se divide em %d ao acertar" % stats.projectile_split_count)

	if stats.crosses_water:
		lines.append("Atravessa água e obstáculos")

	if stats.can_stealth:
		lines.append("Invisível (revelada a %.0f de distância)" % stats.stealth_reveal_range)

	if stats.can_spawn_anywhere:
		lines.append("Pode nascer em qualquer lugar do mapa")

	if stats.kamikaze:
		lines.append("Sacrifica-se logo após atacar")

	if stats.grants_resource_on_death:
		lines.append("Concede %d de recurso a quem a matar" % stats.death_resource_amount)

	if stats.can_convert_enemy:
		lines.append("Domina até %d inimigo(s), convertendo pro seu time" % stats.convert_max_targets)

	if stats.explodes_on_death:
		lines.append("Explode ao morrer (raio %.0f)" % stats.death_explosion_radius)

	if stats.transforms_into_building:
		lines.append("Vira construção após %.0fs" % stats.transform_after_seconds)

	if stats.can_clone:
		lines.append("Cria um clone ao morrer")

	return lines


func _build_spell_lines(card: CardData, spell: SpellData) -> Array[String]:
	var mult = PlayerProfile.get_stat_multiplier(card)
	var lines: Array[String] = []
	lines.append("Custo: %d" % card.cost)

	if spell.damage > 0:
		lines.append("Dano: %d" % round(spell.damage * mult))
	if spell.heal_amount > 0:
		lines.append("Cura: %d" % round(spell.heal_amount * mult))

	if spell.status_effect != UnitData.OnHitEffect.NONE:
		var name_str = ON_HIT_EFFECT_NAMES.get(spell.status_effect, "?")
		lines.append("%s (força %.1f)" % [name_str, spell.status_effect_strength])

	lines.append("Raio: %.0f" % spell.radius)
	if spell.duration > 0:
		lines.append("Duração: %.0fs" % spell.duration)

	return lines


# abre a janela de detalhes da carta, com Voltar e Usar
# divide uma linha "Rótulo: Valor" em dois labels coloridos diferente
# (rótulo dourado opaco, valor em creme) -- se não tiver ":", mostra a
# linha inteira numa cor só (é mais descrição do que atributo nesse caso)
func _split_colored_line(line: String) -> Control:
	var colon_index = line.find(":")
	if colon_index == -1:
		var single_label = Label.new()
		single_label.text = line
		single_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		single_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_VALUE)
		return single_label

	var row = HBoxContainer.new()

	var label_part = Label.new()
	label_part.text = line.substr(0, colon_index + 1)
	label_part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_part.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_LABEL)
	row.add_child(label_part)

	var value_part = Label.new()
	value_part.text = line.substr(colon_index + 1).strip_edges()
	value_part.add_theme_color_override("font_color", ThemeBuilder.COLOR_STAT_VALUE)
	row.add_child(value_part)

	return row


func show_card_details(card: CardData, page: int = 1):
	_line_summon_links = {}

	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var icon = TextureRect.new()
	icon.texture = card.icon
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var title = Label.new()
	title.text = "%s (Nv. %d)" % [card.card_name, PlayerProfile.get_card_level(card)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var nation_role_label = Label.new()
	var nation_text = card.get_nation_name() if card.get_nation_name() != "" else "Coringa"
	nation_role_label.text = "%s • %s" % [nation_text, CardData.role_name(card.role)]
	nation_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nation_role_label.add_theme_font_size_override("font_size", 13)
	nation_role_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_GOLD)
	vbox.add_child(nation_role_label)

	vbox.add_child(HSeparator.new())

	if page == 2:
		_build_card_description_page(vbox, card)

		var nav_row = HBoxContainer.new()
		nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(nav_row)

		var back_arrow = Button.new()
		back_arrow.text = "◀ Estatísticas"
		back_arrow.pressed.connect(func():
			overlay.queue_free()
			show_card_details(card, 1)
		)
		nav_row.add_child(back_arrow)
		return

	var lines: Array[String] = []
	if card.is_spell():
		lines = _build_spell_lines(card, card.spell_data)
	else:
		var stats = _get_unit_stats(card)
		if stats != null:
			lines = _build_unit_lines(card, stats)

	for line in lines:
		if _line_summon_links.has(line):
			var linked_card = _line_summon_links[line]
			var link_button = Button.new()
			link_button.text = line + "  ›"
			link_button.pressed.connect(func():
				overlay.queue_free()
				show_card_details(linked_card)
			)
			vbox.add_child(link_button)
		else:
			vbox.add_child(_split_colored_line(line))

	var next_arrow = Button.new()
	next_arrow.text = "Como jogar ▶"
	next_arrow.pressed.connect(func():
		overlay.queue_free()
		show_card_details(card, 2)
	)
	vbox.add_child(next_arrow)

	vbox.add_child(HSeparator.new())

	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.pressed.connect(func(): overlay.queue_free())
	button_row.add_child(back_button)

	if !PlayerProfile.is_card_unlocked(card):
		var unlock_button = Button.new()

		var pending_predecessors: Array[String] = []
		for predecessor in card.predecessor_cards:
			if predecessor != null and !PlayerProfile.is_card_unlocked(predecessor):
				pending_predecessors.append(predecessor.card_name)

		if !pending_predecessors.is_empty():
			unlock_button.text = "🔒 Desbloqueie %s primeiro" % ", ".join(pending_predecessors)
			unlock_button.disabled = true
		else:
			var unlock_cost = PlayerProfile.get_unlock_cost(card)
			var is_wildcard = card.get_nation_name() == "" or card.get_nation_name() == "Coringa"

			if PlayerProfile.can_unlock_card(card):
				# mostra exatamente a combinação que vai ser gasta -- os dois
				# ícones juntos quando nação + livre entram ao mesmo tempo
				var breakdown = PlayerProfile.get_unlock_cost_breakdown(card)
				var cost_text = ""
				if breakdown["nation"] > 0 and breakdown["free"] > 0:
					cost_text = "🏆 %d + ⭐ %d" % [breakdown["nation"], breakdown["free"]]
				elif breakdown["nation"] > 0:
					cost_text = "🏆 %d XP de %s" % [breakdown["nation"], card.get_nation_name()]
				else:
					cost_text = "⭐ %d XP livre" % breakdown["free"]
				unlock_button.text = "Desbloquear (%s)" % cost_text
				unlock_button.disabled = false
			else:
				# ainda não dá -- mostra o total precisado e o que já tem de cada um
				var have_nation = 0 if is_wildcard else PlayerProfile.get_nation_xp(card.get_nation_name())
				var nation_icon = "" if is_wildcard else "🏆 %d/%d de %s  " % [have_nation, unlock_cost, card.get_nation_name()]
				unlock_button.text = "Precisa de %d XP -- %s⭐ %d livre" % [unlock_cost, nation_icon, PlayerProfile.free_xp]
				unlock_button.disabled = true

		unlock_button.pressed.connect(func():
			if PlayerProfile.unlock_card(card):
				overlay.queue_free()
				show_card_details(card)  # reabre já desbloqueada
		)
		button_row.add_child(unlock_button)
		return  # sem carta desbloqueada, não mostra atualizar/usar ainda

	var upgrade_button = Button.new()
	if PlayerProfile.is_max_level(card):
		upgrade_button.text = "Nível Máximo"
		upgrade_button.disabled = true
	else:
		var use_cost = PlayerProfile.get_upgrade_cost(card)
		var usage = PlayerProfile.get_card_usage(card)
		var coin_cost = PlayerProfile.get_upgrade_coin_cost(card)
		upgrade_button.text = "Atualizar (%d/%d usos, %d moedas)" % [min(usage, use_cost), use_cost, coin_cost]
		upgrade_button.disabled = usage < use_cost or PlayerProfile.coins < coin_cost
	upgrade_button.pressed.connect(func():
		if PlayerProfile.upgrade_card(card):
			overlay.queue_free()
			show_card_details(card)  # reabre já com o nível/custo/stats atualizados
	)
	button_row.add_child(upgrade_button)

	var use_button = Button.new()
	use_button.text = "Usar"
	use_button.pressed.connect(func():
		overlay.queue_free()
		_show_slot_picker(card)
	)
	button_row.add_child(use_button)


# segunda página do popup de carta -- descrição + prós/contras de como
# jogar ela, mais informativo que só os números frios da primeira página
func _build_card_description_page(vbox: VBoxContainer, card: CardData):
	const PAGE_WIDTH = 240.0

	if card.description != "":
		var desc_label = Label.new()
		desc_label.text = card.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = PAGE_WIDTH
		vbox.add_child(desc_label)
		vbox.add_child(HSeparator.new())

	if !card.pros.is_empty():
		var pros_title = Label.new()
		pros_title.text = "Pontos fortes"
		pros_title.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		pros_title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(pros_title)

		for pro in card.pros:
			var pro_label = Label.new()
			pro_label.text = "+ " + pro
			pro_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			pro_label.custom_minimum_size.x = PAGE_WIDTH
			vbox.add_child(pro_label)

	if !card.cons.is_empty():
		var cons_title = Label.new()
		cons_title.text = "Cuidados"
		cons_title.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45))
		cons_title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(cons_title)

		for con in card.cons:
			var con_label = Label.new()
			con_label.text = "- " + con
			con_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			con_label.custom_minimum_size.x = PAGE_WIDTH
			vbox.add_child(con_label)

	if card.description == "" and card.pros.is_empty() and card.cons.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(essa carta ainda não tem descrição/prós/contras cadastrados)"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.custom_minimum_size.x = PAGE_WIDTH
		vbox.add_child(empty_label)

	vbox.add_child(HSeparator.new())


# depois de "Usar", pergunta qual dos 7 slots atuais deve ser substituído
func _show_slot_picker(new_card: CardData):
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.theme = ThemeBuilder.game_theme
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Qual carta você quer substituir?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	for i in DeckManager.full_deck.size():
		var old_card: CardData = DeckManager.full_deck[i]
		var slot_button = _make_icon_button(old_card)
		var index = i  # cópia local, pra não compartilhar a variável do loop na lambda
		slot_button.pressed.connect(func():
			if DeckManager.set_deck_card(index, new_card):
				overlay.queue_free()
			else:
				title.text = "Essa carta já está no seu deck!"
		)
		row.add_child(slot_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel_button)


# monta um botão simples só com o ícone de uma carta (usado no seletor de slot)
func _make_icon_button(card: CardData) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.clip_contents = true

	if card != null:
		var icon = TextureRect.new()
		icon.texture = card.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

	return button


# botão "voltar" do Android (o jogo não fecha mais sozinho com ele)
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_button_pressed()
