extends Resource
class_name CardData

@export var card_name: String
@export var cost: int
@export var icon: Texture2D
@export var description: String

## 2.0 -- raridade (0 comum, 1 rara, 2 épica, 3 lendária): muda a chance no
## baú, o preço na Feira e quantas cópias precisa pra subir de nível
@export var rarity: int = 0
## 2.0 -- arena do Caminho dos Troféus em que a carta começa a aparecer (0 = inicial)
@export var unlock_arena: int = 0
## 2.0 -- arte montada por peças (SpriteForge): receita + paleta
@export var art_recipe: Dictionary = {}
@export var art_palette: Dictionary = {}

## Pontos fortes de jogar essa carta -- lista curta, tipo bullet point
@export var pros: Array[String] = []
## Pontos fracos/cuidados ao jogar essa carta -- lista curta, tipo bullet point
@export var cons: Array[String] = []

# preenche isso pra uma carta de unidade normal
@export var unit_scene: PackedScene

# preenche isso (e deixa unit_scene vazio) pra uma carta de feitiço/suporte
@export var spell_data: SpellData

# categoria/função estratégica da carta -- forma uma TEIA de vantagens: cada
# categoria vence quem está 1 posição E 4 posições à frente dela nessa lista
# (contando em círculo). Essa regra garante sozinha que nunca existe
# contradição (A vence B e B vence A ao mesmo tempo) e que todo mundo tem
# exatamente 2 vitórias e 2 derrotas -- pra adicionar categoria nova, só
# inclui ela na lista em qualquer posição, a teia se recalcula sozinha
enum CardRole {
	ENXAME,         # muitas unidades fracas
	TANQUE,         # HP alto, absorve golpe
	PUNICAO,        # dano alto e pontual
	CONTROLE,       # lentidão/atordoa/confunde
	CONTRA_ATAQUE,  # troca eficiente na defesa
	SUPORTE,        # cura/buff
	FINALIZADOR,    # foco em dano de torre
	CONSTRUCAO,     # defesa parada
	AEREO,          # ameaça voadora
	VERSATIL,       # não se encaixa num extremo
	INVOCADOR,      # invoca outras unidades continuamente
	CERCO,          # ataca a base de longe, sem precisar se aproximar
}
@export var role: CardRole = CardRole.VERSATIL

## Nome da nação dessa carta (ex: "Mimosas", "Aves do Sul") -- texto livre de
## propósito, não é uma lista fixa, assim você cria nação nova só digitando
## um nome novo aqui, sem precisar eu mexer em código toda vez.
## Deixa em branco (ou escreve "Coringa") pra carta coringa -- só desbloqueia
## com XP livre, nunca com XP de nação específica
## Nação dessa carta -- arrasta aqui o .tres de NationData já criado (não é
## mais texto livre, evita erro de digitação/nome não bater). Deixa vazio
## pra virar carta coringa (só aceita XP livre, nunca de nação específica)
@export var nation_data: NationData

## nome de exibição da nação -- "" se não tiver nation_data (vira Coringa)
func get_nation_name() -> String:
	return nation_data.nation_name if nation_data != null else ""

## Custo em XP (da nação dessa carta, ou XP livre) pra desbloquear -- 0 = já
## vem liberada desde o início, sem precisar desbloquear nada
@export var nation_xp_cost: int = 0

## A carta que precisa estar desbloqueada ANTES dessa ficar disponível --
## forma a cadeia de progressão da nação (ex: Vaca Guerreira -> Boi da
## Marreta -> Trio Nelore). Deixa em branco se essa for a primeira da cadeia
## As cartas que precisam estar desbloqueadas ANTES dessa ficar disponível --
## forma a cadeia de progressão da nação. Pode ter mais de uma (ex: precisa
## desbloquear as 2 anteriores pra essa aparecer). Deixa vazio se essa for
## a primeira da cadeia
@export var predecessor_cards: Array[CardData] = []

