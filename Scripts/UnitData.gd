extends Resource
class_name UnitData

# ============================================================
# ESTATÍSTICAS BÁSICAS
# ============================================================

## Vida máxima da unidade.
@export var hp: int = 100
## Dano por ataque, antes de qualquer bônus/redução se aplicar.
@export var damage: int = 10
## Peso pra resolução de colisão entre unidades -- quando duas se esbarram
## andando, a mais LEVE é quem cede espaço, a mais PESADA quase não se
## move. O Godot não tem conceito de massa nativo pra CharacterBody2D, esse
## campo existe só pra resolver isso manualmente. Tanque = valor alto (ex:
## 3.0), unidade leve = valor baixo (ex: 0.5). Padrão 1.0 = "peso médio".
@export var push_weight: float = 1.0
## Velocidade de movimento (pixels por segundo, aproximadamente).
@export var move_speed: float = 50.0
## Tempo entre ataques, em segundos (menor = ataca mais rápido).
@export var attack_speed: float = 1.0
## Distância mínima até o alvo pra conseguir atacar.
@export var attack_range: float = 20.0
## Alcance de "visão": a que distância a unidade nota inimigos e trava
## neles. 0 = usa o Attack Range. Normalmente é igual ou maior que ele.
@export var detection_range: float = 110.0
## Escala visual e física (1.0 = normal) -- escala sprite e colisão juntos.
@export var unit_scale: float = 1.0

## Se marcado, essa unidade nasce "disfarçada" com o ícone de uma carta
## aleatória qualquer (sorteada entre todas do banco), e só revela o
## visual VERDADEIRO dela no primeiro ataque -- surpresa de quem é de
## verdade, até ela agir
@export var spawns_disguised: bool = false

## Ataque carregado ("estilo Príncipe") -- anda uma distância mínima sem
## atacar, e o PRÓXIMO golpe vem carregado com dano extra (e opcionalmente
## empurra o alvo). Depois de usar o golpe carregado, precisa andar de
## novo pra carregar outro -- não é passivo o tempo todo, é sobre construir
## embalo antes de bater
@export var charge_attack: bool = false
## Quantos pixels precisa andar (desde o último ataque) pro próximo golpe
## já sair carregado
@export var charge_distance_needed: float = 150.0
## Multiplicador de dano do golpe carregado -- 2.0 = dobro do dano normal
@export var charge_damage_multiplier: float = 2.0
## Empurra o alvo pra trás quando acerta carregado -- 0 = sem empurrão
@export var charge_knockback_distance: float = 60.0

## Avanço instantâneo "estilo Bandida" -- diferente do ataque carregado
## acima (que precisa andar uma distância normal antes), esse dispara na
## HORA que a unidade avista um alvo pela primeira vez: corre até ele bem
## mais rápido que o normal, ficando invulnerável durante o avanço. Só
## acontece UMA VEZ na vida da unidade (a primeira vez que ela vê alguém)
@export var bandit_dash: bool = false
## Quantas vezes mais rápido que o normal durante o avanço -- 3.0 = triplo da velocidade
@export var dash_speed_multiplier: float = 3.0
## Por quanto tempo dura o avanço (e a invulnerabilidade junto)
@export var dash_duration: float = 0.4
## Quantas unidades essa carta spawna de uma vez (ex: 2 pra vir em dupla).
@export var unit_count: int = 1
## Como as unidades se organizam quando spawna mais de uma de uma vez
## (unit_count > 1) -- Grupo é o padrão clássico (grade quadrada, meio
## orgânica), os outros dão uma cara diferente pra carta
@export_enum("Grupo", "Linha", "Coluna", "Círculo") var spawn_formation: int = 0

# ============================================================
# ATAQUE À DISTÂNCIA E PROJÉTIL
# ============================================================

