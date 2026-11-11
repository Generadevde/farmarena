extends RefCounted
class_name Catalogo
## FARM ARENA 2.0 -- todo o conteúdo oficial do jogo num lugar só.
##
## Cartas, turmas (nações) e torres são DADOS (tabelas abaixo). Nada de
## arquivo .tres/.tscn/.png por carta: na abertura do jogo este catálogo
## monta CardData + UnitData/SpellData + cena da unidade + arte (SpriteForge)
## na memória. Pra criar/ajustar uma carta oficial, é só mexer na tabela.
##
## Cada carta ganha um caminho "virtual" res://c2/<id>.tres -- é o
## identificador usado nos baralhos salvos, estatísticas, bots etc.

const UNIT_TEMPLATE = "res://Units/scenes/unit_base.tscn"
const PATH_PREFIX = "res://c2/"
const SPRITE_SCALE = 1.1  # só visual: o corpo (colisão/alcance) vem do CollisionShape, não do sprite

const COMUM = 0
const RARA = 1
const EPICA = 2
const LENDARIA = 3
## RARIDADE 2.0: não é mais escolhida na mão -- é a QUANTIDADE DE HABILIDADES
## da carta (ver abilities()):  0 = Normal · 1 = Rara · 2 = Épica · 3 = Lendária · 4+ = Mística
## Vale pra carta oficial, da Safra e do Criador, tudo igual.
const MISTICA = 4
const RARITY_NAMES = ["Normal", "Rara", "Épica", "Lendária", "Mística"]
const RARITY_COLORS = [Color("#b9c2c9"), Color("#f29b38"), Color("#b667e8"), Color("#5fe0d0"), Color("#ff5ad0")]

# ---------------------------------------------------------------- turmas
const TURMAS = {
	"Curral": {"cor": "#a8683c", "desc": "Gado bravo: muita vida, coice e marretada."},
	"Galinheiro": {"cor": "#e0483c", "desc": "Aves em bando: baratas, rápidas e barulhentas."},
	"Brejo": {"cor": "#4fae58", "desc": "Sapos e capivaras: controle, puxão e paciência."},
	"Roçado": {"cor": "#f0a030", "desc": "Plantação viva: explosões e dano em área."},
	"Peões": {"cor": "#3c6cb8", "desc": "O povo da roça: equilíbrio, cura e pinga."},
	"Coisa Estranha": {"cor": "#9a5cd0", "desc": "ET, robô e assombração: ninguém sabe de onde veio."},
}

# paletas reaproveitadas
const P_VACA = {"P": "#f2ede0", "S": "#3a3038", "K": "#f0b0a0", "M": "#d8d0c0"}
const P_BOI = {"P": "#8a5a3c", "K": "#e0b090", "M": "#a8b0bc", "W": "#7a5030"}
const P_BEZERRO = {"P": "#c89060", "S": "#f2ede0", "K": "#f0c0a8", "M": "#e8e0d0"}
const P_GALINHA = {"P": "#f4f0e4", "A": "#d83c30", "K": "#f0b030"}
const P_PINTO = {"P": "#f8dc50", "A": "#f08030", "K": "#f09030"}
const P_SAPO = {"P": "#68b848", "K": "#d8e890", "A": "#d83c30", "S": "#40a0d8"}
const P_CAPI = {"P": "#a87848", "K": "#c89868", "A": "#f070a0", "S": "#58a040"}
const P_PEAO = {"S": "#c84838", "A": "#3c5c98", "K": "#e8b088", "M": "#a0a8b4", "W": "#6a4428"}
const P_ABELHA = {"P": "#f4c830", "M": "#3a3038"}
const P_FANTASMA = {"P": "#d8e8f0", "K": "#d8e8f0", "S": "#a8c0d0", "A": "#8048a0", "W": "#5a4028", "M": "#b0b8c0"}

