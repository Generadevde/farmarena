extends RefCounted
class_name Regras
## BATALHA 2.5 -- as regras que dão o "jeitão Clash" pra partida.
##
## O diagnóstico (18-19/11/2026): a torre não defendia nada (4 dos 6 tipos nem
## atiravam, e as que atiravam perdiam pra qualquer tropa sozinha), então
## não existia vantagem de quem defende. Sem isso a partida vira corrida
## -- "ou passa ou morre" -- e as cartas perdem o papel (tanque não precisa
## segurar tiro, bando é sempre o melhor, apoio não precisa de ninguém na
## frente). Medido em 24 partidas bot x bot: mediana de 102 s (de 300),
## 15 de 24 com o vencedor sem levar um arranhão.
##
## São 3 chaves em Configurações > Laboratório, pra comparar ligando e
## desligando no próprio jogo:
##   "torres"  torre de verdade: toda torre atira, com mais vida, dano e alcance
##   "visual"  tropas maiores, cor de time, barra de vida só em quem apanhou,
##             cada tipo de corpo andando e batendo do seu jeito
##   "peso"    1 s pra entrar em campo, preparo antes do golpe, impacto
##   "mao4"    4 cartas na mão (era 3) -- o baralho continua com 7
##   "portao"  3 torres por lado: o PORTÃO na frente (no meio, mais fraco) e as
##             2 de sempre atrás. O contrário do Clash, que põe 2 na frente

##   "rotas"   (só com o portão) a tropa segue a ROTA onde foi solta: esquerda
##             e direita vão na torre de trás daquele lado, meio vai no portão.
##             Sem isso toda tropa ia na torre mais perto -- sempre o portão --
##             e a partida virava "solta tudo no meio"

##   "modulos" BASE PRINCIPAL no meio (caiu, acabou) + 6 pontos em volta, onde
##             cada lado põe 2 MÓDULOS que escolheu antes da partida. Só módulo
##             de tiro atira; os outros valem pela função (recurso, cura, tropa...)

const KEYS = ["torres", "visual", "peso", "mao4", "portao", "rotas", "modulos"]
# O PORTÃO nasce DESLIGADO. Foi testado em 19/11 e o João sentiu na hora: "o jogo
# virou ficar jogando carta no meio". Medido entre bots: com ele, 67% de TODAS as
# cartas caem na rota do meio e o portão é a primeira torre a cair em 15 de 15
# partidas -- mesmo com as 3 rotas e com ele coberto pelas torres de trás. Sendo a
# torre mais fraca e a mais na frente, ele É o jogo. Fica no Laboratório pra comparar.
const DEFAULT_OFF = ["portao"]

# ---------------------------------------------------------------- mão e portão
const HAND_OLD = 3
const HAND_NEW = 4
# o portão fica NA FRENTE e apanha primeiro: menos vida que uma torre de trás,
# tiro mais fraco e alcance menor (ele segura o meio, não a ponte do lado)
const GATE_HP_SHARE = 0.6
const GATE_DAMAGE_SHARE = 0.75
const GATE_RANGE_SHARE = 0.85
const GATE_DY = 270.0               # distância do rio até o portão (as torres de trás ficam a 380). Era 196:
                                    # lá ele ficava SOZINHO, fora do tiro das de trás, e era sempre o alvo mais
                                    # barato. A 270 quem bate nele apanha das 3 torres, e ele cobre as 2 rotas do lado
const LANE_HALF = 75.0              # até 75 do centro é a rota do MEIO; além disso, esquerda ou direita


static func hand_size() -> int:
	return HAND_NEW if on("mao4") else HAND_OLD


static func three_towers() -> bool:
	return on("portao") and !modules()