## Se marcado, essa unidade ataca à distância disparando um projétil, em
## vez de bater corpo a corpo.
@export var is_ranged: bool = false
## Textura/sprite do projétil disparado (só usado se Is Ranged estiver ligado).
@export var projectile_texture: Texture2D
## Velocidade de voo do projétil.
@export var projectile_speed: float = 300.0
## Atravessa o primeiro alvo e continua voando, acertando outros inimigos
## que estiverem no MESMO caminho reto -- não muda de direção nunca.
@export var projectile_pierces: bool = false
## Quantas unidades diferentes o mesmo projétil pode acertar no total,
## enquanto atravessa (só relevante se Projectile Pierces estiver ligado).
@export var projectile_max_targets: int = 1
## Ao acertar o primeiro alvo (ou no fim do percurso), se divide em vários
## projéteis menores DE UMA VEZ, cada um perseguindo um alvo diferente por
## perto -- diferente de encadeado, que é um de cada vez, em sequência.
@export var projectile_splits: bool = false
## Quantos projéteis nascem na hora da divisão (só usado se Projectile
## Splits estiver ligado).
@export var projectile_split_count: int = 3
## Distância MÁXIMA, a partir do ponto de impacto, que os fragmentos
## conseguem mirar -- sem isso, um fragmento podia mirar em algo do outro
## lado do mapa só por ser "o mais próximo" entre poucas opções.
@export var projectile_split_range: float = 150.0

## Encadeado: acerta UM alvo, depois pula pro inimigo mais próximo ainda
## não atingido, um de cada vez em sequência -- diferente de "atravessar"
## (reto, nunca muda de direção) e de "espalhar" (vários projéteis
## simultâneos). Mutuamente exclusivo com Pierces/Splits -- escolhe só um.
@export var projectile_chains: bool = false
## Quantos alvos no total, contando o primeiro (só usado se Projectile
## Chains estiver ligado).
@export var projectile_chain_max_targets: int = 3
## Distância MÁXIMA que o encadeado consegue pular de um alvo pro próximo
## -- sem isso, ele podia atravessar o mapa inteiro atrás do inimigo mais
## próximo, mesmo que estivesse longe demais pra fazer sentido.
@export var projectile_chain_range: float = 150.0

# ============================================================
# ALVO E TIPO
# ============================================================

## Que tipo de inimigo essa unidade consegue atacar/mirar.
enum TargetType { GROUND, AIR, ALL, BUILDING }
## Categoria da própria unidade, usada por outras unidades pra saber se
## conseguem mirar nela (ex: uma carta TargetType=GROUND não mira em AIR).
enum UnitType { GROUND, AIR, BUILDING }

## Que tipo de inimigo essa unidade consegue mirar (ver enum TargetType acima).
@export var target_type: TargetType = TargetType.GROUND
## Categoria dessa unidade (ver enum UnitType acima) -- construções (BUILDING)
## nunca se movem, só atacam quem chegar no alcance.
@export var unit_type: UnitType = UnitType.GROUND
## Tempo de vida em segundos, geralmente usado em construções temporárias.
## 0 = permanente, nunca expira sozinha.
@export var duration: float = 0.0
## Se marcado, o ataque normal já causa dano em área ao redor do alvo, em
## vez de só nele.
@export var is_aoe: bool = false
## Raio da área de dano (só usado se Is Aoe estiver ligado).
@export var aoe_radius: float = 60.0

# ============================================================
# EFEITO AO ACERTAR UM ATAQUE
# ============================================================

## Atordoamento que a unidade sofre assim que NASCE, antes de poder andar
## ou atacar -- representa ela "se recompondo" ao entrar em campo. 0 =
## nasce pronta pra agir na hora, sem atraso nenhum.
@export var initial_stun_duration: float = 0.5

