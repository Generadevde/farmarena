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
	"chapeu": {"palha": 72, "cowboy": 73, "balde": 74, "bandana": 75, "coroa": 76, "cozinheiro": 77, "flor": 78, "penacho": 79, "bone": 80, "cartola": 81, "chifres": 82, "melancia": 83, "gorro": 84, "capacete": 85, "boina": 86, "quepe": 87},
	"arma": {"forcado": 88, "machado": 89, "marreta": 90, "foice": 91, "enxada": 92, "frigideira": 93, "porrete": 94, "estilingue": 95, "viola": 96, "motosserra": 97, "lampiao": 98, "escudo": 99, "vara": 100, "berrante": 101, "garrafa": 102, "rastelo": 103, "espingarda": 104, "regador": 105, "fuzil": 106, "bazuca": 107, "lanca_chamas": 108},
	"costas": {"rabo_galo": 109, "capa": 110, "foguete": 111, "asas_inseto": 112, "cesto": 113, "morcego": 114},
	"quatro": {"casco": 115, "malhado": 116, "pata": 117, "rasteiro": 118, "casca": 119, "sapo": 120, "cavalo": 121, "bezerro": 122, "vaca": 123, "bode": 124, "jegue": 125, "cachorro": 126, "capivara": 127, "porco": 128, "gato": 129, "formiga": 130, "montado": 131, "mapinguari": 132, "cobra": 133, "onca": 134, "caranguejo": 135, "polvo": 136, "aguaviva": 137, "tripe": 138, "dragao": 139, "cerbero": 140},
	"objeto": {"galinheiro": 141, "silo": 142, "colmeia": 143, "poco": 144, "barril": 145, "canhao_milho": 146, "fornalha": 147, "tenda": 148, "ninho": 149, "ovni": 150, "trator": 151, "feno": 152, "carroca": 153, "casinha": 154, "cerca_eletrica": 155, "tanque": 156, "tanque_duplo": 157, "jipe": 158, "lanca_missil": 159, "artilharia": 160, "helicoptero": 161, "dirigivel": 162, "andador": 163, "submarino": 164, "caminhao": 165},
	"torre": {"celeiro": 166, "moinho": 167, "caixa_dagua": 168, "castelo_feno": 169, "forte": 170, "armazem": 171, "capela": 172, "colmeia": 173, "antena": 174, "cocho": 175, "bobina": 176, "prisma": 177, "bunker": 178, "radar": 179, "usina": 180, "refinaria": 181, "quartel": 182, "canhao_grande": 183},
	"icone": {"raio": 184, "tornado": 185, "coracao": 186, "pimenta": 187, "floco": 188, "cogumelo": 189, "escudo": 190, "melancia": 191, "ovo": 192, "vaca_caindo": 193, "nota": 194, "lama": 195, "laco": 196, "espelho": 197, "moeda": 198, "ferradura": 199, "garrafa": 200, "missil": 201, "bomba": 202, "paraquedas": 203, "mira": 204, "engrenagem": 205, "estrela": 206, "onda": 207, "relogio": 208},
	"proj": {"ovo": 209, "milho": 210, "pedra": 211, "flecha": 212, "fogo": 213, "gota": 214, "nota": 215, "raio": 216, "espinho": 217, "estrume": 218, "missil": 219, "bala": 220, "laser": 221},
}
const QUATRO_CABECA = {"casco": Vector2i(10, 6), "malhado": Vector2i(10, 6), "pata": Vector2i(10, 8), "rasteiro": Vector2i(11, 12), "casca": Vector2i(11, 11), "sapo": Vector2i(0, 9), "cavalo": Vector2i(12, 0), "bezerro": Vector2i(9, 10), "vaca": Vector2i(11, 5), "bode": Vector2i(10, 7), "jegue": Vector2i(10, 5), "cachorro": Vector2i(11, 8), "capivara": Vector2i(10, 8), "porco": Vector2i(10, 7), "gato": Vector2i(11, 9), "montado": Vector2i(-7, -4), "onca": Vector2i(11, 8)}
const QUATRO_COSTAS = {"casco": Vector2i(8, -6), "malhado": Vector2i(8, -6), "pata": Vector2i(8, -4), "jegue": Vector2i(8, -7), "cavalo": Vector2i(6, -10), "vaca": Vector2i(7, -8)}
