extends Control

# ============================================================
# CRIADOR DE CARTA/UNIDADE -- ferramenta de DESENVOLVIMENTO
# ============================================================
# Só funciona rodando pelo EDITOR (F6 nessa cena) -- não funciona no jogo
# exportado pro celular, porque res:// vira somente-leitura depois de
# exportar. É pra você usar direto no Godot, não é uma tela pro jogador.
#
# Preenche o formulário (rolando pelas seções) e aperta "Salvar" no fim --
# cria os 2 arquivos (.tres da UnitData e .tres da CardData) na pasta que
# você escolher. Ajusta OUTPUT_UNIT_DIR/OUTPUT_CARD_DIR abaixo se sua
# estrutura de pasta for diferente.

const OUTPUT_UNIT_DIR = "res://Units/Data/"
const OUTPUT_CARD_DIR = "res://Cards/Data/"
# AJUSTA se o caminho de verdade for outro -- o template que TODA unidade
# herda, confirmado pelo usuário. A ferramenta duplica ele (preserva forma
# de colisão, barra de vida com tema, conexão de sinal, tudo) em vez de
# tentar montar uma cena do zero -- muito mais seguro
const UNIT_TEMPLATE_SCENE_PATH = "res://Units/scenes/unit_base.tscn"
const OUTPUT_UNIT_SCENE_DIR = "res://Units/scenes/"