## Efeito aplicado no alvo quando essa unidade acerta um golpe (ou quando um
## feitiço/módulo usa o mesmo sistema). Cada valor usa os campos
## Strength/Duration/Tick Interval/Knockback Distance de um jeito diferente
## -- veja a descrição de cada um abaixo antes de configurar.
enum OnHitEffect {
	## Ataque normal, sem efeito nenhum além do dano de sempre.
	NONE,
	## Reduz a velocidade de movimento do alvo por [Duration] segundos.
	## [Strength] é um MULTIPLICADOR da velocidade normal (ex: 0.5 = anda na
	## metade da velocidade; valores acima de 1.0 na verdade aceleram o alvo).
	SLOW,
	## Reduz o dano causado pelo alvo por [Duration] segundos. [Strength] é
	## um MULTIPLICADOR do dano normal (ex: 0.5 = causa metade do dano).
	WEAKNESS,
	## Deixa o alvo MUITO mais lento por [Duration] segundos -- funciona
	## igual SLOW (mesmo mecanismo por baixo), só que pensado pra ser uma
	## lentidão bem mais forte. [Strength] é o MULTIPLICADOR de velocidade
	## (ex: 0.1 = quase parado, mas ainda anda e ainda ataca -- diferente
	## de STUN, que trava por completo).
	FREEZE,
	## Causa dano contínuo ao longo do tempo. [Strength] é o dano de CADA
	## tick, [Tick Interval] é o intervalo em segundos entre um tick e
	## outro, [Duration] é por quanto tempo total o veneno dura.
	POISON,
	## Imobiliza por completo: o alvo não anda nem ataca por [Duration]
	## segundos -- diferente de FREEZE, que agora só deixa lento, não trava.
	STUN,
	## Empurra o alvo pra trás na hora do impacto, na direção de quem
	## atacou. Usa [Knockback Distance] (não usa Strength nem Duration).
	KNOCKBACK,
	## Dano extra INSTANTÂNEO (além do dano normal do ataque) + um
	## atordoamento BREVE, usando [Duration] -- diferente de FREEZE/STUN,
	## aqui o esperado é uma duração bem curta (ex: 0.5s), tipo um "choque"
	## rápido que reseta ataque em andamento ou muda o foco de quem levou.
	## [Strength] é a QUANTIDADE DE DANO em si, não um multiplicador (único
	## efeito que funciona assim). Some com um flash amarelo visual.
	SHOCK,
	## Confunde o alvo: ele passa a andar na direção CONTRÁRIA de onde
	## deveria, por [Duration] segundos -- como se estivesse desorientado.
	CONFUSE,
	## Puxa o alvo pra perto de quem atacou, na hora do impacto. Usa
	## [Knockback Distance] como distância do puxão (não usa Strength nem
	## Duration).
	PULL,
	## Prende o alvo no lugar por [Duration] segundos -- ele não anda, mas
	## AINDA CONSEGUE ATACAR se algo já estiver ao alcance dele.
	ROOT,
	## Silencia o alvo por [Duration] segundos: enquanto durar, os ataques
	## dele NÃO aplicam o próprio On Hit Effect em ninguém, e as habilidades
	## passivas dele (cura em área, invocar, gerar recurso, invocar ao
	## atacar) ficam desativadas. Não afeta dano nem movimento.
	SILENCE,
	## Marca o alvo como vulnerável por [Duration] segundos: ele passa a
	## receber mais dano de QUALQUER fonte (não só de quem aplicou a marca).
	## [Strength] é o MULTIPLICADOR de dano recebido (ex: 1.5 = leva 50% a
	## mais de dano de tudo enquanto durar).
	MARK,
}
## Qual efeito essa unidade aplica ao acertar um golpe -- veja a descrição
## de cada opção do enum acima pra saber exatamente o que ela faz.
@export var on_hit_effect: OnHitEffect = OnHitEffect.NONE
## Por quanto tempo o efeito dura (SLOW, WEAKNESS, FREEZE, STUN, POISON,
## CONFUSE, ROOT, SILENCE, MARK). Em SHOCK, representa o atordoamento
## BREVE que ele também causa -- use um valor bem menor que o normal (ex:
## 0.5), já que a ideia dele é ser rápido. Não é usado por KNOCKBACK nem PULL.
@export var on_hit_effect_duration: float = 2.0
## Significado MUDA de acordo com o efeito: multiplicador em SLOW/WEAKNESS/
## MARK, dano por tick em POISON, quantidade de dano fixo (instantâneo) em
## SHOCK. Não é usado pelos outros efeitos.
@export var on_hit_effect_strength: float = 0.5
## Intervalo entre ticks -- só usado por POISON.
@export var on_hit_effect_tick_interval: float = 1.0
## Distância do empurrão/puxão -- só usado por KNOCKBACK e PULL.
@export var knockback_distance: float = 40.0

