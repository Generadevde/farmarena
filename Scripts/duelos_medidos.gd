extends RefCounted
class_name DuelosMedidos
## GERADO por ci/lab/medidas.py -- não editar na mão.
## Medido no laboratório (batalha de verdade, cartas no mesmo nível):
##   v = de cada 100 tropas, quantas ela vence num duelo 1 contra 1
##   e = o normal pra uma carta desse preço
##   g / p = de quem ganha (mais caras primeiro) / pra quem perde (mais baratas primeiro)
##   t = quanto tira de uma torre se ninguém defender (%)
const TROPAS = 36
const DATA = {
	"Abóboras Explosivas": {"v": 17, "e": 33, "g": ["Cacto Pistoleiro", "Galinhas Atiradeiras", "Milho Pipoqueiro"], "p": ["Jegue Cargueiro", "Dupla Caipira", "Molecada do Estilingue"], "t": 37},
	"Assombração": {"v": 49, "e": 27, "g": ["Galo e Cia", "Galo Rei", "Cacto Pistoleiro"], "p": ["Bezerrada", "Cebola Chorona", "Tatu Bola"], "t": 38},
	"Bezerrada": {"v": 23, "e": 33, "g": ["Assombração", "Dupla Caipira", "Pato Ninja"], "p": ["Abóboras Explosivas", "Cebola Chorona", "Milho Pipoqueiro"], "t": 26},
	"Bode Cabeçudo": {"t": 81},
	"Boi Marretão": {"v": 80, "e": 90, "g": ["Comitiva", "Capivarada", "Jacaré do Açude"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 100},
	"Boi da Cara Preta": {"v": 94, "e": 71, "g": ["Disco Voador", "Boi Marretão", "Corujão Bombardeiro"], "p": ["ET Abdutor", "Comitiva"], "t": 100},
	"Cacto Pistoleiro": {"v": 46, "e": 46, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Abóboras Explosivas", "Cavalo Coiceiro", "Assombração"], "t": 30},
	"Canhão de Pipoca": {"t": 0},
	"Capivara Zen": {"t": 49},
	"Capivarada": {"v": 77, "e": 71, "g": ["Comitiva", "ET Abdutor", "Jacaré do Açude"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 100},
	"Cavalo Coiceiro": {"v": 43, "e": 46, "g": ["Cacto Pistoleiro", "Molecada do Estilingue", "Galinhas Atiradeiras"], "p": ["Pintaiada", "Assombração", "Galo Rei"], "t": 56},
	"Cebola Chorona": {"v": 23, "e": 33, "g": ["Assombração", "Galinhas Atiradeiras", "Milho Pipoqueiro"], "p": ["Pato Ninja", "Peão do Forcado", "Dupla Caipira"], "t": 13},
	"Colmeia Nervosa": {"t": 12},
	"Comitiva": {"v": 89, "e": 77, "g": ["Boi da Cara Preta", "ET Abdutor", "Corujão Bombardeiro"], "p": ["Jacaré do Açude", "Capivarada", "Boi Marretão"], "t": 100},
	"Corujão Bombardeiro": {"v": 80, "e": 65, "g": ["Boi Marretão", "Capivarada", "Jacaré do Açude"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 30},
	"Disco Voador": {"v": 94, "e": 83, "g": ["Comitiva", "Boi Marretão", "Corujão Bombardeiro"], "p": ["ET Abdutor", "Boi da Cara Preta"], "t": 58},
	"Dupla Caipira": {"v": 34, "e": 65, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Bezerrada", "Pato Ninja", "Milho Pipoqueiro"], "t": 23},
	"ET Abdutor": {"v": 80, "e": 58, "g": ["Boi da Cara Preta", "Disco Voador", "Boi Marretão"], "p": ["Dupla Caipira", "Galinhas Atiradeiras", "Vovô do Lampião"], "t": 21},
	"Enxame de Abelha": {"v": 69, "e": 33, "g": ["Boi Marretão", "Corujão Bombardeiro", "Capivarada"], "p": ["Milho Pipoqueiro", "Vovô do Lampião", "Galinhas Atiradeiras"], "t": 19},
	"Espantalho Ceifador": {"v": 57, "e": 52, "g": ["Galo e Cia", "Assombração", "Tatu Bola"], "p": ["Galo Rei", "Porco Cozinheiro", "Lenhador Furioso"], "t": 62},
	"Forno a Lenha": {"t": 76},
	"Galinhas Atiradeiras": {"v": 34, "e": 33, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Abóboras Explosivas", "Cebola Chorona", "Milho Pipoqueiro"], "t": 20},
	"Galinheiro": {"t": 0},
	"Galo Rei": {"v": 57, "e": 58, "g": ["Lenhador Furioso", "Espantalho Ceifador", "Porco Cozinheiro"], "p": ["Pintaiada", "Assombração", "Galo e Cia"], "t": 74},
	"Galo e Cia": {"v": 60, "e": 58, "g": ["Lenhador Furioso", "Galo Rei", "Porco Cozinheiro"], "p": ["Assombração", "Espantalho Ceifador", "Nuvem de Mosquito"], "t": 62},
	"Jacaré do Açude": {"v": 74, "e": 65, "g": ["Comitiva", "Sapo Rei", "Lenhador Furioso"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 100},
	"Jegue Cargueiro": {"v": 6, "e": 46, "g": ["Abóboras Explosivas", "Ovelha Violeira"], "p": ["Vira-lata Caramelo", "Sapo Linguarudo", "Pintaiada"], "t": 11},
	"Lenhador Furioso": {"v": 60, "e": 65, "g": ["Espantalho Ceifador", "Porco Cozinheiro", "Tatu Bola"], "p": ["Galo Rei", "Galo e Cia", "Nuvem de Mosquito"], "t": 100},
	"Milho Pipoqueiro": {"v": 29, "e": 40, "g": ["Enxame de Abelha", "Urubu de Plantão", "Nuvem de Mosquito"], "p": ["Sapo Linguarudo", "Vira-lata Caramelo", "Abóboras Explosivas"], "t": 15},
	"Molecada do Estilingue": {"v": 37, "e": 40, "g": ["Enxame de Abelha", "Urubu de Plantão", "Nuvem de Mosquito"], "p": ["Milho Pipoqueiro", "Peão do Forcado", "Vovô do Lampião"], "t": 16},
	"Nuvem de Mosquito": {"v": 63, "e": 21, "g": ["Boi Marretão", "Corujão Bombardeiro", "Capivarada"], "p": ["Sapo Linguarudo", "Milho Pipoqueiro", "Dupla Caipira"], "t": 6},
	"Ovelha Violeira": {"v": 0, "e": 40, "g": [], "p": ["Jegue Cargueiro", "Vira-lata Caramelo", "Sapo Linguarudo"], "t": 8},
	"Pato Ninja": {"v": 29, "e": 40, "g": ["Dupla Caipira", "Vovô do Lampião", "Galinhas Atiradeiras"], "p": ["Abóboras Explosivas", "Pintaiada", "Bezerrada"], "t": 20},
	"Peão do Forcado": {"v": 29, "e": 27, "g": ["Molecada do Estilingue", "Vovô do Lampião", "Milho Pipoqueiro"], "p": ["Pato Ninja", "Galinhas Atiradeiras", "Dupla Caipira"], "t": 23},
	"Pintaiada": {"v": 20, "e": 21, "g": ["Galo Rei", "Cavalo Coiceiro", "Vovô do Lampião"], "p": ["Vira-lata Caramelo", "Abóboras Explosivas", "Cebola Chorona"], "t": 10},
	"Porco Cozinheiro": {"v": 57, "e": 58, "g": ["Espantalho Ceifador", "Tatu Bola", "Assombração"], "p": ["Galo Rei", "Galo e Cia", "Lenhador Furioso"], "t": 80},
	"Robô Balde-3000": {"t": 100},
	"Sapo Linguarudo": {"v": 14, "e": 40, "g": ["Urubu de Plantão", "Nuvem de Mosquito", "Milho Pipoqueiro"], "p": ["Vira-lata Caramelo", "Pintaiada", "Bezerrada"], "t": 16},
	"Sapo Rei": {"v": 69, "e": 77, "g": ["Capivarada", "Galo e Cia", "Galo Rei"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 100},
	"Tatu Bola": {"v": 49, "e": 40, "g": ["Assombração", "Cacto Pistoleiro", "Molecada do Estilingue"], "p": ["Porco Cozinheiro", "Galo Rei", "Espantalho Ceifador"], "t": 40},
	"Trator Desgovernado": {"t": 100},
	"Urubu de Plantão": {"v": 66, "e": 40, "g": ["Boi Marretão", "Corujão Bombardeiro", "Capivarada"], "p": ["Sapo Linguarudo", "Milho Pipoqueiro", "Galinhas Atiradeiras"], "t": 11},
	"Vaca Brava": {"t": 73},
	"Vaca e Cria": {"t": 100},
	"Vira-lata Caramelo": {"v": 14, "e": 21, "g": ["Milho Pipoqueiro", "Pintaiada", "Sapo Linguarudo"], "p": ["Bezerrada", "Peão do Forcado", "Pato Ninja"], "t": 15},
	"Vovô do Lampião": {"v": 34, "e": 46, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Pintaiada", "Pato Ninja", "Peão do Forcado"], "t": 12},
}


static func of(card_name: String) -> Dictionary:
	return DATA.get(card_name, {})
