# Diagnóstico — "perdeu a fluidez / a graça" (18–19/11/2026)

O João sentia que "toda unidade é igual, ou morre ou não morre", que faltava
"conexão", "fluidez" e "estratégia" — e que no Clash Royale isso existe até
nas cartas sem habilidade. Este arquivo guarda o que foi medido e o que mudou.

## A causa: não existia vantagem de quem defende

No Clash a torre é perigosa. É ela que dá papel às cartas: o tanque existe
pra segurar o tiro, o apoio precisa de alguém na frente, o bando morre se
chegar sozinho, o feitiço termina o serviço. Defender sai mais barato que
atacar, e o que sobra da defesa vira contra-ataque — esse vai e volta é a
"fluidez".

Aqui a torre não defendia:

- **4 dos 6 tipos de torre nem atiravam** (Moinho, Caixa d'Água, Forte, Armazém).
- O Celeiro (o que atira) tinha 845 de vida e 32 de dano/s, com alcance
  menor que o de TODOS os atiradores: Galinhas, Molecada, Milho, Vovô e Cacto
  batiam nele de fora, sem levar um tiro.
- Medido com cada carta **sozinha contra um Celeiro sem defesa**: **40 das 48
  cartas derrubavam a torre inteira**, inclusive as de custo 15 (Pintaiada,
  Vira-lata) e 20 (Peão). A maioria ainda sobrava viva.
- Duas cartas baratas sem resposta (Peão 20 + Pintaiada 15) = **derrota em 16 s**.

Sem torre perigosa, a partida é corrida ("ou passa ou morre") e toda carta
vira a mesma coisa: um saco de dano.

### Partidas bot x bot (mesmo robô dos dois lados, mesmo nível, 60 de cada)

| | Antes | Agora |
|---|---|---|
| Duração (mediana, de 300 s) | 74 s | 300 s |
| Acabaram em menos de 1 min | 18 de 60 | 0 de 60 |
| Acabaram em menos de 2 min | 39 de 60 | 6 de 60 |
| Nocaute (as 2 torres) | 57 de 60 | 23 de 60 |
| Decididas na vida das torres, no fim do tempo | 3 de 60 | 37 de 60 |
| Vencedor sem levar um arranhão | 38 de 60 | 15 de 60 |
| Os dois lados saíram feridos | 19 de 60 | 32 de 60 |

### Cada carta sozinha contra uma torre (quanto ela tira)

(A coluna do Clash é conta aproximada com os números da torre e das cartas
de lá, não medição.)

| Carta (custo) | Antes | Agora | Clash, pra comparar |
|---|---|---|---|
| Pintaiada (15) | 100% | 9% | Esqueletos: ~2% |
| Peão do Forcado (20) | 100% | 25% | Cavaleiro: ~35% |
| Bezerrada (25) | 100% | 44% | |
| Molecada do Estilingue (30) | 100% | 27% | |
| Vaca Brava (40) | 100% | 82% | Gigante: derruba por pouco |
| cartas de 50+ | 100% | 90–100% | P.E.K.K.A, Golem: derrubam |
| **Derrubam sozinhas** | **40 de 48** | **10 de 48** | só as caras |

## O que mudou — Batalha 2.5 (`Scripts/regras.gd`)

Três chaves em **Configurações → Laboratório da batalha** (todas ligadas;
dá pra desligar uma por uma e comparar):

1. **🏰 Torres de verdade** — toda torre atira (as "de tiro" atiram mais
   forte), com 2,2× a vida, 2,3× o dano e alcance de 6,9 quadrados
   (passa de todo atirador comum). Calibrado pelo Clash: lá a torre nível 11
   tem 3052 de vida e 109 de dano a cada 0,8 s; o Cavaleiro tem 1766 de vida
   e 168 de dano/s. A proporção torre × Peão ficou a mesma.
2. **👀 Tropas grandes e cor de time** — desenho ~55% maior (as pequenas
   crescem mais), contorno e roda no chão azul (seu) ou vermelho (do bot),
   barra de vida na cor do time e só em quem apanhou, quem está embaixo
   aparece na frente, gomos de 10 na barra de recurso, lado do adversário
   avermelhado e alcance das torres dele enquanto você posiciona.
3. **🔨 Golpe com peso** — 1 s pra entrar em campo (com reloginho), a tropa
   arma o golpe antes de bater (o primeiro golpe não é mais instantâneo; o
   intervalo entre golpes é o mesmo), pisca branco e amassa ao apanhar,
   some com um "fantasma" em vez de corte seco, tela treme em pancada forte.

4. **Bot que ataca em bloco** (`AI/push_plan.gd`, vale junto com a chave das
   torres) — com a torre defendendo, o bot que soltava carta sozinha não
   arranhava mais nada (15 de 16 partidas com as torres do jogador intactas).
   Agora ele junta recurso e ataca numa rota só: tanque na frente, apoio logo
   atrás. Conta o seu recurso (gastou tudo? ele vem), aproveita a tropa que
   sobrou da defesa pra contra-atacar e guarda um troco pra não ficar pelado.
   Contra um "jogador de mentira" que defende tudo: o dano nas torres do
   jogador dobrou (12% → 24% por partida) e o bot passou a ganhar 1 em cada 3.

De quebra: explosão conta até a borda do alvo (com os corpos maiores a
abóbora-bomba errava), e o avanço estilo Bandida não é mais gasto enquanto a
tropa ainda está entrando em campo.

## Como medir de novo — `ci/lab/`

O Godot roda aqui sem celular (baixar o binário 4.7 do GitHub). Ver o
cabeçalho de `ci/lab/rodar.sh`:

- `rodar.sh cena` — monta uma situação e grava vídeo na proporção do Moto G75
- `rodar.sh lote` — N partidas bot x bot justas, com resumo
- `rodar.sh solo` — cada carta sozinha contra uma torre
- `rodar.sh duelos` — toda tropa contra toda tropa (1 contra 1) e grava
  `Scripts/duelos_medidos.gd`, que é o que a carta mostra em "Força medida"
- `ci/lab/folha.tscn` — folha com o desenho de todas as tropas no tamanho do campo
- `rodar.sh papel` — o quanto a estimativa "no papel" acerta os duelos de verdade
- `ci/lab/safra.tscn` — gera safras futuras e mostra se as cartas saem no preço certo
- `REGRAS_OFF=torres,visual,peso` na frente = regras antigas, pra comparar

O teste `CI_MODE=regras` (em `ci/battle_test.gd`) garante no GitHub que a
torre continua defendendo.

## Identidade das tropas (19/11) — "tá tudo muito igual, muito repetido"

O João jogou a Batalha 2.5 e disse que as unidades continuavam parecidas
demais: no Clash um cavaleiro e um goblin são claramente diferentes, "tem uma
simetria na diferença". E que tinha lendária que ele não sabia dizer se era
fraca ou forte. Medido, deu três causas:

**1. Nos números, a diferença era só de QUANTO, não de COMO.** Todas as tropas
duelaram entre si (`rodar.sh duelos`, 666 duelos, mesmo nível):

| | Antes | Agora |
|---|---|---|
| Uma única lista "fraca → forte" acerta o resultado | 91% | 85% |
| Idem, só entre cartas de preço parecido (±5) | 88% | 79% |
| Trios pedra-papel-tesoura (preço parecido) | 4,9% | 12,7% |
| Duelos apertados (vencedor com menos de 25% da vida, preço parecido) | 14% | 17% |

O que foi mexido: cada papel foi puxado pro seu canto (antes era tudo
meio-termo). **Bando** (Bezerrada agora são 4, Molecada, Galinhas): cada um
morre com 1 golpe do Peão ou 2 tiros da torre, mas juntos batem muito.
**Matador** (Galo Rei, Jacaré, Boi Marretão, Pato Ninja): golpe maior e mais
espaçado — apaga tropa de vida alta, desperdiça golpe em bando. **Brigão**
(Peão) é a régua. Resultado que dá pra ver: Peão > Pintaiada > Galo Rei > Peão.
O gerador de cartas da safra segue a mesma ideia (bando e matador).

**2. No desenho, quase todo bicho era o mesmo boneco em pé com outra cabeça.**
Agora bicho sem ferramenta anda de quatro patas (vaca malhada, bezerro,
cavalo, jegue, bode, cachorro, capivara), jacaré é rasteiro, tatu tem casco e
sapo fica agachado (`ci/tools/arte/pecas.py`, peças "quatro"). Gente e bicho
com ferramenta continuam em pé. O tamanho voltou a ser quase proporcional
(pintinho miúdo, robô enorme).

**3. No movimento, todo mundo dava o mesmo pulinho.** Agora cada corpo anda de
um jeito (`_walk_anim` em `unit_base.gd`): casco trota ou galopa, ave cisca
rebolando, sapo salta e agacha, jacaré ginga rente ao chão, assombração
flutua, trator treme com o motor, grandão pisa pesado e levanta poeira,
inseto zumbe. E cada um bate de um jeito: marretada, giro da foice, cabeçada,
bicada, estocada.

**Lendária fraca ou forte?** Nenhuma lendária/mística mediu fraca: Assombração
vence 46% dos duelos (o normal pra custo 20 é 27%), Urubu de Plantão 66%
(normal 39%), Tatu Bola 49% (39%), Jacaré 74% (65%), Disco Voador 94% (84%),
Boi da Cara Preta 94% (71%), Cacto 46% (46%), Lenhador 60% (65%). O problema
era não dar pra VER isso: os números da carta (70 de vida!) enganam. Agora o
detalhe da carta mostra a **⚔️ Força medida**: quantas tropas ela vence, o
normal pro preço, de quem ganha, pra quem perde e quanto tira de uma torre
sozinha (`Scripts/duelos_medidos.gd`, gerado pelo laboratório — rodar de novo
quando mexer em número de carta).

Efeito colateral medido e compensado: com as tropas mais afiadas, 19 de 40
partidas entre bots acabavam em nocaute; a vida da torre subiu de 1,45x pra
1,62x e voltou pra 11 de 40 (antes da mudança: 17 de 60).

Bug achado no caminho: duas cartas que devolvem dano (Tatu, Cacto, Robô)
brigando entre si entravam num vai-e-volta sem fim e travavam o jogo.

### Segunda leva (19/11 à noite) — pedidos do João depois de ler o acima

**"Cavalo e bezerro ainda são parecidos; lá tem cavaleiro, goblin, bem
separado. Dá uma enchida. Pode ter tema além de roça: mar, bicho, ET, mito."**

- Cada bicho ganhou o SEU corpo (não mais um corpo de casco pra todos): vaca
  parruda de úbere, bezerro baixinho de meia branca, cavalo alto de crina e
  rabo comprido, bode peludo, jegue de listra no lombo, cachorro magro de rabo
  enrolado, capivara em barril.
- 16 cartas novas, cada uma de um TIPO que não existia, em 2 turmas novas
  (**Mar** e **Lendas**) mais as antigas:
  - Mar: Tubarão de Botas, Caranguejo Gigante, Polvo Tinteiro, Água-viva Elétrica
  - Lendas: Saci (pula numa perna só e dá bote), Mula sem Cabeça, Mapinguari
    (gigante), Boitatá, Dragão do Milharal, Medusa, Cérbero
  - Coisa Estranha: Marcianinhos, Tripé Invasor (raio que esquenta no mesmo alvo)
  - Roçado/Peões/Brejo: Correição de Saúva (9 formigas), Vaqueiro Montado, Onça-Pintada
- Medido de novo com o elenco inteiro (52 tropas de duelo, 1326 duelos): lista
  única acerta 86% (era 91%); entre cartas de preço parecido 79% (era 88%);
  trios pedra-papel-tesoura 11,4% (era 4,9%); duelos apertados 19% (era 14%).
  Sozinhas, só cartas de custo 50+ derrubam uma torre (12 de 64).

**"Carta sem dano, tipo a Pinga da Braba, não evolui."** Era verdade: o nível
só multiplicava vida e dano. Agora (`Regras.apply_level`) cresce junto tudo que
é número de força: explosão, onda de choque, cura, regeneração, escudo, veneno,
cura ao matar. E feitiço de efeito (fúria, escudo, congelar, marca) passa a
DURAR mais a cada nível (+9% por nível). A carta mostra isso em verde.

**"Deixa a info mais parecida com a do Clash."** Atributos em duas colunas com
ícone (vida, dano, dano por segundo, vel. de ataque, alvos, alcance, velocidade
com o número, tipo, quantidade, entrada em campo, custo) e cada HABILIDADE numa
linha com o número dela e o ganho do próximo nível — no lugar dos parágrafos
de "Detalhes" e da lista de estrelas.

**"Atualiza o atualizador, pra ficar tudo coerente. Carta nova vem ajustada?"**
O criador automático (Safra, `creator/card_generator.gd`) foi conferido com
`ci/lab/safra.tscn`, que gera 45 safras futuras e estima cada carta:

- Antes: carta Normal/Rara de Controle, Suporte ou Punição saía sem a
  habilidade do papel dela E com o desconto que "pagava" por ela — até 16
  pontos abaixo do normal pro preço. E carta de Cerco e a receita "de longe"
  atiravam de mais longe que a torre nova: custando 15–40, derrubavam uma torre
  sem levar um tiro.
- Agora: o desconto volta quando a habilidade sai; força da safra 16,5 (era
  15); alcance de cerco e "de longe" abaixo do da torre; bando frágil que bate
  muito, matador de golpe espaçado; bicho sem ferramenta de quatro patas com o
  corpo dele. Média das tropas geradas: +2,7 pontos do normal pro preço.
- Como a safra é refeita da semente toda vez que o jogo abre, as cartas de
  safra que o João JÁ TEM mudam junto (mesmo nome e desenho da cabeça, números
  e corpo novos).
- Safras a partir do período 6926 também sorteiam as turmas Mar e Lendas (as
  anteriores continuam iguais).
- Carta que o laboratório não mediu (safra, carta criada, carta mexida pela
  Assembleia) mostra **Força estimada** em vez de medida: `Scripts/duelo_papel.gd`
  faz o duelo "no papel", só com os números. Conferido contra os 1290 duelos
  de verdade: acerta o vencedor em 93%, erra em média 4,6 pontos na % de
  vitórias e 4,5 pontos no dano em torre (`rodar.sh papel`).

### Terceira leva (19/11, mais tarde) — 12 arenas, ataque na carta, 4 na mão, portão

**"Coloca na carta se o ataque é aéreo, em área, tamanho da área, corpo a
corpo. Deixa bem definido."** A carta ganhou o painel **🗡 Ataque** com quatro
etiquetas: ELA (anda no chão / voa), DISTÂNCIA (corpo a corpo / de longe, com
o número), FORMA (um alvo / área, com o tamanho) e ACERTA (chão, ar, os dois,
só torre). Carta de área também troca a espadinha pelo ícone de área na
miniatura.

**"Em vez de 7 arenas arruma 12, cada uma com tema e as cartas dela, 12 cartas
por arena. Liga o atualizador em todas."**

- 12 arenas (`arenas/arena_manager.gd`), cada uma com cenário e tema: Pasto
  Verde, Curral Velho, Terreiro, Milharal, Brejo, Vila da Feira, Praia da Maré,
  Mata Fechada, Noite Estranha, Encruzilhada, Monte dos Mitos, Arena do Rodeio
  (0 a 8000 troféus).
- Toda carta foi pra arena do tema dela, e 2 turmas novas apareceram: **Mata**
  (onça, saúvas, abelhas...) e **Mitos** (dragão, medusa, cérbero...).
- São **144 cartas**: as 73 feitas à mão + 71 que o criador automático fez pra
  completar 12 por arena (`Catalogo._build_arena_cards`, semente fixa: são
  sempre as mesmas, em todo aparelho). Cada arena recebe papéis diferentes
  (tanque, bando, matador, atirador, voador, controle...) pra não repetir.
- Medido (`LAB_ARENAS=1 rodar.sh` → `ci/lab/safra.tscn`): as tropas geradas
  ficam em média 1,0 ponto abaixo do normal pro preço (não tem carta de graça),
  e nenhuma de custo menor que 50 derruba torre sozinha.
- Safras novas (período 6926 em diante) sorteiam também Mata e Mitos, com os
  bichos e cabeças novos dessas turmas; as safras anteriores não mudam.
- **Não medido:** as 71 cartas geradas não passaram pelo duelo de verdade
  contra todas as outras (a carta delas mostra "Força estimada"), e ninguém
  jogou com elas.

**"3 torres, uma na frente e duas atrás, o contrário do Clash. A da frente com
menos vida. Quem derrubar mais ganha, não precisa derrubar todas; ninguém
derrubou, empate ou ganha quem tem mais vida. E 4 cartas na mão."**

- Regra `portao` (`Scripts/regras.gd`, liga/desliga em Configurações >
  Laboratório): o **portão** fica no meio, a 196 do rio (as de trás a 380),
  com 60% da vida de uma torre de trás, tiro 25% mais fraco e alcance 15%
  menor. Como toda tropa anda pra torre mais perto, o portão é sempre o
  primeiro alvo; depois que ele cai, cada rota vai na sua torre de trás.
- Fim de partida (`batlhe_scene.time_up_loser`): 1º quem derrubou mais torres
  (uma já basta); 2º quem tem mais vida sobrando somando as torres; igual de
  verdade = empate. Derrubou as três, acaba na hora. O placar 🏰 fica embaixo
  do relógio.
- Regra `mao4`: 4 cartas na mão (baralho continua com 7), pro jogador e pro bot.
- Medido entre bots iguais, mesmas cartas e nível (`rodar.sh lote` + `placar.py`):

  | | 2 torres (24 partidas) | portão (48 partidas) |
  |---|---|---|
  | acabou sem NENHUMA torre cair | 15 (63%) | 3 (6%) |
  | decidida no placar de torres | 4 | 35 (73%) |
  | decidida só na vida | 15 | 9 |
  | nocaute (todas as torres) | 5 | 3 |
  | os dois lados perderam torre | 0 | 10 (21%) |
  | 1ª torre cai (mediana) | 116 s | 101 s |
  | viradas na vida, por partida | 0,38 | 0,33 |

  Placares com portão: 1x0 em 29, 1x1 em 7, 2x0 em 5, 2x1 em 1, 3x0 em 1, 3x1
  em 2, 0x0 em 3.
- **O que isso diz:** com o portão quase toda partida tem torre caindo e é
  decidida por torre, não por porcentagem de vida. **O que não melhorou:** 60%
  acabam 1x0 e virada no placar é rara (3 em 48) — entre bots, quem derruba o
  primeiro portão quase sempre leva. Portão com 45% ou 80% da vida não mudou
  isso de forma que desse pra separar do acaso (24 partidas cada).
- **Não medido:** partida de gente contra bot, e se 4 cartas na mão mudam a
  partida (só foi conferido que funciona e cabe na tela).

**"Não consigo abrir um baú sem abrir outro."** Bug: o baú que já tinha ficado
PRONTO, mas ainda não tinha sido pego, continuava contando como "o baú que
está abrindo" e travava a fila. Agora só trava quem está contando o tempo de
verdade (`Progresso.unlocking_index`). A Chave também parou de escolher o baú
pronto quando existe outro esperando.

### Quarta leva (19/11, noite) — "virou ficar jogando carta no meio" e "as cartas estão sem identidade"

O João jogou a versão do portão e disse: *"simplesmente o jogo virou de ficar
jogando carta no meio, e não é isso"*, *"precisa de mais IA"* e *"as cartas
estão sem identidade, e não digo só de visual"*.

**O meio.** A causa é o próprio portão: toda tropa vai na torre mais perto, e
ele é sempre a mais perto. Tentativa de salvar: regra `rotas` (a tropa segue a
rota onde foi solta: lado = torre de trás daquele lado, meio = portão) e o
portão recuado de 196 pra 270, pra ficar coberto pelas duas de trás. Medido
entre bots (24 partidas cada):

| | portão + rotas | 2 torres |
|---|---|---|
| cartas jogadas na rota do meio | 67% | 4% |
| primeira torre a cair | portão em 15 de 15 | — |
| partidas sem torre cair | 9 | 10 |

Mesmo com as rotas, o portão é a torre mais fraca e a mais na frente: ele É o
jogo. **Decisão: o portão volta pro Laboratório, DESLIGADO de fábrica**
(`Regras.DEFAULT_OFF`). Quem ligar ganha as 3 rotas junto, com a linha
tracejada mostrando em que torre a tropa vai. As 4 cartas na mão ficam.

**Mais IA** (`AI/battle_brain.gd`, `AI/push_plan.gd`):

- Defesa: o bot escolhia a carta pelo "papel" dela numa tabela. Agora faz a
  conta do duelo de verdade entre a carta dele e a que está vindo
  (`BattleBrain.duel_margin`, o mesmo cálculo da "Força estimada", que acerta
  o vencedor em 93% dos duelos medidos) e prefere a troca boa: ganhar gastando
  menos do que o outro gastou.
- Com o portão ligado, escolhe a rota contando quantas torres atiram em quem
  chega em cada uma (antes ia sempre no meio).
- Tamanho do ataque e chance de punir quem ficou sem recurso passaram a
  escalar pelas 12 arenas (paravam na 7).
- Medido com `LAB_AB=P|E` (um lado com a IA antiga, o mesmo par de baralhos
  jogado duas vezes trocando quem fica com a antiga), 48 partidas no campo de
  2 torres: **IA nova 31, IA antiga 16, 1 empate**. Com o portão ligado, em 30
  partidas: nova 21, antiga 9.
- O que NÃO mudou: bot contra bot, 10 de 24 partidas ainda acabam sem torre
  cair (decididas na vida). É medida entre bots; com gente jogando não foi medido.

**Identidade.** Duas causas medidas, nenhuma era desenho:

1. *Metade do elenco era enchimento.* Das 58 tropas que o criador fez pra
   completar as 12 arenas, **41 não tinham habilidade nenhuma** e 15 eram
   quase cópia de outra carta (Polvo Parrudo = Bode Parrudo, número por
   número). Nomes como "Robô Ligeiro Gourmet" e "Vaca 3000" não diziam nada.
   Agora (`Catalogo._sign_arena_card`) toda tropa criada tem UMA assinatura que
   combina com o papel, sem repetir no mesmo papel e no máximo 2 vezes no
   elenco, e o nome diz qual é: Tamanduá Disparado (investida), Siri Carrasco
   (executa), Polvo Espinhento (devolve dano), Cavalo Ladrão (rouba recurso).
   Feitiço criado diz o efeito e de onde vem ("Trovão do Mar"). Sobraram 0
   tropas sem habilidade e 0 cópias entre as criadas. Pelo estimador elas
   ficam 4 pontos abaixo do normal pro preço (de propósito, do lado fraco).
2. *O "papel" não dizia como a carta luta.* Punição, Contra-ataque, Versátil,
   Finalizador... Reclassificando pelo jeito de lutar e olhando só duelo de
   preço parecido (±10), a pedra-papel-tesoura **já existia nos números**:

   | linha ganha da coluna | Bando | Matador | Tanque | Área | Atirador | Voador | Lutador |
   |---|---|---|---|---|---|---|---|
   | Bando | · | 83% | 88% | 0% | 54% | 0% | 26% |
   | Matador | 17% | · | 61% | 67% | 87% | 0% | 61% |
   | Tanque | 12% | 37% | · | 64% | 73% | 11% | 70% |
   | Área | 100% | 33% | 36% | · | 100% | 0% | 100% |
   | Atirador | 46% | 9% | 27% | 0% | · | 76% | 16% |
   | Voador | 94% | 100% | 89% | 100% | 22% | · | 100% |
   | Lutador | 63% | 28% | 30% | 0% | 67% | 0% | · |

   Só que o jogo não contava isso pra ninguém. Agora toda carta tem um **TIPO**
   (`Catalogo.kind_of`, sai dos números dela): Bando, Matador, Tanque, Área,
   Atirador, Voador, Lutador, Derruba-torre, Apoio, Construção, Feitiço. Ele
   aparece escrito na carta (no lugar de "Chão"/"Chão+Ar") e a info abre com
   "TIPO — pra que serve — ganha de — perde pra". A tela do baralho avisa o que
   falta ("nada que limpe Bando", "nada que acerte Voador").
   - Marcianinhos (bando de atirador) perdia 12 de 15 duelos de preço
     parecido: dano 48 → 66.

**Versão na tela.** `Scripts/versao.gd` é reescrito pelo build com o número e
a hora; aparece na tela inicial e em Configurações. (O João baixou o APK novo
e abriu o antigo sem perceber.)

**Não medido:** nada disto foi jogado no celular. As cartas criadas continuam
sem duelo de verdade (só estimativa). A tabela acima é das cartas feitas à
mão, medidas antes das mudanças desta leva.

### Quinta leva (20/11) — base principal + módulos, baralhos dos bots, níveis de 1 a 14

Depois de uma manhã de desenhos descartados (portão, torre de comando, três
torres iguais, colheita, campo cruzado), o João fechou o campo: *"uma base
principal e 6 pontos em volta, 3 pra frente e 3 mais atrás; a base principal
não muda, o que muda são os módulos"*.

**Campo (regra `modulos`, ligada de fábrica; desliga no Laboratório).**

- **Casa Grande** (base principal) no meio, a 330 do rio. Igual pros dois
  lados, no nível mais alto de torre dos dois. Caiu, acabou a partida.
- **6 pontos** em volta (`Regras.MODULE_POINTS`): frente esquerda / meio /
  direita, lado esquerdo / direito, atrás da base.
- Cada lado põe **2 módulos** onde quiser (`Progresso.module_loadout`,
  `set_module`). Módulo derrubado para de funcionar na hora (recurso e
  capacidade voltam ao normal) e vale 1 no placar. Fim do tempo: mais módulos
  derrubados, depois vida, depois empate.
- **Só módulo de tiro atira.** Os outros valem pela função.
- Os módulos são as torres que já existiam (10) + 3 novos: Guarita do Caramelo
  (solta tropa quando apanha), Estábulo Ligeiro (cartas de até 30 andam 25%
  mais rápido), Curral de Engorda (um Peão de graça a cada 28 s). Raridade e
  criação pela Safra já existiam pras torres e continuam valendo.
- Aba **Módulos** (era Torres): mapa dos 6 pontos pra tocar e mover, e a lista
  com "pôr no lugar de...".
- O bot escolhe 2 módulos (sempre os mesmos pra cada bot) e nunca deixa a base
  sozinha: dois de defesa guardam as rotas do lado; um só fica na frente do
  meio; módulo de recurso vai pra trás.

Medido entre bots, mesmas cartas e nível (`LAB_MODULOS=2`: módulos sorteados
entre todos, postos pela regra do bot), 36 partidas, base com 2300 de vida:

| | 2 torres (ontem, 24) | módulos (36) |
|---|---|---|
| acabou sem nada cair | 10 | 2 |
| os dois lados perderam alguma coisa | 0 | 10 |
| base principal derrubada (fim na hora) | — | 14 |
| partidas com menos de 2 minutos | 0 | 3 |
| cartas jogadas esquerda / meio / direita | 45 / 4 / 52% | 23 / 56 / 21% |

- **Melhorou:** quase toda partida tem coisa caindo e em 10 de 36 os dois
  lados perdem algo (era 0).
- **Atenção:** a base cai em 14 de 36 (39%) e 56% das cartas vão no meio,
  porque metade dos arranjos do bot tem um módulo só na frente, no meio. Não é
  o "tudo no meio" do portão (67%, sempre o primeiro a cair), mas o meio pesa.
  Com a base em 1500 de vida ela caía em 15 de 36; em 1850, 18 de 36 (já com
  os baralhos novos, mais ofensivos); ficou em 2300.
- **Não medido:** cada módulo sozinho (13 módulos em 36 partidas é pouco pra
  dizer qual é forte demais), e nada com gente jogando.

**Baralhos dos bots** (`ci/lab/decks.tscn`, jogo novo, 101 bots). O João: *"os
bots não tinham estratégia de montar combos ou usavam o mesmo deck repetitivo
demais"*. Medido, ele estava certo:

| | antes | agora |
|---|---|---|
| cartas diferentes em uso | 12 de 144 | 35 |
| cartas iguais entre dois bots (de 7) | 4,1 | 2,2 |
| pares de bots com 5+ cartas iguais | 1616 de 5050 | 129 |
| baralhos sem carta que derruba torre | 23 | 6 |
| baralhos sem nada que limpe bando | 37 | 0 |

`DeckBuilder.plan_deck`: todo baralho nasce em volta de uma dupla (quem
derruba torre + a escolta que atira e pega voador) mais as respostas (limpa
bando, derruba tanque, carta barata, feitiço) e uma vaga do gosto do bot. Cada
bot escolhe as cartas dele por vaga, e pode usar carta de até 2 arenas acima
(na arena 1 só existiam 12 cartas pra todo mundo). Vale pros bots que já
existem (`DECK_STYLE_VERSION` 4 refaz o baralho uma vez). Na partida o bot já
atacava em bloco (líder na frente, apoio atrás); faltava o baralho ter as peças.

**Níveis de 1 a 14** (eram 9), **+10% por nível** (eram +15%). No 14 a carta
tem 2,3x o nível 1; antes, 2,2x no 9. Os 8 primeiros degraus de cópias são os
de antes; os 5 novos continuam a escada. Bots: até 1120 troféus sobem como
antes (nível 9), depois 1 nível a cada 600. Maestria continua no nível 9.
Vida aparece em número redondo (3890, não 3888). **Efeito colateral:** carta
que já estava no nível 2 a 9 fica um pouco mais fraca do que era (nível 9:
2,2x → 1,8x), igual pra você e pros bots.

### Sexta leva (20/11, depois de jogar a 106) — vida das torres, criador de módulos, votação, mais bots

**"Tá com HP demais."** Vida de torre/módulo: 1,62 → **1,3** da vida de base
(−20%); Casa Grande: 2300 → **2000** de base. No nível 1 o Celeiro fica com
1690 (era 2110) e a Casa Grande com 2600 (era 3730). Medido entre bots, 36
partidas cada, módulos variados:

| | antes (1,62 / 2300) | agora (1,3 / 2000) |
|---|---|---|
| base principal derrubada | 14 (39%) | 24 (67%) |
| duração (mediana) | 240 s | 214 s |
| partidas com menos de 2 min | 3 | 9 |
| acabou sem nada cair | 2 | 0 |

É a troca: menos vida = partida mais curta e decidida na base. Outras duas
tentativas (base ainda mais baixa) deram 24 e 21 de 36 — nessa faixa a vida da
base quase não muda o resultado, quem manda é a vida dos módulos da frente.

**Criador automático de módulos.** A Safra já criava uma torre a cada 2
safras, com raridade. Da safra 6928 em diante ela também sorteia os três tipos
novos (acelera cartas baratas, solta tropa quando apanha, dá tropa de graça).
Safras antigas não mudam. **Não medido:** nenhum módulo criado foi posto em
partida; só confere que a ficha sai dentro da faixa dos feitos à mão.

**Votação (Assembleia).** O João: *"acontece tudo de uma vez e os bots votam
tudo igual"*. Os dois termos que mandavam no voto eram iguais pra todo bot (a
taxa de vitória e o uso da carta); o que era de cada bot valia no máximo 0,1.
Agora cada bot tem temperamento e opinião por carta (sempre os mesmos pra
ele), e vota num momento dele dentro dos 3 dias: os votos chegam aos poucos e
a tela mostra quantos ainda vão votar. No fechamento conta todo mundo.
**Não medido:** não rodei uma pauta de ponta a ponta com a população nova.