## Habilidade de maestria: só ativa quando a carta atinge o nível máximo
## (hoje 7) -- reaproveita o MESMO vocabulário de efeito acima (enum
## OnHitEffect), mas como um efeito EXTRA que se SOMA ao On Hit Effect
## normal, não substitui ele. Deixa em NONE pra essa carta não ganhar nada
## especial na maestria.
@export var mastery_effect: OnHitEffect = OnHitEffect.NONE
## Mesmo significado do On Hit Effect Duration acima, mas só pro efeito de maestria.
@export var mastery_effect_duration: float = 2.0
## Mesmo significado do On Hit Effect Strength acima, mas só pro efeito de maestria.
@export var mastery_effect_strength: float = 0.5
## Mesmo significado do On Hit Effect Tick Interval acima, mas só pro efeito de maestria.
@export var mastery_effect_tick_interval: float = 1.0

# ============================================================
# SUPORTE E ECONOMIA
# ============================================================

## Se marcado, cura aliados próximos periodicamente (uma "aura" de cura).
@export var can_heal_allies: bool = false
## Quanto cura por tick (só usado se Can Heal Allies estiver ligado).
@export var heal_aura_amount: int = 10
## Raio da aura de cura.
@export var heal_aura_radius: float = 80.0
## A cada quantos segundos a aura de cura aplica de novo.
@export var heal_aura_interval: float = 1.0

## Se marcado, essa unidade invoca outra periodicamente enquanto viva.
@export var spawns_units: bool = false
## Cena da unidade a ser invocada (só usado se Spawns Units estiver ligado).
@export var spawn_unit_scene: PackedScene
## A cada quantos segundos invoca de novo.
@export var spawn_interval: float = 5.0
## Quantas unidades nascem a cada invocação.
@export var spawn_count: int = 1

## Se marcado, invoca outra(s) unidade(s) no exato momento em que morre.
@export var spawns_on_death: bool = false
## Cena da unidade a ser invocada ao morrer (só usado se Spawns On Death estiver ligado).
@export var death_spawn_scene: PackedScene
## Quantas unidades nascem ao morrer.
@export var death_spawn_count: int = 2

## Se marcado, gera recurso (elixir/moeda) periodicamente pro time dela,
## enquanto viva.
@export var generates_resource: bool = false
## Quanto de recurso gera por tick (só usado se Generates Resource estiver ligado).
@export var resource_per_tick: int = 1
## A cada quantos segundos gera de novo.
@export var resource_tick_interval: float = 1.0

## Se marcado, aumenta a capacidade máxima de recurso guardado do time dela
## (ex: sobe o teto de 100 pra 120).
@export var stores_resource: bool = false
## Quanto aumenta a capacidade máxima (só usado se Stores Resource estiver ligado).
@export var storage_capacity_bonus: int = 20

## Se marcado, rouba recurso do time inimigo sempre que acerta a BASE dele.
@export var steals_resource_on_base_hit: bool = false
## Quanto rouba a cada acerto na base (só usado se Steals Resource On Base Hit estiver ligado).
@export var resource_steal_amount: int = 5

## Se marcado, invoca uma unidade auxiliar toda vez que ataca (com chance
## configurável abaixo).
@export var summons_on_attack: bool = false
## Cena da unidade auxiliar invocada (só usado se Summons On Attack estiver ligado).
@export var attack_summon_scene: PackedScene
## Chance (0.0 a 1.0) de invocar a cada ataque -- 1.0 = sempre invoca.
@export var attack_summon_chance: float = 1.0