# --------------------------------------------------------------
# Tabela de campos de UnitData -- [propriedade, tipo, padrão, rótulo]
# tipos: int, float, string, bool, enum:A,B,C, texture, scene
# Uma entrada com tipo "section" só desenha o cabeçalho da seção (não é
# campo de verdade). Mantém a ORDEM parecida com unit_data.gd, agrupado
# por assunto, pra ficar fácil de comparar com o Inspector depois
# --------------------------------------------------------------
const UNIT_FIELDS = [
	["section", "", "", "Básico"],
	["hp", "int", 100, "HP"],
	["damage", "int", 10, "Dano"],
	["push_weight", "float", 1.0, "Peso (empurrão)"],
	["move_speed", "float", 50.0, "Velocidade de movimento"],
	["attack_speed", "float", 1.0, "Velocidade de ataque (s entre golpes)"],
	["attack_range", "float", 20.0, "Alcance de ataque"],
	["detection_range", "float", 110.0, "Alcance de detecção"],
	["unit_scale", "float", 1.0, "Escala visual/física"],
	["unit_count", "int", 1, "Quantas unidades a carta spawna"],
	["spawn_formation", "enum:Grupo,Linha,Coluna,Círculo", 0, "Formação de spawn"],
	["target_type", "enum:GROUND,AIR,ALL,BUILDING", 0, "O que essa unidade MIRA"],
	["unit_type", "enum:GROUND,AIR,BUILDING", 0, "Tipo dessa unidade"],
	["duration", "float", 0.0, "Duração (0 = permanente)"],
	["role", "enum:Enxame,Tanque,Punição,Controle,Contra-ataque,Suporte,Finalizador,Construção,Aéreo,Versátil,Invocador,Cerco", 9, "Categoria (pra bônus vs categoria)"],

	["section", "", "", "Disfarce"],
	["spawns_disguised", "bool", false, "Nasce disfarçada (ícone aleatório até 1º ataque)"],

	["section", "", "", "Ataque Carregado (estilo Príncipe)"],
	["charge_attack", "bool", false, "Tem ataque carregado"],
	["charge_distance_needed", "float", 150.0, "Distância pra carregar"],
	["charge_damage_multiplier", "float", 2.0, "Multiplicador de dano carregado"],
	["charge_knockback_distance", "float", 60.0, "Empurrão do golpe carregado"],

	["section", "", "", "Avanço (estilo Bandida)"],
	["bandit_dash", "bool", false, "Avança instantâneo ao achar alvo"],
	["dash_speed_multiplier", "float", 3.0, "Multiplicador de velocidade do avanço"],
	["dash_duration", "float", 0.4, "Duração do avanço"],

	["section", "", "", "À Distância / Projétil"],
	["is_ranged", "bool", false, "Ataca à distância"],
	["projectile_texture", "texture", "", "Textura do projétil"],
	["projectile_speed", "float", 300.0, "Velocidade do projétil"],
	["projectile_pierces", "bool", false, "Projétil atravessa (multi-alvo em linha)"],
	["projectile_max_targets", "int", 1, "Quantos alvos o projétil atravessa"],
	["projectile_splits", "bool", false, "Projétil se divide ao acertar"],
	["projectile_split_count", "int", 3, "Em quantos se divide"],
	["projectile_split_range", "float", 150.0, "Raio da divisão"],
	["projectile_chains", "bool", false, "Projétil salta entre alvos (corrente)"],
	["projectile_chain_max_targets", "int", 3, "Quantos alvos na corrente"],
	["projectile_chain_range", "float", 150.0, "Alcance de salto da corrente"],

	["section", "", "", "Área de Efeito"],
	["is_aoe", "bool", false, "Ataque em área"],
	["aoe_radius", "float", 60.0, "Raio da área"],
	["spin_attack", "bool", false, "Ataque giratório (acerta todo mundo ao redor)"],
	["frontal_cone_attack", "bool", false, "Ataque em cone frontal"],
	["cone_angle_degrees", "float", 90.0, "Ângulo do cone (graus)"],
	["aoe_hits_extra_one", "bool", false, "Área + 1 alvo extra fora do raio"],
	["continuous_attack", "bool", false, "Dano contínuo (aura, não golpe único)"],
	["continuous_damage_per_second", "float", 10.0, "Dano por segundo (se contínuo)"],

	["section", "", "", "Atordoamento / Efeito ao Acertar"],
	["initial_stun_duration", "float", 0.5, "Atordoamento ao nascer"],
	["on_hit_effect", "enum:NONE,SLOW,WEAKNESS,FREEZE,POISON,STUN,KNOCKBACK,SHOCK,CONFUSE,PULL,ROOT,SILENCE,MARK", 0, "Efeito ao acertar"],
	["on_hit_effect_duration", "float", 2.0, "Duração do efeito"],
	["on_hit_effect_strength", "float", 0.5, "Força do efeito"],
	["on_hit_effect_tick_interval", "float", 1.0, "Intervalo de tick do efeito"],
	["knockback_distance", "float", 40.0, "Empurrão ao acertar"],

	["section", "", "", "Maestria (nível máximo)"],
	["mastery_effect", "enum:NONE,SLOW,WEAKNESS,FREEZE,POISON,STUN,KNOCKBACK,SHOCK,CONFUSE,PULL,ROOT,SILENCE,MARK", 0, "Efeito bônus no nível máximo"],
	["mastery_effect_duration", "float", 2.0, "Duração"],
	["mastery_effect_strength", "float", 0.5, "Força"],
	["mastery_effect_tick_interval", "float", 1.0, "Intervalo de tick"],

	["section", "", "", "Cura"],
	["can_heal_allies", "bool", false, "Cura aliado ao redor"],
	["heal_aura_amount", "int", 10, "Quanto cura por tick"],
	["heal_aura_radius", "float", 80.0, "Raio da cura"],
	["heal_aura_interval", "float", 1.0, "Intervalo de cura"],

	["section", "", "", "Invocação Periódica"],
	["spawns_units", "bool", false, "Gera unidade periodicamente"],
	["spawn_unit_scene", "scene", "", "Cena da unidade gerada"],
	["spawn_interval", "float", 5.0, "Intervalo de geração"],
	["spawn_count", "int", 1, "Quantas gera por vez"],

	["section", "", "", "Ao Morrer"],
	["spawns_on_death", "bool", false, "Gera unidade ao morrer"],
	["death_spawn_scene", "scene", "", "Cena gerada ao morrer"],
	["death_spawn_count", "int", 2, "Quantas gera ao morrer"],
	["explodes_on_death", "bool", false, "Explode ao morrer"],
	["death_explosion_damage", "int", 50, "Dano da explosão"],
	["death_explosion_radius", "float", 60.0, "Raio da explosão"],
	["grants_resource_on_death", "bool", false, "Dá recurso ao morrer"],
	["death_resource_amount", "int", 10, "Quanto recurso dá"],
	["kamikaze", "bool", false, "Explode ao ENCOSTAR (suicida)"],
	["can_resurrect", "bool", false, "Ressuscita 1 vez"],
	["resurrect_hp_percent", "float", 0.3, "% de HP ao ressuscitar"],

	["section", "", "", "Ao Chegar (spawn)"],
	["deals_arrival_damage", "bool", false, "Causa dano ao chegar"],
	["arrival_damage", "int", 50, "Dano de chegada"],
	["arrival_damage_radius", "float", 60.0, "Raio do dano de chegada"],
	["entrance_rage_duration", "float", 0.0, "Duração de fúria ao entrar (0=sem)"],
	["entrance_rage_damage_mult", "float", 1.5, "Multiplicador de dano na fúria de entrada"],
	["entrance_rage_speed_mult", "float", 1.3, "Multiplicador de velocidade na fúria de entrada"],
	["entrance_shockwave_damage", "int", 0, "Dano de onda de choque ao entrar (0=sem)"],
	["entrance_shockwave_radius", "float", 60.0, "Raio da onda de choque"],

	["section", "", "", "Recurso (produção/roubo)"],
	["generates_resource", "bool", false, "Gera moeda com o tempo"],
	["resource_per_tick", "int", 1, "Quanto gera por tick"],
	["resource_tick_interval", "float", 1.0, "Intervalo de geração"],
	["stores_resource", "bool", false, "Aumenta armazenamento de moeda"],
	["storage_capacity_bonus", "int", 20, "Bônus de armazenamento"],
	["steals_resource_on_base_hit", "bool", false, "Rouba moeda ao acertar base"],
	["resource_steal_amount", "int", 5, "Quanto rouba"],

	["section", "", "", "Invocar ao Atacar"],
	["summons_on_attack", "bool", false, "Invoca unidade ao atacar"],
	["attack_summon_scene", "scene", "", "Cena invocada"],
	["attack_summon_chance", "float", 1.0, "Chance de invocar (0-1)"],

	["section", "", "", "Dano Escalando"],
	["first_attack_bonus", "bool", false, "Bônus no primeiro ataque"],
	["first_attack_multiplier", "float", 2.0, "Multiplicador do 1º ataque"],
	["ramping_damage", "bool", false, "Dano cresce com o tempo de vida"],
	["ramping_damage_per_hit", "float", 0.05, "Quanto cresce por golpe"],
	["ramping_damage_max_multiplier", "float", 2.0, "Teto do crescimento"],
	["same_target_ramping_damage", "bool", false, "Dano cresce contra o MESMO alvo"],
	["same_target_ramping_damage_per_hit", "float", 0.1, "Quanto cresce por golpe (mesmo alvo)"],
	["same_target_ramping_damage_max_multiplier", "float", 2.0, "Teto (mesmo alvo)"],
	["distance_damage_bonus_per_100px", "float", 0.0, "Bônus de dano por 100px percorridos"],
	["ramping_attack_speed", "bool", false, "Velocidade de ataque cresce com o tempo"],
	["attack_speed_ramp_per_hit", "float", 0.05, "Quanto cresce por golpe"],
	["attack_speed_ramp_min_multiplier", "float", 0.5, "Teto (menor = mais rápido no máximo)"],
	["pre_attack_speed_boost", "bool", false, "Boost de velocidade ao achar alvo novo"],
	["pre_attack_boost_multiplier", "float", 1.5, "Multiplicador do boost"],
	["pre_attack_boost_duration", "float", 0.5, "Duração do boost"],

	["section", "", "", "Execução / Fúria por HP Baixo"],
	["execute_threshold", "float", 0.0, "% de HP do ALVO abaixo do qual executa (0=sem)"],
	["execute_damage_mult", "float", 2.0, "Multiplicador de dano na execução"],
	["low_hp_rage_threshold", "float", 0.0, "% de HP PRÓPRIO abaixo do qual enfurece (0=sem)"],
	["low_hp_rage_damage_mult", "float", 1.5, "Multiplicador de dano enfurecido"],

	["section", "", "", "Escudo / Redução de Dano"],
	["has_shield", "bool", false, "Tem escudo (recarrega)"],
	["shield_amount", "int", 50, "Quanto absorve"],
	["shield_recharge_time", "float", 0.0, "Tempo pra recarregar (0=não recarrega)"],
	["has_temp_shield", "bool", false, "Tem escudo TEMPORÁRIO (só ao nascer)"],
	["temp_shield_amount", "int", 30, "Quanto absorve (temporário)"],
	["temp_shield_duration", "float", 5.0, "Duração do escudo temporário"],
	["damage_reduction_percent", "float", 0.0, "% de redução de dano permanente"],

	["section", "", "", "Vínculo / Aggro"],
	["is_linked", "bool", false, "Vinculada a outra (divide dano)"],
	["link_share_percent", "float", 0.3, "% de dano dividido"],
	["forces_aggro", "bool", false, "Força inimigo a mirar nela (provocar)"],
	["taunt_radius", "float", 150.0, "Raio do provocar"],

	["section", "", "", "Imunidades"],
	["immune_to_effect", "enum:NONE,SLOW,WEAKNESS,FREEZE,POISON,STUN,KNOCKBACK,SHOCK,CONFUSE,PULL,ROOT,SILENCE,MARK", 0, "Imune a esse efeito"],
	["immune_to_knockback", "bool", false, "Imune a empurrão"],
	["immune_to_pull", "bool", false, "Imune a puxão"],
	["immune_while_moving", "bool", false, "Imune enquanto se movendo"],

	["section", "", "", "Roubo de Vida / Contra-ataque"],
	["lifesteal_percent", "float", 0.0, "% de dano causado vira cura"],
	["counter_attack_chance", "float", 0.0, "Chance de contra-atacar ao ser atingida"],
	["reflects_damage", "bool", false, "Reflete dano recebido"],
	["reflect_damage_percent", "float", 0.3, "% refletida"],

	["section", "", "", "Regeneração / Cura ao Matar"],
	["passive_regen", "bool", false, "Regenera HP com o tempo"],
	["regen_amount", "int", 5, "Quanto regenera por tick"],
	["regen_interval", "float", 2.0, "Intervalo de regeneração"],
	["heals_on_kill", "bool", false, "Cura ao matar"],
	["heal_on_kill_amount", "int", 15, "Quanto cura ao matar"],
	["converts_kills_to_gold", "bool", false, "Dá ouro ao matar"],
	["gold_per_kill", "int", 5, "Ouro por abate"],

	["section", "", "", "Movimento Especial"],
	["crosses_water", "bool", false, "Atravessa água (unidade terrestre)"],
	["can_spawn_anywhere", "bool", false, "Pode nascer em qualquer lugar do mapa"],
	["landing_duration", "float", 0.0, "Tempo de pouso/aterrissagem (0=sem)"],
	["can_stealth", "bool", false, "Fica invisível até revelada"],
	["stealth_reveal_range", "float", 40.0, "Alcance que revela ela"],
	["spawn_invulnerability_duration", "float", 0.0, "Invulnerável ao nascer por X segundos"],

	["section", "", "", "Bônus contra Categoria"],
	["extra_damage_vs_role", "enum:Enxame,Tanque,Punição,Controle,Contra-ataque,Suporte,Finalizador,Construção,Aéreo,Versátil,Invocador,Cerco", 9, "Categoria que recebe bônus de dano"],
	["extra_damage_vs_role_mult", "float", 0.0, "% de dano extra contra essa categoria"],

	["section", "", "", "Transformação"],
	["transforms_into_building", "bool", false, "Vira construção depois de um tempo"],
	["transform_after_seconds", "float", 5.0, "Depois de quantos segundos"],
	["transformed_scene", "scene", "", "Cena que ela vira"],

	["section", "", "", "Clonagem"],
	["can_clone", "bool", false, "Se clona ao morrer"],
	["clone_hp_percent", "float", 0.5, "% de HP do clone"],
	["clone_count", "int", 1, "Quantos clones"],

	["section", "", "", "Conversão de Inimigo"],
	["can_convert_enemy", "bool", false, "Converte inimigo pro seu lado"],
	["convert_max_targets", "int", 1, "Quantos consegue converter"],
]

