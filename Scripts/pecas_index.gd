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
	"torre": {"celeiro": 100, "moinho": 101, "caixa_dagua": 102, "castelo_feno": 103, "forte": 104, "armazem": 105, "capela": 106, "colmeia": 107, "antena": 108, "cocho": 109},
	"icone": {"raio": 110, "tornado": 111, "coracao": 112, "pimenta": 113, "floco": 114, "cogumelo": 115, "escudo": 116, "melancia": 117, "ovo": 118, "vaca_caindo": 119, "nota": 120, "lama": 121, "laco": 122, "espelho": 123, "moeda": 124, "ferradura": 125, "garrafa": 126},
	"proj": {"ovo": 127, "milho": 128, "pedra": 129, "flecha": 130, "fogo": 131, "gota": 132, "nota": 133, "raio": 134, "espinho": 135, "estrume": 136},
}