# ============================================================
# ESCALADA DE PODER
# ============================================================

## Se marcado, o PRIMEIRO ataque dessa unidade (desde que nasceu) causa
## dano multiplicado.
@export var first_attack_bonus: bool = false
## Multiplicador de dano do primeiro golpe (só usado se First Attack Bonus estiver ligado).
@export var first_attack_multiplier: float = 2.0

## Se marcado, o dano da unidade sobe a cada golpe DADO por ela (não
## por vida perdida -- ver Low Hp Rage Threshold abaixo pra essa outra ideia).
@export var ramping_damage: bool = false
## Quanto o multiplicador de dano sobe por golpe (só usado se Ramping Damage estiver ligado).
@export var ramping_damage_per_hit: float = 0.05
## Teto do multiplicador de dano, não importa quantos golpes já deu.
@export var ramping_damage_max_multiplier: float = 2.0

## Dano cresce enquanto continua atacando o MESMO alvo -- reseta se trocar
## de foco. Diferente de ramping_damage (que é geral e nunca reseta,
## mesmo trocando de alvo) -- essa recompensa "focar fogo" de verdade,
## punindo quem fica trocando de alvo toda hora
@export var same_target_ramping_damage: bool = false
@export var same_target_ramping_damage_per_hit: float = 0.1
@export var same_target_ramping_damage_max_multiplier: float = 2.0

## Causa dano A MAIS quanto mais longe o alvo estiver (unidade tipo
## "franco-atirador") -- esse valor é o bônus por cada 100px de distância
## (ex: 0.1 = +10% de dano a cada 100px além do alcance mínimo). 0 = desativado.
## Só faz sentido em unidade à distância de verdade
@export var distance_damage_bonus_per_100px: float = 0.0

## Se marcado, a velocidade de ataque (menos tempo entre golpes) melhora a
## cada golpe dado.
@export var ramping_attack_speed: bool = false
## Quanto o multiplicador de velocidade de ataque melhora por golpe (só
## usado se Ramping Attack Speed estiver ligado).
@export var attack_speed_ramp_per_hit: float = 0.05
## Teto do multiplicador (quanto MENOR, mais rápido -- é aplicado no tempo
## entre ataques, não na velocidade em si).
@export var attack_speed_ramp_min_multiplier: float = 0.5

## Se marcado, acelera o movimento por um instante logo ANTES de atacar --
## efeito de "investida"/"corrida pro ataque".
@export var pre_attack_speed_boost: bool = false
## Multiplicador de velocidade durante a investida (só usado se Pre Attack
## Speed Boost estiver ligado).ba
@export var pre_attack_boost_multiplier: float = 1.5
## Duração da investida, em segundos.
@export var pre_attack_boost_duration: float = 0.5

## Fúria de entrada: a unidade nasce com dano e velocidade turbinados por
## [Entrance Rage Duration] segundos, depois volta ao normal sozinha -- o
## oposto do Initial Stun Duration (que atrasa em vez de turbinar). Boa pra
## unidade de investida que precisa "chegar com tudo". 0 = desativado.
@export var entrance_rage_duration: float = 0.0
## Multiplicador de dano durante a fúria de entrada.
@export var entrance_rage_damage_mult: float = 1.5
## Multiplicador de velocidade durante a fúria de entrada.
@export var entrance_rage_speed_mult: float = 1.3

## Onda de choque de entrada: causa dano em área ao redor de si mesma no
## instante em que nasce -- uma entrada agressiva/ofensiva, complementando
## a Fúria de Entrada acima (que é defensiva/de sustentação, não causa
## dano). 0 = desativado.
@export var entrance_shockwave_damage: int = 0
## Raio da onda de choque de entrada (só relevante se o dano acima for maior que 0).
@export var entrance_shockwave_radius: float = 60.0

