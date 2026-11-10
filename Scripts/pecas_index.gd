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
	"objeto": {"galinheiro": 85, "silo": 86, "colmeia": 87, "poco": 88, "barril": 89, "canhao_milho": 90, "fornalha": 91, "tenda": 92, "ninho": 93, "ovni": 94, "trator": 95, "feno": 96, "carroca": 97, "casinha": 98, "cerca_eletrica": 99},
	"torre": {"celeiro": 100, "moinho": 101, "caixa_dagua": 102, "castelo_feno": 103},
	"icone": {"raio": 104, "tornado": 105, "coracao": 106, "pimenta": 107, "floco": 108, "cogumelo": 109, "escudo": 110, "melancia": 111, "ovo": 112, "vaca_caindo": 113, "nota": 114, "lama": 115, "laco": 116, "espelho": 117, "moeda": 118, "ferradura": 119, "garrafa": 120},
	"proj": {"ovo": 121, "milho": 122, "pedra": 123, "flecha": 124, "fogo": 125, "gota": 126, "nota": 127, "raio": 128, "espinho": 129, "estrume": 130},
}