# ---------------------------------------------------------------- módulos
## quantos módulos cabem por lado: abre com o NÍVEL DOS MÓDULOS (o mesmo 1 a 14 das cartas).
## Na partida os DOIS lados entram com a mesma quantidade: a do jogador.
const MODULE_SLOTS_MAX = 3
const MODULE_SLOT_LEVELS = [1, 5, 13]   # nível em que abre o 1º, o 2º e o 3º espaço
const MAIN_BASE_POS = Vector2(0, 330)   # a partir do meio do rio, pro lado de quem é o dono
# os 6 pontos: 3 na frente (esquerda, meio, direita), 2 nos lados da base e 1 atrás dela
const MODULE_POINTS = [Vector2(-150, 235), Vector2(0, 225), Vector2(150, 235), Vector2(-140, 395), Vector2(0, 435), Vector2(140, 395)]
const MODULE_POINT_NAMES = ["Frente esquerda", "Frente meio", "Frente direita", "Lado esquerdo", "Atrás da base", "Lado direito"]
const DEFAULT_POINTS = [0, 2, 1]             # onde os módulos nascem, antes de a batalha pôr cada um no ponto escolhido
# ordem dos pontos pra completar espaço vazio. O primeiro é um LADO da frente, não o meio: com o
# único módulo na frente do meio, tudo que o adversário tem pra bater fica na rota do meio e a
# partida vira "jogar carta no meio" (medido: 98% das jogadas dos bots no meio)
const FILL_POINTS = [0, 2, 1, 3, 5, 4]


static func module_slots(level: int) -> int:
	var forced = int(_t("slots", 0.0))   # laboratório e testes: REGRAS_TUNE="slots=3"
	if forced > 0:
		return clampi(forced, 1, MODULE_SLOTS_MAX)
	var n = 0
	for lv in MODULE_SLOT_LEVELS:
		if level >= lv:
			n += 1
	return clampi(n, 1, MODULE_SLOTS_MAX)


## nível em que abre o próximo espaço (0 = já abriu todos)
static func next_slot_level(level: int) -> int:
	for lv in MODULE_SLOT_LEVELS:
		if lv > level:
			return lv
	return 0


static func modules() -> bool:
	return on("modulos")


## a Casa Grande começa DORMINDO: só atira depois de levar dano ou de perder um módulo
## (a torre do rei do Clash). Laboratório: REGRAS_TUNE="sono=0" desliga.
static func main_sleeps() -> bool:
	return modules() and _t("sono", 1.0) > 0.5


## alcance do tiro da Casa Grande
const MAIN_RANGE = 215.0


static func main_range() -> float:
	return _t("mainrange", MAIN_RANGE)


static func routes() -> bool:
	return on("rotas") and three_towers()


## rota de quem é solto na posição x: -1 esquerda, 0 meio, 1 direita
static func lane_of(x: float) -> int:
	var dx = x - ArenaBuilder.CENTER.x
	return 0 if absf(dx) <= LANE_HALF else (-1 if dx < 0.0 else 1)


## a torre do ADVERSÁRIO no fim da rota (null se ela já caiu): meio = portão,
## lado = a torre de trás daquele lado
static func route_tower(tree: SceneTree, attacker_team, lane: int) -> Node:
	var group = "enemy_base" if attacker_team == GameManager.Team.PLAYER else "player_base"
	for t in tree.get_nodes_in_group(group):
		if !is_instance_valid(t) or t.is_queued_for_deletion() or t.hp <= 0:
			continue
		if lane == 0:
			if t.is_gate:
				return t
		elif !t.is_gate and signf(t.global_position.x - ArenaBuilder.CENTER.x) == float(lane):
			return t
	return null


static func gate_hp_share() -> float:
	return _t("gatehp", GATE_HP_SHARE)


static func gate_damage_share() -> float:
	return _t("gatedmg", GATE_DAMAGE_SHARE)


static func gate_range_share() -> float:
	return _t("gaterange", GATE_RANGE_SHARE)

