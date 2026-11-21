extends Node

# CONTEÚDO PERSONALIZADO (autoload "CustomContent")
# Tudo que você cria/edita DENTRO do jogo (no celular) vem parar aqui:
#   - cartas novas  -> user://custom/cards/<id>.tres (+ arte, stats, cena)
#   - bases novas   -> user://custom/bases/<id>.tres (+ arte)
#   - edição de carta/base QUE JÁ EXISTIA no jogo -> user://custom/overrides.json
#     (o res:// do jogo exportado é somente-leitura, então a edição é
#     reaplicada por cima toda vez que o jogo abre)
#   - arenas (nome, emoji, troféu, recompensa, fundo) -> user://custom/arenas.json
# Cartas/bases novas entram no CardDatabase / BotSimulator.available_bases,
# então aparecem na coleção, no deck e nos decks dos BOTS também.

signal content_changed

const ROOT = "user://custom/"
const CARDS_DIR = "user://custom/cards/"
const UNITS_DIR = "user://custom/units/"
const BASES_DIR = "user://custom/bases/"
const ART_DIR = "user://custom/art/"
const OVERRIDES_PATH = "user://custom/overrides.json"
const ARENAS_PATH = "user://custom/arenas.json"
const UNIT_TEMPLATE = "res://Units/scenes/unit_base.tscn"

const CARD_ART_SIZE = Vector2i(48, 48)  # 2.0: mesma grade das cartas oficiais (peças do SpriteForge)
const BASE_ART_SIZE = Vector2i(48, 48)  # 2.0: torre na mesma grade das peças
const ARENA_ART_SIZE = Vector2i(36, 64)  # 9:16, igual a tela
const PROJ_ART_SIZE = Vector2i(16, 16)  # projétil -- desenhe apontando pra DIREITA (ele gira na direção do tiro)

# ---------------------------------------------------------------- campos
# lista ÚNICA de campos editáveis -- usada pelo formulário do criador E pra
# salvar/reaplicar edição de carta original. Formato:
#   [propriedade, rótulo, tipo, opções]
# tipos: "int" [min,max,passo], "float" [min,max,passo], "bool", "text",
#        "multiline", "enum" [lista de nomes]
const ROLE_NAMES = ["Enxame", "Tanque", "Punição", "Controle", "Contra-ataque", "Suporte", "Finalizador", "Construção", "Aéreo", "Versátil", "Invocador", "Cerco"]
const EFFECT_NAMES = ["Nenhum", "Lentidão", "Fraqueza", "Congelar", "Veneno", "Atordoar", "Empurrão", "Choque", "Confusão", "Puxão", "Enraizar", "Silêncio", "Marcar"]

const CARD_FIELDS = [
	["card_name", "Nome", "text", []],
	["cost", "Custo (0 a 100, igual a barra de recurso)", "int", [5, 100, 5]],
	["role", "Categoria", "enum", ROLE_NAMES],
	["nation_data", "Nação", "nation", []],
	["danger_level", "Perigo (pra IA)", "int", [1, 10, 1]],
	["rarity", "Raridade", "enum", ["Normal", "Rara", "Épica", "Lendária", "Mística"]],
	["companion_id", "Vem junto com (outra tropa na mesma carta)", "cardid", []],
	["companion_count", "Quantas vêm junto", "int", [0, 12, 1]],
	["unlock_arena", "Libera na arena (0 = desde o começo)", "int", [0, 12, 1]],
	["description", "Descrição", "multiline", []],
]