## Execução: causa dano MULTIPLICADO contra alvo com vida abaixo dessa
## fração do HP máximo dele (ex: 0.3 = alvo com menos de 30% de vida leva
## dano extra). 0 = desativado. Combina bem com a categoria Finalizador.
@export var execute_threshold: float = 0.0
## Multiplicador de dano contra alvo abaixo do limite de execução (só
## relevante se Execute Threshold for maior que 0).
@export var execute_damage_mult: float = 2.0

## Fúria por vida baixa: a PRÓPRIA unidade fica mais forte quando a vida
## dela cai abaixo dessa fração do HP máximo (ex: 0.3 = fica mais forte com
## menos de 30% de vida). Diferente do Ramping Damage (que sobe por golpe
## DADO, não por vida perdida). 0 = desativado.
@export var low_hp_rage_threshold: float = 0.0
## Multiplicador de dano enquanto estiver com vida baixa (só relevante se
## Low Hp Rage Threshold for maior que 0).
@export var low_hp_rage_damage_mult: float = 1.5

# ============================================================
# PADRÕES DE ATAQUE ESPECIAIS
# ============================================================

## Se marcado, causa dano contínuo por segundo enquanto o alvo estiver no
## alcance (tipo um raio/laser), em vez de golpes discretos.
@export var continuous_attack: bool = false
## Dano por segundo do ataque contínuo (só usado se Continuous Attack estiver ligado).
@export var continuous_damage_per_second: float = 10.0

## Se marcado, o ataque acerta todo mundo ao redor de SI MESMA (não só
## perto do alvo principal).
@export var spin_attack: bool = false

## Se marcado, o dano em área só acontece num CONE na frente da unidade,
## não no círculo inteiro ao redor.
@export var frontal_cone_attack: bool = false
## Abertura do cone, em graus (só usado se Frontal Cone Attack estiver ligado).
@export var cone_angle_degrees: float = 90.0

## Se marcado, o ataque normal acerta o alvo principal E mais UM inimigo
## próximo (sem ser uma área cheia).
@export var aoe_hits_extra_one: bool = false

# ============================================================
# SOBREVIVÊNCIA E DEFESA
# ============================================================

## Se marcado, a unidade nasce com um escudo que absorve dano antes da vida
## em si ser afetada.
@export var has_shield: bool = false
## Quanto o escudo absorve no total (só usado se Has Shield estiver ligado).
@export var shield_amount: int = 50
## Se maior que 0, o escudo volta a carregar sozinho depois de ficar esse
## tanto de segundos SEM levar dano nenhum (recarrega até o valor cheio de
## Shield Amount de novo). 0 = escudo é de uso único, não recarrega.
@export var shield_recharge_time: float = 0.0

## Escudo temporário: some depois de um tempo, mesmo que não tenha sido
## usado todo (diferente do Has Shield normal, que só some quando gasto).
@export var has_temp_shield: bool = false
## Quanto o escudo temporário absorve (só usado se Has Temp Shield estiver ligado).
@export var temp_shield_amount: int = 30
## Depois de quantos segundos o escudo temporário desaparece sozinho.
@export var temp_shield_duration: float = 5.0

## Reduz TODO dano recebido nessa porcentagem fixa, sempre -- aplica ANTES
## do escudo (0.0 = sem redução, 0.5 = metade do dano).
@export var damage_reduction_percent: float = 0.0

## Se marcado, essa unidade compartilha uma fração do dano que leva com as
## outras unidades vinculadas a ela (nascidas juntas na mesma carta).
@export var is_linked: bool = false
## Fração do dano compartilhada com as unidades vinculadas (só usado se Is
## Linked estiver ligado).
@export var link_share_percent: float = 0.3

## Se marcado, ao morrer pela primeira vez, ressuscita com uma fração da
## vida em vez de morrer de verdade (só funciona uma vez por unidade).
@export var can_resurrect: bool = false
## Fração da vida máxima com que ressuscita (só usado se Can Resurrect estiver ligado).
@export var resurrect_hp_percent: float = 0.3