# ---------------------------------------------------------------- cartas
# campos: id, nome, turma, custo (0-100), papel, raridade, arena (em qual
# arena do Caminho dos Troféus ela entra nos baús; 0 = já vem com você),
# perigo (1-10 pra IA), desc/pros/cons, receita+paleta (arte),
# u = campos do UnitData | f = campos do SpellData, proj = projétil,
# filho/filho_morte/filho_ataque/invoca = id de outra carta,
# ficha = true -> só existe como filhote (não entra em baralho)
const CARTAS = [
	# ============================== CURRAL
	{"id": "vaca_brava", "nome": "Vaca Brava", "turma": "Curral", "custo": 40, "papel": "TANQUE", "raridade": COMUM, "arena": 0, "perigo": 5,
		"desc": "Ela não tá brava com você. Tá brava com tudo.",
		"pros": ["Muita vida", "Vai direto pra torre, ignora as tropas"], "cons": ["Lenta", "Só bate em torre e construção"],
		"receita": {"pernas": "casco", "corpo": "redondo", "bracos": "patas", "cabeca": "vaca"}, "paleta": P_VACA,
		"u": {"hp": 2300, "damage": 110, "attack_speed": 2.0, "move_speed": 28.0, "unit_scale": 1.5, "push_weight": 3.8, "target_type": "BUILDING"}},
	{"id": "bezerrada", "nome": "Bezerrada", "turma": "Curral", "custo": 25, "papel": "ENXAME", "raridade": COMUM, "arena": 0, "perigo": 3,
		"desc": "Três bezerros que acabaram de descobrir que têm cabeça dura.",
		"pros": ["Três de uma vez", "Barato e rápido"], "cons": ["Morrem pra dano em área"],
		"receita": {"pernas": "casco", "corpo": "redondo", "bracos": "patas", "cabeca": "vaca"}, "paleta": P_BEZERRO,
		"u": {"hp": 300, "damage": 55, "attack_speed": 1.5, "move_speed": 75.0, "unit_scale": 0.8, "unit_count": 3}},
	{"id": "bezerro", "nome": "Bezerro", "turma": "Curral", "custo": 10, "papel": "ENXAME", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "casco", "corpo": "redondo", "bracos": "patas", "cabeca": "vaca"}, "paleta": P_BEZERRO,
		"u": {"hp": 300, "damage": 55, "attack_speed": 1.5, "move_speed": 75.0, "unit_scale": 0.8}},
	{"id": "cavalo_coiceiro", "nome": "Cavalo Coiceiro", "turma": "Curral", "custo": 35, "papel": "CONTRA_ATAQUE", "raridade": RARA, "arena": 1, "perigo": 5,
		"desc": "Nunca fique atrás dele. Nem na frente. Nem do lado.",
		"pros": ["Rápido", "Coice joga o inimigo longe"], "cons": ["Vida mediana"],
		"receita": {"pernas": "casco", "corpo": "redondo", "bracos": "patas", "cabeca": "cavalo"}, "paleta": {"P": "#b87848", "S": "#3a2820", "K": "#e0c0a0"},
		"u": {"hp": 760, "damage": 150, "attack_speed": 1.6, "move_speed": 85.0, "unit_scale": 1.15, "push_weight": 2.0, "on_hit_effect": "KNOCKBACK", "knockback_distance": 55.0, "charge_attack": true}},
	{"id": "ovelha_violeira", "nome": "Ovelha Violeira", "turma": "Curral", "custo": 30, "papel": "SUPORTE", "raridade": RARA, "arena": 2, "perigo": 4,
		"desc": "Toca moda de viola tão bonita que até ferida fecha.",
		"pros": ["Cura quem está perto", "Ataca de longe"], "cons": ["Dano baixíssimo", "Frágil sozinha"],
		"receita": {"pernas": "casco", "corpo": "la", "bracos": "patas", "cabeca": "ovelha", "arma": "viola"}, "paleta": {"P": "#4a4048", "S": "#f4f0e8", "K": "#4a4048", "W": "#b07038", "A": "#e06080"},
		"proj": "nota",
		"u": {"hp": 620, "damage": 28, "attack_speed": 1.2, "move_speed": 45.0, "is_ranged": true, "attack_range": 110.0, "target_type": "ALL", "can_heal_allies": true, "heal_aura_amount": 28, "heal_aura_radius": 95.0, "heal_aura_interval": 1.0}},
	{"id": "bode_cabecudo", "nome": "Bode Cabeçudo", "turma": "Curral", "custo": 45, "papel": "FINALIZADOR", "raridade": RARA, "arena": 3, "perigo": 7,
		"desc": "Viu uma torre? Ele já foi. Ignora todo o resto.",
		"pros": ["Só mira em torre e construção", "Dano alto em torre"], "cons": ["Não se defende de tropa"],
		"receita": {"pernas": "casco", "corpo": "poncho", "bracos": "patas", "cabeca": "bode", "chapeu": "cowboy"}, "paleta": {"P": "#c8c0b0", "S": "#e8e0d0", "A": "#b8402c", "K": "#e8d8c0", "M": "#e0d8c0", "W": "#6a4428"},
		"u": {"hp": 1350, "damage": 190, "attack_speed": 1.8, "move_speed": 55.0, "unit_scale": 1.25, "push_weight": 2.5, "target_type": "BUILDING"}},
	{"id": "boi_marretao", "nome": "Boi Marretão", "turma": "Curral", "custo": 70, "papel": "PUNICAO", "raridade": EPICA, "arena": 4, "perigo": 9,
		"desc": "Uma marretada só. Quem sobrar em pé, voa.",
		"pros": ["Dano em área gigantesco", "Empurra todo mundo"], "cons": ["Ataque muito lento", "Caro"],
		"receita": {"pernas": "casco", "corpo": "armadura", "bracos": "patas", "cabeca": "boi", "arma": "marreta"}, "paleta": P_BOI,
		"u": {"hp": 1950, "damage": 560, "attack_speed": 5.0, "move_speed": 28.0, "unit_scale": 1.8, "push_weight": 4.5, "is_aoe": true, "aoe_radius": 55.0, "on_hit_effect": "KNOCKBACK", "knockback_distance": 45.0, "immune_to_knockback": true}},

	# ============================== GALINHEIRO
	{"id": "pintaiada", "nome": "Pintaiada", "turma": "Galinheiro", "custo": 15, "papel": "ENXAME", "raridade": COMUM, "arena": 0, "perigo": 2,
		"desc": "Seis pintinhos. Piu. Piu. Piu. Piu. Piu. Piu.",
		"pros": ["Baratíssimo", "Cerca unidade grande"], "cons": ["Qualquer coisa mata"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "pato"}, "paleta": P_PINTO,
		"u": {"hp": 45, "damage": 25, "attack_speed": 0.8, "move_speed": 80.0, "unit_scale": 0.55, "unit_count": 6, "push_weight": 0.4}},
	{"id": "pintinho", "nome": "Pintinho", "turma": "Galinheiro", "custo": 5, "papel": "ENXAME", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "pato"}, "paleta": P_PINTO,
		"u": {"hp": 45, "damage": 25, "attack_speed": 0.8, "move_speed": 80.0, "unit_scale": 0.55, "push_weight": 0.4, "initial_stun_duration": 0.2}},
	{"id": "galinha_atiradeira", "nome": "Galinhas Atiradeiras", "turma": "Galinheiro", "custo": 25, "papel": "VERSATIL", "raridade": COMUM, "arena": 0, "perigo": 3,
		"desc": "Botam ovo. Em você. Com força.",
		"pros": ["Acertam voador", "Ataque de longe"], "cons": ["Pouca vida"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "galinha", "costas": "rabo_galo"}, "paleta": P_GALINHA,
		"proj": "ovo",
		"u": {"hp": 190, "damage": 55, "attack_speed": 1.3, "move_speed": 55.0, "unit_scale": 0.85, "unit_count": 2, "is_ranged": true, "attack_range": 105.0, "target_type": "ALL"}},
	{"id": "pato_ninja", "nome": "Pato Ninja", "turma": "Galinheiro", "custo": 30, "papel": "PUNICAO", "raridade": RARA, "arena": 1, "perigo": 6,
		"desc": "Quack. Foi a última coisa que a torre ouviu.",
		"pros": ["Invisível até chegar perto", "Golpe fortíssimo"], "cons": ["Vida de papel", "Ataque lento"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "pato", "chapeu": "bandana"}, "paleta": {"P": "#f0e8a0", "A": "#30303c", "K": "#f09030"},
		"u": {"hp": 260, "damage": 380, "attack_speed": 3.0, "move_speed": 75.0, "unit_scale": 0.8, "can_stealth": true}},
	{"id": "galo_rei", "nome": "Galo Rei", "turma": "Galinheiro", "custo": 45, "papel": "PUNICAO", "raridade": EPICA, "arena": 3, "perigo": 7,
		"desc": "Acorda o sítio inteiro às 4 da manhã e ainda bate em quem reclamar.",
		"pros": ["Chega em fúria", "Dano alto e rápido"], "cons": ["Não acerta voador"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "galinha", "chapeu": "coroa", "costas": "rabo_galo"}, "paleta": {"P": "#b84828", "A": "#e8a020", "K": "#f0c040"},
		"u": {"hp": 980, "damage": 200, "attack_speed": 1.4, "move_speed": 60.0, "unit_scale": 1.25, "push_weight": 1.8, "entrance_rage_duration": 4.0, "entrance_rage_damage_mult": 1.4, "entrance_rage_speed_mult": 1.4, "first_attack_bonus": true, "first_attack_multiplier": 1.5}},
	{"id": "corujao", "nome": "Corujão Bombardeiro", "turma": "Galinheiro", "custo": 50, "papel": "AEREO", "raridade": RARA, "arena": 4, "perigo": 8,
		"desc": "Voa devagar, solta pedra do céu e não pede desculpa.",
		"pros": ["Voa", "Dano em área no chão"], "cons": ["Lento", "Não ataca outros voadores"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "coruja"}, "paleta": {"P": "#8a6848", "K": "#e8d8b0", "M": "#f0a030"},
		"proj": "pedra",
		"u": {"hp": 950, "damage": 210, "attack_speed": 3.0, "move_speed": 36.0, "unit_scale": 1.35, "unit_type": "AIR", "is_ranged": true, "attack_range": 60.0, "is_aoe": true, "aoe_radius": 55.0, "target_type": "GROUND"}},
	{"id": "galinheiro", "nome": "Galinheiro", "turma": "Galinheiro", "custo": 40, "papel": "INVOCADOR", "raridade": RARA, "arena": 2, "perigo": 5,
		"desc": "De dentro sai pintinho sem parar. Ninguém sabe quantos cabem.",
		"pros": ["Solta pintinhos o tempo todo", "Distrai o inimigo"], "cons": ["Não ataca", "Some com o tempo"],
		"receita": {"objeto": "galinheiro"}, "paleta": {"W": "#8a5a34", "A": "#c8483c", "K": "#f0d060"}, "filho": "pintinho",
		"u": {"hp": 650, "damage": 0, "attack_speed": 0.0, "move_speed": 0.0, "attack_range": 0.0, "unit_scale": 1.5, "unit_type": "BUILDING", "duration": 40.0, "spawns_units": true, "spawn_interval": 7.0, "spawn_count": 2}},
	{"id": "chocadeira", "nome": "Chocadeira", "turma": "Galinheiro", "custo": 20, "papel": "INVOCADOR", "raridade": RARA, "arena": 2, "perigo": 3,
		"desc": "Joga um ovo em qualquer lugar da arena. Nascem cinco problemas.",
		"pros": ["Invoca em qualquer lugar", "Ótimo pra distrair"], "cons": ["Pintinhos são fracos"],
		"receita": {"icone": "ovo"}, "paleta": {"K": "#f8ecc8"}, "invoca": "pintinho",
		"f": {"radius": 45.0, "damage": 0, "summon_count": 5, "affects_enemies": false, "fx_color": "#f8dc50"}},

	# ============================== BREJO
	{"id": "sapo_linguarudo", "nome": "Sapo Linguarudo", "turma": "Brejo", "custo": 30, "papel": "CONTROLE", "raridade": COMUM, "arena": 1, "perigo": 4,
		"desc": "Estica a língua, gruda e puxa. Higiene duvidosa.",
		"pros": ["Puxa o inimigo pra perto", "Acerta voador"], "cons": ["Dano baixo"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "sapo"}, "paleta": P_SAPO,
		"proj": "gota",
		"u": {"hp": 430, "damage": 60, "attack_speed": 1.8, "move_speed": 45.0, "is_ranged": true, "attack_range": 130.0, "target_type": "ALL", "on_hit_effect": "PULL", "knockback_distance": 60.0}},
	{"id": "sapinho", "nome": "Sapinho", "turma": "Brejo", "custo": 5, "papel": "ENXAME", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "sapo"}, "paleta": P_SAPO,
		"u": {"hp": 160, "damage": 45, "attack_speed": 1.0, "move_speed": 70.0, "unit_scale": 0.6, "initial_stun_duration": 0.2}},
	{"id": "mosquitada", "nome": "Nuvem de Mosquito", "turma": "Brejo", "custo": 15, "papel": "ENXAME", "raridade": RARA, "arena": 1, "perigo": 3,
		"desc": "Bzzzzzzzzz. Não adianta abanar.",
		"pros": ["Voam", "Seis de uma vez"], "cons": ["Um espirro mata todos"],
		"receita": {"pernas": "inseto", "corpo": "listrado", "cabeca": "abelha", "costas": "asas_inseto"}, "paleta": {"P": "#6a7080", "M": "#30303c"},
		"u": {"hp": 35, "damage": 22, "attack_speed": 1.0, "move_speed": 85.0, "unit_scale": 0.5, "unit_count": 6, "unit_type": "AIR", "target_type": "ALL", "push_weight": 0.3}},
	{"id": "capivara_zen", "nome": "Capivara Zen", "turma": "Brejo", "custo": 35, "papel": "TANQUE", "raridade": RARA, "arena": 2, "perigo": 5,
		"desc": "Tão tranquila que todo mundo quer bater nela. Ela nem liga.",
		"pros": ["Chama a atenção dos inimigos", "Leva menos dano e se regenera"], "cons": ["Quase não causa dano", "Só bate em torre e construção"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "capivara", "chapeu": "flor"}, "paleta": P_CAPI,
		"u": {"hp": 1750, "damage": 30, "attack_speed": 1.5, "move_speed": 35.0, "unit_scale": 1.3, "push_weight": 3.0, "forces_aggro": true, "taunt_radius": 130.0, "damage_reduction_percent": 0.2, "passive_regen": true, "regen_amount": 25, "regen_interval": 1.5, "target_type": "BUILDING"}},
	{"id": "capivarada", "nome": "Capivarada", "turma": "Brejo", "custo": 55, "papel": "TANQUE", "raridade": RARA, "arena": 3, "perigo": 7,
		"desc": "Quatro capivaras andando juntas, sem pressa nenhuma.",
		"pros": ["Grupo resistente", "Quatro de uma vez"], "cons": ["Lentas", "Dano em área machuca"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "capivara"}, "paleta": {"P": "#8a6038", "K": "#b88858"},
		"u": {"hp": 560, "damage": 65, "attack_speed": 1.6, "move_speed": 40.0, "unit_scale": 1.1, "unit_count": 4, "push_weight": 1.6}},
	{"id": "sapo_rei", "nome": "Sapo Rei", "turma": "Brejo", "custo": 60, "papel": "INVOCADOR", "raridade": EPICA, "arena": 5, "perigo": 8,
		"desc": "Ninguém quis beijar. Aí ele ficou assim.",
		"pros": ["Quando morre, viram 4 sapinhos", "Forte e gordo"], "cons": ["Lento"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "sapo", "chapeu": "coroa"}, "paleta": {"P": "#3c8848", "K": "#c8e080", "A": "#d83c30", "S": "#40a0d8"}, "filho_morte": "sapinho",
		"u": {"hp": 1600, "damage": 130, "attack_speed": 2.2, "move_speed": 30.0, "unit_scale": 1.7, "push_weight": 3.5, "spawns_on_death": true, "death_spawn_count": 4, "is_aoe": true, "aoe_radius": 40.0}},
	{"id": "lamacal", "nome": "Lamaçal", "turma": "Brejo", "custo": 25, "papel": "CONTROLE", "raridade": COMUM, "arena": 1, "perigo": 3,
		"desc": "Uma poça de lama de respeito. Ninguém sai correndo dali.",
		"pros": ["Deixa todo mundo lento", "Dura bastante"], "cons": ["Quase não causa dano"],
		"receita": {"icone": "lama"}, "paleta": {"W": "#7a5030"},
		"f": {"radius": 95.0, "duration": 5.0, "tick_interval": 0.5, "damage": 10, "status_effect": "SLOW", "status_effect_strength": 0.45, "status_effect_duration": 1.0, "fx_color": "#7a5030"}},
	{"id": "tornado", "nome": "Redemoinho", "turma": "Brejo", "custo": 30, "papel": "CONTROLE", "raridade": EPICA, "arena": 4, "perigo": 4,
		"desc": "Junta todo mundo no meio. Perfeito pra soltar uma melancia depois.",
		"pros": ["Puxa os inimigos pro centro", "Combina com dano em área"], "cons": ["Dano fraco sozinho"],
		"receita": {"icone": "tornado"}, "paleta": {"M": "#a8b4c0", "W": "#7a5030"},
		"f": {"radius": 110.0, "duration": 4.0, "tick_interval": 0.25, "damage": 8, "status_effect": "PULL", "knockback_distance": 22.0, "fx_color": "#c8d4e0"}},

	# ============================== ROÇADO
	{"id": "espantalho", "nome": "Espantalho Ceifador", "turma": "Roçado", "custo": 40, "papel": "PUNICAO", "raridade": RARA, "arena": 1, "perigo": 6,
		"desc": "Cansou de espantar corvo. Agora espanta exército.",
		"pros": ["Gira a foice e acerta todos em volta", "Ótimo contra enxame"], "cons": ["Não acerta voador"],
		"receita": {"pernas": "fantasma", "corpo": "saco", "bracos": "humanos", "cabeca": "espantalho", "chapeu": "palha", "arma": "foice"}, "paleta": {"P": "#c8a860", "S": "#8a6a40", "A": "#a03c30", "K": "#d8b870", "M": "#b0b8c0", "W": "#5a4028"},
		"u": {"hp": 950, "damage": 130, "attack_speed": 1.5, "move_speed": 45.0, "unit_scale": 1.2, "spin_attack": true, "aoe_radius": 30.0}},
	{"id": "milho_pipoqueiro", "nome": "Milho Pipoqueiro", "turma": "Roçado", "custo": 30, "papel": "VERSATIL", "raridade": COMUM, "arena": 0, "perigo": 4,
		"desc": "Esquenta, estoura e espalha. Cada tiro vira três.",
		"pros": ["Tiro se divide em 3", "Acerta voador"], "cons": ["Frágil"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "milho"}, "paleta": {"P": "#f4d040", "S": "#68b048", "A": "#3c5c98", "K": "#e8b088"},
		"proj": "milho",
		"u": {"hp": 380, "damage": 90, "attack_speed": 1.4, "move_speed": 45.0, "is_ranged": true, "attack_range": 140.0, "target_type": "ALL", "projectile_splits": true, "projectile_split_count": 3, "projectile_split_range": 90.0}},
	{"id": "abobora_explosiva", "nome": "Abóboras Explosivas", "turma": "Roçado", "custo": 25, "papel": "PUNICAO", "raridade": RARA, "arena": 2, "perigo": 6,
		"desc": "Correm sorrindo na direção do inimigo. O sorriso é o último aviso.",
		"pros": ["Explodem em área", "Rápidas"], "cons": ["Morrem ao explodir"],
		"receita": {"pernas": "bota", "corpo": "poncho", "bracos": "humanos", "cabeca": "abobora"}, "paleta": {"P": "#f08828", "S": "#58a040", "A": "#503868", "K": "#e8b088", "W": "#5a4028"},
		"u": {"hp": 220, "damage": 60, "attack_speed": 1.0, "move_speed": 85.0, "unit_scale": 0.8, "unit_count": 2, "kamikaze": true, "explodes_on_death": true, "death_explosion_damage": 330, "death_explosion_radius": 60.0}},
	{"id": "cebola_chorona", "nome": "Cebola Chorona", "turma": "Roçado", "custo": 25, "papel": "CONTROLE", "raridade": COMUM, "arena": 2, "perigo": 4,
		"desc": "Chora e faz chorar. Inimigo de olho ardendo bate mais fraco.",
		"pros": ["Enfraquece quem está na frente", "Ataque em cone"], "cons": ["Dano baixo"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "cebola"}, "paleta": {"P": "#c880c0", "S": "#e8e0d0", "A": "#8048a0", "K": "#e8d0e0"},
		"u": {"hp": 560, "damage": 45, "attack_speed": 1.2, "move_speed": 50.0, "frontal_cone_attack": true, "cone_angle_degrees": 100.0, "aoe_radius": 35.0, "on_hit_effect": "WEAKNESS", "on_hit_effect_strength": 0.5, "on_hit_effect_duration": 3.0}},
	{"id": "canhao_pipoca", "nome": "Canhão de Pipoca", "turma": "Roçado", "custo": 30, "papel": "CONSTRUCAO", "raridade": COMUM, "arena": 0, "perigo": 4,
		"desc": "Defesa clássica da roça. O cheiro de manteiga é brinde.",
		"pros": ["Defende sozinho", "Acerta voador"], "cons": ["Não anda", "Some com o tempo"],
		"receita": {"objeto": "canhao_milho"}, "paleta": {"W": "#8a5a34", "M": "#8890a0", "A": "#c8483c", "K": "#f8ecc8"},
		"proj": "milho",
		"u": {"hp": 720, "damage": 115, "attack_speed": 1.3, "move_speed": 0.0, "unit_scale": 1.4, "unit_type": "BUILDING", "duration": 35.0, "is_ranged": true, "attack_range": 185.0, "target_type": "ALL"}},
	{"id": "melancia_bomba", "nome": "Melancia-Bomba", "turma": "Roçado", "custo": 40, "papel": "PUNICAO", "raridade": RARA, "arena": 3, "perigo": 6,
		"desc": "Madura, docinha e com pavio.",
		"pros": ["Dano alto em área"], "cons": ["Fraca contra torre"],
		"receita": {"icone": "melancia"}, "paleta": {"S": "#3c9848", "W": "#6a4428"},
		"f": {"radius": 75.0, "damage": 400, "base_damage_multiplier": 0.3, "fx_color": "#e84848"}},
	{"id": "fornalha", "nome": "Forno a Lenha", "turma": "Roçado", "custo": 50, "papel": "INVOCADOR", "raridade": EPICA, "arena": 5, "perigo": 6,
		"desc": "Assa abóbora explosiva fresquinha de 9 em 9 segundos.",
		"pros": ["Fábrica de abóbora-bomba", "Pressão constante"], "cons": ["Caro", "Não se defende"],
		"receita": {"objeto": "fornalha"}, "paleta": {"A": "#b85840", "M": "#585c68"}, "filho": "aboborinha",
		"u": {"hp": 700, "damage": 0, "attack_speed": 0.0, "move_speed": 0.0, "attack_range": 0.0, "unit_scale": 1.5, "unit_type": "BUILDING", "duration": 45.0, "spawns_units": true, "spawn_interval": 9.0, "spawn_count": 1}},
	{"id": "aboborinha", "nome": "Aboborinha", "turma": "Roçado", "custo": 10, "papel": "PUNICAO", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "bota", "corpo": "poncho", "bracos": "humanos", "cabeca": "abobora"}, "paleta": {"P": "#f08828", "S": "#58a040", "A": "#503868", "K": "#e8b088", "W": "#5a4028"},
		"u": {"hp": 200, "damage": 60, "attack_speed": 1.0, "move_speed": 85.0, "unit_scale": 0.7, "kamikaze": true, "explodes_on_death": true, "death_explosion_damage": 260, "death_explosion_radius": 55.0, "initial_stun_duration": 0.2}},

	# ============================== PEÕES
	{"id": "peao_forcado", "nome": "Peão do Forcado", "turma": "Peões", "custo": 20, "papel": "VERSATIL", "raridade": COMUM, "arena": 0, "perigo": 3,
		"desc": "Acorda cedo, trabalha duro e espeta quem pisar na horta.",
		"pros": ["Barato e confiável", "Bom de vida pelo preço"], "cons": ["Nada de especial"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano", "chapeu": "palha", "arma": "forcado"}, "paleta": P_PEAO,
		"u": {"hp": 640, "damage": 95, "attack_speed": 1.2, "move_speed": 55.0}},
	{"id": "molecada", "nome": "Molecada do Estilingue", "turma": "Peões", "custo": 30, "papel": "VERSATIL", "raridade": COMUM, "arena": 0, "perigo": 4,
		"desc": "Três moleques, três estilingues e nenhuma vidraça inteira no bairro.",
		"pros": ["Três atiradores", "Acertam voador"], "cons": ["Morrem fácil"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano", "chapeu": "bandana", "arma": "estilingue"}, "paleta": {"S": "#e8c040", "A": "#c84838", "K": "#d89868", "W": "#6a4428", "M": "#888890"},
		"proj": "pedra",
		"u": {"hp": 170, "damage": 50, "attack_speed": 1.2, "move_speed": 55.0, "unit_scale": 0.8, "unit_count": 3, "is_ranged": true, "attack_range": 125.0, "target_type": "ALL"}},
	{"id": "vovo_lampiao", "nome": "Vovô do Lampião", "turma": "Peões", "custo": 35, "papel": "SUPORTE", "raridade": RARA, "arena": 1, "perigo": 5,
		"desc": "No tempo dele isso tudo era mato. E ele botava fogo.",
		"pros": ["Tiro de fogo queima com o tempo", "Alcance longo"], "cons": ["Anda devagar"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "velho", "chapeu": "palha", "arma": "lampiao"}, "paleta": {"S": "#58a050", "A": "#705038", "K": "#d8a078", "M": "#606878", "W": "#6a4428"},
		"proj": "fogo",
		"u": {"hp": 480, "damage": 60, "attack_speed": 1.6, "move_speed": 38.0, "is_ranged": true, "attack_range": 150.0, "target_type": "ALL", "on_hit_effect": "POISON", "on_hit_effect_strength": 18.0, "on_hit_effect_duration": 4.0, "on_hit_effect_tick_interval": 1.0}},
	{"id": "porco_cozinheiro", "nome": "Porco Cozinheiro", "turma": "Peões", "custo": 45, "papel": "TANQUE", "raridade": RARA, "arena": 3, "perigo": 6,
		"desc": "Frigideira de ferro fundido. Serve pra fritar e pra atordoar.",
		"pros": ["Frigideirada atordoa", "Bastante vida"], "cons": ["Lento"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "porco", "chapeu": "cozinheiro", "arma": "frigideira"}, "paleta": {"P": "#f0a0a8", "K": "#f8c0c0", "M": "#5a606c", "W": "#4a3828"},
		"u": {"hp": 1700, "damage": 125, "attack_speed": 1.8, "move_speed": 36.0, "unit_scale": 1.4, "push_weight": 3.0, "on_hit_effect": "STUN", "on_hit_effect_duration": 0.6}},
	{"id": "lenhador", "nome": "Lenhador Furioso", "turma": "Peões", "custo": 50, "papel": "FINALIZADOR", "raridade": EPICA, "arena": 4, "perigo": 8,
		"desc": "Quanto mais bate, mais rápido bate. Não tente acalmar.",
		"pros": ["Ataca cada vez mais rápido", "Fica mais forte quase morrendo"], "cons": ["Demora pra engrenar"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "velho", "chapeu": "bandana", "arma": "machado"}, "paleta": {"S": "#b83830", "A": "#3a3038", "K": "#d8a078", "M": "#a0a8b4", "W": "#6a4428"},
		"u": {"hp": 1150, "damage": 150, "attack_speed": 1.6, "move_speed": 52.0, "unit_scale": 1.2, "push_weight": 2.0, "ramping_attack_speed": true, "attack_speed_ramp_per_hit": 0.08, "attack_speed_ramp_min_multiplier": 0.4, "low_hp_rage_threshold": 0.35, "low_hp_rage_damage_mult": 1.5}},
	{"id": "trator", "nome": "Trator Desgovernado", "turma": "Peões", "custo": 55, "papel": "FINALIZADOR", "raridade": EPICA, "arena": 5, "perigo": 8,
		"desc": "Alguém esqueceu o freio de mão. Agora é problema da torre.",
		"pros": ["Corre direto pra torre", "Bate muito forte na chegada"], "cons": ["Ignora tropas"],
		"receita": {"objeto": "trator"}, "paleta": {"A": "#d84838", "M": "#484c58", "K": "#e8c040"},
		"u": {"hp": 1400, "damage": 260, "attack_speed": 2.2, "move_speed": 70.0, "unit_scale": 1.3, "push_weight": 4.0, "target_type": "BUILDING", "charge_attack": true, "charge_distance_needed": 150.0, "charge_damage_multiplier": 2.0}},
	{"id": "moda_de_viola", "nome": "Moda de Viola", "turma": "Peões", "custo": 30, "papel": "SUPORTE", "raridade": RARA, "arena": 2, "perigo": 3,
		"desc": "Uma música tão boa que cura. E tira qualquer efeito ruim.",
		"pros": ["Cura em área por 4 segundos", "Remove lentidão, veneno, gelo..."], "cons": ["Não causa dano"],
		"receita": {"icone": "nota"}, "paleta": {"A": "#40b868"},
		"f": {"radius": 90.0, "duration": 4.0, "tick_interval": 0.5, "damage": 0, "heal_amount": 45, "affects_enemies": false, "affects_allies": true, "cleanses": true, "fx_color": "#60e088"}},
	{"id": "pinga_braba", "nome": "Pinga da Braba", "turma": "Peões", "custo": 25, "papel": "SUPORTE", "raridade": RARA, "arena": 3, "perigo": 4,
		"desc": "Um gole e a tropa inteira fica valente. E rápida. E barulhenta.",
		"pros": ["Fúria: mais dano e velocidade", "Vira qualquer briga"], "cons": ["Precisa de tropa em campo"],
		"receita": {"icone": "pimenta"}, "paleta": {"A": "#e04030", "S": "#58a040"},
		"f": {"radius": 100.0, "damage": 0, "affects_enemies": false, "affects_allies": true, "rage_damage_mult": 1.35, "rage_speed_mult": 1.3, "rage_attack_speed_mult": 1.3, "buff_duration": 6.0, "fx_color": "#ff6040"}},
	{"id": "tampa_de_panela", "nome": "Tampa de Panela", "turma": "Peões", "custo": 20, "papel": "SUPORTE", "raridade": COMUM, "arena": 1, "perigo": 2,
		"desc": "Escudo oficial da roça desde que a vó brigou com o vô.",
		"pros": ["Dá escudo pros aliados", "Barato"], "cons": ["Escudo some depois de um tempo"],
		"receita": {"icone": "escudo"}, "paleta": {"M": "#a8b4c0", "A": "#3c6cb8"},
		"f": {"radius": 90.0, "damage": 0, "affects_enemies": false, "affects_allies": true, "shield_amount": 260, "buff_duration": 8.0, "fx_color": "#80c0ff"}},

	# ============================== LOTE 2 (peças novas)
	{"id": "caramelo", "nome": "Vira-lata Caramelo", "turma": "Peões", "custo": 15, "papel": "CONTRA_ATAQUE", "raridade": COMUM, "arena": 1, "perigo": 3,
		"desc": "Patrimônio nacional. Corre atrás de qualquer coisa que se mexa.",
		"pros": ["Muito rápido", "Barato", "Morde bem pelo preço"], "cons": ["Pouca vida"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "cachorro"}, "paleta": {"P": "#d89848", "S": "#a86830", "K": "#f0d0a0", "A": "#f07080"},
		"u": {"hp": 360, "damage": 62, "attack_speed": 0.8, "move_speed": 95.0, "unit_scale": 0.85, "push_weight": 0.8}},
	{"id": "jegue_cargueiro", "nome": "Jegue Cargueiro", "turma": "Curral", "custo": 35, "papel": "SUPORTE", "raridade": RARA, "arena": 2, "perigo": 4,
		"desc": "Carrega a colheita nas costas. Enquanto ele vive, seu recurso rende mais.",
		"pros": ["Gera recurso enquanto está em campo", "Aguenta bem"], "cons": ["Quase não bate", "Teimoso: anda devagar"],
		"receita": {"pernas": "casco", "corpo": "colete", "bracos": "patas", "cabeca": "burro", "chapeu": "palha", "costas": "cesto"}, "paleta": {"P": "#9a8878", "S": "#c8b8a0", "K": "#e8dcc8", "W": "#7a5030", "A": "#d04030"},
		"u": {"hp": 1100, "damage": 40, "attack_speed": 1.6, "move_speed": 30.0, "unit_scale": 1.2, "push_weight": 2.5, "generates_resource": true, "resource_per_tick": 1, "resource_tick_interval": 1.6}},
	{"id": "tatu_bola", "nome": "Tatu Bola", "turma": "Brejo", "custo": 30, "papel": "TANQUE", "raridade": COMUM, "arena": 2, "perigo": 4,
		"desc": "Fecha a casca e deixa bater. Devolve parte da pancada.",
		"pros": ["Leva 35% menos dano", "Devolve dano em quem bate", "Não é empurrado"], "cons": ["Dano baixo"],
		"receita": {"pernas": "patinha", "corpo": "armadura", "bracos": "patas", "cabeca": "tatu"}, "paleta": {"M": "#b09878", "K": "#d8c0a0"},
		"u": {"hp": 900, "damage": 45, "attack_speed": 1.4, "move_speed": 42.0, "push_weight": 2.2, "damage_reduction_percent": 0.35, "reflects_damage": true, "reflect_damage_percent": 0.25, "immune_to_knockback": true}},
	{"id": "jacare_acude", "nome": "Jacaré do Açude", "turma": "Brejo", "custo": 50, "papel": "PUNICAO", "raridade": EPICA, "arena": 4, "perigo": 8,
		"desc": "Fica quietinho. Aí alguém chega perto demais.",
		"pros": ["Primeira mordida vale em dobro", "Finaliza quem está com pouca vida", "Recupera vida mordendo"], "cons": ["Lento", "Não acerta voador"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "jacare"}, "paleta": {"P": "#4a8848", "K": "#c8d890"},
		"u": {"hp": 1500, "damage": 210, "attack_speed": 2.0, "move_speed": 34.0, "unit_scale": 1.45, "push_weight": 3.2, "first_attack_bonus": true, "first_attack_multiplier": 2.0, "execute_threshold": 0.3, "execute_damage_mult": 2.0, "lifesteal_percent": 0.25}},
	{"id": "urubu", "nome": "Urubu de Plantão", "turma": "Galinheiro", "custo": 30, "papel": "AEREO", "raridade": RARA, "arena": 3, "perigo": 5,
		"desc": "Só aparece quando a coisa já tá feia. Pra você ou pro inimigo.",
		"pros": ["Voa", "Dano dobrado em quem está quase morrendo", "Se cura ao matar"], "cons": ["Fraco contra tropa inteira"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "urubu"}, "paleta": {"P": "#3a3440", "K": "#c87878", "M": "#d8d0c0"},
		"u": {"hp": 420, "damage": 85, "attack_speed": 1.2, "move_speed": 62.0, "unit_type": "AIR", "target_type": "ALL", "execute_threshold": 0.4, "execute_damage_mult": 2.0, "heals_on_kill": true, "heal_on_kill_amount": 150}},
	{"id": "cacto_pistoleiro", "nome": "Cacto Pistoleiro", "turma": "Roçado", "custo": 35, "papel": "CONTROLE", "raridade": RARA, "arena": 4, "perigo": 5,
		"desc": "Veio do sertão. Atira espinho que atravessa a fila inteira.",
		"pros": ["Espinho atravessa até 3 inimigos", "Alcance longo", "Machuca quem bate nele"], "cons": ["Anda devagar"],
		"receita": {"pernas": "bota", "corpo": "poncho", "bracos": "humanos", "cabeca": "cacto", "chapeu": "cowboy"}, "paleta": {"S": "#58a858", "P": "#d8b060", "A": "#d04870", "K": "#58a858", "W": "#7a5030"},
		"proj": "espinho",
		"u": {"hp": 560, "damage": 75, "attack_speed": 1.5, "move_speed": 36.0, "is_ranged": true, "attack_range": 165.0, "target_type": "ALL", "projectile_pierces": true, "projectile_max_targets": 3, "reflects_damage": true, "reflect_damage_percent": 0.2}},
	{"id": "tomate_podre", "nome": "Chuva de Tomate", "turma": "Roçado", "custo": 30, "papel": "CONTROLE", "raridade": COMUM, "arena": 3, "perigo": 4,
		"desc": "A plateia não gostou. Os inimigos saem marcados: tudo dói mais neles.",
		"pros": ["Marca os inimigos: levam 40% mais dano", "Área grande"], "cons": ["Dano próprio baixo"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "tomate"}, "paleta": {"A": "#e04030", "S": "#58a040", "K": "#e8b088"},
		"f": {"radius": 95.0, "damage": 70, "base_damage_multiplier": 0.1, "status_effect": "MARK", "status_effect_strength": 1.4, "status_effect_duration": 6.0, "fx_color": "#e04030"}},
	{"id": "caveira_boi", "nome": "Boi da Cara Preta", "turma": "Coisa Estranha", "custo": 55, "papel": "FINALIZADOR", "raridade": LENDARIA, "arena": 6, "perigo": 9,
		"desc": "Pega essa torre que tem medo de careta. Morre, levanta e continua.",
		"pros": ["Levanta uma vez depois de morrer", "Cada golpe bate mais forte", "Rouba vida e enfurece quase morrendo"], "cons": ["Caro", "Vida mediana"],
		"receita": {"pernas": "fantasma", "corpo": "saco", "bracos": "humanos", "cabeca": "caveira", "costas": "morcego", "arma": "foice"}, "paleta": {"M": "#e8e0d0", "P": "#584868", "K": "#584868", "W": "#3a2a30", "A": "#8048a0"},
		"u": {"hp": 900, "damage": 150, "attack_speed": 1.5, "move_speed": 48.0, "unit_scale": 1.3, "push_weight": 2.0, "unit_type": "AIR", "target_type": "ALL", "can_resurrect": true, "resurrect_hp_percent": 0.5, "ramping_damage": true, "ramping_damage_per_hit": 0.12, "ramping_damage_max_multiplier": 2.2, "lifesteal_percent": 0.2, "low_hp_rage_threshold": 0.4, "low_hp_rage_damage_mult": 1.4}},

	# ============================== CARTAS DE TURMA MISTA (unidades diferentes juntas)
	{"id": "moleque", "nome": "Moleque", "turma": "Peões", "custo": 10, "papel": "VERSATIL", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano", "chapeu": "bandana", "arma": "estilingue"}, "paleta": {"S": "#e8c040", "A": "#c84838", "K": "#d89868", "W": "#6a4428", "M": "#888890"},
		"proj": "pedra",
		"u": {"hp": 170, "damage": 50, "attack_speed": 1.2, "move_speed": 55.0, "unit_scale": 0.8, "is_ranged": true, "attack_range": 125.0, "target_type": "ALL"}},
	{"id": "berranteiro", "nome": "Berranteiro", "turma": "Peões", "custo": 15, "papel": "CONTROLE", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "bota", "corpo": "poncho", "bracos": "humanos", "cabeca": "velho", "chapeu": "cowboy"}, "paleta": {"P": "#a87848", "A": "#58a050", "K": "#d8a078", "W": "#5a4028"},
		"proj": "nota",
		"u": {"hp": 420, "damage": 45, "attack_speed": 1.5, "move_speed": 45.0, "is_ranged": true, "attack_range": 120.0, "target_type": "ALL", "on_hit_effect": "SLOW", "on_hit_effect_strength": 0.55, "on_hit_effect_duration": 2.0}},
	{"id": "comitiva", "nome": "Comitiva", "turma": "Peões", "custo": 60, "papel": "VERSATIL", "raridade": RARA, "arena": 4, "perigo": 8,
		"desc": "O cozinheiro vai na frente apanhando. A molecada vai atrás atirando pedra. Trabalho em equipe.",
		"pros": ["Tanque + 2 atiradores numa carta só", "Avanço completo"], "cons": ["Cara", "Dano em área pega todos"],
		"receita": {"pernas": "patinha", "corpo": "redondo", "bracos": "patas", "cabeca": "porco", "chapeu": "cowboy", "arma": "frigideira"}, "paleta": {"P": "#e89098", "K": "#f8c0c0", "M": "#5a606c", "W": "#6a4428", "A": "#c84838"},
		"junto": [["moleque", 2]],
		"u": {"hp": 1400, "damage": 110, "attack_speed": 1.8, "move_speed": 40.0, "unit_scale": 1.35, "push_weight": 3.0}},
	{"id": "vaca_e_cria", "nome": "Vaca e Cria", "turma": "Curral", "custo": 55, "papel": "TANQUE", "raridade": RARA, "arena": 3, "perigo": 7,
		"desc": "Mexeu com os bezerros, mexeu com a mãe. Mexeu com a mãe, bom... boa sorte.",
		"pros": ["Tanque com 2 bezerros de investida", "Difícil de parar com uma carta só"], "cons": ["Lenta", "A mãe só bate em torre e construção"],
		"receita": {"pernas": "casco", "corpo": "redondo", "bracos": "patas", "cabeca": "vaca", "chapeu": "flor"}, "paleta": P_VACA,
		"junto": [["bezerro", 2]],
		"u": {"hp": 1900, "damage": 100, "attack_speed": 2.0, "move_speed": 32.0, "unit_scale": 1.45, "push_weight": 3.6, "target_type": "BUILDING"}},
	{"id": "galo_e_cia", "nome": "Galo e Cia", "turma": "Galinheiro", "custo": 45, "papel": "ENXAME", "raridade": RARA, "arena": 5, "perigo": 7,
		"desc": "O galo manda. Os quatro pintinhos obedecem. Mais ou menos.",
		"pros": ["Galo forte + 4 pintinhos", "Cerca e bate"], "cons": ["Pintinhos morrem fácil"],
		"receita": {"pernas": "ave", "corpo": "penas", "bracos": "asas", "cabeca": "galinha", "chapeu": "penacho", "costas": "rabo_galo"}, "paleta": {"P": "#c85830", "A": "#e8a020", "K": "#f0c040", "M": "#8890a0"},
		"junto": [["pintinho", 4]],
		"u": {"hp": 820, "damage": 160, "attack_speed": 1.4, "move_speed": 58.0, "unit_scale": 1.15, "push_weight": 1.6}},
	{"id": "dupla_caipira", "nome": "Dupla Caipira", "turma": "Peões", "custo": 50, "papel": "SUPORTE", "raridade": EPICA, "arena": 5, "perigo": 6,
		"desc": "Um toca viola e cura. O outro toca berrante e deixa o inimigo lerdo. Sucesso nas rádios.",
		"pros": ["Cura aliados + deixa inimigos lentos", "Os dois atacam de longe"], "cons": ["Dano baixo", "Frágeis"],
		"receita": {"pernas": "bota", "corpo": "macacao", "bracos": "humanos", "cabeca": "humano", "chapeu": "cowboy", "arma": "viola"}, "paleta": {"S": "#e8e0d0", "A": "#8a5a34", "K": "#e8b088", "W": "#b07038"},
		"proj": "nota", "junto": [["berranteiro", 1]],
		"u": {"hp": 520, "damage": 35, "attack_speed": 1.2, "move_speed": 45.0, "is_ranged": true, "attack_range": 120.0, "target_type": "ALL", "can_heal_allies": true, "heal_aura_amount": 30, "heal_aura_radius": 100.0, "heal_aura_interval": 1.0}},

	# ============================== COISA ESTRANHA
	{"id": "assombracao", "nome": "Assombração", "turma": "Coisa Estranha", "custo": 20, "papel": "ENXAME", "raridade": RARA, "arena": 2, "perigo": 4,
		"desc": "Quatro almas penadas do antigo dono do sítio. Só dá pra bater quando param.",
		"pros": ["Intocáveis enquanto andam", "Dano bom pelo preço"], "cons": ["Vida minúscula quando param"],
		"receita": {"pernas": "fantasma", "corpo": "redondo", "bracos": "patas", "cabeca": "espantalho"}, "paleta": P_FANTASMA,
		"u": {"hp": 70, "damage": 80, "attack_speed": 1.3, "move_speed": 45.0, "unit_scale": 0.8, "unit_count": 4, "immune_while_moving": true, "push_weight": 0.5}},
	{"id": "abelhas", "nome": "Enxame de Abelha", "turma": "Coisa Estranha", "custo": 25, "papel": "AEREO", "raridade": RARA, "arena": 1, "perigo": 4,
		"desc": "Mexeu com uma, mexeu com todas.",
		"pros": ["Voam", "Ferroada forte pelo preço"], "cons": ["Pouca vida"],
		"receita": {"pernas": "inseto", "corpo": "listrado", "cabeca": "abelha", "costas": "asas_inseto"}, "paleta": P_ABELHA,
		"u": {"hp": 90, "damage": 44, "attack_speed": 0.9, "move_speed": 75.0, "unit_scale": 0.6, "unit_count": 4, "unit_type": "AIR", "target_type": "ALL", "push_weight": 0.4}},
	{"id": "abelha", "nome": "Abelha", "turma": "Coisa Estranha", "custo": 5, "papel": "AEREO", "raridade": COMUM, "ficha": true,
		"receita": {"pernas": "inseto", "corpo": "listrado", "cabeca": "abelha", "costas": "asas_inseto"}, "paleta": P_ABELHA,
		"u": {"hp": 90, "damage": 44, "attack_speed": 0.9, "move_speed": 75.0, "unit_scale": 0.6, "unit_type": "AIR", "target_type": "ALL", "push_weight": 0.4, "initial_stun_duration": 0.2}},
	{"id": "colmeia", "nome": "Colmeia Nervosa", "turma": "Coisa Estranha", "custo": 45, "papel": "INVOCADOR", "raridade": RARA, "arena": 3, "perigo": 6,
		"desc": "Não cutuque. Sério. Tarde demais.",
		"pros": ["Solta abelhas voadoras", "Abelhas envenenam"], "cons": ["Não ataca sozinha"],
		"receita": {"objeto": "colmeia"}, "paleta": {"P": "#e8b838", "W": "#6a4428", "M": "#30303c"}, "filho": "abelha",
		"u": {"hp": 650, "damage": 0, "attack_speed": 0.0, "move_speed": 0.0, "attack_range": 0.0, "unit_scale": 1.4, "unit_type": "BUILDING", "duration": 35.0, "spawns_units": true, "spawn_interval": 6.0, "spawn_count": 2}},
	{"id": "et_abdutor", "nome": "ET Abdutor", "turma": "Coisa Estranha", "custo": 45, "papel": "AEREO", "raridade": EPICA, "arena": 4, "perigo": 7,
		"desc": "Veio buscar vaca. Achou a briga mais interessante.",
		"pros": ["Voa", "Raio confunde: o inimigo anda pra trás"], "cons": ["Vida mediana"],
		"receita": {"pernas": "bota", "corpo": "redondo", "bracos": "patas", "cabeca": "et", "costas": "foguete"}, "paleta": {"P": "#78c878", "K": "#a8e0a0", "A": "#f04848", "M": "#b0b8c0", "W": "#484858"},
		"proj": "raio",
		"u": {"hp": 720, "damage": 120, "attack_speed": 1.8, "move_speed": 50.0, "unit_type": "AIR", "is_ranged": true, "attack_range": 120.0, "target_type": "ALL", "on_hit_effect": "CONFUSE", "on_hit_effect_duration": 1.5}},
	{"id": "robo_balde", "nome": "Robô Balde-3000", "turma": "Coisa Estranha", "custo": 80, "papel": "TANQUE", "raridade": LENDARIA, "arena": 6, "perigo": 10,
		"desc": "Feito de balde, roda de carrinho de mão e uma motosserra. Funciona. Infelizmente.",
		"pros": ["Vida absurda", "Chega dando onda de choque", "Blindado: devolve dano e ninguém empurra"], "cons": ["Lentíssimo", "Caríssimo", "Só bate em torre e construção"],
		"receita": {"pernas": "rodas", "corpo": "armadura", "bracos": "humanos", "cabeca": "balde", "arma": "motosserra"}, "paleta": {"M": "#98a0ac", "S": "#787c88", "K": "#787c88", "A": "#e06030", "W": "#484858"},
		"u": {"hp": 3600, "damage": 300, "attack_speed": 3.6, "move_speed": 14.0, "unit_scale": 2.3, "push_weight": 6.0, "immune_to_knockback": true, "immune_to_pull": true, "entrance_shockwave_damage": 150, "entrance_shockwave_radius": 70.0, "is_aoe": true, "aoe_radius": 40.0, "target_type": "BUILDING", "damage_reduction_percent": 0.15, "reflects_damage": true, "reflect_damage_percent": 0.15}},
	{"id": "disco_voador", "nome": "Disco Voador", "turma": "Coisa Estranha", "custo": 65, "papel": "AEREO", "raridade": LENDARIA, "arena": 6, "perigo": 9,
		"desc": "Aquela luz no céu do sítio que ninguém acredita quando você conta.",
		"pros": ["Voa e ataca muito rápido", "Dano em área"], "cons": ["Alcance curto", "Caro"],
		"receita": {"objeto": "ovni"}, "paleta": {"M": "#a0a8b8", "S": "#50c0e0", "A": "#f04848"},
		"proj": "raio",
		"u": {"hp": 1300, "damage": 70, "attack_speed": 0.6, "move_speed": 40.0, "unit_scale": 1.5, "push_weight": 2.5, "unit_type": "AIR", "is_ranged": true, "attack_range": 80.0, "target_type": "ALL", "is_aoe": true, "aoe_radius": 35.0, "projectile_chains": true, "projectile_chain_max_targets": 3, "projectile_chain_range": 90.0, "on_hit_effect": "SLOW", "on_hit_effect_strength": 0.7, "on_hit_effect_duration": 1.0}},
	{"id": "raio", "nome": "Raio", "turma": "Coisa Estranha", "custo": 20, "papel": "PUNICAO", "raridade": COMUM, "arena": 0, "perigo": 4,
		"desc": "Céu limpo, sem nuvem. E mesmo assim caiu.",
		"pros": ["Dano na hora", "Barato"], "cons": ["Área pequena"],
		"receita": {"icone": "raio"}, "paleta": {"K": "#f8e040"},
		"f": {"radius": 48.0, "damage": 250, "base_damage_multiplier": 0.35, "fx_color": "#fff080"}},
	{"id": "geada", "nome": "Geada", "turma": "Coisa Estranha", "custo": 35, "papel": "CONTROLE", "raridade": EPICA, "arena": 5, "perigo": 5,
		"desc": "Geada fora de época. Congela tudo: tropa, plantação e esperança.",
		"pros": ["Congela os inimigos por 3 segundos"], "cons": ["Dano baixo"],
		"receita": {"icone": "floco"}, "paleta": {"S": "#70c8f0"},
		"f": {"radius": 85.0, "damage": 60, "base_damage_multiplier": 0.1, "status_effect": "FREEZE", "status_effect_duration": 3.0, "fx_color": "#a0e0ff"}},
	{"id": "vaca_cadente", "nome": "Vaca Cadente", "turma": "Coisa Estranha", "custo": 60, "papel": "PUNICAO", "raridade": LENDARIA, "arena": 6, "perigo": 8,
		"desc": "O ET devolveu a vaca. De muito, muito alto. Ela sobrevive e ainda sai brigando.",
		"pros": ["Dano enorme em área", "A vaca fica em campo depois"], "cons": ["Caro"],
		"receita": {"icone": "vaca_caindo"}, "paleta": P_VACA, "invoca": "bezerro",
		"f": {"radius": 90.0, "damage": 520, "base_damage_multiplier": 0.3, "status_effect": "KNOCKBACK", "knockback_distance": 50.0, "summon_count": 2, "fx_color": "#ffb040"}},
]

