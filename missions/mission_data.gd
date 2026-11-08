extends Resource
class_name MissionData

enum MissionType {
	WIN_BATTLES,       # vencer X partidas
	PLAY_CARDS,        # jogar X cartas (de qualquer tipo)
	PLAY_NATION_CARDS, # jogar X cartas de uma nação específica (sorteada entre as que o jogador já tem XP)
	USE_SPELL,         # usar X feitiços
	DESTROY_BASE,      # destruir a base inimiga X vezes (= vencer, mas fica registrado como conquista separada se quiser diferenciar depois)
	PLAY_SPECIFIC_CARD, # jogar UMA carta específica (target_card) X vezes
	KILL_SPECIFIC_UNIT, # matar unidades de UM tipo específico (target_card) X vezes
	PLAY_BATTLES,       # jogar X partidas, não importa se venceu ou perdeu
	DEAL_DAMAGE,        # causar X de dano acumulado na base inimiga
	RECEIVE_DAMAGE,     # receber X de dano acumulado na própria base
	WIN_STREAK,         # vencer X partidas SEGUIDAS (reseta pra 0 se perder uma no meio)
}

enum RewardType {
	COINS,
	FREE_XP,
	NATION_XP,  # só faz sentido combinado com type = PLAY_NATION_CARDS -- premia com XP da MESMA nação que a missão pediu
}

## Texto da missão. Pode usar {target} (o número) e {nation} (só preenchido
## se o tipo for PLAY_NATION_CARDS) -- ex: "Jogue {target} cartas da nação
## {nation}" vira "Jogue 8 cartas da nação Mimosas" na hora de gerar
@export var description_template: String = ""

@export var type: MissionType = MissionType.PLAY_CARDS

## Quantidade necessária pra completar (o "X" da descrição)
@export var target: int = 10

## Só usado em PLAY_SPECIFIC_CARD ou KILL_SPECIFIC_UNIT -- qual carta/unidade
## em particular essa missão pede. O texto do template pode usar {card}
## também, além de {target}/{nation}
@export var target_card: CardData

@export var reward_type: RewardType = RewardType.COINS

## Quantidade da recompensa (moedas, ou XP, dependendo do reward_type acima)
@export var reward_amount: int = 100

## Peso de sorteio -- missão com peso maior aparece com mais frequência no
## dia a dia. Padrão 1 pra todas terem a mesma chance
@export var weight: float = 1.0