## Se marcado, força inimigos próximos a mirar nela em vez de em outras
## unidades/na base (efeito "provocar"/tanque).
@export var forces_aggro: bool = false
## Raio dentro do qual a provocação funciona (só usado se Forces Aggro estiver ligado).
@export var taunt_radius: float = 150.0

## Efeito ao qual essa unidade é completamente imune -- nunca é afetada por
## ele, não importa quem tente aplicar. NONE = sem imunidade a efeito nenhum.
@export var immune_to_effect: OnHitEffect = OnHitEffect.NONE
## Se marcado, nunca é empurrada por KNOCKBACK.
@export var immune_to_knockback: bool = false
## Se marcado, nunca é puxada por PULL.
@export var immune_to_pull: bool = false

## Fração do dano causado que vira cura pra si mesma (0.0 a 1.0).
@export var lifesteal_percent: float = 0.0
## Chance (0.0 a 1.0) de contra-atacar automaticamente sempre que leva dano.
@export var counter_attack_chance: float = 0.0
## Se marcado, reflete uma fração do dano recebido de volta pra quem atacou.
@export var reflects_damage: bool = false
## Fração do dano refletida de volta (só usado se Reflects Damage estiver ligado).
@export var reflect_damage_percent: float = 0.3

## Se marcado, recupera vida sozinha periodicamente, mesmo sem fazer nada.
@export var passive_regen: bool = false
## Quanto recupera por tick (só usado se Passive Regen estiver ligado).
@export var regen_amount: int = 5
## A cada quantos segundos recupera de novo.
@export var regen_interval: float = 2.0

## Se marcado, recupera vida sempre que MATA um inimigo.
@export var heals_on_kill: bool = false
## Quanto recupera a cada abate (só usado se Heals On Kill estiver ligado).
@export var heal_on_kill_amount: int = 15

## Se marcado, converte cada abate em moeda pro time dela.
@export var converts_kills_to_gold: bool = false
## Quanto de moeda ganha por abate (só usado se Converts Kills To Gold estiver ligado).
@export var gold_per_kill: int = 5

# ============================================================
# MOVIMENTO E POSICIONAMENTO ESPECIAL
# ============================================================

## Se marcado, nada/voa sobre água e obstáculos sem precisar ser do tipo
## AIR (precisa de uma NavigationRegion2D extra sobre a água, configurada
## no editor).
@export var crosses_water: bool = false
## Se marcado, ignora a área restrita de spawn -- pode nascer em qualquer
## lugar do mapa, não só na área normal do time dela.
@export var can_spawn_anywhere: bool = false

## Pra carta de reforço aéreo: quantos segundos a unidade fica "pousando"
## logo ao nascer -- não anda nem ataca nesse período (mesmo efeito de
## incapacitar), mas continua um alvo válido, podendo ser atacada normalmente
## enquanto desce. 0 = nasce pronta pra agir na hora, sem pouso nenhum
@export var landing_duration: float = 0.0

## Se marcado, fica invisível/não pode ser mirada até um inimigo chegar
## perto o suficiente (ver Stealth Reveal Range abaixo).
@export var can_stealth: bool = false
## Só fica visível/alvo se um inimigo chegar mais perto que essa distância
## (só usado se Can Stealth estiver ligado).
@export var stealth_reveal_range: float = 40.0

## Fica IMUNE a dano enquanto estiver se movendo -- só fica vulnerável de
## verdade quando para (pra atacar, ou porque chegou no alvo). Dá uma
## unidade "furtiva em movimento", interessante contra canhão de base ou
## qualquer coisa que atire de longe.
@export var immune_while_moving: bool = false

## Fica intocável (ninguém pode mirar nela) por esses segundos logo ao
## nascer -- emboscada de verdade, ninguém percebe a tempo de reagir. 0 = sem invulnerabilidade nenhuma
@export var spawn_invulnerability_duration: float = 0.0