const BARALHO_INICIAL = ["peao_forcado", "pintaiada", "galinha_atiradeira", "vaca_brava", "molecada", "raio", "canhao_pipoca"]

# ---------------------------------------------------------------- torres
const TORRES = [
	{"id": "celeiro", "nome": "Celeiro Velho", "turma": "Peões", "arena": 0, "tipo": "CANNON", "categoria": "DEFENSIVO",
		"desc": "O clássico. Aguenta bastante e ainda atira milho.",
		"pros": ["Vida alta", "Atira sozinho"], "cons": ["Tiro fraco"],
		"receita": {"torre": "celeiro"}, "paleta": {"A": "#b8402c", "W": "#6a4428", "K": "#f0d060"}, "proj": "milho",
		"b": {"base_hp": 1300, "attack_damage": 32, "attack_range": 125.0, "attack_speed": 1.0}},
	{"id": "moinho", "nome": "Moinho de Vento", "turma": "Roçado", "arena": 2, "tipo": "PRODUCTION", "categoria": "ECONOMICO",
		"desc": "Mói o dia inteiro: seus recursos chegam mais rápido.",
		"pros": ["Recurso 12% mais rápido"], "cons": ["Não ataca", "Menos vida"],
		"receita": {"torre": "moinho"}, "paleta": {"K": "#e8d8b0", "A": "#b8402c", "S": "#58a0d8", "W": "#6a4428"},
		"b": {"base_hp": 1150, "production_speed_boost": 0.12}},
	{"id": "caixa_dagua", "nome": "Caixa d'Água", "turma": "Brejo", "arena": 3, "tipo": "HEAL", "categoria": "DEFENSIVO",
		"desc": "Água fresca: cura as tropas que ficarem por perto.",
		"pros": ["Cura aliados próximos"], "cons": ["Não ataca"],
		"receita": {"torre": "caixa_dagua"}, "paleta": {"S": "#3c88c8", "A": "#b8402c", "W": "#6a4428"},
		"b": {"base_hp": 1200, "heal_amount": 14, "heal_radius": 110.0, "heal_interval": 1.0}},
	{"id": "castelo_feno", "nome": "Castelo de Feno", "turma": "Curral", "arena": 5, "tipo": "CANNON", "categoria": "OFENSIVO",
		"desc": "Parece frágil. O tiro em área prova que não é.",
		"pros": ["Tiro em área", "Alcance longo"], "cons": ["Atira devagar", "Menos vida"],
		"receita": {"torre": "castelo_feno"}, "paleta": {"K": "#e8c850", "A": "#3c6cb8", "W": "#6a4428"}, "proj": "pedra",
		"b": {"base_hp": 1050, "attack_damage": 45, "attack_range": 175.0, "attack_speed": 2.4, "is_aoe": true, "aoe_radius": 55.0, "projectile_speed": 250.0}},
	{"id": "forte", "nome": "Forte de Toras", "turma": "Peões", "arena": 1, "tipo": "HP", "categoria": "DEFENSIVO",
		"desc": "Não faz nada além de aguentar. Mas aguenta muito.",
		"pros": ["A torre com mais vida do jogo"], "cons": ["Não ataca", "Nenhum bônus"],
		"receita": {"torre": "forte"}, "paleta": {"W": "#8a5a34", "A": "#3c6cb8", "M": "#585c68"},
		"b": {"base_hp": 1750}},
	{"id": "armazem", "nome": "Armazém de Sacas", "turma": "Roçado", "arena": 2, "tipo": "CAPACITY", "categoria": "ECONOMICO",
		"desc": "Mais espaço pra guardar: seu recurso vai até 125 em vez de 100.",
		"pros": ["Guarda 25 a mais de recurso", "Ótimo pra cartas caras"], "cons": ["Não ataca"],
		"receita": {"torre": "armazem"}, "paleta": {"K": "#d8c8a8", "M": "#a04838", "S": "#c8a860", "W": "#6a4428", "A": "#58a040"},
		"b": {"base_hp": 1200, "capacity_bonus": 25}},
	{"id": "capela", "nome": "Capela do Sino", "turma": "Peões", "arena": 3, "tipo": "AURA", "categoria": "DEFENSIVO",
		"desc": "O sino toca e o inimigo que chega perto fica lerdo, pensando na vida.",
		"pros": ["Deixa lentos os inimigos por perto"], "cons": ["Não causa dano"],
		"receita": {"torre": "capela"}, "paleta": {"K": "#f2ede0", "A": "#3c6cb8", "W": "#6a4428", "M": "#e8c040"},
		"b": {"base_hp": 1250, "aura_radius": 135.0, "aura_tick_interval": 1.0, "effect": "SLOW", "effect_strength": 0.6, "effect_duration": 1.5}},
	{"id": "cocho", "nome": "Tanque de Leite", "turma": "Curral", "arena": 4, "tipo": "PRODUCTION", "categoria": "ECONOMICO",
		"desc": "Leite fresco o dia todo. O recurso enche bem mais rápido, mas a lata é fina.",
		"pros": ["Recurso 20% mais rápido"], "cons": ["Pouca vida", "Não ataca"],
		"receita": {"torre": "cocho"}, "paleta": {"M": "#c8d0d8", "K": "#f8f8f0", "W": "#6a4428"},
		"b": {"base_hp": 950, "production_speed_boost": 0.2}},
	{"id": "colmeia_torre", "nome": "Colmeia Gigante", "turma": "Coisa Estranha", "arena": 4, "tipo": "AURA", "categoria": "OFENSIVO",
		"desc": "Quem encosta sai todo ferroado. O veneno continua doendo depois.",
		"pros": ["Envenena os inimigos por perto"], "cons": ["Alcance curto", "Vida mediana"],
		"receita": {"torre": "colmeia"}, "paleta": {"P": "#e8b838", "M": "#30303c"},
		"b": {"base_hp": 1150, "aura_radius": 115.0, "aura_tick_interval": 1.5, "effect": "POISON", "effect_strength": 14.0, "effect_duration": 3.0, "effect_tick_interval": 1.0}},
	{"id": "antena", "nome": "Antena do ET", "turma": "Coisa Estranha", "arena": 6, "tipo": "CANNON", "categoria": "OFENSIVO",
		"desc": "Era pra pegar sinal de TV. Pegou outra coisa. Atira raio longe e forte.",
		"pros": ["Tiro forte", "Alcance enorme"], "cons": ["A torre com menos vida", "Atira devagar"],
		"receita": {"torre": "antena"}, "paleta": {"M": "#a0a8b8", "S": "#50e0a0", "A": "#f04848", "K": "#f8e040"}, "proj": "raio",
		"b": {"base_hp": 900, "attack_damage": 85, "attack_range": 210.0, "attack_speed": 2.0, "projectile_speed": 420.0}},
]