## Quão perigosa essa carta é quando aparece como AMEAÇA inimiga -- avaliação
## manual (1 = pouco ameaçadora, tipo enxame fraco; 10 = muito ameaçadora,
## tipo tanque pesado ou finalizador forte). O bot usa isso pra decidir se
## vale a pena responder com força total, mesmo sem contra-categoria exata
@export_range(1, 10) var danger_level: int = 3

# distâncias (na ordem do enum acima) que definem quem cada categoria vence
const ROLE_WIN_OFFSETS = [1, 4]

# distâncias que definem afinidade/combo -- propositalmente diferentes das
# de vencer, pra ser uma relação totalmente separada (não é sobre rivalidade,
# é sobre jogar bem JUNTO). Funciona nos dois sentidos: se A tem afinidade
# com B, B também tem com A
const ROLE_AFFINITY_OFFSETS = [2, 5]


func is_spell() -> bool:
	return spell_data != null


# texto legível da categoria -- usado em qualquer lugar que precise mostrar
# a categoria pro jogador (ícone, popup de info, etc), em vez do número cru
static func role_name(role: int) -> String:
	match role:
		CardRole.ENXAME: return "Enxame"
		CardRole.TANQUE: return "Tanque"
		CardRole.PUNICAO: return "Punição"
		CardRole.CONTROLE: return "Controle"
		CardRole.CONTRA_ATAQUE: return "Contra-ataque"
		CardRole.SUPORTE: return "Suporte"
		CardRole.FINALIZADOR: return "Finalizador"
		CardRole.CONSTRUCAO: return "Construção"
		CardRole.AEREO: return "Aéreo"
		CardRole.VERSATIL: return "Versátil"
		CardRole.INVOCADOR: return "Invocador"
		CardRole.CERCO: return "Cerco"
	return "?"


# true se role_a vence role_b -- calculado na hora a partir da posição de
# cada um no enum, não depende de tabela escrita à mão
static func role_beats(role_a: int, role_b: int) -> bool:
	var count = CardRole.size()
	for offset in ROLE_WIN_OFFSETS:
		if role_b == (role_a + offset) % count:
			return true
	return false


## Tier -- número que você mesmo define, controla a ORDEM de exibição na
## coleção (tier menor aparece primeiro) e o selinho "Tier X" no ícone.
## IMPORTANTE: isso é só visual/organização -- o DESBLOQUEIO de verdade
## continua sendo controlado por predecessor_cards, não por esse número.
## Pra ficar coerente, mantém o costume de "quem precisa de uma carta tem
## tier maior que ela" -- mas o jogo não obriga isso automaticamente mais,
## já que agora é você quem decide o número
@export var tier: int = 1


# true se as duas categorias têm afinidade (combo) entre si -- simétrico:
# não importa a ordem que você passa role_a/role_b
static func has_affinity(role_a: int, role_b: int) -> bool:
	var count = CardRole.size()
	for offset in ROLE_AFFINITY_OFFSETS:
		if role_b == (role_a + offset) % count:
			return true
		if role_a == (role_b + offset) % count:
			return true
	return false


# imprime as duas tabelas no Output -- chama isso de qualquer lugar (ex: um
# botão de debug) sempre que quiser conferir depois de mexer nas categorias
static func print_role_tables():
	var count = CardRole.size()
	var names = CardRole.keys()

	print("=== QUEM VENCE QUEM ===")
	for a in range(count):
		var beats_list: Array = []
		for b in range(count):
			if role_beats(a, b):
				beats_list.append(names[b])
		print("%s vence: %s" % [names[a], ", ".join(beats_list)])

	print("=== QUEM COMBINA COM QUEM ===")
	for a in range(count):
		var affinity_list: Array = []
		for b in range(count):
			if a != b and has_affinity(a, b):
				affinity_list.append(names[b])
		print("%s combina com: %s" % [names[a], ", ".join(affinity_list)])
