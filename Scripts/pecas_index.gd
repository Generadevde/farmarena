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
	"cabeca": {"vaca": 22, "boi": 23, "porco": 24, "galinha": 25, "pato": 26, "ovelha": 27, "bode": 28, "cavalo": 29, "sapo": 30, "capivara": 31, "gato": 32, "coruja": 33, "abelha": 34, "humano": 35, "velho": 36, "espantalho": 37, "abobora": 38, "milho": 39, "et": 40, "balde": 41, "cebola": 42, "cachorro": 43, "burro": 44, "tatu": 45, "jacare": 46, "urubu": 47, "tomate": 48, "cacto": 49, "caveira": 50, "saci": 51, "chama": 52, "onca": 53, "tubarao": 54, "medusa": 55, "peixe": 56, "polvo": 57, "siri": 58, "baleia": 59, "cavalo_marinho": 60, "tartaruga": 61, "macaco": 62, "arara": 63, "tamandua": 64, "preguica": 65, "cobra": 66, "ciclope": 67, "elmo": 68, "lobisomem": 69, "curupira": 70, "marciano": 71},
	"chapeu": {"palha": 72, "cowboy": 73, "balde": 74, "bandana": 75, "coroa": 76, "cozinheiro": 77, "flor": 78, "penacho": 79, "bone": 80, "cartola": 81, "chifres": 82, "melancia": 83, "gorro": 84},
	"arma": {"forcado": 85, "machado": 86, "marreta": 87, "foice": 88, "enxada": 89, "frigideira": 90, "porrete": 91, "estilingue": 92, "viola": 93, "motosserra": 94, "lampiao": 95, "escudo": 96, "vara": 97, "berrante": 98, "garrafa": 99, "rastelo": 100, "espingarda": 101, "regador": 102},
	"costas": {"rabo_galo": 103, "capa": 104, "foguete": 105, "asas_inseto": 106, "cesto": 107, "morcego": 108},
	"quatro": {"casco": 109, "malhado": 110, "pata": 111, "rasteiro": 112, "casca": 113, "sapo": 114, "cavalo": 115, "bezerro": 116, "vaca": 117, "bode": 118, "jegue": 119, "cachorro": 120, "capivara": 121, "porco": 122, "gato": 123, "formiga": 124, "montado": 125, "mapinguari": 126, "cobra": 127, "onca": 128, "caranguejo": 129, "polvo": 130, "aguaviva": 131, "tripe": 132, "dragao": 133, "cerbero": 134},
	"objeto": {"galinheiro": 135, "silo": 136, "colmeia": 137, "poco": 138, "barril": 139, "canhao_milho": 140, "fornalha": 141, "tenda": 142, "ninho": 143, "ovni": 144, "trator": 145, "feno": 146, "carroca": 147, "casinha": 148, "cerca_eletrica": 149},
	"torre": {"celeiro": 150, "moinho": 151, "caixa_dagua": 152, "castelo_feno": 153, "forte": 154, "armazem": 155, "capela": 156, "colmeia": 157, "antena": 158, "cocho": 159},
	"icone": {"raio": 160, "tornado": 161, "coracao": 162, "pimenta": 163, "floco": 164, "cogumelo": 165, "escudo": 166, "melancia": 167, "ovo": 168, "vaca_caindo": 169, "nota": 170, "lama": 171, "laco": 172, "espelho": 173, "moeda": 174, "ferradura": 175, "garrafa": 176},
	"proj": {"ovo": 177, "milho": 178, "pedra": 179, "flecha": 180, "fogo": 181, "gota": 182, "nota": 183, "raio": 184, "espinho": 185, "estrume": 186},
}
const QUATRO_CABECA = {"casco": Vector2i(10, 6), "malhado": Vector2i(10, 6), "pata": Vector2i(10, 8), "rasteiro": Vector2i(11, 12), "casca": Vector2i(11, 11), "sapo": Vector2i(0, 9), "cavalo": Vector2i(12, 0), "bezerro": Vector2i(9, 10), "vaca": Vector2i(11, 5), "bode": Vector2i(10, 7), "jegue": Vector2i(10, 5), "cachorro": Vector2i(11, 8), "capivara": Vector2i(10, 8), "porco": Vector2i(10, 7), "gato": Vector2i(11, 9), "montado": Vector2i(-7, -4), "onca": Vector2i(11, 8)}
const QUATRO_COSTAS = {"casco": Vector2i(8, -6), "malhado": Vector2i(8, -6), "pata": Vector2i(8, -4), "jegue": Vector2i(8, -7), "cavalo": Vector2i(6, -10), "vaca": Vector2i(7, -8)}
