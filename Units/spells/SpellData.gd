extends Resource
class_name SpellData

# raio de alcance do efeito
@export var radius: float = 80.0
# 0 = instantâneo (ex: bola de fogo); >0 = fica na área aplicando efeito com o tempo
@export var duration: float = 0.0
# a cada quantos segundos o efeito é reaplicado, enquanto durar (só relevante se duration > 0)
@export var tick_interval: float = 0.5

# dano instantâneo (duration=0) ou por tick (duration>0) -- 0 = esse feitiço não causa dano
@export var damage: int = 0

# multiplicador de dano quando o alvo é a BASE (não unidade) -- 0.12 = só
# 12% do dano normal na base (padrão, mesmo valor que já era fixo pra todo
# feitiço antes). Ajusta por feitiço agora: um feitiço "de cerco" pode ter
# um valor mais alto, um de controle pode ficar ainda mais baixo, etc.
@export_range(0.0, 2.0) var base_damage_multiplier: float = 0.12

# cura instantânea (duration=0) ou por tick (duration>0) -- 0 = esse feitiço não cura
@export var heal_amount: int = 0

# efeito de status opcional, POR CIMA do dano/cura acima -- mesmo vocabulário
# que as unidades já usam quando acertam um golpe. Dá pra combinar (ex: dano
# + atordoa, tipo uma "Trovoada"), ou usar só o status sem dano nenhum (ex:
# um "Nevoeiro" que só confunde, sem causar dano)
@export var status_effect: UnitData.OnHitEffect = UnitData.OnHitEffect.NONE
# multiplicador de velocidade/dano (SLOW/WEAKNESS -- valor >1 no SLOW vira um
# "acelera", tipo fúria) ou dano extra (SHOCK)
@export var status_effect_strength: float = 0.5
## quanto tempo o efeito (congelar, lentidão, veneno...) dura em quem foi
## atingido, em segundos. 0 = automático (2s no instantâneo; no feitiço que
## fica no chão, dura enquanto a unidade está na área + um pouquinho)
@export var status_effect_duration: float = 0.0
# distância do empurrão (só usado se status_effect = KNOCKBACK)
@export var knockback_distance: float = 40.0

# quem esse feitiço afeta -- dá pra combinar os dois se quiser (raro, mas possível)
@export var affects_enemies: bool = true
@export var affects_allies: bool = false

# textura opcional do círculo/efeito visual no chão, enquanto o feitiço dura
@export var ground_effect_texture: Texture2D

@export_group("Reforço nos aliados")
## FÚRIA: multiplica o dano dos aliados atingidos (1 = sem fúria, 1.4 = +40%)
@export var rage_damage_mult: float = 1.0
## FÚRIA: multiplica a velocidade de andar (1.35 = +35%)
@export var rage_speed_mult: float = 1.0
## FÚRIA: ataca mais rápido (1.35 = 35% mais golpes)
@export var rage_attack_speed_mult: float = 1.0
## ESCUDO temporário que absorve dano em cada aliado atingido
@export var shield_amount: int = 0
## PURIFICAR: tira todo efeito ruim dos aliados atingidos
@export var cleanses: bool = false
## quanto tempo a fúria/escudo dura em quem foi atingido (0 = automático)
@export var buff_duration: float = 0.0

@export_group("Invocação")
## unidade que nasce no lugar onde o feitiço caiu (time de quem lançou)
@export var summon_scene: PackedScene
@export var summon_count: int = 0
## Se > 0 (e o feitiço dura um tempo), nasce MAIS UMA unidade a cada tantos
## segundos, num ponto aleatório da área (estilo "cemitério").
@export var summon_interval: float = 0.0

@export_group("Visual")
## cor do efeito no chão/partículas (o jogo escolhe uma se ficar transparente)
@export var fx_color: Color = Color(0, 0, 0, 0)


@export_group("Mecânicas novas (versão 113)")
## ROLA pelo chão (tipo o Tronco): sai de onde você soltou e anda pra frente, acertando
## uma vez cada tropa de chão no caminho. O raio vira a meia-largura.
@export var rolls: bool = false
@export var roll_distance: float = 320.0
@export var roll_speed: float = 260.0
## ESCOLHE os alvos (tipo o Relâmpago): acerta só os N de mais vida dentro do raio. 0 = todo mundo.
@export var picks_strongest: int = 0
## ESPELHO: repete a última carta que você jogou, no lugar onde soltar.
@export var mirror: bool = false

## EFEITOS (aba "Efeitos" do Criador). fx_style: 0 = automático; 1.. = Fx.STYLE_NAMES.
@export var fx_style: int = 0
## quanto de partícula (1 = normal)
@export var fx_power: float = 1.0
## som: 0 = automático; 1.. = SOUND_IDS
@export var fx_sound: int = 0
## cor: 0 = a do estilo; 1.. = TINT_COLORS
@export var fx_tint: int = 0
const TINT_NAMES = ["Cor do estilo", "Vermelho", "Laranja", "Amarelo", "Verde", "Azul claro", "Azul", "Roxo", "Rosa", "Branco", "Preto"]
const TINT_COLORS = [Color(0, 0, 0, 0), Color(1.0, 0.3, 0.25), Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.3), Color(0.45, 0.9, 0.4), Color(0.6, 0.9, 1.0),
	Color(0.3, 0.5, 1.0), Color(0.7, 0.4, 0.95), Color(1.0, 0.55, 0.8), Color(1, 1, 1), Color(0.15, 0.12, 0.18)]
const SOUND_NAMES = ["Automático", "Explosão", "Raio", "Gelo", "Cura", "Fúria", "Lama", "Carta", "Sem som"]
const SOUND_IDS = ["", "explosao", "raio", "gelo", "cura", "furia", "lama", "carta", ""]