# --------------------------------------------------------------
# Campos de CardData -- os que não são a UnitData em si
# --------------------------------------------------------------
var _field_inputs: Dictionary = {}  # nome do campo -> Control (LineEdit/CheckBox/OptionButton)
var _file_dialog: FileDialog
var _file_dialog_callback: Callable
var _card_name_input: LineEdit
var _cost_input: LineEdit
var _description_input: TextEdit
var _pros_input: TextEdit
var _cons_input: TextEdit
var _icon_path_input: LineEdit
var _sprite_path_input: LineEdit
var _unit_scene_path_input: LineEdit
var _spell_data_path_input: LineEdit
var _role_input: OptionButton
var _nation_data_path_input: LineEdit
var _nation_xp_cost_input: LineEdit
var _predecessor_paths_input: TextEdit
var _danger_level_input: LineEdit
var _tier_input: LineEdit
var _status_label: Label


func _ready():
	custom_minimum_size = Vector2(700, 900)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.size = Vector2(700, 500)
	_file_dialog.file_selected.connect(_on_file_dialog_selected)
	add_child(_file_dialog)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	root_vbox.custom_minimum_size = Vector2(660, 0)
	scroll.add_child(root_vbox)

	var title = Label.new()
	title.text = "🛠️ Criador de Carta/Unidade (ferramenta de desenvolvimento)"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	var warning = Label.new()
	warning.text = "Só funciona rodando pelo editor (F6). Não existe no jogo exportado."
	warning.add_theme_font_size_override("font_size", 11)
	warning.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	root_vbox.add_child(warning)

	root_vbox.add_child(HSeparator.new())

	_build_card_section(root_vbox)
	root_vbox.add_child(HSeparator.new())
	_build_unit_fields(root_vbox)

	root_vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(_status_label)

	var save_button = Button.new()
	save_button.text = "💾 Salvar (cria os 2 .tres)"
	save_button.add_theme_font_size_override("font_size", 16)
	save_button.pressed.connect(_on_save_pressed)
	root_vbox.add_child(save_button)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	root_vbox.add_child(spacer)


