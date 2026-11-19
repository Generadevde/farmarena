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
- `REGRAS_OFF=torres,visual,peso` na frente = regras antigas, pra comparar

O teste `CI_MODE=regras` (em `ci/battle_test.gd`) garante no GitHub que a
torre continua defendendo.

## Ficou pra depois (não mexido)

- (19/11, pedido do João) A partida passou pra 4 minutos, com recurso em dobro
  só no último. Entre bots: 17 de 60 acabam em nocaute, o resto é decidido na
  vida das torres quando o tempo acaba. Com x2 nos 2 últimos minutos seriam 28.
- (19/11) Espaço pessoal: tropas do mesmo lado que não estão brigando passam a
  ficar 1,35 corpo de distância (antes 0,85) -- menos boneco empilhado no
  mesmo ponto. Vale só com a regra "visual" ligada.
- Cartas que sozinhas ainda rendem demais pro custo: Assombração (20 → 38%),
  Abóboras (25 → 41%), Bezerrada (25 → 44%), Cavalo (35 → 56%).
- Nível pesa 15% em vida E dano por nível (Clash ≈ 10%). O João achou que
  não é o principal.
- Mão de 3 cartas e baralho de 7 (Clash: 4 e 8) — é do projeto original.
- Começa a partida com 5 de 100 de recurso (Clash começa com metade).
- Bug antigo: popup do baú abre por cima da carta aberta.
- As artes vêm todas do mesmo molde de corpo (SpriteForge): maiores elas se
  distinguem bem melhor, mas poses diferentes por carta ajudariam mais ainda.