**Mais bots.** Eram 101 fixos + os que nasciam perto de você. Agora a
população sobe até 220, no máximo 12 por vez (pra não travar), espalhados
pela tabela. **Atenção:** telas que percorrem todos os bots (ranking,
Assembleia) vão trabalhar o dobro; não foi medido no celular.

### Sétima leva (20/11, depois de jogar a 107/108) — "não acaba", "as cartas perderam a noção", espaços por nível

O João mandou uma foto: 3 minutos de partida, 0 × 0, todas as torres cheias.
"Praticamente impossível acabar, [a torre] tá muito forte e as coisas fracas."
E sobre as tropas: "tem umas que são fracas e estão gigantes", "olha o tamanho
das abelhas".

**O erro de medida era meu.** Tudo que estava escrito acima foi medido em
partida "justa": dois robôs completos, cartas no nível 5, baralhos de bots de
todas as arenas. O caso dele nunca tinha sido medido: perfil novo, baralho
inicial, nível 1, contra o bot que o pareamento escolhe. Agora tem o modo
`LAB_NOVATO=1` (com `LAB_HUMANO=1 LAB_BOT=1`, sem `LAB_FAIR`) e o
`placar.py` continua valendo; o resumo do ponto de vista do jogador é o `ci/lab/novato.py`. 24 partidas de cada:

