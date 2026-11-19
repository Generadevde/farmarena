extends RefCounted
class_name DuelosMedidos
## GERADO por ci/lab/medidas.py -- não editar na mão.
## Medido no laboratório (batalha de verdade, cartas no mesmo nível):
##   v = de cada 100 tropas, quantas ela vence num duelo 1 contra 1
##   e = o normal pra uma carta desse preço
##   g / p = de quem ganha (mais caras primeiro) / pra quem perde (mais baratas primeiro)
##   t = quanto tira de uma torre se ninguém defender (%)
##   k = [vida, dano] com que foi medida (mudou? o jogo passa a estimar: Scripts/duelo_papel.gd)
const TROPAS = 52
## reta "normal pro preço": fração de vitórias = LINHA_A + LINHA_B * custo
const LINHA_A = -0.0509
const LINHA_B = 0.01363
const DATA = {
	"Abóboras Explosivas": {"v": 8, "e": 29, "g": ["Milho Pipoqueiro", "Galinhas Atiradeiras", "Pato Ninja"], "p": ["Jegue Cargueiro", "Dupla Caipira", "Cavalo Coiceiro"], "t": 37, "k": [220, 60]},
	"Assombração": {"v": 45, "e": 22, "g": ["Galo e Cia", "Galo Rei", "Medusa"], "p": ["Polvo Tinteiro", "Cebola Chorona", "Mula sem Cabeça"], "t": 38, "k": [70, 80]},
	"Bezerrada": {"v": 18, "e": 29, "g": ["Dupla Caipira", "Correição de Saúva", "Pato Ninja"], "p": ["Cebola Chorona", "Polvo Tinteiro", "Peão do Forcado"], "t": 28, "k": [90, 50]},
	"Bode Cabeçudo": {"t": 81, "k": [1350, 190]},
	"Boi Marretão": {"v": 80, "e": 90, "g": ["Comitiva", "Tripé Invasor", "Capivarada"], "p": ["Água-viva Elétrica", "Nuvem de Mosquito", "Urubu de Plantão"], "t": 100, "k": [2100, 680]},
	"Boi da Cara Preta": {"v": 94, "e": 70, "g": ["Disco Voador", "Dragão do Milharal", "Mapinguari"], "p": ["ET Abdutor", "Tripé Invasor", "Comitiva"], "t": 100, "k": [720, 125]},
	"Boitatá": {"v": 43, "e": 49, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Pato Ninja", "Saci", "Cavalo Coiceiro"], "t": 20, "k": [520, 85]},
	"Cacto Pistoleiro": {"v": 37, "e": 43, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Correição de Saúva", "Saci", "Cavalo Coiceiro"], "t": 30, "k": [480, 130]},
	"Canhão de Pipoca": {"t": 0, "k": [720, 115]},
	"Capivara Zen": {"t": 49, "k": [1750, 40]},
	"Capivarada": {"v": 76, "e": 70, "g": ["Comitiva", "Tripé Invasor", "Jacaré do Açude"], "p": ["Água-viva Elétrica", "Nuvem de Mosquito", "Urubu de Plantão"], "t": 100, "k": [520, 120]},
	"Caranguejo Gigante": {"v": 51, "e": 49, "g": ["Assombração", "Medusa", "Tatu Bola"], "p": ["Tubarão de Botas", "Espantalho Ceifador", "Cérbero"], "t": 63, "k": [1300, 95]},
	"Cavalo Coiceiro": {"v": 39, "e": 43, "g": ["Boitatá", "Mula sem Cabeça", "Cacto Pistoleiro"], "p": ["Correição de Saúva", "Assombração", "Medusa"], "t": 56, "k": [820, 170]},
	"Cebola Chorona": {"v": 20, "e": 29, "g": ["Assombração", "Correição de Saúva", "Milho Pipoqueiro"], "p": ["Peão do Forcado", "Pato Ninja", "Vovô do Lampião"], "t": 13, "k": [620, 55]},
	"Colmeia Nervosa": {"t": 10, "k": [650, 0]},
	"Comitiva": {"v": 92, "e": 77, "g": ["Boi da Cara Preta", "Dragão do Milharal", "Tripé Invasor"], "p": ["Capivarada", "Boi Marretão", "Mapinguari"], "t": 100, "k": [1400, 130]},
	"Correição de Saúva": {"v": 27, "e": 36, "g": ["Galo Rei", "Tubarão de Botas", "Medusa"], "p": ["Bezerrada", "Polvo Tinteiro", "Cebola Chorona"], "t": 23, "k": [30, 14]},
	"Corujão Bombardeiro": {"v": 78, "e": 63, "g": ["Mapinguari", "Boi Marretão", "Capivarada"], "p": ["Medusa", "Água-viva Elétrica", "Nuvem de Mosquito"], "t": 30, "k": [950, 210]},
	"Cérbero": {"v": 57, "e": 63, "g": ["Galo e Cia", "Espantalho Ceifador", "Caranguejo Gigante"], "p": ["Tubarão de Botas", "Água-viva Elétrica", "Porco Cozinheiro"], "t": 75, "k": [1250, 105]},
	"Disco Voador": {"v": 92, "e": 84, "g": ["Comitiva", "Dragão do Milharal", "Mapinguari"], "p": ["Medusa", "ET Abdutor", "Tripé Invasor"], "t": 58, "k": [1150, 58]},
	"Dragão do Milharal": {"v": 90, "e": 70, "g": ["Mapinguari", "Boi Marretão", "Corujão Bombardeiro"], "p": ["Tripé Invasor", "Disco Voador", "Comitiva"], "t": 35, "k": [900, 105]},
	"Dupla Caipira": {"v": 31, "e": 63, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Bezerrada", "Pato Ninja", "Milho Pipoqueiro"], "t": 23, "k": [520, 35]},
	"ET Abdutor": {"v": 75, "e": 56, "g": ["Boi da Cara Preta", "Disco Voador", "Boi Marretão"], "p": ["Galinhas Atiradeiras", "Vovô do Lampião", "Dupla Caipira"], "t": 21, "k": [600, 110]},
	"Enxame de Abelha": {"v": 69, "e": 29, "g": ["Mapinguari", "Boi Marretão", "Corujão Bombardeiro"], "p": ["Polvo Tinteiro", "Galinhas Atiradeiras", "Milho Pipoqueiro"], "t": 19, "k": [90, 44]},
	"Espantalho Ceifador": {"v": 55, "e": 49, "g": ["Galo e Cia", "Caranguejo Gigante", "Assombração"], "p": ["Tubarão de Botas", "Cérbero", "Água-viva Elétrica"], "t": 62, "k": [1200, 145]},
	"Forno a Lenha": {"t": 76, "k": [700, 0]},
	"Galinhas Atiradeiras": {"v": 25, "e": 29, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Abóboras Explosivas", "Bezerrada", "Cebola Chorona"], "t": 20, "k": [150, 72]},
	"Galinheiro": {"t": 0, "k": [650, 0]},
	"Galo Rei": {"v": 59, "e": 56, "g": ["Lenhador Furioso", "Porco Cozinheiro", "Vaqueiro Montado"], "p": ["Pintaiada", "Correição de Saúva", "Assombração"], "t": 74, "k": [820, 285]},
	"Galo e Cia": {"v": 63, "e": 56, "g": ["Onça-Pintada", "Lenhador Furioso", "Galo Rei"], "p": ["Assombração", "Espantalho Ceifador", "Cérbero"], "t": 62, "k": [820, 160]},
	"Jacaré do Açude": {"v": 75, "e": 63, "g": ["Tripé Invasor", "Sapo Rei", "Onça-Pintada"], "p": ["Água-viva Elétrica", "Nuvem de Mosquito", "Urubu de Plantão"], "t": 100, "k": [1450, 280]},
	"Jegue Cargueiro": {"v": 6, "e": 43, "g": ["Polvo Tinteiro", "Abóboras Explosivas", "Ovelha Violeira"], "p": ["Vira-lata Caramelo", "Pintaiada", "Sapo Linguarudo"], "t": 11, "k": [1100, 40]},
	"Lenhador Furioso": {"v": 65, "e": 63, "g": ["Sapo Rei", "Vaqueiro Montado", "Porco Cozinheiro"], "p": ["Água-viva Elétrica", "Galo Rei", "Nuvem de Mosquito"], "t": 100, "k": [1050, 125]},
	"Mapinguari": {"v": 82, "e": 97, "g": ["Comitiva", "Tripé Invasor", "Boi Marretão"], "p": ["Nuvem de Mosquito", "Urubu de Plantão", "Enxame de Abelha"], "t": 100, "k": [3400, 280]},
	"Marcianinhos": {"v": 37, "e": 43, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Polvo Tinteiro", "Milho Pipoqueiro", "Saci"], "t": 27, "k": [95, 48]},
	"Medusa": {"v": 45, "e": 56, "g": ["Disco Voador", "Corujão Bombardeiro", "ET Abdutor"], "p": ["Pintaiada", "Pato Ninja", "Correição de Saúva"], "t": 37, "k": [680, 110]},
	"Milho Pipoqueiro": {"v": 27, "e": 36, "g": ["Enxame de Abelha", "Urubu de Plantão", "Nuvem de Mosquito"], "p": ["Abóboras Explosivas", "Vira-lata Caramelo", "Sapo Linguarudo"], "t": 15, "k": [340, 105]},
	"Molecada do Estilingue": {"v": 29, "e": 36, "g": ["Enxame de Abelha", "Urubu de Plantão", "Nuvem de Mosquito"], "p": ["Polvo Tinteiro", "Milho Pipoqueiro", "Vovô do Lampião"], "t": 18, "k": [90, 62]},
	"Mula sem Cabeça": {"v": 41, "e": 49, "g": ["Assombração", "Boitatá", "Marcianinhos"], "p": ["Cavalo Coiceiro", "Medusa", "Caranguejo Gigante"], "t": 45, "k": [760, 105]},
	"Nuvem de Mosquito": {"v": 63, "e": 15, "g": ["Mapinguari", "Boi Marretão", "Corujão Bombardeiro"], "p": ["Sapo Linguarudo", "Polvo Tinteiro", "Galinhas Atiradeiras"], "t": 6, "k": [35, 22]},
	"Onça-Pintada": {"v": 67, "e": 56, "g": ["Tripé Invasor", "Lenhador Furioso", "Vaqueiro Montado"], "p": ["Água-viva Elétrica", "Porco Cozinheiro", "Nuvem de Mosquito"], "t": 78, "k": [880, 150]},
	"Ovelha Violeira": {"v": 0, "e": 36, "g": [], "p": ["Jegue Cargueiro", "Vira-lata Caramelo", "Pintaiada"], "t": 8, "k": [620, 28]},
	"Pato Ninja": {"v": 25, "e": 36, "g": ["Medusa", "Boitatá", "Dupla Caipira"], "p": ["Abóboras Explosivas", "Pintaiada", "Bezerrada"], "t": 20, "k": [300, 420]},
	"Peão do Forcado": {"v": 20, "e": 22, "g": ["Milho Pipoqueiro", "Vovô do Lampião", "Polvo Tinteiro"], "p": ["Pato Ninja", "Galinhas Atiradeiras", "Correição de Saúva"], "t": 23, "k": [640, 95]},
	"Pintaiada": {"v": 14, "e": 15, "g": ["Galo Rei", "Medusa", "Vovô do Lampião"], "p": ["Abóboras Explosivas", "Vira-lata Caramelo", "Bezerrada"], "t": 8, "k": [45, 25]},
	"Polvo Tinteiro": {"v": 20, "e": 43, "g": ["Enxame de Abelha", "Nuvem de Mosquito", "Água-viva Elétrica"], "p": ["Jegue Cargueiro", "Vira-lata Caramelo", "Sapo Linguarudo"], "t": 13, "k": [520, 70]},
	"Porco Cozinheiro": {"v": 59, "e": 56, "g": ["Onça-Pintada", "Cérbero", "Espantalho Ceifador"], "p": ["Água-viva Elétrica", "Galo Rei", "Vaqueiro Montado"], "t": 80, "k": [1700, 140]},
	"Robô Balde-3000": {"t": 100, "k": [3600, 300]},
	"Saci": {"v": 35, "e": 43, "g": ["Boitatá", "Cacto Pistoleiro", "Marcianinhos"], "p": ["Correição de Saúva", "Cavalo Coiceiro", "Mula sem Cabeça"], "t": 45, "k": [560, 135]},
	"Sapo Linguarudo": {"v": 14, "e": 36, "g": ["Urubu de Plantão", "Nuvem de Mosquito", "Água-viva Elétrica"], "p": ["Vira-lata Caramelo", "Pintaiada", "Bezerrada"], "t": 16, "k": [540, 85]},
	"Sapo Rei": {"v": 73, "e": 77, "g": ["Tripé Invasor", "Capivarada", "Onça-Pintada"], "p": ["Água-viva Elétrica", "Nuvem de Mosquito", "Lenhador Furioso"], "t": 100, "k": [1800, 170]},
	"Tatu Bola": {"v": 45, "e": 36, "g": ["Assombração", "Medusa", "Boitatá"], "p": ["Caranguejo Gigante", "Tubarão de Botas", "Espantalho Ceifador"], "t": 40, "k": [900, 45]},
	"Trator Desgovernado": {"t": 100, "k": [1400, 260]},
	"Tripé Invasor": {"v": 84, "e": 70, "g": ["Boi da Cara Preta", "Disco Voador", "Dragão do Milharal"], "p": ["Onça-Pintada", "Sapo Rei", "Jacaré do Açude"], "t": 100, "k": [950, 40]},
	"Tubarão de Botas": {"v": 55, "e": 56, "g": ["Vaqueiro Montado", "Cérbero", "Espantalho Ceifador"], "p": ["Correição de Saúva", "Água-viva Elétrica", "Galo Rei"], "t": 73, "k": [1000, 170]},
	"Urubu de Plantão": {"v": 67, "e": 36, "g": ["Mapinguari", "Boi Marretão", "Corujão Bombardeiro"], "p": ["Sapo Linguarudo", "Galinhas Atiradeiras", "Vovô do Lampião"], "t": 11, "k": [380, 80]},
	"Vaca Brava": {"t": 73, "k": [2300, 110]},
	"Vaca e Cria": {"t": 100, "k": [1900, 100]},
	"Vaqueiro Montado": {"v": 59, "e": 63, "g": ["Porco Cozinheiro", "Cérbero", "Espantalho Ceifador"], "p": ["Tubarão de Botas", "Água-viva Elétrica", "Galo Rei"], "t": 99, "k": [1250, 190]},
	"Vira-lata Caramelo": {"v": 12, "e": 15, "g": ["Milho Pipoqueiro", "Polvo Tinteiro", "Pintaiada"], "p": ["Bezerrada", "Peão do Forcado", "Galinhas Atiradeiras"], "t": 15, "k": [440, 64]},
	"Vovô do Lampião": {"v": 27, "e": 43, "g": ["ET Abdutor", "Enxame de Abelha", "Urubu de Plantão"], "p": ["Pintaiada", "Peão do Forcado", "Pato Ninja"], "t": 12, "k": [460, 65]},
	"Água-viva Elétrica": {"v": 59, "e": 36, "g": ["Boi Marretão", "Corujão Bombardeiro", "Capivarada"], "p": ["Sapo Linguarudo", "Polvo Tinteiro", "Galinhas Atiradeiras"], "t": 3, "k": [360, 60]},
}


static func of(card_name: String) -> Dictionary:
	return DATA.get(card_name, {})
