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

const KEYS = ["torres", "visual", "peso"]

# ---------------------------------------------------------------- torres
# Calibrado pelo Clash (torre nível 11: 3052 de vida, 109 de dano a cada
# 0,8 s, alcance 7,5 quadrados; Cavaleiro: 1766 de vida, 168 de dano/s):
# lá a torre mata 1 elixir de Cavaleiro em ~4 s e aguenta ~55 "elixir-segundos"
# de pancada. Aqui dava 10 s e 21. Com os números abaixo: ~4 s e ~47.
const TOWER_HP_FRACTION_OLD = 0.65
const TOWER_HP_FRACTION = 1.62     # (era 1.45) as tropas ficaram mais "afiadas" em 19/11 -- bando e matador
                                   # batem bem mais; com 1.45 quase metade das partidas entre bots acabava em nocaute
const TOWER_DAMAGE_MULT = 2.3        # Celeiro: 32 -> 74 por tiro
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
	return bool(Config.data.get("regra_" + key, true))


static func set_on(key: String, value: bool):
	Config.data["regra_" + key] = value


static func tower_hp_fraction() -> float:
	return _t("hp", TOWER_HP_FRACTION) if on("torres") else TOWER_HP_FRACTION_OLD


static func tower_shoots(b: BaseData) -> bool:
	if b == null:
		return false
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
	return int(round(round(b.base_hp * level_mult) * tower_hp_fraction()))


## Os textos das torres foram escritos quando só a "de tiro" atirava.
## Com toda torre atirando, "Não ataca" e "Tiro fraco" deixam de ser verdade.
static func tower_con_text(text: String) -> String:
	if !on("torres"):
		return text
	var t = text.strip_edges().to_lower()
	if t in ["não ataca", "não causa dano direto", "não causa dano"]:
		return "Só o tiro básico"
	if t == "tiro fraco":
		return "Nenhum bônus extra"
	return text


static func tower_pro_text(text: String) -> String:
	if !on("torres"):
		return text
	var t = text.strip_edges().to_lower()
	if t in ["atira sozinho", "atira sozinha"]:
		return "Tiro mais forte que o das outras"
	return text


# ---------------------------------------------------------------- relógio
const BATTLE_SECONDS = 240.0   # partida de 4 minutos
const DOUBLE_SECONDS = 60.0    # recurso em dobro no último minuto


static func battle_duration() -> float:
	return _t("dur", BATTLE_SECONDS)


static func double_time() -> float:
	return _t("x2", DOUBLE_SECONDS)


# ---------------------------------------------------------------- visual
const SPRITE_BOOST = 1.5       # tropa "normal" (escala 1.0) fica 50% maior na tela
const SPRITE_CURVE = 0.85      # quase proporcional: pintinho é miúdo, vaca é grande, robô é enorme
                               # (era 0.6 -- espremia todo mundo pro mesmo tamanho)
const BODY_BOOST = 1.28        # o corpo (colisão) cresce menos que o desenho
const BODY_CURVE = 0.8
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
static func apply_level(stats: UnitData, mult: float) -> void:
	if stats == null or mult == 1.0:
		return
	for f in LEVEL_FIELDS:
		var v = stats.get(f)
		if v == null or float(v) <= 0.0:
			continue
		if v is int:
			stats.set(f, int(round(v * mult)))
		else:
			stats.set(f, snappedf(float(v) * mult, 0.1))
	if stats.on_hit_effect == UnitData.OnHitEffect.POISON:
		stats.on_hit_effect_strength = round(stats.on_hit_effect_strength * mult)


## feitiço/efeito sem número de dano pra crescer (fúria, congelar, lentidão):
## o que cresce com o nível é o TEMPO que o efeito dura
static func effect_time_mult(power: float) -> float:
	return 1.0 + maxf(power - 1.0, 0.0) * EFFECT_TIME_SHARE