| caso de quem começa | acaba antes do tempo | ninguém derruba nada | jogador não derruba nada |
|---|---|---|---|
| versão 108, 2 módulos | 4 | 2 | 5 |
| 1 módulo (regra nova dos espaços), sem mais nada | 6 | **11** | 12 |
| + Casa Grande dormindo | 5 | 6 | 9 |
| + tiro da torre 74 → 58 (1 módulo) | 9 | 4 | 9 |
| idem, 2 módulos | 7 | 0 | 7 |

O "jogador" dessas partidas é um robô simples (defende e, com 55 de recurso,
solta uma tropa qualquer), então o número absoluto vale pouco; a comparação
entre linhas é o que conta. Entre robôs fortes (justa, 2 módulos, 40 partidas)
o mesmo ajuste dá base derrubada em 29, duração mediana 214 s e 14 partidas com
menos de 2 minutos: lá a partida já é rápida, por isso a vida não desceu mais.

**O que mudou na batalha.**

- **A Casa Grande dorme** (`player_base.asleep`, `Regras.main_sleeps`): não
  atira até levar dano ou perder um módulo. É a torre do rei do Clash. Antes,
  quem atacava um módulo da frente ficava no alcance do módulo E da Casa Grande
  (178 de distância entre os dois, alcance 215): 148 de dano por segundo em
  cima de um Peão de 640 de vida.
