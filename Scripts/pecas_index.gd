extends RefCounted
class_name PecasIndex
## GERADO por ci/tools/arte/exportar.py -- não editar na mão

const COLS = 16
const CELL = 48
const ORDEM = ["costas", "pernas", "corpo", "bracos", "cabeca", "chapeu", "arma"]
const PECAS = {
	"pernas": {"casco": 0, "bota": 1, "ave": 2, "patinha": 3, "fantasma": 4, "rodas": 5, "inseto": 6},
	"corpo": {"redondo": 7, "macacao": 8, "penas": 9, "la": 10, "listrado": 11, "armadura": 12, "poncho": 13, "saco": 14},
	"bracos": {"patas": 15, "humanos": 16, "asas": 17},
	"cabeca": {"vaca": 18, "boi": 19, "porco": 20, "galinha": 21, "pato": 22, "ovelha": 23, "bode": 24, "cavalo": 25, "sapo": 26, "capivara": 27, "gato": 28, "coruja": 29, "abelha": 30, "humano": 31, "velho": 32, "espantalho": 33, "abobora": 34, "milho": 35, "et": 36, "balde": 37, "cebola": 38},
	"chapeu": {"palha": 39, "cowboy": 40, "balde": 41, "bandana": 42, "coroa": 43, "cozinheiro": 44, "flor": 45, "penacho": 46},
	"arma": {"forcado": 47, "machado": 48, "marreta": 49, "foice": 50, "enxada": 51, "frigideira": 52, "porrete": 53, "estilingue": 54, "viola": 55, "motosserra": 56, "lampiao": 57, "escudo": 58},
	"costas": {"rabo_galo": 59, "capa": 60, "foguete": 61, "asas_inseto": 62},
	"objeto": {"galinheiro": 63, "silo": 64, "colmeia": 65, "poco": 66, "barril": 67, "canhao_milho": 68, "fornalha": 69, "tenda": 70, "ninho": 71, "ovni": 72, "trator": 73, "feno": 74},
	"torre": {"celeiro": 75, "moinho": 76, "caixa_dagua": 77, "castelo_feno": 78},
	"icone": {"raio": 79, "tornado": 80, "coracao": 81, "pimenta": 82, "floco": 83, "cogumelo": 84, "escudo": 85, "melancia": 86, "ovo": 87, "vaca_caindo": 88, "nota": 89, "lama": 90, "laco": 91, "espelho": 92, "moeda": 93},
	"proj": {"ovo": 94, "milho": 95, "pedra": 96, "flecha": 97, "fogo": 98, "gota": 99, "nota": 100, "raio": 101, "espinho": 102, "estrume": 103},
}
