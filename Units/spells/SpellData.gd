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