- **Tiro de torre 2,3× → 1,8×** (Celeiro 74 → 58) e **vida 1,3 → 1,2**
  (Casa Grande 2600 → 2400, Celeiro 1690 → 1560 no nível 1).
- Testei encurtar o alcance da Casa Grande (130) e não serve: a distância do
  tiro das tropas é medida da borda, então atirador comum (alcance 125) batia
  nela de fora. Ficou o alcance de sempre, com o sono.

**Espaços de módulo por nível** (`Regras.MODULE_SLOT_LEVELS = [1, 5, 13]`):
nível dos módulos 1 a 4 = 1 módulo, 5 a 12 = 2, 13 e 14 = 3. Na partida os
dois lados entram com a quantidade do jogador (`bot_module_loadout(perfil,
espaços)`), pra ninguém jogar com um módulo a mais. O que estava guardado além
dos espaços de hoje continua guardado. Entre robôs fortes as três faixas
saíram parecidas (base derrubada em 21/22/22 de 40, mediana 231/231/233 s).
Com um módulo só **na frente do meio**, 98% das jogadas dos bots foram no
meio (o mesmo defeito do portão): módulo sozinho agora vai pra um lado.

**Módulo repetido.** O mesmo módulo pode ocupar todos os espaços. 60 pares de
partidas, mesmo sorteio, o lado P com dois iguais ou com dois diferentes: 23
vitórias nos dois casos. 1 em cada 5 bots leva dois iguais (nunca de recurso).
Dois módulos de velocidade somam (teto +60%).