const UNIT_FIELDS = [
	["hp", "Vida", "int", [1, 20000, 10]],
	["damage", "Dano", "int", [0, 5000, 5]],
	["attack_speed", "Tempo entre ataques (s)", "float", [0.1, 10.0, 0.1]],
	["attack_range", "Alcance (corpo a corpo: folga até encostar, padrão 15)", "float", [0.0, 600.0, 5.0]],
	["move_speed", "Velocidade", "float", [0.0, 200.0, 5.0]],
	["unit_count", "Quantidade", "int", [1, 20, 1]],
	["push_weight", "Peso (empurrão)", "float", [0.1, 10.0, 0.1]],
	["unit_scale", "Tamanho", "float", [0.5, 3.0, 0.1]],
	["unit_type", "Tipo", "enum", ["Terrestre", "Aérea", "Construção"]],
	["target_type", "Ataca", "enum", ["Terrestre", "Aéreo", "Tudo", "Só construção/base"]],
	["is_ranged", "Ataque à distância", "bool", []],
	["projectile_speed", "Velocidade do projétil", "float", [50.0, 1500.0, 25.0]],
	["is_aoe", "Dano em área", "bool", []],
	["aoe_radius", "Raio da área", "float", [10.0, 300.0, 5.0]],
	["detection_range", "Visão", "float", [20.0, 600.0, 10.0]],
	["duration", "Dura X segundos (0 = pra sempre)", "float", [0.0, 120.0, 1.0]],
	["spawn_formation", "Formação", "enum", ["Grupo", "Linha", "Coluna", "Círculo"]],
	["on_hit_effect", "Efeito ao acertar", "enum", EFFECT_NAMES],
	["on_hit_effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
	["on_hit_effect_duration", "Duração do efeito (s)", "float", [0.0, 20.0, 0.25]],
	["can_heal_allies", "Cura aliados perto", "bool", []],
	["heal_aura_amount", "Cura por pulso", "int", [0, 500, 1]],
	["heal_aura_radius", "Raio da cura", "float", [10.0, 300.0, 5.0]],
	["forces_aggro", "Provoca (puxa inimigos)", "bool", []],
	["explodes_on_death", "Explode ao morrer", "bool", []],
	["death_explosion_damage", "Dano da explosão", "int", [0, 3000, 10]],
	["death_explosion_radius", "Raio da explosão", "float", [10.0, 300.0, 5.0]],
	["kamikaze", "Kamikaze (morre ao atacar)", "bool", []],
	["crosses_water", "Atravessa água", "bool", []],
	["can_spawn_anywhere", "Pode nascer em qualquer lugar", "bool", []],
	["damage_reduction_percent", "Redução de dano (0-0.9)", "float", [0.0, 0.9, 0.05]],
	["lifesteal_percent", "Roubo de vida (0-1)", "float", [0.0, 1.0, 0.05]],
]

# TODOS os outros campos do UnitData (habilidades/efeitos) -- a lista é
# montada sozinha a partir do próprio recurso (unit_extra_fields), esses são
# só os nomes em português. Campo novo que você criar no UnitData aparece
# sozinho no Criador, com o nome técnico mesmo.
const UNIT_EXTRA_LABELS = {
	"anim_entry": "Jeito de entrar", "anim_gait": "Jeito de andar", "anim_hit": "Jeito de bater", "anim_death": "Jeito de morrer", "anim_speed": "Velocidade da animação (1 = normal)",
	"anim_amount": "Tamanho do balanço (1 = normal, 0 = parado)",
	"repairs_buildings": "Conserta: devolve vida pras construções em volta", "repair_amount": "Vida devolvida por vez", "repair_radius": "Raio do conserto",
	"repair_interval": "Tempo entre consertos (s)", "repair_towers": "Conserta as torres também",
	"ward_allies": "Cúpula: aliados em volta levam menos dano", "ward_radius": "Raio da cúpula", "ward_reduction": "Quanto de dano a cúpula tira (0.3 = 30%)",
	"pre_attack_boost_range": "Distância do alvo em que acelera", "charge_speed_mult": "Investida: corre mais enquanto carrega (x)",
	"dash_repeats": "Vários avanços (repete o avanço)", "dash_cooldown": "Tempo entre avanços (s)", "dash_min_range": "Só avança se o alvo estiver a mais de",
	"dash_damage_mult": "Dano do golpe depois do avanço (x)",
	"jump_attack": "Salto: pula no alvo e cai dando dano em área", "jump_min_range": "Salto: distância mínima", "jump_max_range": "Salto: distância máxima",
	"jump_damage": "Dano da queda do salto", "jump_radius": "Raio da queda do salto", "jump_cooldown": "Tempo entre saltos (s)",
	"late_boost_after": "Esquenta depois de (s em campo)", "late_boost_damage_mult": "Esquenta: dano (x)", "late_boost_speed_mult": "Esquenta: passo (x)",
	"projectile_can_miss": "Tiro pode errar (vai reto pra onde o alvo estava)", "projectile_launch_angle": "Ângulo de saída do tiro (0 = reto, maior = arco)",
	"charged_shot": "Tiro carregado (Sparky): carrega antes do 1º tiro; atordoar zera a carga",
	"entrance_effect": "Efeito ao cair (atordoar, congelar...)", "entrance_effect_duration": "Duração do efeito ao cair (s)",
	"death_effect": "Efeito ao morrer nos inimigos em volta", "death_effect_duration": "Duração do efeito ao morrer (s)",
	"death_effect_strength": "Força do efeito ao morrer", "death_effect_radius": "Raio do efeito ao morrer",
	"death_rage_duration": "Fúria nos aliados ao morrer (s, 0 = não)",
	"lifetime": "Vida útil: a vida cai sozinha até acabar em (s, 0 = não cai)",
	"min_attack_range": "Alcance mínimo (não acerta quem está mais perto)",
	"projectile_returns": "Bumerangue: o tiro vai e volta acertando de novo",
	"building_damage_mult": "Dano em construção e torre (x)",
	"zaps_attackers": "Choque de volta: quem bate nela leva choque", "zap_damage": "Dano do choque de volta", "zap_radius": "Alcance do choque de volta",
	"zap_stun": "Atordoa por (s)",
	"curses_on_hit": "Maldição: quem ela acerta e morre vira tropa sua", "curse_duration": "Duração da maldição (s)", "curse_spawn_scene": "Vira esta tropa",
	"produces_resource": "Coletor: dá recurso pro dono", "resource_amount": "Recurso por vez", "resource_interval": "A cada (s)",
	"recoil_distance": "Coice: pula pra trás depois do tiro (distância)",
	"close_damage_bonus": "Mais dano de perto (0.5 = +50% encostado)",
	"beam_attack": "Raio contínuo (torre inferno): raio ligado no alvo em vez de projétil",
	"beam_tint": "Cor do raio", "beam_heats_red": "Raio fica vermelho conforme esquenta",
	"aura_buff": "Aura: reforça os aliados em volta", "aura_radius": "Raio da aura", "aura_damage_mult": "Aura: dano dos aliados (x)",
	"aura_speed_mult": "Aura: passo dos aliados (x)", "aura_attack_speed_mult": "Aura: velocidade de ataque dos aliados (x)",
	"pulses": "Pulso: onda em volta de tempos em tempos", "pulse_interval": "Tempo entre pulsos (s)", "pulse_damage": "Dano do pulso",
	"pulse_radius": "Raio do pulso", "pulse_effect": "Efeito do pulso", "pulse_effect_duration": "Duração do efeito do pulso (s)",
	"pulse_effect_strength": "Força do efeito do pulso",
	"leaves_trail": "Rastro: deixa poças que machucam", "trail_damage": "Dano da poça (a cada meio segundo)", "trail_duration": "Quanto a poça dura (s)",
	"trail_radius": "Tamanho da poça", "trail_slow": "Lentidão da poça (0 = não deixa lento)",
	"grows_over_time": "Cresce: mais dano quanto mais tempo viva", "grow_interval": "Cresce a cada (s)", "grow_damage_step": "Quanto cresce por vez (0.1 = +10%)",
	"grow_max_mult": "Teto do crescimento (x)",
	"is_trap": "Armadilha: escondida até pisarem, aí explode", "trap_trigger_radius": "Distância que dispara a armadilha", "trap_damage": "Dano da armadilha",
	"trap_radius": "Raio da explosão da armadilha", "trap_effect": "Efeito da armadilha", "trap_effect_duration": "Duração do efeito da armadilha (s)",
	"blinks": "Pisca: teleporta pra cima do alvo", "blink_interval": "Tempo entre teleportes (s)", "blink_range": "Distância máxima do teleporte",
	"hides_underground": "Construção que se esconde (só aparece pra atirar)",
	"heals_on_attack": "Cura quem está perto a cada golpe",
	"attack_heal_amount": "Cura por golpe",
	"attack_heal_radius": "Raio da cura do golpe",
	"rider_attack": "Segundo ataque (cavaleiro / atiradores nas costas)",
	"rider_damage": "Dano do segundo ataque",
	"rider_range": "Alcance do segundo ataque",
	"rider_interval": "Tempo entre os segundos ataques (s)",
	"rider_count": "Quantos alvos por vez",
	"rider_effect": "Efeito do segundo ataque",
	"rider_effect_duration": "Duração desse efeito (s)",
	"rider_effect_strength": "Força desse efeito",
	"spawns_disguised": "Nasce disfarçada (revela no 1º ataque)",
	"charge_attack": "Golpe carregado (anda e bate forte)",
	"charge_distance_needed": "Distância pra carregar",
	"charge_damage_multiplier": "Multiplicador do golpe carregado",
	"charge_knockback_distance": "Empurrão do golpe carregado",
	"bandit_dash": "Avanço instantâneo (1x)",
	"dash_speed_multiplier": "Velocidade do avanço",
	"dash_duration": "Duração do avanço",
	"projectile_pierces": "Projétil atravessa",
	"projectile_max_targets": "Máx. alvos atravessados",
	"projectile_splits": "Projétil se divide",
	"projectile_split_count": "Pedaços da divisão",
	"projectile_split_range": "Alcance da divisão",
	"projectile_chains": "Projétil em cadeia (pula)",
	"projectile_chain_max_targets": "Máx. pulos da cadeia",
	"projectile_chain_range": "Alcance do pulo",
	"initial_stun_duration": "Atordoado ao nascer (s)",
	"on_hit_effect_tick_interval": "Intervalo do efeito (veneno)",
	"knockback_distance": "Distância do empurrão/puxão",
	"mastery_effect": "Efeito de maestria (nível 7+)",
	"mastery_effect_duration": "Duração da maestria",
	"mastery_effect_strength": "Força da maestria",
	"mastery_effect_tick_interval": "Intervalo da maestria",
	"heal_aura_interval": "Intervalo da cura",
	"spawns_units": "Invoca unidades",
	"spawn_unit_scene": "Unidade invocada",
	"spawn_interval": "Invoca a cada (s)",
	"spawn_count": "Quantas invoca",
	"spawns_on_death": "Invoca ao morrer",
	"death_spawn_scene": "Unidade que surge ao morrer",
	"death_spawn_count": "Quantas surgem ao morrer",
	"generates_resource": "Gera recurso",
	"resource_per_tick": "Recurso por pulso",
	"resource_tick_interval": "Intervalo do recurso",
	"stores_resource": "Aumenta limite de recurso",
	"storage_capacity_bonus": "Limite extra",
	"steals_resource_on_base_hit": "Rouba recurso ao bater na base",
	"resource_steal_amount": "Quanto rouba",
	"summons_on_attack": "Invoca ao atacar",
	"attack_summon_scene": "Unidade invocada no ataque",
	"attack_summon_chance": "Chance de invocar (0-1)",
	"first_attack_bonus": "Primeiro ataque mais forte",
	"first_attack_multiplier": "Multiplicador do 1º ataque",
	"ramping_damage": "Dano cresce a cada golpe",
	"ramping_damage_per_hit": "Aumento por golpe",
	"ramping_damage_max_multiplier": "Máximo do aumento",
	"same_target_ramping_damage": "Dano cresce no mesmo alvo",
	"same_target_ramping_damage_per_hit": "Aumento por golpe (mesmo alvo)",
	"same_target_ramping_damage_max_multiplier": "Máximo (mesmo alvo)",
	"distance_damage_bonus_per_100px": "Dano extra por distância (a cada 100px)",
	"ramping_attack_speed": "Ataca cada vez mais rápido",
	"attack_speed_ramp_per_hit": "Aceleração por golpe",
	"attack_speed_ramp_min_multiplier": "Limite da aceleração",
	"pre_attack_speed_boost": "Acelera ao achar alvo",
	"pre_attack_boost_multiplier": "Multiplicador da aceleração",
	"pre_attack_boost_duration": "Duração da aceleração",
	"entrance_rage_duration": "Fúria ao entrar (s)",
	"entrance_rage_damage_mult": "Dano na fúria de entrada",
	"entrance_rage_speed_mult": "Velocidade na fúria de entrada",
	"entrance_shockwave_damage": "Onda de choque ao entrar (dano)",
	"entrance_shockwave_radius": "Raio da onda de choque",
	"execute_threshold": "Executa alvo com vida abaixo de (0-1)",
	"execute_damage_mult": "Dano da execução",
	"low_hp_rage_threshold": "Fúria com vida abaixo de (0-1)",
	"low_hp_rage_damage_mult": "Dano na fúria de vida baixa",
	"continuous_attack": "Ataque contínuo (raio/lança-chamas)",
	"continuous_damage_per_second": "Dano por segundo contínuo",
	"spin_attack": "Ataque giratório (360°)",
	"frontal_cone_attack": "Ataque em cone",
	"cone_angle_degrees": "Ângulo do cone",
	"aoe_hits_extra_one": "Acerta +1 alvo extra",
	"has_shield": "Tem escudo",
	"shield_amount": "Escudo",
	"shield_recharge_time": "Escudo recarrega após (s)",
	"has_temp_shield": "Escudo temporário",
	"temp_shield_amount": "Escudo temporário (valor)",
	"temp_shield_duration": "Duração do escudo temporário",
	"is_linked": "Vida compartilhada com o grupo",
	"link_share_percent": "Fração compartilhada",
	"can_resurrect": "Ressuscita 1x",
	"resurrect_hp_percent": "Vida ao ressuscitar (0-1)",
	"taunt_radius": "Raio da provocação",
	"immune_to_effect": "Imune ao efeito",
	"immune_to_knockback": "Imune a empurrão",
	"immune_to_pull": "Imune a puxão",
	"counter_attack_chance": "Chance de contra-ataque (0-1)",
	"reflects_damage": "Reflete dano",
	"reflect_damage_percent": "Fração refletida",
	"passive_regen": "Regenera vida",
	"regen_amount": "Regeneração",
	"regen_interval": "Intervalo da regeneração",
	"heals_on_kill": "Cura ao matar",
	"heal_on_kill_amount": "Cura ao matar (valor)",
	"converts_kills_to_gold": "Ganha ouro ao matar",
	"gold_per_kill": "Ouro por abate",
	"landing_duration": "Tempo pousando (reforço aéreo)",
	"can_stealth": "Fica invisível",
	"stealth_reveal_range": "Distância que revela",
	"immune_while_moving": "Imune enquanto anda",
	"spawn_invulnerability_duration": "Invulnerável ao nascer (s)",
	"extra_damage_vs_role": "Dano extra contra categoria",
	"extra_damage_vs_role_mult": "Dano extra (0.5 = +50%)",
	"deals_arrival_damage": "Dano ao chegar",
	"arrival_damage": "Dano de chegada",
	"arrival_damage_radius": "Raio do dano de chegada",
	"transforms_into_building": "Vira construção",
	"transform_after_seconds": "Vira depois de (s)",
	"transformed_scene": "Construção em que se transforma",
	"can_clone": "Se clona",
	"clone_hp_percent": "Vida do clone (0-1)",
	"clone_count": "Quantos clones",
	"grants_resource_on_death": "Dá recurso ao morrer",
	"death_resource_amount": "Recurso ao morrer",
	"can_convert_enemy": "Converte inimigo",
	"convert_max_targets": "Máx. conversões",
}

# campos que não fazem sentido no formulário (já estão acima ou são imagem)
const UNIT_SKIP = ["role", "projectile_texture"]

const SPELL_FX_FIELDS = ["fx_style", "fx_tint", "fx_power", "fx_sound"]
const SPELL_FIELDS = [
	["fx_style", "Estilo do efeito", "enum", Fx.STYLE_NAMES],
	["fx_tint", "Cor", "enum", SpellData.TINT_NAMES],
	["fx_power", "Quantidade de partícula (1 = normal)", "float", [0.3, 2.5, 0.1]],
	["fx_sound", "Som", "enum", SpellData.SOUND_NAMES],
	["radius", "Raio", "float", [10.0, 400.0, 5.0]],
	["damage", "Dano", "int", [0, 5000, 5]],
	["duration", "Duração (0 = instantâneo)", "float", [0.0, 20.0, 0.5]],
	["tick_interval", "Intervalo entre pulsos (s)", "float", [0.1, 5.0, 0.1]],
	["heal_amount", "Cura", "int", [0, 2000, 5]],
	["status_effect", "Efeito", "enum", EFFECT_NAMES],
	["status_effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
	["status_effect_duration", "Duração do efeito em quem é atingido (s) — 0 = automático", "float", [0.0, 30.0, 0.5]],
	["rolls", "Rola pelo chão (anda pra frente batendo, tipo tronco)", "bool", []],
	["roll_distance", "Até onde rola", "float", [50.0, 900.0, 10.0]],
	["roll_speed", "Velocidade da rolagem", "float", [50.0, 800.0, 10.0]],
	["picks_strongest", "Acerta só os N de mais vida no raio (0 = todos)", "int", [0, 10, 1]],
	["mirror", "Espelho: repete a última carta que você jogou", "bool", []],
	["affects_enemies", "Afeta inimigos", "bool", []],
	["affects_allies", "Afeta aliados", "bool", []],
	["base_damage_multiplier", "Dano na base (fração)", "float", [0.0, 2.0, 0.02]],
	["knockback_distance", "Força do empurrão/puxão (tornado)", "float", [0.0, 200.0, 2.0]],
	["rage_damage_mult", "Fúria: dano dos aliados (1 = nada, 1.4 = +40%)", "float", [1.0, 3.0, 0.05]],
	["rage_speed_mult", "Fúria: velocidade dos aliados", "float", [1.0, 3.0, 0.05]],
	["rage_attack_speed_mult", "Fúria: rapidez de ataque dos aliados", "float", [1.0, 3.0, 0.05]],
	["shield_amount", "Escudo nos aliados (absorve dano)", "int", [0, 3000, 10]],
	["cleanses", "Purificar (tira efeitos ruins dos aliados)", "bool", []],
	["buff_duration", "Duração da fúria/escudo (s) — 0 = automático", "float", [0.0, 30.0, 0.5]],
	["clones_allies", "Clone: copia as tropas aliadas na área (com 1 de vida)", "bool", []],
	["splits_damage", "Vazio: o dano é dividido entre quem estiver na área", "bool", []],
	["building_damage_mult", "Dano em construção (x) — Terremoto", "float", [0.0, 10.0, 0.25]],
	["summon_at_end", "Rolando: a invocação nasce no fim da rolagem (barril)", "bool", []],
	["summon_scene", "Invoca a unidade", "scene", []],
	["summon_count", "Quantas invoca de uma vez, na hora que cai (0 = nenhuma)", "int", [0, 20, 1]],
	["summon_interval", "Invoca 1 a cada (s) enquanto o feitiço durar (0 = desligado)", "float", [0.0, 10.0, 0.1]],
]

const BASE_FIELDS = [
	["base_name", "Nome", "text", []],
	["description", "Descrição", "multiline", []],
	["base_hp", "Vida", "int", [100, 20000, 50]],
	["base_type", "Função", "enum", ["Canhão", "Produção", "Cura", "Vida extra", "Espaço", "Aura"]],
	["category", "Categoria", "enum", ["Ofensivo", "Defensivo", "Econômico"]],
	["nation_data", "Nação", "nation", []],
	["attack_damage", "Dano do canhão", "int", [0, 2000, 5]],
	["attack_range", "Alcance do canhão", "float", [20.0, 600.0, 10.0]],
	["attack_speed", "Tempo entre tiros (s)", "float", [0.1, 10.0, 0.1]],
	["is_aoe", "Tiro em área", "bool", []],
	["aoe_radius", "Raio do tiro", "float", [10.0, 300.0, 5.0]],
	["production_speed_boost", "Produção extra (0.12 = 12%)", "float", [0.0, 1.0, 0.01]],
	["heal_amount", "Cura por pulso", "int", [0, 500, 1]],
	["heal_radius", "Raio da cura", "float", [10.0, 400.0, 10.0]],
	["heal_interval", "Intervalo da cura (s)", "float", [0.2, 10.0, 0.1]],
	["capacity_bonus", "Espaço extra de recurso", "int", [0, 200, 5]],
	["aura_radius", "Raio da aura", "float", [10.0, 400.0, 10.0]],
	["effect", "Efeito da aura", "enum", EFFECT_NAMES],
	["effect_strength", "Força do efeito", "float", [0.0, 500.0, 0.05]],
	["targets", "Acerta", "enum", ["Chão e ar", "Só chão", "Só ar"]],
	["projectile_speed", "Velocidade do projétil", "float", [60.0, 1200.0, 20.0]],
	["projectile_can_miss", "Tiro pode errar (vai reto pra onde o alvo estava)", "bool", []],
	["projectile_launch_angle", "Ângulo de saída do tiro (0 = reto, maior = arco mais alto)", "float", [0.0, 80.0, 5.0]],
	["projectile_pierces", "Tiro atravessa", "bool", []],
	["projectile_max_targets", "Atravessa quantos alvos", "int", [1, 10, 1]],
	["projectile_splits", "Tiro se divide ao acertar", "bool", []],
	["projectile_split_count", "Em quantos se divide", "int", [1, 8, 1]],
	["projectile_split_range", "Alcance dos pedaços", "float", [30.0, 400.0, 10.0]],
	["projectile_chains", "Tiro pula em cadeia", "bool", []],
	["projectile_chain_max_targets", "Pula em quantos alvos", "int", [1, 10, 1]],
	["projectile_chain_range", "Distância de cada pulo", "float", [30.0, 400.0, 10.0]],
	["effect_duration", "Duração do efeito (s)", "float", [0.0, 20.0, 0.25]],
	["effect_tick_interval", "Efeito: tempo entre os pulsos (s)", "float", [0.1, 5.0, 0.1]],
	["knockback_distance", "Distância do empurrão / puxão", "float", [0.0, 200.0, 5.0]],
	["aura_tick_interval", "Aura: tempo entre os pulsos (s)", "float", [0.2, 10.0, 0.1]],
	["beam_attack", "Raio contínuo (torre inferno): raio ligado no alvo em vez de projétil", "bool", []],
	["beam_tint", "Cor do raio", "enum", ["Laranja (padrão)", "Vermelho", "Laranja", "Amarelo", "Verde", "Azul claro", "Azul", "Roxo", "Rosa", "Branco", "Preto"]],
	["beam_heats_red", "Raio fica vermelho conforme esquenta", "bool", []],
	["extra_targets", "Atira em mais alvos por vez (+)", "int", [0, 5, 1]],
	["ramp_per_shot", "Dano cresce a cada tiro no mesmo alvo (0.2 = +20%, 0 = desligado)", "float", [0.0, 2.0, 0.05]],
	["ramp_max_mult", "Teto do crescimento (x)", "float", [1.0, 10.0, 0.5]],
	["execute_threshold", "Executa alvo com menos que (fração da vida, 0 = desligado)", "float", [0.0, 1.0, 0.05]],
	["execute_damage_mult", "Dano no alvo fraco (x)", "float", [1.0, 10.0, 0.5]],
	["damage_reduction_percent", "Redução de dano (0.2 = 20%)", "float", [0.0, 0.9, 0.05]],
	["regen_per_second", "Regenera vida por segundo", "int", [0, 500, 5]],
	["reflect_percent", "Devolve dano pra quem bate de perto (0.3 = 30%)", "float", [0.0, 2.0, 0.05]],
	["death_explosion_damage", "Explode ao cair: dano (0 = desligado)", "int", [0, 5000, 10]],
	["death_explosion_radius", "Explode ao cair: raio", "float", [30.0, 400.0, 10.0]],
	["gives_initial_boost", "Dá impulso no começo da partida", "bool", []],
	["initial_money_boost", "Impulso: recurso extra no começo", "int", [0, 100, 5]],
	["initial_production_speed_mult", "Impulso: recurso mais rápido no começo (x)", "float", [1.0, 4.0, 0.1]],
	["initial_boost_duration", "Impulso: quanto dura (s)", "float", [0.0, 120.0, 5.0]],
	["unlock_arena", "Libera na arena (0 = desde o começo)", "int", [0, 12, 1]],
	["rarity_pick", "Raridade (mais raro = mais caro pra subir de nível)", "enum", ["Automática (pela habilidade)", "Normal", "Rara", "Épica", "Lendária", "Mística"]],
	["spawn_card_id", "Solta esta tropa", "cardid", []],
	["spawn_on_hit", "Solta quando APANHA (desligado: solta sozinho, de tempos em tempos)", "bool", []],
	["spawn_cooldown", "Intervalo entre as tropas (s)", "float", [1.0, 120.0, 1.0]],
	["ally_speed_bonus", "Suas tropas andam mais rápido (0.25 = +25%)", "float", [0.0, 1.0, 0.05]],
	["ally_speed_max_cost", "...só as cartas de custo até", "int", [0, 100, 5]],
]

var _extra_fields_cache: Array = []


# gera a lista [prop, rótulo, tipo, opções] de TODO campo exportado do
# UnitData que não está em UNIT_FIELDS
func unit_extra_fields() -> Array:
	if !_extra_fields_cache.is_empty():
		return _extra_fields_cache
	var base: Dictionary = {}
	for f in UNIT_FIELDS:
		base[f[0]] = true
	var probe = UnitData.new()
	for p in probe.get_property_list():
		var pname: String = p["name"]
		if base.has(pname) or pname in UNIT_SKIP:
			continue
		if !(p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or !(p["usage"] & PROPERTY_USAGE_EDITOR):
			continue
		var label = UNIT_EXTRA_LABELS.get(pname, pname.replace("_", " ").capitalize())
		match p["type"]:
			TYPE_BOOL:
				_extra_fields_cache.append([pname, label, "bool", []])
			TYPE_INT:
				if p["hint"] == PROPERTY_HINT_ENUM:
					var opts: Array = []
					for item in String(p["hint_string"]).split(","):
						opts.append(item.split(":")[0].strip_edges())
					if pname.ends_with("effect"):
						opts = Array(EFFECT_NAMES)
					_extra_fields_cache.append([pname, label, "enum", opts])
				elif pname == "beam_tint":
					_extra_fields_cache.append([pname, label, "enum", ["Cor da carta", "Vermelho", "Laranja", "Amarelo", "Verde", "Azul claro", "Azul", "Roxo", "Rosa", "Branco", "Preto"]])
				else:
					_extra_fields_cache.append([pname, label, "int", [0, 100000, 1]])
			TYPE_FLOAT:
				_extra_fields_cache.append([pname, label, "float", [0.0, 100000.0, 0.05]])
			TYPE_OBJECT:
				if p["hint_string"] == "PackedScene":
					_extra_fields_cache.append([pname, label, "scene", []])
	return _extra_fields_cache


# todos os campos de unidade (básicos + habilidades) -- usado pra salvar edição
func all_unit_fields() -> Array:
	return UNIT_FIELDS + unit_extra_fields()


var custom_cards: Array[CardData] = []
var custom_bases: Array[BaseData] = []
var _overrides: Dictionary = {"cards": {}, "bases": {}}
var _originals: Dictionary = {}  # caminho -> snapshot original (pra "restaurar original")
var _sprite_overrides: Dictionary = {}  # caminho da carta -> Texture2D (sprite da unidade em campo)
var _arena_data: Array = []
var _loaded := false
var default_projectile: ImageTexture


func _ready():
	for d in [ROOT, CARDS_DIR, UNITS_DIR, BASES_DIR, ART_DIR]:
		DirAccess.make_dir_recursive_absolute(d)
	default_projectile = _make_default_projectile()
	load_all()


func load_all():
	if _loaded:
		return
	_loaded = true
	_load_custom_cards()
	_load_custom_bases()
	_load_overrides()
	_load_arenas()


# ================================================================ helpers

static func new_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]


static func image_to_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func texture_to_image(tex: Texture2D, size: Vector2i) -> Image:
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	if img == null:
		img = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		return img
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != size:
		# arte maior/menor -- encaixa no tamanho do editor sem borrar
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	return img


func default_projectile_image() -> Image:
	var img = Image.create_empty(PROJ_ART_SIZE.x, PROJ_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in PROJ_ART_SIZE.x:
		for y in PROJ_ART_SIZE.y:
			var d = Vector2(x - 7.5, y - 7.5).length()
			if d <= 3.2:
				img.set_pixel(x, y, Color(1, 0.95, 0.6))
			elif d <= 4.3:
				img.set_pixel(x, y, Color("1a1018"))
	return img


# grava a arte do projétil (se foi desenhada) e devolve a textura a usar
func _store_projectile(pack: Dictionary, art_path: String, current: Texture2D) -> Texture2D:
	if !pack.get("proj_changed", false) or pack.get("proj_image") == null:
		return current
	var tex: ImageTexture = null
	if current is ImageTexture and current.resource_path == art_path:
		tex = current
		tex.set_image(pack["proj_image"])
		ResourceSaver.save(tex, art_path)
	else:
		tex = image_to_texture(pack["proj_image"])
		_save_texture(tex, art_path)
	return tex


func _make_default_projectile() -> ImageTexture:
	var img = Image.create_empty(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 6:
		for y in 6:
			if Vector2(x - 2.5, y - 2.5).length() <= 2.6:
				img.set_pixel(x, y, Color(1, 0.95, 0.6))
	return ImageTexture.create_from_image(img)


func _save_texture(tex: ImageTexture, path: String) -> ImageTexture:
	ResourceSaver.save(tex, path)
	tex.take_over_path(path)
	return tex


func _list_files(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if !dir.current_is_dir() and f.ends_with(ext):
			out.append(dir_path + f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func get_prop(obj: Object, prop: String):
	return obj.get(prop)


static func set_prop(obj: Object, prop: String, value):
	var current = obj.get(prop)
	if current is int and value is float:
		value = int(round(value))
	elif current is float and value is int:
		value = float(value)
	obj.set(prop, value)


static func snapshot(obj: Object, fields: Array) -> Dictionary:
	var d = {}
	for f in fields:
		var v = obj.get(f[0])
		if f[2] == "scene" or f[2] == "nation":
			v = "res:" + (v.resource_path if v is Resource else "")
		d[f[0]] = v
	return d


static func apply_snapshot(obj: Object, data: Dictionary, fields: Array):
	for f in fields:
		if !data.has(f[0]):
			continue
		var v = data[f[0]]
		if f[2] == "scene" or f[2] == "nation":
			var path = String(v).trim_prefix("res:")
			obj.set(f[0], load(path) if path != "" and ResourceLoader.exists(path) else null)
		else:
			set_prop(obj, f[0], v)


func is_custom(res: Resource) -> bool:
	return res != null and res.resource_path.begins_with(ROOT)


func has_override(res: Resource) -> bool:
	if res == null:
		return false
	return _overrides["cards"].has(res.resource_path) or _overrides["bases"].has(res.resource_path)


func get_sprite_override(card_path: String) -> Texture2D:
	return _sprite_overrides.get(card_path, null)


# ================================================================ cartas

func _load_custom_cards():
	for path in _list_files(CARDS_DIR, ".tres"):
		var card = load(path)
		if card is CardData:
			_register_card(card)


# carta "só invocação": não entra no baralho, na coleção nem nos bots --
# existe só pra ser filhote de outra carta (invocar, nascer ao morrer...)
static func is_spawn_only(card: CardData) -> bool:
	return card != null and card.has_meta("spawn_only") and bool(card.get_meta("spawn_only"))


func spawn_only_cards() -> Array:
	return custom_cards.filter(func(c): return is_spawn_only(c))


# toda carta de unidade que pode ser escolhida como filhote (jogáveis + só invocação)
func all_unit_cards_for_spawn() -> Array:
	var out: Array = []
	for c in CardDatabase.all_cards + spawn_only_cards():
		if c != null and c.unit_scene != null and !out.has(c):
			out.append(c)
	return out


func _register_card(card: CardData):
	CardGenerator.reset_style_cache()  # arte nova vira peça/cor pro gerador
	if !custom_cards.has(card):
		custom_cards.append(card)
	if is_spawn_only(card):
		CardDatabase.all_cards.erase(card)
	elif !CardDatabase.all_cards.has(card):
		CardDatabase.all_cards.append(card)


# cria uma carta NOVA vazia (unidade ou feitiço) com valores razoáveis --
# o criador preenche e chama save_card()
func make_blank_card(is_spell: bool) -> Dictionary:
	var card = CardData.new()
	card.card_name = "Nova carta"
	card.cost = 30
	card.role = CardData.CardRole.VERSATIL
	card.danger_level = 3
	card.description = ""
	card.tier = 1
	card.nation_xp_cost = 0
	var stats: UnitData = null
	var spell: SpellData = null
	if is_spell:
		spell = SpellData.new()
		spell.damage = 200
		spell.radius = 70.0
	else:
		stats = UnitData.new()
		stats.hp = 400
		stats.damage = 60
		stats.attack_speed = 1.2
		stats.attack_range = 15.0
		stats.move_speed = 45.0
	var img = Image.create_empty(CARD_ART_SIZE.x, CARD_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return {"card": card, "stats": stats, "spell": spell, "image": img, "is_new": true,
		"proj_image": default_projectile_image()}


# monta o "pacote de edição" de uma carta existente (original ou criada)
func open_card_for_edit(card: CardData) -> Dictionary:
	var stats: UnitData = DeckBuilder.get_unit_stats(card)
	var img = texture_to_image(card.icon, CARD_ART_SIZE)
	var proj_img = default_projectile_image()
	if stats != null and stats.projectile_texture != null:
		proj_img = texture_to_image(stats.projectile_texture, PROJ_ART_SIZE)
	return {"card": card, "stats": stats, "spell": card.spell_data, "image": img, "is_new": false, "proj_image": proj_img}


## CÓPIA de uma carta (sua ou do jogo): abre como carta NOVA, com tudo igual e " (cópia)" no nome.
## Só vira carta de verdade quando salvar; a original não muda.
func copy_card_pack(card: CardData) -> Dictionary:
	var src = open_card_for_edit(card)
	var c2: CardData = card.duplicate()
	c2.card_name = card.card_name + " (cópia)"
	c2.unit_scene = null
	c2.spell_data = null
	c2.icon = null
	if card.art_recipe != null:
		c2.art_recipe = card.art_recipe.duplicate()
	if card.art_palette != null:
		c2.art_palette = card.art_palette.duplicate()
	var st2: UnitData = src["stats"].duplicate() if src["stats"] != null else null
	return {"card": c2, "stats": st2, "spell": src["spell"].duplicate() if src["spell"] != null else null,
		"image": src["image"].duplicate(), "proj_image": src["proj_image"].duplicate(), "proj_changed": true, "is_new": true}


# salva um pacote de edição. Pra carta criada: grava os arquivos. Pra carta
# ORIGINAL do jogo: aplica na memória e guarda como override
func save_card(pack: Dictionary, image_changed: bool) -> CardData:
	var card: CardData = pack["card"]
	if pack.get("is_new", false) or is_custom(card):
		return _save_custom_card(pack, image_changed)
	_save_card_override(pack, image_changed)
	DeckBuilder.clear_cache()
	content_changed.emit()
	return card


func _save_custom_card(pack: Dictionary, image_changed: bool) -> CardData:
	var card: CardData = pack["card"]
	var id: String
	if card.resource_path.begins_with(CARDS_DIR):
		id = card.resource_path.get_file().get_basename()
	else:
		id = new_id("carta")

	# arte -- ImageTexture salva em .res (load() funciona no celular, PNG cru não)
	var art_path = ART_DIR + id + ".res"
	var tex: ImageTexture = card.icon if card.icon is ImageTexture and card.icon.resource_path == art_path else null
	if tex == null:
		tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
	elif image_changed:
		tex.set_image(pack["image"])
		ResourceSaver.save(tex, art_path)
	card.icon = tex

	if pack["spell"] != null:
		var spell: SpellData = pack["spell"]
		var spell_path = UNITS_DIR + id + "_spell.tres"
		ResourceSaver.save(spell, spell_path)
		spell.take_over_path(spell_path)
		card.spell_data = spell
		card.unit_scene = null
	else:
		var stats: UnitData = pack["stats"]
		stats.role = card.role
		stats.projectile_texture = _store_projectile(pack, ART_DIR + id + "_proj.res", stats.projectile_texture)
		if stats.is_ranged and stats.projectile_texture == null:
			stats.projectile_texture = default_projectile
		var stats_path = UNITS_DIR + id + "_stats.tres"
		ResourceSaver.save(stats, stats_path)
		stats.take_over_path(stats_path)
		var scene_path = UNITS_DIR + id + ".tscn"
		if card.unit_scene == null or card.unit_scene.resource_path != scene_path:
			card.unit_scene = _build_unit_scene(stats, tex, scene_path)
		card.spell_data = null

	var card_path = CARDS_DIR + id + ".tres"
	var err = ResourceSaver.save(card, card_path)
	if err != OK:
		push_error("CustomContent: não consegui salvar a carta (%d)" % err)
	card.take_over_path(card_path)
	_register_card(card)
	DeckBuilder.clear_cache()
	content_changed.emit()
	return card


# duplica o molde de unidade do jogo (mantém colisão, barra de vida, área
# de detecção, navegação...) e só troca stats + sprite
func _build_unit_scene(stats: UnitData, tex: Texture2D, scene_path: String) -> PackedScene:
	var template: PackedScene = load(UNIT_TEMPLATE)
	var node = template.instantiate()
	node.stats = stats
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if tex != null and tex.get_width() >= 48:
			sprite.scale = Vector2(Catalogo.SPRITE_SCALE, Catalogo.SPRITE_SCALE)  # arte 2.0 (48x48)
	var packed = PackedScene.new()
	packed.pack(node)
	node.free()
	ResourceSaver.save(packed, scene_path)
	packed.take_over_path(scene_path)
	return packed


func delete_custom_card(card: CardData):
	if !is_custom(card):
		return
	var id = card.resource_path.get_file().get_basename()
	for p in [CARDS_DIR + id + ".tres", UNITS_DIR + id + ".tscn", UNITS_DIR + id + "_stats.tres", UNITS_DIR + id + "_spell.tres", ART_DIR + id + ".res"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	custom_cards.erase(card)
	CardDatabase.all_cards.erase(card)
	content_changed.emit()


func _save_card_override(pack: Dictionary, image_changed: bool):
	var card: CardData = pack["card"]
	var path = card.resource_path
	var entry: Dictionary = _overrides["cards"].get(path, {})
	entry["card"] = snapshot(card, CARD_FIELDS)
	if pack["stats"] != null:
		entry["unit"] = snapshot(pack["stats"], all_unit_fields())
		if pack.get("proj_changed", false):
			var proj_path = ART_DIR + "ovp_" + str(abs(hash(path))) + ".res"
			pack["stats"].projectile_texture = _store_projectile(pack, proj_path, null)
			entry["proj_art"] = proj_path
	if pack["spell"] != null:
		entry["spell"] = snapshot(pack["spell"], SPELL_FIELDS)
	if image_changed:
		var art_path = ART_DIR + "ov_" + str(abs(hash(path))) + ".res"
		var tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
		entry["art"] = art_path
		card.icon = tex
		_sprite_overrides[path] = tex
	_overrides["cards"][path] = entry
	_write_overrides()


func restore_original_card(card: CardData):
	var path = card.resource_path
	if _originals.has(path):
		var o = _originals[path]
		apply_snapshot(card, o["card"], CARD_FIELDS)
		Catalogo.apply_companion(card)
		var stats = DeckBuilder.get_unit_stats(card)
		if stats != null and o.has("unit"):
			apply_snapshot(stats, o["unit"], all_unit_fields())
			stats.projectile_texture = o.get("proj", stats.projectile_texture)
		if card.spell_data != null and o.has("spell"):
			apply_snapshot(card.spell_data, o["spell"], SPELL_FIELDS)
		if o.has("icon"):
			card.icon = o["icon"]
	_sprite_overrides.erase(path)
	_overrides["cards"].erase(path)
	_write_overrides()
	content_changed.emit()


# guarda os valores originais ANTES de aplicar edição (só na 1ª vez), pra
# conseguir "restaurar original" sem reiniciar o jogo
func remember_original_card(card: CardData):
	var path = card.resource_path
	if _originals.has(path) or is_custom(card):
		return
	var o = {"card": snapshot(card, CARD_FIELDS), "icon": card.icon}
	var stats = DeckBuilder.get_unit_stats(card)
	if stats != null:
		o["unit"] = snapshot(stats, all_unit_fields())
		o["proj"] = stats.projectile_texture
	if card.spell_data != null:
		o["spell"] = snapshot(card.spell_data, SPELL_FIELDS)
	_originals[path] = o


func remember_original_base(base: BaseData):
	var path = base.resource_path
	if _originals.has(path) or is_custom(base):
		return
	_originals[path] = {"base": snapshot(base, BASE_FIELDS), "icon": base.icon, "texture": base.base_texture, "proj": base.projectile_texture}


# ================================================================ bases

func _load_custom_bases():
	for path in _list_files(BASES_DIR, ".tres"):
		var b = load(path)
		if b is BaseData:
			_register_base(b)


func _register_base(b: BaseData):
	if !custom_bases.has(b):
		custom_bases.append(b)
	if !BotSimulator.available_bases.has(b):
		BotSimulator.available_bases.append(b)


func make_blank_base() -> Dictionary:
	var b = BaseData.new()
	b.base_name = "Nova base"
	b.base_hp = 1000
	b.base_type = BaseData.BaseType.CANNON
	b.nation_xp_cost = 0
	var img = Image.create_empty(BASE_ART_SIZE.x, BASE_ART_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return {"base": b, "image": img, "is_new": true, "proj_image": default_projectile_image()}


## CÓPIA de um módulo (seu ou do jogo): abre como módulo NOVO, igual, com " (cópia)" no nome
func copy_base_pack(b: BaseData) -> Dictionary:
	var src = open_base_for_edit(b)
	var b2: BaseData = b.duplicate()
	b2.base_name = b.base_name + " (cópia)"
	b2.base_texture = null
	b2.icon = null
	return {"base": b2, "image": src["image"].duplicate(), "proj_image": src["proj_image"].duplicate(), "proj_changed": true, "is_new": true}


func open_base_for_edit(b: BaseData) -> Dictionary:
	var tex = b.base_texture if b.base_texture != null else b.icon
	var proj_img = texture_to_image(b.projectile_texture, PROJ_ART_SIZE) if b.projectile_texture != null else default_projectile_image()
	return {"base": b, "image": texture_to_image(tex, BASE_ART_SIZE), "is_new": false, "proj_image": proj_img}


func save_base(pack: Dictionary, image_changed: bool) -> BaseData:
	var b: BaseData = pack["base"]
	if !(pack.get("is_new", false) or is_custom(b)):
		var path = b.resource_path
		var entry: Dictionary = _overrides["bases"].get(path, {})
		entry["base"] = snapshot(b, BASE_FIELDS)
		if image_changed:
			var art_path = ART_DIR + "ovb_" + str(abs(hash(path))) + ".res"
			var tex = image_to_texture(pack["image"])
			_save_texture(tex, art_path)
			entry["art"] = art_path
			b.base_texture = tex
			b.icon = tex
		if pack.get("proj_changed", false):
			var proj_path = ART_DIR + "ovbp_" + str(abs(hash(path))) + ".res"
			b.projectile_texture = _store_projectile(pack, proj_path, null)
			entry["proj_art"] = proj_path
		_overrides["bases"][path] = entry
		_write_overrides()
		content_changed.emit()
		return b

	var id: String = b.resource_path.get_file().get_basename() if b.resource_path.begins_with(BASES_DIR) else new_id("base")
	var art_path = ART_DIR + id + ".res"
	var tex: ImageTexture = b.base_texture if b.base_texture is ImageTexture and b.base_texture.resource_path == art_path else null
	if tex == null:
		tex = image_to_texture(pack["image"])
		_save_texture(tex, art_path)
	elif image_changed:
		tex.set_image(pack["image"])
		ResourceSaver.save(tex, art_path)
	b.base_texture = tex
	b.icon = tex
	b.projectile_texture = _store_projectile(pack, ART_DIR + id + "_proj.res", b.projectile_texture)
	if b.projectile_texture == null:
		b.projectile_texture = default_projectile
	var base_path = BASES_DIR + id + ".tres"
	ResourceSaver.save(b, base_path)
	b.take_over_path(base_path)
	_register_base(b)
	content_changed.emit()
	return b


func restore_original_base(b: BaseData):
	var path = b.resource_path
	if _originals.has(path):
		apply_snapshot(b, _originals[path]["base"], BASE_FIELDS)
		b.icon = _originals[path]["icon"]
		b.base_texture = _originals[path]["texture"]
		b.projectile_texture = _originals[path].get("proj", b.projectile_texture)
	_overrides["bases"].erase(path)
	_write_overrides()
	content_changed.emit()


func delete_custom_base(b: BaseData):
	if !is_custom(b):
		return
	var id = b.resource_path.get_file().get_basename()
	for p in [BASES_DIR + id + ".tres", ART_DIR + id + ".res"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	custom_bases.erase(b)
	BotSimulator.available_bases.erase(b)
	content_changed.emit()


# todas as nações que existem no jogo: as cadastradas no NationDatabase +
# as que as cartas e bases já usam (o banco de nações pode estar vazio)
func all_nations() -> Array:
	var out: Array = []
	var names: Dictionary = {}
	var pools: Array = [NationDatabase.all_nations]
	var from_items: Array = []
	for c in CardDatabase.all_cards:
		if c != null and c.nation_data != null:
			from_items.append(c.nation_data)
	for b in all_bases([]):
		if b != null and b.nation_data != null:
			from_items.append(b.nation_data)
	pools.append(from_items)
	for pool in pools:
		for n in pool:
			if n != null and !names.has(n.nation_name):
				names[n.nation_name] = true
				out.append(n)
	out.sort_custom(func(a, b): return a.nation_name < b.nation_name)
	return out


# todas as bases que o jogo conhece (originais da coleção + criadas)
func all_bases(original_list: Array) -> Array:
	var out: Array = []
	for b in original_list:
		if b != null and !out.has(b):
			out.append(b)
	for b in BotSimulator.available_bases:
		if b != null and !out.has(b):
			out.append(b)
	for b in custom_bases:
		if !out.has(b):
			out.append(b)
	return out


# ================================================================ overrides

func _load_overrides():
	if !FileAccess.file_exists(OVERRIDES_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
	if !(data is Dictionary):
		return
	_overrides["cards"] = data.get("cards", {})
	_overrides["bases"] = data.get("bases", {})

	for path in _overrides["cards"]:
		if !ResourceLoader.exists(path):
			continue
		var card = load(path)
		if !(card is CardData):
			continue
		remember_original_card(card)
		var entry = _overrides["cards"][path]
		apply_snapshot(card, entry.get("card", {}), CARD_FIELDS)
		Catalogo.apply_companion(card)
		var stats = DeckBuilder.get_unit_stats(card)
		if stats != null and entry.has("unit"):
			apply_snapshot(stats, entry["unit"], all_unit_fields())
			if stats.is_ranged and stats.projectile_texture == null:
				stats.projectile_texture = default_projectile
		if card.spell_data != null and entry.has("spell"):
			apply_snapshot(card.spell_data, entry["spell"], SPELL_FIELDS)
		var proj_art = entry.get("proj_art", "")
		if stats != null and proj_art != "" and ResourceLoader.exists(proj_art):
			stats.projectile_texture = load(proj_art)
		var art = entry.get("art", "")
		if art != "" and ResourceLoader.exists(art):
			var tex = load(art)
			card.icon = tex
			_sprite_overrides[path] = tex

	for path in _overrides["bases"]:
		if !ResourceLoader.exists(path):
			continue
		var b = load(path)
		if !(b is BaseData):
			continue
		remember_original_base(b)
		var entry = _overrides["bases"][path]
		apply_snapshot(b, entry.get("base", {}), BASE_FIELDS)
		var bproj = entry.get("proj_art", "")
		if bproj != "" and ResourceLoader.exists(bproj):
			b.projectile_texture = load(bproj)
		var art = entry.get("art", "")
		if art != "" and ResourceLoader.exists(art):
			var tex = load(art)
			b.base_texture = tex
			b.icon = tex


func _write_overrides():
	var f = FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_overrides, "\t"))


# ================================================================ arenas

func _load_arenas():
	_arena_data = []
	if FileAccess.file_exists(ARENAS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(ARENAS_PATH))
		if data is Array:
			_arena_data = data
	_apply_arenas()


func _apply_arenas():
	var list: Array = ArenaManager.DEFAULT_ARENAS.duplicate(true)
	for entry in _arena_data:
		var idx = int(entry.get("index", 0))
		if idx <= 0:
			continue
		while list.size() <= idx:
			list.append({"name": "Arena %d" % list.size(), "emoji": "⭐", "trophy_threshold": 0})
		var a: Dictionary = list[idx].duplicate(true)
		for k in ["name", "emoji", "trophy_threshold", "rewards"]:
			if entry.has(k):
				a[k] = entry[k]
		a["trophy_threshold"] = int(a["trophy_threshold"])
		var bg = entry.get("background", "")
		if bg != "" and ResourceLoader.exists(bg):
			a["background_texture"] = load(bg)
			a["background"] = bg
		list[idx] = a
	ArenaManager.arenas = list
	ArenaManager.max_arena = list.size() - 1


func get_arena_entry(index: int) -> Dictionary:
	var a: Dictionary = ArenaManager.get_arena_info(index).duplicate(true) if index <= ArenaManager.max_arena else {}
	if !a.has("rewards"):
		a["rewards"] = ArenaManager.default_rewards_for(index)
	a["index"] = index
	return a


func save_arena(index: int, data: Dictionary, image: Image):
	var entry: Dictionary = {}
	for e in _arena_data:
		if int(e.get("index", 0)) == index:
			entry = e
			break
	if entry.is_empty():
		entry = {"index": index}
		_arena_data.append(entry)
	for k in ["name", "emoji", "trophy_threshold", "rewards"]:
		if data.has(k):
			entry[k] = data[k]
	if image != null:
		var art_path = ART_DIR + "arena_%d.res" % index
		var tex: ImageTexture = null
		if ResourceLoader.exists(art_path):
			tex = load(art_path)
			tex.set_image(image)
			ResourceSaver.save(tex, art_path)
		else:
			tex = image_to_texture(image)
			_save_texture(tex, art_path)
		entry["background"] = art_path
	_write_arenas()
	_apply_arenas()
	content_changed.emit()


func reset_arena(index: int):
	for e in _arena_data.duplicate():
		if int(e.get("index", 0)) == index:
			_arena_data.erase(e)
	_write_arenas()
	_apply_arenas()
	content_changed.emit()


func add_arena() -> int:
	var idx = ArenaManager.max_arena + 1
	var prev = ArenaManager.get_arena_info(ArenaManager.max_arena)
	save_arena(idx, {
		"name": "Arena %d" % idx, "emoji": "⭐",
		"trophy_threshold": int(prev.get("trophy_threshold", 0)) + 1000,
		"rewards": ArenaManager.default_rewards_for(idx),
	}, null)
	return idx


# só dá pra apagar a ÚLTIMA arena criada por você (as 7 originais ficam)
func remove_last_arena() -> bool:
	var idx = ArenaManager.max_arena
	if idx <= ArenaManager.DEFAULT_MAX_ARENA:
		return false
	reset_arena(idx)
	return true


func _write_arenas():
	var f = FileAccess.open(ARENAS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_arena_data, "\t"))


# ================================================================ COMEÇAR DO ZERO
# Chave "do_zero" (Criador > Coleção do jogo). Ligada, o jogo passa a usar SÓ as cartas
# criadas por você: coleção, baralho e bots. Nada é apagado de verdade: as cartas do jogo
# ficam guardadas e voltam ao desligar. Dá pra jogar com UMA carta só (ela se repete
# no baralho); o baralho inicial só entra enquanto você não criou nenhuma.
const ZERO_MIN = 8
const BACKUP_DIR = "user://custom_copia/"
var _full_cards: Array = []


func zero_on() -> bool:
	return bool(Config.data.get("do_zero", false))


func zero_pool() -> Array:
	# só as SUAS cartas, mesmo que seja uma só -- ou NENHUMA: aí a coleção fica vazia de
	# verdade e só não dá pra entrar em batalha (can_battle)
	var out: Array = []
	for c in custom_cards:
		if c != null and !is_spawn_only(c):
			out.append(c)
	# chave à parte: emprestar o baralho inicial do jogo enquanto você não tem nenhuma carta
	if out.is_empty() and bool(Config.data.get("zero_inicial", false)):
		out = Catalogo.starter_deck().duplicate()
	return out


## dá pra entrar em batalha? No "começar do zero" precisa de pelo menos uma carta sua.
func can_battle() -> bool:
	return !zero_on() or !zero_pool().is_empty()


## quantas das cartas em jogo ainda são emprestadas do jogo (0 = só as suas)
func zero_borrowed() -> int:
	return zero_pool().filter(func(c): return !custom_cards.has(c)).size()


func apply_zero():
	if zero_on():
		if _full_cards.is_empty():
			_full_cards = CardDatabase.all_cards.duplicate()
		CardDatabase.all_cards.assign(zero_pool())
		# carta de arena 0 nasce na sua coleção; as de arena maior vêm dos baús e da Feira dessa arena
		if PlayerProfile.active_profile_id >= 0 and Progresso.d.has("owned"):
			Progresso._ensure_defaults()
	elif !_full_cards.is_empty():
		var back: Array = _full_cards.duplicate()
		for c in custom_cards:
			if c != null and !is_spawn_only(c) and !back.has(c):
				back.append(c)
		CardDatabase.all_cards.assign(back)
		_full_cards = []
	_apply_safra_switch()
	DeckBuilder.clear_cache()
	apply_zero_modules()
	Assembleia.apply_all()


# ---- módulos "do zero": a mesma ideia das cartas. Ligado, só existem os módulos que você
# criar (pra você e pros bots); sem nenhum, a batalha é só com a Casa Grande.
var _full_bases: Array = []


func zero_modules_on() -> bool:
	return bool(Config.data.get("do_zero_mod", false))


func apply_zero_modules():
	if zero_modules_on():
		if _full_bases.is_empty():
			_full_bases = BotSimulator.available_bases.duplicate()
		BotSimulator.available_bases.assign(custom_bases.filter(func(b): return b != null))
	elif !_full_bases.is_empty():
		var back: Array = _full_bases.duplicate()
		for b in custom_bases:
			if b != null and !back.has(b):
				back.append(b)
		BotSimulator.available_bases.assign(back)
		_full_bases = []


## o baralho de quem joga no "começar do zero". Com menos cartas que o tamanho do
## baralho, elas se REPETEM até encher: com uma carta só, o baralho são 8 dela.
## `owned_only`: só as que o jogador já TEM (as de arena 0 nascem com ele; as outras
## vêm dos baús e da Feira da arena). `arena_cap`: o bot só usa carta até essa arena.
## Se o filtro não deixar nenhuma, vale a coleção inteira (senão não tem como jogar).
func zero_deck(seed_name: String, prefer: Array = [], owned_only: bool = false, arena_cap: int = -1) -> Array:
	var pool = zero_pool()
	var allowed = pool.filter(func(c): return (!owned_only or Progresso.is_owned(c)) and (arena_cap < 0 or c.unlock_arena <= arena_cap))
	if !allowed.is_empty():
		pool = allowed
	var out: Array = []
	for c in prefer:
		if pool.has(c) and !out.has(c) and out.size() < ZERO_MIN:
			out.append(c)
	var rng = RandomNumberGenerator.new()
	rng.seed = abs(hash(seed_name))
	var rest = pool.filter(func(c): return !out.has(c))
	while out.size() < ZERO_MIN and !rest.is_empty():
		out.append(rest.pop_at(rng.randi() % rest.size()))
	var i = 0
	while out.size() < ZERO_MIN and !pool.is_empty():
		out.append(pool[i % pool.size()])
		i += 1
	return out


func _copy_dir(from: String, to: String) -> int:
	DirAccess.make_dir_recursive_absolute(to)
	var n = 0
	var dir = DirAccess.open(from)
	if dir == null:
		return 0
	for sub in dir.get_directories():
		n += _copy_dir(from.path_join(sub), to.path_join(sub))
	for f in dir.get_files():
		if dir.copy(from.path_join(f), to.path_join(f)) == OK:
			n += 1
	return n


## guarda uma cópia de tudo que você criou e editou (cartas, módulos, arenas, desenhos)
func backup_save() -> int:
	var n = _copy_dir(ROOT, BACKUP_DIR)
	var f = FileAccess.open(BACKUP_DIR.path_join("quando.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string(Time.get_datetime_string_from_system(false, true))
	return n


func backup_when() -> String:
	return FileAccess.get_file_as_string(BACKUP_DIR.path_join("quando.txt")) if FileAccess.file_exists(BACKUP_DIR.path_join("quando.txt")) else ""


## põe a cópia de volta por cima do que tem agora (vale depois de fechar e abrir o jogo)
func backup_restore() -> int:
	return _copy_dir(BACKUP_DIR, ROOT) if backup_when() != "" else 0


# ---- chave "safra_off": as cartas colhidas pela safra saem do jogo (e voltam ao religar)
var _safra_hidden: Array = []


func safra_off() -> bool:
	return bool(Config.data.get("safra_off", false))


func _apply_safra_switch():
	if safra_off():
		for c in _full_cards.duplicate():
			if c != null and c.has_meta("safra"):
				_full_cards.erase(c)
				if !_safra_hidden.has(c):
					_safra_hidden.append(c)
		for c in CardDatabase.all_cards.duplicate():
			if c != null and c.has_meta("safra"):
				CardDatabase.all_cards.erase(c)
				if !_safra_hidden.has(c):
					_safra_hidden.append(c)
	elif !_safra_hidden.is_empty():
		# no "começar do zero" elas voltam pra lista guardada (a que retorna quando o modo desliga)
		for c in _safra_hidden:
			if zero_on():
				if !_full_cards.has(c):
					_full_cards.append(c)
			elif !CardDatabase.all_cards.has(c):
				CardDatabase.all_cards.append(c)
		_safra_hidden = []
