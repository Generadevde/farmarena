class_name ArchetypeQuotes
extends RefCounted

# frases semi-automáticas por ARQUÉTIPO (personalidade), não por bot
# individual -- sorteia um pedaço de "pre_phrase_1" e um de "pre_phrase_2"
# do arquétipo do bot que vai falar, junta os dois, e ATÉ opcionalmente
# emenda uma menção de carta no final (não sempre -- ver mention_chance)
#
# uso: ArchetypeQuotes.POOLS.get(archetype, null)
const POOLS = {
	AIProfile.Archetype.AGRESSIVO: {
		"pre_phrase_1": [
			"Não vim aqui pra defender nada,",
			"Base? Não conheço,",
			"Enquanto vocês ficam pensando,",
			"Recuar não tá no meu vocabulário,",
			"Só sei jogar pra frente,",
			"Deixa eu te mostrar uma coisa:",
			"Cansei de esperar,",
		],
		"pre_phrase_2": [
			"eu já mandei tudo pra cima.",
			"a próxima onda já tá vindo.",
			"quem hesita, perde a arena.",
			"ataque é a melhor (e única) defesa.",
			"vou até não sobrar mais nada.",
			"pressão constante é minha assinatura.",
		],
		"mention_chance": 0.5,
	},
	AIProfile.Archetype.PASSIVO: {
		"pre_phrase_1": [
			"Prefiro esperar o momento certo,",
			"Não tenho pressa nenhuma,",
			"Enquanto minha base aguenta,",
			"Segurança em primeiro lugar,",
			"Vou com calma,",
			"Cada partida é uma maratona,",
		],
		"pre_phrase_2": [
			"e o resto se resolve sozinho.",
			"deixo o adversário se desgastar primeiro.",
			"não vejo motivo pra correr risco à toa.",
			"paciência sempre vence afobação.",
			"prefiro terminar com a base inteira.",
		],
		"mention_chance": 0.3,
	},
	AIProfile.Archetype.CURIOSO: {
		"pre_phrase_1": [
			"Sabe o que eu descobri outro dia?",
			"Fiquei pensando aqui,",
			"Nunca sei o que vou fazer até a hora,",
			"Toda partida é um experimento novo,",
			"Testei uma coisa diferente hoje,",
			"Curiosidade nunca matou ninguém (comigo),",
		],
		"pre_phrase_2": [
			"e funcionou melhor do que eu esperava.",
			"cada jogo ensina algo novo.",
			"talvez eu tente de novo, talvez não.",
			"gosto de me surpreender também.",
			"não sigo receita, sigo instinto.",
		],
		"mention_chance": 0.5,
	},
	AIProfile.Archetype.ATACA_TUDO: {
		"pre_phrase_1": [
			"Custo não é problema meu,",
			"Toda carta na mão é uma carta esperando demais,",
			"Não guardo nada pra depois,",
			"Vi uma abertura e fui,",
			"Enquanto tiver moeda, eu jogo,",
		],
		"pre_phrase_2": [
			"gasto tudo até não sobrar mais nada.",
			"o campo é meu, ponto final.",
			"reserva é coisa de quem tem medo.",
			"prefiro atacar demais do que de menos.",
			"deixa eu tomar conta disso.",
		],
		"mention_chance": 0.4,
	},
	AIProfile.Archetype.ESTRUTURAL: {
		"pre_phrase_1": [
			"Uma boa construção vale mais que dez unidades,",
			"Minha base é minha fortaleza,",
			"Enquanto a estrutura aguenta,",
			"Prefiro erguer do que atacar,",
			"Defesa bem montada nunca falha,",
		],
		"pre_phrase_2": [
			"o resto do jogo se resolve sozinho.",
			"não preciso correr atrás de nada.",
			"quem ataca minha base se arrepende.",
			"construção é a base de tudo (literalmente).",
			"aguento o tempo que for preciso.",
		],
		"mention_chance": 0.3,
	},
	AIProfile.Archetype.METAGAMER: {
		"pre_phrase_1": [
			"Andei estudando os números da temporada,",
			"O que tá vencendo agora é bem claro,",
			"Sigo o que funciona, simples assim,",
			"Analisando a taxa de vitória geral,",
			"Todo mundo devia prestar atenção nisso:",
		],
		"pre_phrase_2": [
			"e ajustei o deck de acordo.",
			"quem não acompanha a meta fica pra trás.",
			"não tem mistério, é estatística.",
			"o que funciona pros outros, funciona pra mim.",
			"prefiro dado a instinto.",
		],
		"mention_chance": 0.8,
	},
	AIProfile.Archetype.CAOTICO: {
		"pre_phrase_1": [
			"Nem eu sei o que vou fazer,",
			"Ontem joguei tudo ao contrário,",
			"Regra? Que regra?",
			"Decisão de hoje: nenhuma decisão,",
			"Segui o vento (metaforicamente),",
		],
		"pre_phrase_2": [
			"e olha, deu certo de novo.",
			"imprevisibilidade é minha estratégia oficial.",
			"até eu me surpreendo às vezes.",
			"quem consegue prever isso, ganha um prêmio.",
			"sem padrão nenhum, de propósito.",
		],
		"mention_chance": 0.3,
	},
	AIProfile.Archetype.POUPADOR: {
		"pre_phrase_1": [
			"Guardo moeda igual quem guarda pra emergência,",
			"Nunca gasto tudo de uma vez,",
			"Prefiro sobrar do que faltar,",
			"Reserva é sagrada pra mim,",
			"Só jogo o que sei que compensa,",
		],
		"pre_phrase_2": [
			"nunca se sabe quando vai precisar.",
			"cautela nunca é exagero.",
			"prefiro perder uma chance a ficar exposto.",
			"economia bem feita ganha partida.",
			"sobra sempre é melhor que falta.",
		],
		"mention_chance": 0.25,
	},
	AIProfile.Archetype.VINGATIVO: {
		"pre_phrase_1": [
			"Quem me acerta, paga caro depois,",
			"Não esqueço quando levo dano,",
			"Guardo isso pra revanche,",
			"Toda agressão tem resposta,",
			"Machucado eu fico mais perigoso,",
		],
		"pre_phrase_2": [
			"e a resposta costuma doer o dobro.",
			"vingança é só justiça com atraso.",
			"quem começa, eu termino.",
			"nada fica sem troco por aqui.",
			"dano recebido é dano que vou devolver.",
		],
		"mention_chance": 0.4,
	},
	AIProfile.Archetype.OPORTUNISTA: {
		"pre_phrase_1": [
			"Não ataco por atacar,",
			"Espero juntar o suficiente,",
			"Quando o momento chega, eu sei,",
			"Paciência tem recompensa,",
			"Guardo força pra hora certa,",
		],
		"pre_phrase_2": [
			"e aí sim vale a pena investir tudo.",
			"o timing importa mais que a pressa.",
			"melhor um golpe certeiro do que dez fracos.",
			"sei reconhecer quando vale a pena.",
			"quem espera sempre alcança (literalmente).",
		],
		"mention_chance": 0.4,
	},
	AIProfile.Archetype.PROVOCADOR: {
		"pre_phrase_1": [
			"Jogo baratinho primeiro só pra ver a reação,",
			"Adoro uma isca bem colocada,",
			"Nunca mostro a mão de cara,",
			"Deixo o adversário morder o anzol,",
			"Provoco antes de golpear,",
		],
		"pre_phrase_2": [
			"e depois é só aproveitar o exagero dele.",
			"quem morde a isca sempre se arrepende.",
			"reação exagerada é presente de grátis.",
			"gosto de ver quem cai primeiro.",
			"provocação bem feita já é meio caminho andado.",
		],
		"mention_chance": 0.35,
	},
	AIProfile.Archetype.ENXAMEADOR: {
		"pre_phrase_1": [
			"Não preciso de uma unidade forte,",
			"Quantidade também é qualidade,",
			"Um sozinho cai, muitos nem tanto,",
			"Prefiro encher o campo,",
			"Números vencem poder individual,",
		],
		"pre_phrase_2": [
			"prefiro encher o campo de uma vez.",
			"é difícil parar todo mundo ao mesmo tempo.",
			"enxame não se segura com um golpe só.",
			"divido a atenção do adversário assim.",
			"um cai, dez continuam vindo.",
		],
		"mention_chance": 0.35,
	},
	AIProfile.Archetype.EMBOSCADA: {
		"pre_phrase_1": [
			"Fico esperando, quietinho,",
			"Ninguém me vê chegar,",
			"Gosto de reagir rápido demais pro adversário perceber,",
			"Deixo o exagero vir até mim,",
			"Sou rápido quando preciso ser,",
		],
		"pre_phrase_2": [
			"e quando reajo, já é tarde pra fugir.",
			"quem se estica demais sente o troco na hora.",
			"velocidade de reação é minha marca.",
			"não corro atrás, espero a oportunidade vir.",
			"contra-ataque bem cronometrado nunca falha.",
		],
		"mention_chance": 0.3,
	},
	AIProfile.Archetype.ACUMULADOR: {
		"pre_phrase_1": [
			"Não gasto nada até ter o suficiente,",
			"Tudo que junto é pra um golpe só,",
			"Prefiro guardar tudo pro momento certo,",
			"Um grande ataque vale mais que vários pequenos,",
			"Sou paciente com meu próprio plano,",
		],
		"pre_phrase_2": [
			"e quando solto tudo, é de uma vez.",
			"planejamento sempre supera impulso.",
			"prefiro um golpe decisivo a vários fracos.",
			"guardo recurso como quem guarda munição.",
			"quando ataco, ataco de verdade.",
		],
		"mention_chance": 0.4,
	},
	AIProfile.Archetype.REATIVO_PURO: {
		"pre_phrase_1": [
			"Não inicio nada, só respondo,",
			"Deixo o adversário abrir o jogo,",
			"Prefiro reagir com calma,",
			"Cada movimento meu tem um motivo,",
			"Sou devagar, mas nunca erro o momento,",
		],
		"pre_phrase_2": [
			"e minha resposta sempre vem certeira.",
			"metodologia vence impulso, sempre.",
			"reajo só quando vale a pena reagir.",
			"prefiro precisão a velocidade.",
			"quem inicia se expõe, e eu aproveito isso.",
		],
		"mention_chance": 0.3,
	},
	AIProfile.Archetype.TERRITORIAL: {
		"pre_phrase_1": [
			"Controlar o campo é mais importante que atacar,",
			"Cada construção minha é um posto avançado,",
			"Domino espaço antes de dominar dano,",
			"Prefiro expandir devagar e com firmeza,",
			"O território fala por si,",
		],
		"pre_phrase_2": [
			"quem controla o mapa controla a partida.",
			"expansão bem feita nunca é perda de tempo.",
			"cada construção é uma vitória silenciosa.",
			"prefiro presença constante a explosão rápida.",
			"território ganho não se perde fácil.",
		],
		"mention_chance": 0.35,
	},
	AIProfile.Archetype.IMPULSIVO: {
		"pre_phrase_1": [
			"Penso depois, jogo agora,",
			"Não dá tempo de planejar,",
			"Vi a carta, joguei a carta,",
			"Reflexo é meu único plano,",
			"Rápido demais pra hesitar,",
		],
		"pre_phrase_2": [
			"e às vezes até funciona.",
			"planejar é perda de tempo mesmo.",
			"decidir rápido já é metade da vitória.",
			"não tenho paciência pra estratégia longa.",
			"impulso tem lá seus dias de glória.",
		],
		"mention_chance": 0.25,
	},
	AIProfile.Archetype.ANALITICO: {
		"pre_phrase_1": [
			"Prefiro equilíbrio a extremo,",
			"Cada decisão minha pesa os dois lados,",
			"Não me apego a um jeito só de jogar,",
			"Ajusto rápido quando algo não funciona,",
			"Gosto de pensar antes de agir, mas sem exagero,",
		],
		"pre_phrase_2": [
			"funciona melhor do que parece.",
			"adaptação é a chave de tudo.",
			"não tenho vício de personalidade nenhum.",
			"prefiro o meio-termo bem calibrado.",
			"mudo de ideia rápido se precisar.",
		],
		"mention_chance": 0.4,
	},
	AIProfile.Archetype.APOSTADOR: {
		"pre_phrase_1": [
			"Gasto tudo na carta mais cara, sempre,",
			"Não calculo risco, sinto o momento,",
			"Prefiro apostar alto do que jogar seguro,",
			"Ritmo? Não tenho nenhum,",
			"Vivo no talvez,",
		],
		"pre_phrase_2": [
			"às vezes dá muito certo, às vezes nem tanto.",
			"prefiro o risco grande à segurança pequena.",
			"quem não arrisca, não sente a emoção.",
			"aposto tudo, sempre foi assim.",
			"inconsistência também é uma estratégia (juro).",
		],
		"mention_chance": 0.3,
	},
}