# ---------- seção CardData (campos que não fazem parte de UnitData) ----------
func _build_card_section(parent: VBoxContainer):
	var header = Label.new()
	header.text = "📇 CardData (a carta em si)"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	parent.add_child(header)

	_card_name_input = _labeled_line_edit(parent, "Nome da carta")
	_cost_input = _labeled_line_edit(parent, "Custo (elixir)", "3")

	var desc_label = Label.new()
	desc_label.text = "Descrição"
	parent.add_child(desc_label)
	_description_input = TextEdit.new()
	_description_input.custom_minimum_size = Vector2(0, 50)
	parent.add_child(_description_input)

	var pros_label = Label.new()
	pros_label.text = "Pros (1 por linha)"
	parent.add_child(pros_label)
	_pros_input = TextEdit.new()
	_pros_input.custom_minimum_size = Vector2(0, 50)
	parent.add_child(_pros_input)

	var cons_label = Label.new()
	cons_label.text = "Cons (1 por linha)"
	parent.add_child(cons_label)
	_cons_input = TextEdit.new()
	_cons_input.custom_minimum_size = Vector2(0, 50)
	parent.add_child(_cons_input)

	_icon_path_input = _labeled_line_edit(parent, "Caminho do ícone (res://.../algo.png)", "", PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPG", "*.svg ; SVG"]))
	_sprite_path_input = _labeled_line_edit(parent, "Sprite VISUAL da unidade no jogo (diferente do ícone -- esse aparece de verdade na batalha)", "", PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPG", "*.svg ; SVG"]))
	_unit_scene_path_input = _labeled_line_edit(parent, "Caminho da cena de unidade PRONTA (só se você já tem uma feita -- se preencheu o sprite acima, a ferramenta gera sozinha e ignora esse campo)", "", PackedStringArray(["*.tscn ; Cena Godot"]))
	_spell_data_path_input = _labeled_line_edit(parent, "Caminho do SpellData (res://.../algo.tres) -- preenche ISSO e deixa a cena de unidade vazia, se for carta de feitiço", "", PackedStringArray(["*.tres ; Recurso Godot"]))

	var role_label = Label.new()
	role_label.text = "Categoria da carta"
	parent.add_child(role_label)
	_role_input = OptionButton.new()
	for role_name in ["Enxame", "Tanque", "Punição", "Controle", "Contra-ataque", "Suporte", "Finalizador", "Construção", "Aéreo", "Versátil", "Invocador", "Cerco"]:
		_role_input.add_item(role_name)
	parent.add_child(_role_input)

	_nation_data_path_input = _labeled_line_edit(parent, "Caminho do NationData (res://.../algo.tres) -- vazio = coringa", "", PackedStringArray(["*.tres ; Recurso Godot"]))
	_nation_xp_cost_input = _labeled_line_edit(parent, "Custo em XP de nação pra desbloquear", "0")

	var pred_label = Label.new()
	pred_label.text = "Cartas predecessoras (1 caminho res://... por linha) -- vazio = tier inicial"
	parent.add_child(pred_label)
	_predecessor_paths_input = TextEdit.new()
	_predecessor_paths_input.custom_minimum_size = Vector2(0, 40)
	parent.add_child(_predecessor_paths_input)

	var add_predecessor_button = Button.new()
	add_predecessor_button.text = "+ Adicionar predecessora..."
	add_predecessor_button.pressed.connect(func():
		_open_file_picker(PackedStringArray(["*.tres ; Recurso Godot"]), func(path):
			if _predecessor_paths_input.text.strip_edges() == "":
				_predecessor_paths_input.text = path
			else:
				_predecessor_paths_input.text += "\n" + path
		)
	)
	parent.add_child(add_predecessor_button)

	_danger_level_input = _labeled_line_edit(parent, "Nível de perigo (1-10, avaliação do bot)", "3")
	_tier_input = _labeled_line_edit(parent, "Tier (número que você escolhe)", "1")


func _on_file_dialog_selected(path: String):
	if _file_dialog_callback.is_valid():
		_file_dialog_callback.call(path)


# abre o seletor de arquivo nativo do Godot, filtrado pro tipo certo -- ao
# escolher, chama "callback" com o caminho (res://...) escolhido. Quem
# chama decide o que fazer com ele (substituir texto de um campo, ou
# ADICIONAR como nova linha numa lista, como as predecessoras fazem)
func _open_file_picker(filters: PackedStringArray, callback: Callable):
	_file_dialog_callback = callback
	_file_dialog.filters = filters
	_file_dialog.popup_centered()


func _labeled_line_edit(parent: VBoxContainer, label_text: String, default_text: String = "", picker_filters: PackedStringArray = []) -> LineEdit:
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = default_text

	if picker_filters.is_empty():
		parent.add_child(line_edit)
	else:
		var row = HBoxContainer.new()
		parent.add_child(row)
		line_edit.custom_minimum_size = Vector2(420, 0)
		row.add_child(line_edit)
		var pick_button = Button.new()
		pick_button.text = "Selecionar..."
		pick_button.pressed.connect(func(): _open_file_picker(picker_filters, func(path): line_edit.text = path))
		row.add_child(pick_button)

	return line_edit


# ---------- campos de UnitData, gerados a partir da tabela ----------
func _build_unit_fields(parent: VBoxContainer):
	var header = Label.new()
	header.text = "⚔️ UnitData (a unidade em si)"
	header.add_theme_font_size_override("font_size", 16)
	parent.add_child(header)

	var current_section_body: VBoxContainer = null

	for field in UNIT_FIELDS:
		var field_name = field[0]
		var field_type = field[1]
		var default_value = field[2]
		var label_text = field[3]

		if field_name == "section":
			current_section_body = _add_collapsible_section(parent, label_text)
			continue

		if current_section_body == null:
			current_section_body = parent  # segurança, não deveria acontecer

		_add_field(current_section_body, field_name, field_type, default_value, label_text)


# seção que expande/recolhe -- clica no cabeçalho pra abrir/fechar. Começa
# FECHADA (só "Básico" começa aberta), senão a tela vira um poço sem fundo
func _add_collapsible_section(parent: VBoxContainer, title_text: String) -> VBoxContainer:
	var header_button = Button.new()
	header_button.text = "▶ " + title_text
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(header_button)

	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.visible = title_text == "Básico"
	header_button.text = ("▼ " if body.visible else "▶ ") + title_text
	parent.add_child(body)

	header_button.pressed.connect(func():
		body.visible = !body.visible
		header_button.text = ("▼ " if body.visible else "▶ ") + title_text
	)

	return body


func _add_field(parent: VBoxContainer, field_name: String, field_type: String, default_value, label_text: String):
	var row = HBoxContainer.new()
	parent.add_child(row)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(280, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)

	if field_type == "bool":
		var check = CheckBox.new()
		check.button_pressed = default_value
		row.add_child(check)
		_field_inputs[field_name] = check

	elif field_type.begins_with("enum:"):
		var options = field_type.substr(5).split(",")
		var option_button = OptionButton.new()
		for opt in options:
			option_button.add_item(opt)
		option_button.selected = default_value if default_value is int else 0
		option_button.custom_minimum_size = Vector2(180, 0)
		row.add_child(option_button)
		_field_inputs[field_name] = option_button

	elif field_type == "texture" or field_type == "scene":
		var line_edit = LineEdit.new()
		line_edit.placeholder_text = "res://... (opcional)"
		line_edit.custom_minimum_size = Vector2(220, 0)
		row.add_child(line_edit)
		_field_inputs[field_name] = line_edit

		var filters = PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPG", "*.svg ; SVG"]) if field_type == "texture" else PackedStringArray(["*.tscn ; Cena Godot"])
		var pick_button = Button.new()
		pick_button.text = "..."
		pick_button.pressed.connect(func(): _open_file_picker(filters, func(path): line_edit.text = path))
		row.add_child(pick_button)

	else:  # int, float, string
		var line_edit = LineEdit.new()
		line_edit.text = str(default_value)
		line_edit.custom_minimum_size = Vector2(120, 0)
		row.add_child(line_edit)
		_field_inputs[field_name] = line_edit


# ---------- salvar ----------
func _on_save_pressed():
	if _card_name_input.text.strip_edges() == "":
		_status_label.text = "⚠️ Preenche pelo menos o nome da carta."
		_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		return

	var unit_data = UnitData.new()
	for field in UNIT_FIELDS:
		var field_name = field[0]
		var field_type = field[1]
		if field_name == "section":
			continue
		var input = _field_inputs[field_name]
		_apply_field_value(unit_data, field_name, field_type, input)

	var safe_name = _card_name_input.text.strip_edges().to_snake_case()
	DirAccess.make_dir_recursive_absolute(OUTPUT_UNIT_DIR)
	var unit_path = OUTPUT_UNIT_DIR + safe_name + "_unit.tres"
	var err_unit = ResourceSaver.save(unit_data, unit_path)
	if err_unit != OK:
		_status_label.text = "❌ Erro salvando UnitData (código %d) -- confere se a pasta %s existe" % [err_unit, OUTPUT_UNIT_DIR]
		_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		return

	# gera a CENA da unidade -- duplica o template (unit_base.tscn) em vez
	# de tentar montar do zero, preservando forma de colisão, barra de
	# vida com tema, conexão de sinal etc. Só troca o sprite visual (se
	# preenchido) e o nome. Se não achar o template, avisa mas não trava o
	# resto -- a UnitData/CardData ainda ficam salvas, só falta a cena
	var generated_scene_path = ""
	if _sprite_path_input.text.strip_edges() != "":
		generated_scene_path = _generate_unit_scene(safe_name, _sprite_path_input.text.strip_edges())

	var card_data = CardData.new()
	card_data.card_name = _card_name_input.text.strip_edges()
	card_data.cost = int(_cost_input.text) if _cost_input.text.is_valid_int() else 3
	card_data.description = _description_input.text
	card_data.pros = _split_lines(_pros_input.text)
	card_data.cons = _split_lines(_cons_input.text)
	card_data.role = _role_input.selected
	card_data.danger_level = int(_danger_level_input.text) if _danger_level_input.text.is_valid_int() else 3
	card_data.tier = int(_tier_input.text) if _tier_input.text.is_valid_int() else 1
	card_data.nation_xp_cost = int(_nation_xp_cost_input.text) if _nation_xp_cost_input.text.is_valid_int() else 0

	if _icon_path_input.text.strip_edges() != "" and ResourceLoader.exists(_icon_path_input.text.strip_edges()):
		card_data.icon = load(_icon_path_input.text.strip_edges())

	if generated_scene_path != "":
		card_data.unit_scene = load(generated_scene_path)
	elif _unit_scene_path_input.text.strip_edges() != "" and ResourceLoader.exists(_unit_scene_path_input.text.strip_edges()):
		card_data.unit_scene = load(_unit_scene_path_input.text.strip_edges())

	if _spell_data_path_input.text.strip_edges() != "" and ResourceLoader.exists(_spell_data_path_input.text.strip_edges()):
		card_data.spell_data = load(_spell_data_path_input.text.strip_edges())

	if _nation_data_path_input.text.strip_edges() != "" and ResourceLoader.exists(_nation_data_path_input.text.strip_edges()):
		card_data.nation_data = load(_nation_data_path_input.text.strip_edges())

	var predecessors: Array[CardData] = []
	for line in _split_lines(_predecessor_paths_input.text):
		if ResourceLoader.exists(line):
			predecessors.append(load(line))
		else:
			_status_label.text = "⚠️ Predecessora não encontrada, ignorada: %s" % line
	card_data.predecessor_cards = predecessors

	DirAccess.make_dir_recursive_absolute(OUTPUT_CARD_DIR)
	var card_path = OUTPUT_CARD_DIR + safe_name + "card.tres"
	var err_card = ResourceSaver.save(card_data, card_path)
	if err_card != OK:
		_status_label.text = "❌ UnitData salva, mas erro salvando CardData (código %d)" % err_card
		_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		return

	var scene_line = "\nCena da unidade: %s" % generated_scene_path if generated_scene_path != "" else ""
	_status_label.text = "✅ Salvo!\nUnitData: %s%s\nCardData: %s\n\nLembra: precisa arrastar a carta pro array All Cards do CardDatabase (ou rodar o refresh_card_database.gd) pra ela aparecer no jogo." % [unit_path, scene_line, card_path]
	_status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))