# ---------------------------------------------------------------- torres
# Calibrado pelo Clash (torre nível 11: 3052 de vida, 109 de dano a cada
# 0,8 s, alcance 7,5 quadrados; Cavaleiro: 1766 de vida, 168 de dano/s):
# lá a torre mata 1 elixir de Cavaleiro em ~4 s e aguenta ~55 "elixir-segundos"
# de pancada. Aqui dava 10 s e 21. Com os números abaixo: ~4 s e ~47.
const TOWER_HP_FRACTION_OLD = 0.65
# 20/11: 1.62 -> 1.3. O João achou vida demais nas torres. Com módulos, medido entre bots:
# com 1.62 a base caía em 14 de 36 partidas; ver DIAGNOSTICO pra conta com 1.3.
const TOWER_HP_FRACTION = 1.2       # era 1.3 (e antes 1.62): no caso de quem começa (baralho inicial, nível 1) a torre não caía
                                   # batem bem mais; com 1.45 quase metade das partidas entre bots acabava em nocaute
const TOWER_DAMAGE_MULT = 1.8        # Celeiro: 32 -> 58 por tiro (era 2.3 = 74: tropa de quem começa morria antes de encostar)
const TOWER_RANGE_BONUS = 90.0       # Celeiro: 125 -> 215 (passa de todo atirador comum)
const TOWER_RANGE_MAX = 280.0
# torre que não é "de tiro" (moinho, armazém, forte, cura, aura) ganha o
# tiro básico: mais fraco que o do Celeiro, mas defende
const TOWER_BASIC_DAMAGE = 54.0
const TOWER_BASIC_INTERVAL = 1.0
const TOWER_BASIC_RANGE = 215.0


static var _env_off: Array = []
static var _env_read := false
static var forced: Dictionary = {}   # testes: Regras.forced["torres"] = false


static func on(key: String) -> bool:
	if forced.has(key):
		return bool(forced[key])
	if !_env_read:
		_env_read = true
		_env_off = Array(OS.get_environment("REGRAS_OFF").split(",", false))  # só pra laboratório/testes
	if _env_off.has(key):
		return false
	return bool(Config.data.get("regra_" + key, !DEFAULT_OFF.has(key)))


static func set_on(key: String, value: bool):
	Config.data["regra_" + key] = value


static func tower_hp_fraction() -> float:
	return _t("hp", TOWER_HP_FRACTION) if on("torres") else TOWER_HP_FRACTION_OLD


static func tower_shoots(b: BaseData) -> bool:
	if b == null:
		return false
	if modules():
		return b.base_type == BaseData.BaseType.CANNON   # módulo que não é de tiro vale pela função dele
	return b.base_type == BaseData.BaseType.CANNON or on("torres")


## dano de UM tiro, sem o multiplicador de nível
static func tower_damage(b: BaseData) -> float:
	if b.base_type == BaseData.BaseType.CANNON:
		return b.attack_damage * (_t("dmg", TOWER_DAMAGE_MULT) if on("torres") else 1.0)
	return _t("basic", TOWER_BASIC_DAMAGE)


static func tower_interval(b: BaseData) -> float:
	if b.base_type == BaseData.BaseType.CANNON:
		return maxf(b.attack_speed, 0.2)
	return TOWER_BASIC_INTERVAL


static func tower_range(b: BaseData) -> float:
	if b.base_type == BaseData.BaseType.CANNON:
		if !on("torres"):
			return b.attack_range
		return minf(b.attack_range + _t("range", TOWER_RANGE_BONUS), TOWER_RANGE_MAX)
	return 125.0 + _t("range", TOWER_RANGE_BONUS)


# laboratório: REGRAS_TUNE="hp=1.3,dmg=2.0,range=80,basic=50" troca os números sem recompilar
static var _tune: Dictionary = {}
static var _tune_read := false


## testes: força (ou solta, com `on = false`) um ajuste sem depender do ambiente
static func set_tune(key: String, value: float, on: bool = true):
	_t(key, 0.0)   # lê o ambiente antes, pra ele não passar por cima depois
	if on:
		_tune[key] = value
	else:
		_tune.erase(key)


static func _t(key: String, fallback: float) -> float:
	if !_tune_read:
		_tune_read = true
		for pair in OS.get_environment("REGRAS_TUNE").split(",", false):
			var kv = pair.split("=")
			if kv.size() == 2:
				_tune[kv[0]] = float(kv[1])
	return float(_tune.get(key, fallback))