**Tamanho = força × porte** (`Regras.strength_scale`, `Catalogo.porte`). O
tamanho era um número escrito carta por carta e a curva do desenho espremia
todo mundo (galinha de 150 de vida com 87% do tamanho do Peão). Agora sai da
vida (+ um pouco do dano do golpe) vezes o porte do bicho, tirado do desenho:
abelha/mosquito/formiga 0,6, galinha/pato/sapo 0,8, gente 1,0, vaca/cavalo
1,15, mapinguari 1,25. Na tela (1,00 = desenho original): abelha 0,97 → 0,49,
pintinho 0,90 → 0,53, galinha 1,31 → 0,74, Peão 1,50 → 1,31, Vaca Brava 2,12
→ 2,11, Robô Balde 3,04 → 2,41. Construção fica com o tamanho da carta.

**Defeito achado no laboratório.** Na partida "justa" os dois lados são
`BotController`, que têm o próprio dinheiro: módulo de recurso (Moinho,
Tanque de Leite, Armazém) não faz nada lá. O valor deles nunca foi medido.

**Bug da coleção (105 a 107).** O aviso "o que falta no baralho" usava texto
com quebra automática dentro da doca fixa; a doca "media" 2031 px e o espaço
reservado embaixo dela empurrava a coleção pra fora da tela. Teste novo
`CI_MODE=telas` abre o menu de verdade e confere isso, os espaços e os
tamanhos.