# ---------------------------------------------------------------- construção
static var _built := false
static var _cards: Array = []
static var _tokens: Array = []
static var _by_id: Dictionary = {}
static var _bases: Array = []
static var _nations: Dictionary = {}
static var _template: PackedScene


static func _ensure():
	if _built:
		return
	_built = true
	for turma in TURMAS:
		var n = NationData.new()
		n.nation_name = turma
		n.color = Color.html(TURMAS[turma]["cor"])
		_nations[turma] = n
	_template = load(UNIT_TEMPLATE)
	for def in CARTAS:
		var card = build_card(def, PATH_PREFIX + def["id"] + ".tres")
		_by_id[def["id"]] = card
		if def.get("ficha", false):
			_tokens.append(card)
		else:
			_cards.append(card)
	# 2ª passada: filhotes (precisa de todas as cenas prontas)
	for def in CARTAS:
		link_children(_by_id[def["id"]], def, _by_id)
	for def in TORRES:
		_bases.append(build_base(def, PATH_PREFIX + "torre_" + def["id"] + ".tres"))


static func cards() -> Array:
	_ensure()
	return _cards


static func tokens() -> Array:
	_ensure()
	return _tokens


static func bases() -> Array:
	_ensure()
	return _bases


static func nations() -> Array:
	_ensure()
	return _nations.values()