## vida de UMA torre em campo (são 2 por lado), já com o nível
static func tower_hp(b: BaseData, level_mult: float = 1.0) -> int:
	return tidy(round(b.base_hp * level_mult) * tower_hp_fraction())


## Os textos das torres foram escritos quando só a "de tiro" atirava.
## Com toda torre atirando, "Não ataca" e "Tiro fraco" deixam de ser verdade.
static func tower_con_text(text: String) -> String:
	if !on("torres"):
		return text
	var t = text.strip_edges().to_lower()
	if t in ["não ataca", "não causa dano direto", "não causa dano"]:
		return "Não atira" if modules() else "Só o tiro básico"
	if t == "tiro fraco":
		return "Nenhum bônus extra"
	return text


static func tower_pro_text(text: String) -> String:
	if !on("torres"):
		return text
	var t = text.strip_edges().to_lower()
	if t in ["atira sozinho", "atira sozinha"]:
		return "Módulo de tiro: defende sozinho" if modules() else "Tiro mais forte que o das outras"
	return text


# ---------------------------------------------------------------- relógio
const BATTLE_SECONDS = 240.0   # partida de 4 minutos
const DOUBLE_SECONDS = 60.0    # recurso em dobro no último minuto


static func battle_duration() -> float:
	return _t("dur", BATTLE_SECONDS)


static func double_time() -> float:
	return _t("x2", DOUBLE_SECONDS)


# ---------------------------------------------------------------- visual
const SPRITE_BOOST = 1.3       # tropa "normal" (escala 1.0) fica 30% maior na tela (era 1.5: tudo grande demais)
const SPRITE_CURVE = 1.0       # proporcional à escala: pintinho é miúdo, vaca é grande, robô é enorme
                               # (era 0.85 -- galinha de 150 de vida ficava quase do tamanho do peão)
const BODY_BOOST = 1.11        # o corpo (colisão) cresce menos que o desenho (era 1.28; desceu junto com o desenho)
const BODY_CURVE = 0.8


## TAMANHO = FORÇA x PORTE.
## Força, igual ao Clash: quanto mais forte, maior. A vida pesa mais; o dano de um
## golpe pesa um pouco (pra matador não virar formiga). O Peão do Forcado (640 de
## vida) é o 1,0.
## Porte é o tamanho do bicho de verdade (Catalogo.porte): abelha é miúda, galinha
## é menor que gente, vaca é maior. Sem isso, abelha e moleque de 90 de vida saíam
## do mesmo tamanho.
## Vale pra toda tropa do catálogo, das arenas e da safra; construção fica com o
## tamanho escrito na carta.
const SIZE_REF = 700.0
const SIZE_POWER = 0.28
const SIZE_MIN = 0.38
const SIZE_MAX = 2.0


static func strength_scale(hp: float, damage: float, porte: float = 1.0) -> float:
	var s = maxf(hp + 0.8 * maxf(damage, 0.0), 20.0)
	return snappedf(clampf(pow(s / SIZE_REF, SIZE_POWER) * porte, SIZE_MIN, SIZE_MAX), 0.01)
const COLOR_ALLY = Color("#4aa8ff")
const COLOR_ENEMY = Color("#ff5648")


## multiplicador do DESENHO em cima do tamanho antigo (que já usava unit_scale)
static func sprite_factor(unit_scale: float) -> float:
	if !on("visual") or unit_scale <= 0.0:
		return 1.0
	return SPRITE_BOOST * pow(unit_scale, SPRITE_CURVE) / unit_scale


## multiplicador do CORPO (colisão) em cima do tamanho antigo
static func body_factor(unit_scale: float) -> float:
	if !on("visual") or unit_scale <= 0.0:
		return 1.0
	return BODY_BOOST * pow(unit_scale, BODY_CURVE) / unit_scale


## fração do corpo que cada tropa guarda de espaço em volta (0.85 = antigo)
const SPACING = 1.35


static func spacing() -> float:
	return _t("sep", SPACING) if on("visual") else 0.85


