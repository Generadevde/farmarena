extends Resource
class_name BaseData

## Cada base é uma escolha completa, com identidade e HP próprios -- o
## jogador escolhe UMA antes da partida (igual escolhe o baralho), e os
## bots escolhem a deles de acordo com a personalidade.
@export var base_name: String = "Base"

## Nome da nação dessa base -- mesma regra da carta, texto livre
## Nação dessa base -- mesma regra da carta, arrasta o .tres de NationData
@export var nation_data: NationData

func get_nation_name() -> String:
	return nation_data.nation_name if nation_data != null else ""

@export_multiline var description: String
## Pontos fortes de usar essa base -- lista curta, tipo bullet point
@export var pros: Array[String] = []
## Pontos fracos/cuidados ao usar essa base -- lista curta, tipo bullet point
@export var cons: Array[String] = []
@export var icon: Texture2D

## Imagem da própria base no campo de batalha -- se preenchida, troca a
## aparência dela de verdade quando essa base é escolhida (não fica mais
## sempre com o visual fixo que estava na cena antes). Deixa em branco se
## quiser que essa base específica mantenha a aparência padrão da cena.
@export var base_texture: Texture2D

## Custo em XP (da nação dessa base, ou XP livre) pra desbloquear -- mesmo
## sistema de CardData.nation_xp_cost. 0 = já vem liberada desde o início
@export var nation_xp_cost: int = 0

## As bases que precisam estar desbloqueadas ANTES dessa ficar disponível --
## forma a cadeia de progressão da nação, mesmo conceito de CardData.predecessor_cards.
## Junto com nation_xp_cost, isso já controla o desbloqueio de verdade
## (PlayerProfile.can_unlock_base/unlock_base), igual carta
@export var predecessor_bases: Array[BaseData] = []

## Tier -- número que você mesmo define, mesma regra de CardData.tier.
## Desbloqueio continua controlado por predecessor_bases, esse número é só
## visual/organização (ordem na grade + selinho "Tier X")
@export var tier: int = 1

## Vida total dessa base -- cada tipo pode ter um valor bem diferente (ex:
## uma base Canhão pode ter menos vida que uma base de Vida, como
## contrapartida por já vir atacando sozinha).
@export var base_hp: int = 1000

## Tipo funcional -- o que essa base FAZ na prática.
enum BaseType { CANNON, PRODUCTION, HEAL, HP, CAPACITY, AURA }
@export var base_type: BaseType = BaseType.CANNON

## Categoria estratégica -- separada do tipo funcional acima, porque um
## mesmo tipo pode servir a propósitos diferentes (ex: uma Aura pode ser
## pensada como ofensiva ou defensiva, dependendo do efeito configurado).
## É essa categoria que os bots usam pra escolher base de acordo com a
## personalidade deles, não o tipo funcional.
enum BaseCategory { OFENSIVO, DEFENSIVO, ECONOMICO }
@export var category: BaseCategory = BaseCategory.DEFENSIVO

# --- Base Canhão: ataca sozinha ---
@export var attack_damage: int = 50
@export var attack_range: float = 150.0
@export var attack_speed: float = 1.0  # segundos entre disparos

## Textura do projétil disparado pelo canhão -- se ficar em branco, o
## disparo continua acontecendo, só que sem nenhum projétil visual (dano
## instantâneo, como já era antes desse campo existir).
@export var projectile_texture: Texture2D
## Velocidade de voo do projétil do canhão.
@export var projectile_speed: float = 300.0

## Se marcado, o disparo do canhão causa dano em área ao redor do alvo
## atingido, em vez de só nele -- mesmo mecanismo de dano em área que
## unidade à distância com Is Aoe ligado já usa
@export var is_aoe: bool = false
@export var aoe_radius: float = 60.0

# --- Base Guarnição: gera unidade sozinha, periodicamente, igual uma
# unidade com "spawns_units" já faz -- útil pra base mais autônoma/ofensiva ---
@export var spawns_units: bool = false
@export var spawn_unit_scene: PackedScene
@export var spawn_interval: float = 8.0
@export var spawn_count: int = 1

# --- Boost inicial: dá um empurrão só uma vez, no começo da partida (ex:
# ouro/energia extra de largada, ou um multiplicador de velocidade
# temporário nos primeiros segundos) ---
@export var gives_initial_boost: bool = false
@export var initial_money_boost: int = 0  # quantidade extra de recurso já na largada
@export var initial_production_speed_mult: float = 1.0  # 1.0 = sem alteração; ex: 1.5 = produção 50% mais rápida
@export var initial_boost_duration: float = 0.0  # por quantos segundos o multiplicador de produção dura (0 = só o dinheiro de largada, sem duração)

# --- Base Produção: acelera a geração de recurso do jogador ---
@export var production_speed_boost: float = 0.12  # 0.12 = 12% mais rápido

# --- Base Cura: cura unidades aliadas ao redor, periodicamente ---
@export var heal_amount: int = 10
@export var heal_radius: float = 100.0
@export var heal_interval: float = 1.0

# --- Base Espaço: aumenta a capacidade máxima de recurso (ex: 100 -> 120) ---
@export var capacity_bonus: int = 20

# --- Base Aura: aplica um efeito (mesmo vocabulário das unidades) em todo
# inimigo que chegar perto, periodicamente ---
@export var aura_radius: float = 120.0
@export var aura_tick_interval: float = 1.5

# --- Efeito opcional, reaproveitado tanto pelo Canhão (aplica no alvo
# atingido, além do dano normal) quanto pela Aura (aplica em quem entrar no
# raio) -- mesmo enum/parâmetros que UnitData.on_hit_effect já usa ---
@export var effect: UnitData.OnHitEffect = UnitData.OnHitEffect.NONE
@export var effect_strength: float = 0.5
@export var effect_duration: float = 2.0
@export var effect_tick_interval: float = 1.0
@export var knockback_distance: float = 40.0