static func nation(turma: String) -> NationData:
	_ensure()
	return _nations.get(turma, null)


static func card(id: String) -> CardData:
	_ensure()
	return _by_id.get(id, null)


static func starter_deck() -> Array:
	_ensure()
	var out: Array = []
	for id in BARALHO_INICIAL:
		out.append(_by_id[id])
	return out


## acha uma carta (oficial, ficha ou criada) pelo caminho salvo
static func find_card(path: String) -> CardData:
	_ensure()
	if path == "":
		return null
	for c in CardDatabase.all_cards:
		if c != null and c.resource_path == path:
			return c
	for c in _tokens:
		if c.resource_path == path:
			return c
	if !path.begins_with(PATH_PREFIX) and ResourceLoader.exists(path):
		var res = load(path)
		if res is CardData:
			return res
	return null


static func find_base(path: String) -> BaseData:
	_ensure()
	for b in BotSimulator.available_bases:
		if b != null and b.resource_path == path:
			return b
	return null


static var _rarity_cache: Dictionary = {}


## RARIDADE 3.0
## Normal e Rara: SEM habilidade (a Rara só é uma carta melhorzinha/diferente).
## Épica: habilidade fraca (1-2 pontos). Lendária: habilidade boa (3-4).
## Mística: as melhores (5+). Cada habilidade vale 1, 2 ou 3 pontos.
static func rarity_from_score(score: int, base_rarity: int = 0) -> int:
	if score <= 0:
		return clampi(base_rarity, COMUM, RARA)
	if score <= 2:
		return EPICA
	if score <= 4:
		return LENDARIA
	return MISTICA