static func team_color(is_player: bool) -> Color:
	return COLOR_ALLY if is_player else COLOR_ENEMY


const OUTLINE_SHADER = """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform float flash = 0.0;
void fragment() {
	vec4 c = COLOR;
	COLOR.rgb = mix(c.rgb, vec3(1.0), flash);
	if (c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (a > 0.1) {
			COLOR = vec4(outline_color.rgb, outline_color.a * step(0.01, a));
		}
	}
}
"""
static var _outline_mats: Dictionary = {}


## contorno fininho na cor do time em volta do desenho da tropa
static var _outline_shader: Shader = null


static func outline_material(is_player: bool, flashing: bool = false) -> ShaderMaterial:
	var key = [is_player, flashing]
	if _outline_mats.has(key):
		return _outline_mats[key]
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var m = ShaderMaterial.new()
	m.shader = _outline_shader
	var c = team_color(is_player)
	m.set_shader_parameter("outline_color", Color(c.r, c.g, c.b, 0.95))
	m.set_shader_parameter("flash", 0.78 if flashing else 0.0)
	_outline_mats[key] = m
	return m


# ---------------------------------------------------------------- peso
const DEPLOY_TIME = 1.0        # igual ao Clash: toda tropa leva 1 s pra entrar em campo


## tempo de entrada em campo (a tropa aparece, mas ainda não anda nem bate)
static func deploy_time(stats: UnitData) -> float:
	var base = stats.initial_stun_duration
	if on("peso") and base >= 0.4:
		return maxf(base, DEPLOY_TIME)
	return base


## preparo do golpe: a tropa "arma" o ataque antes de acertar. O intervalo
## entre golpes não muda -- só o PRIMEIRO golpe deixa de ser instantâneo.
static func windup_time(stats: UnitData) -> float:
	if !on("peso") or stats.continuous_attack or stats.attack_speed <= 0.0:
		return 0.0
	return clampf(stats.attack_speed * 0.35, 0.2, 0.7)

# ---------------------------------------------------------------- nível da carta
## Subir de nível melhora TUDO que é número de força da tropa, não só vida e
## dano. Antes, carta que vive de habilidade (cura, explosão, veneno, escudo)
## evoluía e continuava igualzinha no que ela faz de melhor.
const LEVEL_FIELDS = ["hp", "damage", "death_explosion_damage", "entrance_shockwave_damage", "arrival_damage",
	"heal_aura_amount", "heal_on_kill_amount", "regen_amount", "shield_amount", "temp_shield_amount",
	"continuous_damage_per_second"]
const EFFECT_TIME_SHARE = 0.6   # duração de efeito cresce 60% do que vida/dano crescem (15% -> 9% por nível)


## aplica o multiplicador do nível numa CÓPIA dos números (quem chama duplica antes)
## número "redondo" de vida: de 10 em 10 acima de 1000, de 5 em 5 acima de 200
## (3888 vira 3890, 1264 vira 1260). Só arruma a leitura, não muda o equilíbrio.
static func tidy(v: float) -> int:
	if v >= 1000.0:
		return int(round(v / 10.0)) * 10
	if v >= 200.0:
		return int(round(v / 5.0)) * 5
	return int(round(v))


static func apply_level(stats: UnitData, mult: float) -> void:
	if stats == null or mult == 1.0:
		return
	for f in LEVEL_FIELDS:
		var v = stats.get(f)
		if v == null or float(v) <= 0.0:
			continue
		if v is int:
			stats.set(f, tidy(v * mult) if f == "hp" else int(round(v * mult)))
		else:
			stats.set(f, snappedf(float(v) * mult, 0.1))
	if stats.on_hit_effect == UnitData.OnHitEffect.POISON:
		stats.on_hit_effect_strength = round(stats.on_hit_effect_strength * mult)


## feitiço/efeito sem número de dano pra crescer (fúria, congelar, lentidão):
## o que cresce com o nível é o TEMPO que o efeito dura
static func effect_time_mult(power: float) -> float:
	return 1.0 + maxf(power - 1.0, 0.0) * EFFECT_TIME_SHARE
