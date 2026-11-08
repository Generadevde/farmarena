extends Resource
class_name AIProfile

@export var profile_name: String = "IA"
@export var deck: Array[CardData] = []
@export var card_levels: Dictionary = {}  # caminho do .tres da carta -> nível (1 = base)

## Personalidade nomeada do bot -- a fonte de coerência por trás dos traços
## abaixo (reserva, agressividade, etc). Cada arquétipo já vem com uma
## combinação de traços que faz sentido junto, em vez de cada traço ser
## sorteado de forma totalmente independente dos outros.
enum Archetype {
	AGRESSIVO, PASSIVO, CURIOSO, ATACA_TUDO, ESTRUTURAL, METAGAMER, CAOTICO, POUPADOR, VINGATIVO,
	OPORTUNISTA, PROVOCADOR, ENXAMEADOR, EMBOSCADA, ACUMULADOR, REATIVO_PURO, TERRITORIAL, IMPULSIVO, ANALITICO, APOSTADOR,
	PERFECCIONISTA, MINIMALISTA, METRONOMO, COMBINADOR, BOOMER, BABY,
}
const ARCHETYPE_NAMES = {
	Archetype.AGRESSIVO: "Agressivo",
	Archetype.PASSIVO: "Passivo",
	Archetype.CURIOSO: "Curioso",
	Archetype.ATACA_TUDO: "Ataca Tudo",
	Archetype.ESTRUTURAL: "Estrutural",
	Archetype.METAGAMER: "Metagamer",
	Archetype.CAOTICO: "Caótico",
	Archetype.POUPADOR: "Poupador",
	Archetype.VINGATIVO: "Vingativo",
	Archetype.OPORTUNISTA: "Oportunista",
	Archetype.PROVOCADOR: "Provocador",
	Archetype.ENXAMEADOR: "Enxameador",
	Archetype.EMBOSCADA: "Emboscada",
	Archetype.ACUMULADOR: "Acumulador",
	Archetype.REATIVO_PURO: "Reativo Puro",
	Archetype.TERRITORIAL: "Territorial",
	Archetype.IMPULSIVO: "Impulsivo",
	Archetype.ANALITICO: "Analítico",
	Archetype.APOSTADOR: "Apostador",
	Archetype.PERFECCIONISTA: "Perfeccionista",
	Archetype.MINIMALISTA: "Minimalista",
	Archetype.METRONOMO: "Metrônomo",
	Archetype.COMBINADOR: "Combinador",
	Archetype.BOOMER: "Boomer",
	Archetype.BABY: "Baby",
}
@export var archetype: int = Archetype.AGRESSIVO
## Teimosia: define se o bot troca de deck quando uma carta está indo mal,
## ou insiste nela mesmo assim. 0.0 = troca fácil (experimenta sempre),
## 1.0 = praticamente nunca troca, não importa o quão mal esteja indo.
@export var stubbornness: float = 0.5

# cartas que esse bot já conhece/pode usar -- só esse conjunto entra no deck
# dele ou nas trocas de evolução, nunca o banco inteiro de uma vez
@export var known_cards: Array[CardData] = []

# --- estratégia: mexe nesses 3 pra dar personalidade diferente a cada bot ---

# quanto de recurso o bot sempre guarda de reserva antes de jogar qualquer carta
# (0 = gasta tudo que puder; um valor alto = joga bem menos, mais econômico)
@export var min_money_reserve: int = 0

# true = entre as cartas que consegue pagar, escolhe sempre a mais cara (geralmente
# a mais forte); false = escolhe aleatoriamente entre as que consegue pagar
@export var prefer_expensive: bool = false

# true = só joga quando detecta uma unidade do jogador se aproximando da base dele
# (comportamento defensivo/reativo); false = joga no timer normalmente, sem se importar
@export var reacts_to_threats: bool = false

# a cada quantos segundos o bot considera jogar uma carta -- menor = mais rápido/agressivo
@export var decision_interval: float = 3.0

# true = ignora feitiços enquanto tiver alguma unidade que consiga pagar (bot "exército",
# só usa magia quando não sobra outra opção); false = considera tudo igual
@export var prefer_units_over_spells: bool = false

# carta "de assinatura": se estiver no baralho e o bot puder pagar, joga ela antes de
# qualquer outra lógica -- dá uma jogada característica/reconhecível pro bot
@export var favorite_card: CardData

# true = depois que a própria base leva dano, o bot ignora a reserva de dinheiro por
# um tempo (fica desesperado/agressivo reagindo ao ataque)
@export var revenge_mode: bool = false

# módulo instalado na base desse bot (canhão, produção, cura, vida, espaço)
@export var equipped_base: BaseData
@export var base_level: int = 1  # nível da base do bot -- upado com o mesmo custo (ouro + partidas) que o jogador usa
## categoria de base que esse bot prefere (Ofensivo/Defensivo/Econômico) --
## ligada à personalidade dele, sorteada com peso na criação
@export var preferred_base_category: int = BaseData.BaseCategory.DEFENSIVO

# categoria que esse bot prefere -- dá identidade tipo "gosta de enxame",
# "gosta de construção". Usado tanto pra montar o deck dele (favorece cartas
# dessa categoria) quanto na hora de escolher o que jogar em campo
@export var preferred_role: int = CardData.CardRole.VERSATIL


func get_card_level(card: CardData) -> int:
	return card_levels.get(card.resource_path, 1)


func get_archetype_name() -> String:
	return ARCHETYPE_NAMES.get(archetype, "Desconhecido")


func get_stat_multiplier(card: CardData) -> float:
	return PlayerProfile.compute_stat_multiplier(get_card_level(card))


# escolhe uma carta entre as que o bot consegue pagar, respeitando a estratégia dele
func choose_card(affordable: Array[CardData]) -> CardData:
	if affordable.is_empty():
		return null

	# carta favorita: joga assim que possível, na frente de qualquer outra lógica
	if favorite_card != null and favorite_card in affordable:
		return favorite_card

	var pool = affordable
	if prefer_units_over_spells:
		var units_only: Array[CardData] = []
		for card in affordable:
			if !card.is_spell():
				units_only.append(card)
		if !units_only.is_empty():
			pool = units_only

	# entre as opções, prioriza quem for da categoria preferida do bot, se
	# tiver alguma disponível -- dá o "gosta de enxame"/"gosta de construção"
	# na prática, não só como identidade do deck
	var role_matches: Array[CardData] = []
	for card in pool:
		if card.role == preferred_role:
			role_matches.append(card)
	if !role_matches.is_empty():
		pool = role_matches

	if prefer_expensive:
		var best = pool[0]
		for card in pool:
			if card.cost > best.cost:
				best = card
		return best

	return pool[randi() % pool.size()]