static func rarity_of(c: CardData) -> int:
	if c == null:
		return 0
	var key = c.get_instance_id()
	if !_rarity_cache.has(key):
		_rarity_cache[key] = rarity_from_score(ability_score(c), c.rarity)
	return _rarity_cache[key]


static func clear_rarity_cache():
	_rarity_cache.clear()


static func ability_score(c: CardData) -> int:
	var total = 0
	for pair in abilities_detail(c):
		total += int(pair[1])
	return total


## só os nomes (pra mostrar)
static func abilities(c: CardData) -> Array:
	return abilities_detail(c).map(func(pair): return pair[0])


const EFFECT_POINTS = {
	UnitData.OnHitEffect.SLOW: 1, UnitData.OnHitEffect.WEAKNESS: 1, UnitData.OnHitEffect.POISON: 1,
	UnitData.OnHitEffect.KNOCKBACK: 1, UnitData.OnHitEffect.MARK: 1, UnitData.OnHitEffect.FREEZE: 3,
}


static func _effect_points(effect: int) -> int:
	return int(EFFECT_POINTS.get(effect, 2))


static func abilities_detail(c: CardData) -> Array:
	if c == null:
		return []
	if c.is_spell():
		return spell_abilities(c.spell_data)
	return unit_abilities(DeckBuilder.get_unit_stats(c))