# falas DIRIGIDAS AO JOGADOR, depois de uma partida real contra ele --
# "win" = o bot venceu (provoca/desafia); "loss" = o bot perdeu (guarda
# rancor/promete revanche). Diferente do POOLS acima (que é ambiente geral,
# sem falar direto com você)
const POST_BATTLE_POOLS = {
	AIProfile.Archetype.AGRESSIVO: {
		"win": ["Nem viu de onde veio, foi?", "Isso é só o começo, volta aí.", "Achou que ia segurar minha pressão?"],
		"loss": ["Foi sorte, na próxima é diferente.", "Você aguentou dessa vez. Só dessa.", "Revanche. Agora."],
	},
	AIProfile.Archetype.PASSIVO: {
		"win": ["Paciência sempre compensa, viu?", "Você atacou demais, eu só esperei.", "Minha base ficou de pé, a sua não."],
		"loss": ["Bem, defendi o que deu.", "Você foi mais rápido dessa vez.", "Vou rever minha estratégia com calma."],
	},
	AIProfile.Archetype.CURIOSO: {
		"win": ["Interessante, aquilo funcionou melhor do que eu esperava!", "Aprendi algo novo jogando contra você.", "Quero tentar de novo, foi divertido."],
		"loss": ["Hmm, não esperava essa. Anotado.", "Você me pegou de surpresa, admito.", "Vou testar outra coisa da próxima vez."],
	},
	AIProfile.Archetype.ATACA_TUDO: {
		"win": ["Eu simplesmente não parei. Nunca paro.", "Sua base não durou nada.", "Quer tentar de novo? Eu topo sempre."],
		"loss": ["Gastei tudo e não foi suficiente dessa vez.", "Vou atacar ainda mais forte na próxima.", "Isso não fica assim."],
	},
	AIProfile.Archetype.ESTRUTURAL: {
		"win": ["Minha fortaleza aguentou tudo que você mandou.", "Construção bem feita nunca cai.", "Tenta de novo, minha base te espera."],
		"loss": ["Minha estrutura cedeu dessa vez. Vou reforçar.", "Achei que aguentaria mais.", "Preciso rever minhas defesas."],
	},
	AIProfile.Archetype.METAGAMER: {
		"win": ["Seu deck não seguia a meta atual. Eu sim.", "Estatística não mente.", "Ajusta seu baralho e tenta de novo."],
		"loss": ["Interessante, sua estratégia não estava nos meus dados.", "Vou reanalisar isso.", "Você fugiu da curva esperada."],
	},
	AIProfile.Archetype.CAOTICO: {
		"win": ["Nem eu sabia que ia dar certo, mas deu!", "Imprevisibilidade venceu de novo.", "Bora outra? Prometo ser ainda mais aleatório."],
		"loss": ["Ah, o caos me traiu dessa vez.", "Nem sempre dá certo, faz parte.", "Vamos ver o que dá da próxima."],
	},
	AIProfile.Archetype.POUPADOR: {
		"win": ["Guardei o suficiente pra hora certa.", "Minha reserva valeu a pena.", "Cautela venceu pressa, como sempre."],
		"loss": ["Talvez eu tenha guardado demais dessa vez.", "Vou repensar minha reserva.", "Prudência não é garantia, aprendi."],
	},
	AIProfile.Archetype.VINGATIVO: {
		"win": ["Você me acertou antes. Agora sabe o que sinto.", "Vingança sempre vem.", "Não esquece, eu não esqueço."],
		"loss": ["Isso não fica assim. Eu volto.", "Guardei essa derrota. Você vai ver.", "A próxima vai ser diferente, prometo."],
	},
	AIProfile.Archetype.OPORTUNISTA: {
		"win": ["Esperei o momento certo, e funcionou.", "Você gastou tudo cedo demais.", "Paciência sempre compensa no fim."],
		"loss": ["Esperei demais dessa vez, acho.", "Vou calibrar meu timing.", "Não vi a chance certa a tempo."],
	},
	AIProfile.Archetype.PROVOCADOR: {
		"win": ["Você mordeu a isca direitinho.", "Adorei ver você cair nessa.", "Bora de novo? Tenho mais isca guardada."],
		"loss": ["Dessa vez você não mordeu. Impressionante.", "Vou precisar de uma isca melhor.", "Você é esperto, admito."],
	},
	AIProfile.Archetype.ENXAMEADOR: {
		"win": ["Muitos sempre vencem um só.", "Você não conseguiu parar todo mundo.", "Números nunca mentem."],
		"loss": ["Dessa vez você limpou meu enxame rápido demais.", "Preciso de mais unidades ainda.", "Vou voltar com mais gente."],
	},
	AIProfile.Archetype.EMBOSCADA: {
		"win": ["Você se esticou, eu aproveitei.", "Nunca me viu chegando.", "Reação rápida sempre vence exagero."],
		"loss": ["Dessa vez não tive brecha pra reagir.", "Você não deu abertura nenhuma.", "Vou esperar uma chance melhor."],
	},
	AIProfile.Archetype.ACUMULADOR: {
		"win": ["Guardei tudo pra um golpe só, e funcionou.", "Paciência e planejamento vencem.", "Valeu a pena esperar."],
		"loss": ["Não deu tempo de soltar tudo que guardei.", "Preciso ser mais rápido com meu plano.", "Vou ajustar quando atacar."],
	},
	AIProfile.Archetype.REATIVO_PURO: {
		"win": ["Só reagi ao que você fez. Bastou.", "Metodologia sempre vence impulso.", "Esperei o momento certo de responder."],
		"loss": ["Não reagi rápido o suficiente dessa vez.", "Vou rever meu tempo de resposta.", "Você foi mais direto que eu."],
	},
	AIProfile.Archetype.TERRITORIAL: {
		"win": ["Eu controlava o campo inteiro.", "Território ganho não se perde fácil.", "Sua base nunca teve chance contra meu domínio."],
		"loss": ["Perdi controle do campo dessa vez.", "Preciso expandir melhor.", "Você tomou meu espaço."],
	},
	AIProfile.Archetype.IMPULSIVO: {
		"win": ["Nem pensei, só joguei. Deu certo!", "Reflexo bateu estratégia dessa vez.", "Rápido demais pra você acompanhar."],
		"loss": ["Fui rápido demais e sem plano nenhum dessa vez.", "Talvez eu devesse pensar um pouco mais.", "Nah, vou continuar do mesmo jeito."],
	},
	AIProfile.Archetype.ANALITICO: {
		"win": ["Equilíbrio sempre vence extremo.", "Analisei bem e funcionou.", "Adaptação foi a chave dessa vitória."],
		"loss": ["Preciso reanalisar minha abordagem.", "Você encontrou o desequilíbrio certo.", "Vou ajustar rápido pra próxima."],
	},
	AIProfile.Archetype.APOSTADOR: {
		"win": ["Apostei tudo, e valeu a pena!", "Risco grande, recompensa grande.", "Vamos apostar de novo?"],
		"loss": ["Perdi a aposta dessa vez.", "Nem sempre dá certo, mas eu aposto de novo.", "Risco é risco, aceito o resultado."],
	},
}
