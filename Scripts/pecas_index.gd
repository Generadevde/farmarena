extends RefCounted
class_name PecasIndex
## GERADO por ci/tools/arte/exportar.py -- não editar na mão

const COLS = 16
const CELL = 48
const ORDEM = ["costas", "pernas", "corpo", "bracos", "cabeca", "chapeu", "arma"]
const PECAS = {
	"pernas": {"casco": 0, "bota": 1, "ave": 2, "patinha": 3, "fantasma": 4, "rodas": 5, "inseto": 6},
	"corpo": {"redondo": 7, "macacao": 8, "penas": 9, "la": 10, "listrado": 11, "armadura": 12, "poncho": 13, "saco": 14, "colete": 15, "terno": 16},
	"bracos": {"patas": 17, "humanos": 18, "asas": 19},
	"cabeca": {"vaca": 20, "boi": 21, "porco": 22, "galinha": 23, "pato": 24, "ovelha": 25, "bode": 26, "cavalo": 27, "sapo": 28, "capivara": 29, "gato": 30, "coruja": 31, "abelha": 32, "humano": 33, "velho": 34, "espantalho": 35, "abobora": 36, "milho": 37, "et": 38, "balde": 39, "cebola": 40, "cachorro": 41, "burro": 42, "tatu": 43, "jacare": 44, "urubu": 45, "tomate": 46, "cacto": 47, "caveira": 48},
	"chapeu": {"palha": 49, "cowboy": 50, "balde": 51, "bandana": 52, "coroa": 53, "cozinheiro": 54, "flor": 55, "penacho": 56, "bone": 57, "cartola": 58, "chifres": 59, "melancia": 60},
	"arma": {"forcado": 61, "machado": 62, "marreta": 63, "foice": 64, "enxada": 65, "frigideira": 66, "porrete": 67, "estilingue": 68, "viola": 69, "motosserra": 70, "lampiao": 71, "escudo": 72, "vara": 73, "berrante": 74, "garrafa": 75, "rastelo": 76, "espingarda": 77, "regador": 78},
	"costas": {"rabo_galo": 79, "capa": 80, "foguete": 81, "asas_inseto": 82, "cesto": 83, "morcego": 84},
	"quatro": {"casco": 85, "malhado": 86, "pata": 87, "rasteiro": 88, "casca": 89, "sapo": 90},
	"objeto": {"galinheiro": 91, "silo": 92, "colmeia": 93, "poco": 94, "barril": 95, "canhao_milho": 96, "fornalha": 97, "tenda": 98, "ninho": 99, "ovni": 100, "trator": 101, "feno": 102, "carroca": 103, "casinha": 104, "cerca_eletrica": 105},
	"torre": {"celeiro": 106, "moinho": 107, "caixa_dagua": 108, "castelo_feno": 109, "forte": 110, "armazem": 111, "capela": 112, "colmeia": 113, "antena": 114, "cocho": 115},
	"icone": {"raio": 116, "tornado": 117, "coracao": 118, "pimenta": 119, "floco": 120, "cogumelo": 121, "escudo": 122, "melancia": 123, "ovo": 124, "vaca_caindo": 125, "nota": 126, "lama": 127, "laco": 128, "espelho": 129, "moeda": 130, "ferradura": 131, "garrafa": 132},
	"proj": {"ovo": 133, "milho": 134, "pedra": 135, "flecha": 136, "fogo": 137, "gota": 138, "nota": 139, "raio": 140, "espinho": 141, "estrume": 142},
}
const QUATRO_CABECA = {"casco": Vector2i(10, 6), "malhado": Vector2i(10, 6), "pata": Vector2i(10, 8), "rasteiro": Vector2i(11, 12), "casca": Vector2i(11, 11), "sapo": Vector2i(0, 9)}
const QUATRO_COSTAS = {"casco": Vector2i(8, -6), "malhado": Vector2i(8, -6), "pata": Vector2i(8, -4)}
