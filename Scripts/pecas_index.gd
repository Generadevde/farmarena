extends RefCounted
class_name PecasIndex
## GERADO por ci/tools/arte/exportar.py -- não editar na mão

const COLS = 16
const CELL = 48
const ORDEM = ["costas", "pernas", "corpo", "bracos", "cabeca", "chapeu", "arma"]
const PECAS = {
	"pernas": {"casco": 0, "bota": 1, "ave": 2, "patinha": 3, "fantasma": 4, "rodas": 5, "inseto": 6, "saci": 7},
	"corpo": {"redondo": 8, "macacao": 9, "penas": 10, "la": 11, "listrado": 12, "armadura": 13, "poncho": 14, "saco": 15, "colete": 16, "terno": 17, "saci": 18},
	"bracos": {"patas": 19, "humanos": 20, "asas": 21},
	"cabeca": {"vaca": 22, "boi": 23, "porco": 24, "galinha": 25, "pato": 26, "ovelha": 27, "bode": 28, "cavalo": 29, "sapo": 30, "capivara": 31, "gato": 32, "coruja": 33, "abelha": 34, "humano": 35, "velho": 36, "espantalho": 37, "abobora": 38, "milho": 39, "et": 40, "balde": 41, "cebola": 42, "cachorro": 43, "burro": 44, "tatu": 45, "jacare": 46, "urubu": 47, "tomate": 48, "cacto": 49, "caveira": 50, "saci": 51, "chama": 52, "onca": 53, "tubarao": 54, "medusa": 55, "peixe": 56, "polvo": 57},
	"chapeu": {"palha": 58, "cowboy": 59, "balde": 60, "bandana": 61, "coroa": 62, "cozinheiro": 63, "flor": 64, "penacho": 65, "bone": 66, "cartola": 67, "chifres": 68, "melancia": 69, "gorro": 70},
	"arma": {"forcado": 71, "machado": 72, "marreta": 73, "foice": 74, "enxada": 75, "frigideira": 76, "porrete": 77, "estilingue": 78, "viola": 79, "motosserra": 80, "lampiao": 81, "escudo": 82, "vara": 83, "berrante": 84, "garrafa": 85, "rastelo": 86, "espingarda": 87, "regador": 88},
	"costas": {"rabo_galo": 89, "capa": 90, "foguete": 91, "asas_inseto": 92, "cesto": 93, "morcego": 94},
	"quatro": {"casco": 95, "malhado": 96, "pata": 97, "rasteiro": 98, "casca": 99, "sapo": 100, "cavalo": 101, "bezerro": 102, "vaca": 103, "bode": 104, "jegue": 105, "cachorro": 106, "capivara": 107, "porco": 108, "gato": 109, "formiga": 110, "montado": 111, "mapinguari": 112, "cobra": 113, "onca": 114, "caranguejo": 115, "polvo": 116, "aguaviva": 117, "tripe": 118, "dragao": 119, "cerbero": 120},
	"objeto": {"galinheiro": 121, "silo": 122, "colmeia": 123, "poco": 124, "barril": 125, "canhao_milho": 126, "fornalha": 127, "tenda": 128, "ninho": 129, "ovni": 130, "trator": 131, "feno": 132, "carroca": 133, "casinha": 134, "cerca_eletrica": 135},
	"torre": {"celeiro": 136, "moinho": 137, "caixa_dagua": 138, "castelo_feno": 139, "forte": 140, "armazem": 141, "capela": 142, "colmeia": 143, "antena": 144, "cocho": 145},
	"icone": {"raio": 146, "tornado": 147, "coracao": 148, "pimenta": 149, "floco": 150, "cogumelo": 151, "escudo": 152, "melancia": 153, "ovo": 154, "vaca_caindo": 155, "nota": 156, "lama": 157, "laco": 158, "espelho": 159, "moeda": 160, "ferradura": 161, "garrafa": 162},
	"proj": {"ovo": 163, "milho": 164, "pedra": 165, "flecha": 166, "fogo": 167, "gota": 168, "nota": 169, "raio": 170, "espinho": 171, "estrume": 172},
}
const QUATRO_CABECA = {"casco": Vector2i(10, 6), "malhado": Vector2i(10, 6), "pata": Vector2i(10, 8), "rasteiro": Vector2i(11, 12), "casca": Vector2i(11, 11), "sapo": Vector2i(0, 9), "cavalo": Vector2i(12, 0), "bezerro": Vector2i(9, 10), "vaca": Vector2i(11, 5), "bode": Vector2i(10, 7), "jegue": Vector2i(10, 5), "cachorro": Vector2i(11, 8), "capivara": Vector2i(10, 8), "porco": Vector2i(10, 7), "gato": Vector2i(11, 9), "montado": Vector2i(-7, -4), "onca": Vector2i(11, 8)}
const QUATRO_COSTAS = {"casco": Vector2i(8, -6), "malhado": Vector2i(8, -6), "pata": Vector2i(8, -4), "jegue": Vector2i(8, -7), "cavalo": Vector2i(6, -10), "vaca": Vector2i(7, -8)}