# duplica o template (unit_base.tscn) pra criar a cena dessa unidade nova
# -- carrega, instancia (isso já traz TODOS os nós filhos: colisão, área de
# ataque, navegação, barra de vida com tema, label de nível, tudo igual ao
# template), troca só o sprite e o nome, empacota de novo e salva com o
# nome novo. Devolve o caminho salvo, ou "" se algo der errado
func _generate_unit_scene(safe_name: String, sprite_path: String) -> String:
	if !ResourceLoader.exists(UNIT_TEMPLATE_SCENE_PATH):
		_status_label.text += "\n⚠️ Não achei o template em %s -- ajusta UNIT_TEMPLATE_SCENE_PATH no topo do script. Cena da unidade NÃO foi gerada." % UNIT_TEMPLATE_SCENE_PATH
		return ""

	if !ResourceLoader.exists(sprite_path):
		_status_label.text += "\n⚠️ Sprite não encontrado em %s -- cena NÃO foi gerada." % sprite_path
		return ""

	var template: PackedScene = load(UNIT_TEMPLATE_SCENE_PATH)
	var instance = template.instantiate()
	instance.name = safe_name.to_pascal_case()

	var sprite_node = instance.get_node_or_null("Sprite2D")
	if sprite_node == null:
		_status_label.text += "\n⚠️ O template não tem um nó Sprite2D -- cena NÃO foi gerada."
		instance.queue_free()
		return ""
	sprite_node.texture = load(sprite_path)

	DirAccess.make_dir_recursive_absolute(OUTPUT_UNIT_SCENE_DIR)
	var scene_path = OUTPUT_UNIT_SCENE_DIR + safe_name + ".tscn"

	var new_packed_scene = PackedScene.new()
	new_packed_scene.pack(instance)
	var err = ResourceSaver.save(new_packed_scene, scene_path)
	instance.queue_free()

	if err != OK:
		_status_label.text += "\n⚠️ Erro salvando a cena da unidade (código %d)." % err
		return ""

	return scene_path


func _split_lines(text: String) -> Array[String]:
	var result: Array[String] = []
	for line in text.split("\n"):
		var trimmed = line.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result


func _apply_field_value(unit_data: UnitData, field_name: String, field_type: String, input: Control):
	if field_type == "bool":
		unit_data.set(field_name, input.button_pressed)
	elif field_type.begins_with("enum:"):
		unit_data.set(field_name, input.selected)
	elif field_type == "texture":
		var path = input.text.strip_edges()
		if path != "" and ResourceLoader.exists(path):
			unit_data.set(field_name, load(path))
	elif field_type == "scene":
		var path = input.text.strip_edges()
		if path != "" and ResourceLoader.exists(path):
			unit_data.set(field_name, load(path))
	elif field_type == "int":
		unit_data.set(field_name, int(input.text) if input.text.is_valid_int() else 0)
	elif field_type == "float":
		unit_data.set(field_name, float(input.text) if input.text.is_valid_float() else 0.0)
	else:  # string
		unit_data.set(field_name, input.text)