## Causa dano A MAIS contra unidade dessa categoria específica -- ex: 0.5
## aqui = +50% de dano contra quem for dessa categoria. 0 = desativado.
## Valor espelha CardData.CardRole (mesma ordem), mas como número (int) em
## vez do tipo de outra classe -- referenciar enum de outro script direto
## no @export pode falhar na hora do Godot escanear as classes globais,
## dependendo da ordem que ele processa os arquivos
@export_enum("Enxame", "Tanque", "Punição", "Controle", "Contra-ataque", "Suporte", "Finalizador", "Construção", "Aéreo", "Versátil", "Invocador", "Cerco") var extra_damage_vs_role: int = 9
@export var extra_damage_vs_role_mult: float = 0.0
## a própria categoria dessa unidade (pra OUTRA unidade checar bônus contra
## ela) -- espelha CardData.role, guardado aqui também pra consulta rápida
## em combate, sem precisar procurar na CardDatabase toda vez que bate
@export_enum("Enxame", "Tanque", "Punição", "Controle", "Contra-ataque", "Suporte", "Finalizador", "Construção", "Aéreo", "Versátil", "Invocador", "Cerco") var role: int = 9

# ============================================================
# MORTE, SACRIFÍCIO E CONVERSÃO
# ============================================================

## Se marcado, causa dano em área ao redor de si mesma no instante em que morre.
@export var explodes_on_death: bool = false
## Dano da explosão de morte (só usado se Explodes On Death estiver ligado).
@export var death_explosion_damage: int = 50
## Raio da explosão de morte.
@export var death_explosion_radius: float = 60.0

## Se marcado, causa dano em área ao redor de si mesma no instante em que
## NASCE -- oposto do "explode ao morrer", isso é "explode ao chegar"
## (ex: unidade que salta do avião e causa impacto onde aterrissa)
@export var deals_arrival_damage: bool = false
## Dano do impacto de chegada (só usado se Deals Arrival Damage estiver ligado).
@export var arrival_damage: int = 50
## Raio do impacto de chegada.
@export var arrival_damage_radius: float = 60.0

## Se marcado, depois de um tempo em campo, essa unidade se transforma
## numa construção (vira outra cena por completo).
@export var transforms_into_building: bool = false
## Depois de quantos segundos acontece a transformação (só usado se
## Transforms Into Building estiver ligado).
@export var transform_after_seconds: float = 5.0
## Cena em que ela se transforma.
@export var transformed_scene: PackedScene

## Se marcado, nasce uma cópia dela mesma (com vida reduzida) no instante
## em que morre.
@export var can_clone: bool = false
## Fração da vida máxima com que o(s) clone(s) nasce(m) (só usado se Can
## Clone estiver ligado).
@export var clone_hp_percent: float = 0.5
## Quantos clones nascem de uma vez ao morrer -- 1 = comportamento normal
## (um clone só); 2 ou mais vira "dividir ao morrer" de verdade, espalhando
## os clones ao redor da posição de morte.
@export var clone_count: int = 1

## Se marcado, a unidade morre sozinha logo depois de dar o próprio golpe
## (bombardeiro suicida -- ataca uma vez e se sacrifica).
@export var kamikaze: bool = false

## Se marcado, ao morrer, concede recurso pro time que a matou (tipo uma
## recompensa/bounty).
@export var grants_resource_on_death: bool = false
## Quanto de recurso concede ao morrer (só usado se Grants Resource On
## Death estiver ligado).
@export var death_resource_amount: int = 10

## Se marcado, ao invés de matar o alvo, converte ele pro próprio time
## (domina o inimigo em vez de destruir).
@export var can_convert_enemy: bool = false
## Quantos inimigos consegue converter no total, ao longo da vida dessa
## unidade (só usado se Can Convert Enemy estiver ligado).
@export var convert_max_targets: int = 1