### Oitava leva (20/11) — Criador novo ("oficina")

Pedido do João: um Criador "profissional", que mexa em tudo (visual e lógica)
de qualquer carta, módulo e feitiço, sem ser uma lista comprida, mantendo o
criador automático da safra. A parte de salvar já existia e ficou igual
(`CustomContent`: carta do jogo editada fica guardada à parte e tem "↺
Original"). O que mudou foi a tela (`creator/creator_menu.gd`):

- **Cabeçalho fixo**: arte ao vivo, tipo detectado pelos números
  (`Catalogo.kind_from`), a **régua** (vida, dano e força em % do padrão) e a
  tropa desenhada no tamanho de campo ao lado de um Peão e da Casa Grande.
- **Abas**: Básico, Combate, Habilidades, Visual, Teste (tropa); Básico,
  Efeito, Visual (feitiço); Básico, Função, Visual (módulo).
- **Habilidades** como botõezinhos em 6 grupos (`ABILITIES`): só a ligada abre
  os números dela, já com um valor inicial. Campo novo do `UnitData` que não
  estiver em nenhum grupo aparece em "Outros números".
- **Régua** (`creator/regua.gd`): o padrão de cada tipo é a mediana das cartas
  do próprio jogo (vida total por custo, dano por segundo por custo,
  quantidade, velocidade, alcance). "Preencher pelo padrão" põe os números do
  tipo escolhido pro custo da carta, e o tamanho pela regra força × porte.
- **Arte por peças**: postura, cabeça, corpo, braços, pernas, chapéu, arma,
  costas e 6 cores (`SpriteForge`), além do desenho pixel a pixel.
- **Teste**: contas feitas na hora com os números da tela
  (`DueloPapel.duel_stats`, `tower_share_stats`): quanto tira de uma torre
  sozinha e o duelo contra 10 cartas de custo parecido.
- **Módulo**: função com só os campos dela, os campos novos (solta tropa,
  velocidade, arena) e o que os números viram no campo.
- O `−`/`+` não arredonda mais o número que já estava na carta (2300 de vida
  aparecia como 2301; 32 de dano como 30).

A régua mostra que várias cartas do jogo fogem do padrão do próprio tipo
(Vaca Brava: 192% da vida de um Derruba-torre de custo 40). Não mexi nelas:
é o que o João quer acertar à mão pelo Criador.

### Nona leva (20/11) — mecânicas que faltavam em relação ao Clash

O João pediu todas menos a habilidade com botão (não gosta de campeão). Todas
têm campo no Criador e teste em `CI_MODE=novas`. Nenhuma carta do jogo usa
ainda: é matéria-prima pro Criador.

| mecânica | onde | campos |
|---|---|---|
| Carta de duas tropas | `CardData`, `Catalogo.apply_companion` | `companion_id`, `companion_count` |
| Feitiço que rola (Tronco) | `SpellEffect._roll` | `rolls`, `roll_distance`, `roll_speed` (não acerta voador) |
| Feitiço que escolhe alvo (Relâmpago) | `SpellEffect._apply_tick` | `picks_strongest` |
| Espelho | `batlhe_scene.cast_spell`, `_last_card` | `mirror` (custo fixo da carta, não "o da última + 1") |
| Construção que se esconde (Tesla) | `unit_base.is_hidden` | `hides_underground` (sem alvo, não apanha nem de feitiço) |
| Cura a cada golpe (Curandeira) | `unit_base._perform_attack` | `heals_on_attack`, `attack_heal_amount`, `attack_heal_radius` |
| Segundo ataque (Domador / atiradores nas costas) | `unit_base._process_extras` | `rider_*` (só em tropa, nunca em torre) |

O "Goblin Gigante" sai de segundo ataque com `rider_count` > 1 mais "invoca ao
morrer", que já existia. A régua e o duelo de papel do Criador não enxergam
estas mecânicas, e os bots jogam o Espelho como um feitiço qualquer.

### Décima leva (20/11) — começar do zero, Espelho do bot, recurso e transparência

- **Começar do zero** (`CustomContent.zero_on/zero_pool/apply_zero`, chave
  `do_zero`): o jogo passa a usar só as cartas criadas no Criador (coleção,
  baralho do jogador em `DeckManager.start_deck`, baralho dos bots em
  `_start_ai_hand` e `BotController.setup`). Nada é apagado: as cartas do jogo
  saem de `CardDatabase.all_cards` e voltam ao desligar. Com menos de 7 cartas
  próprias, o baralho inicial completa. Feira, baús, arenas e torneio NÃO foram
  revistos nesse modo.
- **Cópia de segurança**: `backup_save/backup_restore` copiam `user://custom`
  pra `user://custom_copia` e de volta.
- **Safra pausada** (`safra_pausa`): não colhe safra nova; as já colhidas ficam.
- **Bot e Espelho** (`ai_can_play`): só joga com carta anterior de custo parecido.
- **Recurso**: 1 ponto a cada 0,28 s (era 0,25). No Clash é 1 de elixir a cada
  2,8 s, e 1 de elixir = 10 pontos daqui.
- **Transparência**: tropa entrando em campo 78% → 92% de opacidade; invisível
  ou imune andando 40% → 60%.

### Décima primeira leva (20/11) — baralho de 8, carta enxuta, oportunidade na Feira, Criador na barra

- **Baralho de 8** (`Progresso.DECK_SIZE`, `BotLearning.DECK_SIZE`), 4 na mão,
  como no Clash. O baralho inicial ganhou o Milho Pipoqueiro; baralho salvo com
  7 é completado sozinho (`_valid_deck`); os bots remontam o deles
  (`DECK_STYLE_VERSION = 5`).
- **Tela da carta**: números em quadradinhos, uma caixa só com o tipo (como
  luta, de quem ganha, de quem perde) e o resto atrás de "Mais detalhes". Antes
  "ganha de / perde pra" aparecia em três painéis.
- **Feira**: "Oportunidade de hoje", um negócio diferente por data, uma vez por
  dia (`Progresso.OPPORTUNITIES`).
- **Criador** com botão próprio na barra de baixo.
- O "HUD em geral" não foi redesenhado: ficou pra uma rodada própria, com foto.

### Décima segunda leva (20/11) — 35 peças de arte novas (guerra e máquina)

`ci/tools/arte/militar.py`, no clima dos jogos de estratégia dos anos 2000,
com desenhos próprios: 10 veículos (tanque, tanque duplo, jipe, lança-míssil,
artilharia, helicóptero, dirigível, andador, submarino, caminhão), 8 prédios
(bobina, prisma, bunker, radar, usina, refinaria, quartel, canhão grande), 8
ícones (míssil, bomba, paraquedas, mira, engrenagem, estrela, onda, relógio), 3
chapéus, 3 armas e 3 projéteis. Atlas: 187 → 222 peças. Aparecem no Criador
(montar por peças); nenhuma carta do jogo usa ainda, e o criador automático
tem lista própria de peças, então as cartas dele não mudaram.

## Ficou pra depois (não mexido)

- (19/11, pedido do João) A partida passou pra 4 minutos, com recurso em dobro
  só no último. Entre bots: 17 de 60 acabam em nocaute, o resto é decidido na
  vida das torres quando o tempo acaba. Com x2 nos 2 últimos minutos seriam 28.
- (19/11) Espaço pessoal: tropas do mesmo lado que não estão brigando passam a
  ficar 1,35 corpo de distância (antes 0,85) -- menos boneco empilhado no
  mesmo ponto. Vale só com a regra "visual" ligada.
- Cartas que sozinhas ainda tiram bastante da torre pro custo: Assombração
  (20 → 38%), Abóboras (25 → 37%), Cavalo (35 → 56%).
- Nível pesa 15% em vida E dano por nível (Clash ≈ 10%). O João achou que
  não é o principal.
- Baralho de 7 (Clash: 8). A mão passou pra 4 em 19/11.
- Começa a partida com 5 de 100 de recurso (Clash começa com metade).
- Bug antigo: popup do baú abre por cima da carta aberta.
- Voadores dominam duelo (Mosquito, Abelha, Urubu, Boi da Cara Preta): tropa
  de chão sem tiro não encosta neles. É de propósito (no Clash também), mas
  vale olhar se enjoar.
- Aves ainda dividem o mesmo corpo (pinto, galinha, galo, pato, coruja).
- As 16 cartas novas, a info nova, as 12 arenas com as 71 cartas geradas, o
  portão e a mão de 4 NÃO foram jogados no celular: só medidos aqui (duelos,
  torre, partidas entre bots, bateria de testes, fotos da tela).
- O portão usa o mesmo desenho da torre, só menor. Um desenho próprio (uma
  porteira) deixaria mais claro.
- Replays gravados antes do portão não batem mais (o campo mudou).
- Estimativa no papel não conta filhote que nasce na morte nem cura em área.
- Som: cada tropa ainda usa os mesmos sons de golpe.