## [nome, pontos] de cada habilidade de um feitiço. Dano, cura e escudo são a
## FUNÇÃO do feitiço, não habilidade.
static func spell_abilities(sp: SpellData) -> Array:
	var out: Array = []
	if sp == null:
		return out
	if sp.status_effect != UnitData.OnHitEffect.NONE:
		out.append(["Efeito: " + CustomContent.EFFECT_NAMES[sp.status_effect], _effect_points(sp.status_effect)])
	if sp.cleanses:
		out.append(["Purifica", 1])
	if sp.rage_damage_mult > 1.0 or sp.rage_speed_mult > 1.0:
		out.append(["Fúria", 2])
	if sp.summon_interval > 0.0 and sp.duration > 0.0:
		out.append(["Invoca sem parar", 3])
	elif sp.summon_count > 0:
		out.append(["Invoca tropas", 2])
	return out


## [nome, pontos] de tudo que a unidade faz ALÉM de andar, bater e ter vida.
## Voar, atirar de longe, bater em área, vir em bando ou com acompanhantes
## são características, não habilidades.
static func unit_abilities(st: UnitData) -> Array:
	var out: Array = []
	if st == null:
		return out
	if st.on_hit_effect != UnitData.OnHitEffect.NONE:
		out.append(["Golpe: " + CustomContent.EFFECT_NAMES[st.on_hit_effect], _effect_points(st.on_hit_effect)])
	if st.charge_attack:
		out.append(["Investida", 1])
	if st.can_stealth:
		out.append(["Furtivo", 2])
	if st.first_attack_bonus:
		out.append(["1º golpe em dobro", 1])
	if st.entrance_rage_duration > 0:
		out.append(["Entra em fúria", 1])
	if st.entrance_shockwave_damage > 0 or st.deals_arrival_damage:
		out.append(["Onda de choque", 1])
	if st.lifesteal_percent > 0:
		out.append(["Roubo de vida", 1])
	if st.forces_aggro:
		out.append(["Provoca", 2])
	if st.damage_reduction_percent > 0 or st.has_shield:
		out.append(["Casca dura", 1])
	if st.passive_regen:
		out.append(["Regenera", 1])
	if st.is_linked:
		out.append(["Divide o dano", 2])
	if st.spawns_on_death:
		out.append(["Filhotes ao morrer", 2])
	if st.kamikaze or st.explodes_on_death:
		out.append(["Explode", 2])
	if st.projectile_chains:
		out.append(["Tiro em corrente", 3])
	elif st.projectile_splits or st.projectile_pierces:
		out.append(["Tiro especial", 2])
	if st.can_heal_allies:
		out.append(["Cura aliados", 2])
	if st.spawns_units or st.summons_on_attack:
		out.append(["Invoca tropas", 2])
	if st.immune_while_moving:
		out.append(["Intocável andando", 3])
	if st.ramping_attack_speed or st.ramping_damage or st.same_target_ramping_damage:
		out.append(["Vai ficando mais forte", 2])
	if st.low_hp_rage_threshold > 0:
		out.append(["Fúria na beira da morte", 2])
	if st.execute_threshold > 0:
		out.append(["Executa", 2])
	if st.generates_resource:
		out.append(["Gera recurso", 2])
	if st.reflects_damage:
		out.append(["Devolve dano", 2])
	if st.heals_on_kill:
		out.append(["Cura ao matar", 1])
	if st.can_resurrect:
		out.append(["Levanta de novo", 3])
	if st.immune_to_knockback or st.immune_to_pull:
		out.append(["Inabalável", 1])
	if st.can_clone:
		out.append(["Clone ao morrer", 2])
	if st.counter_attack_chance > 0:
		out.append(["Revida", 1])
	if st.converts_kills_to_gold:
		out.append(["Recurso ao matar", 1])
	if st.steals_resource_on_base_hit:
		out.append(["Rouba recurso", 1])
	if st.aoe_hits_extra_one:
		out.append(["Golpe duplo", 1])
	if st.bandit_dash:
		out.append(["Bote", 1])
	if st.distance_damage_bonus_per_100px > 0:
		out.append(["Mais dano de longe", 1])
	if st.can_spawn_anywhere:
		out.append(["Nasce em qualquer lugar", 2])
	return out


## desliga TODA habilidade de uma unidade (gerador: cartas Normal e Rara)
static func strip_abilities(st: UnitData):
	st.on_hit_effect = UnitData.OnHitEffect.NONE
	for f in ["charge_attack", "can_stealth", "first_attack_bonus", "deals_arrival_damage", "forces_aggro", "has_shield", "passive_regen",
			"is_linked", "spawns_on_death", "kamikaze", "explodes_on_death", "projectile_chains", "projectile_splits", "projectile_pierces",
			"can_heal_allies", "summons_on_attack", "immune_while_moving", "ramping_attack_speed", "ramping_damage",
			"same_target_ramping_damage", "generates_resource", "reflects_damage", "heals_on_kill", "can_resurrect", "immune_to_knockback",
			"immune_to_pull", "can_clone", "converts_kills_to_gold", "steals_resource_on_base_hit", "aoe_hits_extra_one", "bandit_dash"]:
		st.set(f, false)
	for f in ["entrance_rage_duration", "entrance_shockwave_damage", "lifesteal_percent", "damage_reduction_percent", "low_hp_rage_threshold",
			"execute_threshold", "counter_attack_chance", "distance_damage_bonus_per_100px"]:
		st.set(f, 0)


## raridade das TORRES: mesma régua. Só vida ou só canhão = sem habilidade.
static func base_ability(b: BaseData) -> Array:
	## devolve [nome, pontos] ou [] se a torre não tem habilidade
	if b == null:
		return []
	match b.base_type:
		BaseData.BaseType.PRODUCTION:
			return ["Recurso mais rápido", 1 if b.production_speed_boost <= 0.15 else 3]
		BaseData.BaseType.CAPACITY:
			return ["Guarda mais recurso", 2]
		BaseData.BaseType.HEAL:
			return ["Cura aliados", 2]
		BaseData.BaseType.AURA:
			return ["Aura: " + CustomContent.EFFECT_NAMES[b.effect], _effect_points(b.effect) + 2]
	return []


static func base_rarity(b: BaseData) -> int:
	var ab = base_ability(b)
	if ab.is_empty():
		# sem habilidade: Rara se tiver um "jeitão" (tiro em área ou alcance longo)
		var fancy = b != null and b.base_type == BaseData.BaseType.CANNON and (b.is_aoe or b.attack_range >= 170.0)
		return RARA if fancy else COMUM
	return rarity_from_score(int(ab[1]))


static func rarity_color(c: CardData) -> Color:
	return RARITY_COLORS[rarity_of(c)]


# ---------------------------------------------------------------- montagem (também usada pelo gerador/Safra)
static func _enum_value(enum_dict: Dictionary, value, fallback: int = 0) -> int:
	if value is String:
		return int(enum_dict.get(value, fallback))
	return int(value)


## stats_override / spell_override: números já prontos (gerador / Safra)
static func build_card(def: Dictionary, path: String = "", stats_override: UnitData = null, spell_override: SpellData = null) -> CardData:
	_ensure()
	if _template == null:
		_template = load(UNIT_TEMPLATE)
	var card = CardData.new()
	card.card_name = def.get("nome", "Carta")
	card.cost = int(def.get("custo", 30))
	card.description = def.get("desc", "")
	card.pros.assign(def.get("pros", []))
	card.cons.assign(def.get("cons", []))
	card.role = _enum_value(CardData.CardRole, def.get("papel", "VERSATIL"), CardData.CardRole.VERSATIL)
	card.danger_level = int(def.get("perigo", 3))
	card.rarity = int(def.get("raridade", 0))
	card.unlock_arena = int(def.get("arena", 0))
	card.tier = card.unlock_arena + 1
	card.art_recipe = def.get("receita", {}).duplicate()
	card.art_palette = def.get("paleta", {}).duplicate()
	card.nation_data = _nations.get(def.get("turma", ""), null)
	card.icon = SpriteForge.make(card.art_recipe, card.art_palette)
	if def.get("ficha", false):
		card.set_meta("spawn_only", true)

	if def.has("f") or spell_override != null:
		var spell = spell_override if spell_override != null else SpellData.new()
		_apply_fields(spell, def.get("f", {}))
		card.spell_data = spell
	else:
		var stats = stats_override if stats_override != null else UnitData.new()
		_apply_fields(stats, def.get("u", {}))
		stats.role = card.role
		if stats.is_ranged:
			stats.detection_range = maxf(stats.detection_range, stats.attack_range + 20.0)
			stats.projectile_texture = SpriteForge.projectile(def.get("proj", "pedra"), card.art_palette)
		card.unit_scene = build_unit_scene(stats, card.icon)
	if path != "":
		card.take_over_path(path)
	return card


static func link_children(card: CardData, def: Dictionary, by_id: Dictionary):
	if card.spell_data != null:
		if def.has("invoca") and by_id.has(def["invoca"]):
			card.spell_data.summon_scene = by_id[def["invoca"]].unit_scene
		return
	for pair in def.get("junto", []):
		if by_id.has(pair[0]):
			card.companions.append({"scene": by_id[pair[0]].unit_scene, "count": int(pair[1])})
	var stats: UnitData = unit_stats(card)
	if stats == null:
		return
	if def.has("filho") and by_id.has(def["filho"]):
		stats.spawn_unit_scene = by_id[def["filho"]].unit_scene
	if def.has("filho_morte") and by_id.has(def["filho_morte"]):
		stats.death_spawn_scene = by_id[def["filho_morte"]].unit_scene
	if def.has("filho_ataque") and by_id.has(def["filho_ataque"]):
		stats.attack_summon_scene = by_id[def["filho_ataque"]].unit_scene


static var _stats_by_scene: Dictionary = {}


static func unit_stats(card: CardData) -> UnitData:
	if card == null or card.unit_scene == null:
		return null
	return _stats_by_scene.get(card.unit_scene, null)


static func build_unit_scene(stats: UnitData, tex: Texture2D) -> PackedScene:
	var node = _template.instantiate()
	node.stats = stats
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	var packed = PackedScene.new()
	packed.pack(node)
	node.free()
	_stats_by_scene[packed] = stats
	return packed


static func _apply_fields(obj: Object, fields: Dictionary):
	for key in fields:
		var value = fields[key]
		match key:
			"target_type":
				value = _enum_value(UnitData.TargetType, value)
			"unit_type":
				value = _enum_value(UnitData.UnitType, value)
			"on_hit_effect", "status_effect", "mastery_effect", "immune_to_effect", "effect":
				value = _enum_value(UnitData.OnHitEffect, value)
			"fx_color":
				value = Color.html(value) if value is String else value
		if key in obj:
			obj.set(key, value)
		else:
			push_warning("Catalogo: campo desconhecido '%s'" % key)


static func build_base(def: Dictionary, path: String = "") -> BaseData:
	var b = BaseData.new()
	b.base_name = def.get("nome", "Torre")
	b.description = def.get("desc", "")
	b.pros.assign(def.get("pros", []))
	b.cons.assign(def.get("cons", []))
	b.nation_data = _nations.get(def.get("turma", ""), null)
	b.base_type = _enum_value(BaseData.BaseType, def.get("tipo", "CANNON"))
	b.category = _enum_value(BaseData.BaseCategory, def.get("categoria", "DEFENSIVO"))
	b.tier = int(def.get("arena", 0)) + 1
	b.unlock_arena = int(def.get("arena", 0))
	var tex = SpriteForge.make(def.get("receita", {}), def.get("paleta", {}))
	b.icon = tex
	b.base_texture = tex
	_apply_fields(b, def.get("b", {}))
	if b.base_type == BaseData.BaseType.CANNON:
		b.projectile_texture = SpriteForge.projectile(def.get("proj", "pedra"), def.get("paleta", {}))
	if path != "":
		b.take_over_path(path)
	return b
