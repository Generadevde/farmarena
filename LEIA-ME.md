# Farm Arena 2.0

Jogo de cartas e torres offline (estilo Clash Royale, tema roça), feito em Godot 4.7 para celular em pé.

**Instalar no celular:** https://github.com/Generadevde/farmarena/releases/latest/download/farmarena.apk
(cada alteração enviada para o GitHub gera um APK novo sozinho, em uns 5 minutos)

## O que tem

- **Batalha**: arena simétrica, rio com 3 passagens. Cada lado tem a **Casa Grande** (base principal: caiu, acabou; começa dormindo e só atira depois de levar dano ou de perder um módulo) e **de 1 a 3 módulos** (1 até o nível 4 dos módulos, 2 do 5 ao 12, 3 do 13 em diante; pode repetir o mesmo) que você escolhe e põe nos 6 pontos em volta dela. Módulo derrubado para de funcionar e vale 1 no placar; se o tempo acabar, ganha quem derrubou mais e, empatando, quem tem mais vida. Partida de 4 minutos, 4 cartas na mão (baralho de 7), recurso de 0 a 100, em dobro no último minuto. No Laboratório dá pra voltar às 2 torres iguais.
- **144 cartas em 10 turmas** (Curral, Galinheiro, Brejo, Roçado, Peões, Coisa Estranha, Mar, Mata, Lendas, Mitos). Toda carta tem um **TIPO** que diz como ela luta e de quem ganha/perde (Bando, Matador, Tanque, Área, Atirador, Voador, Lutador, Derruba-torre, Apoio, Construção, Feitiço).
- **12 arenas**, uma por faixa de troféu, cada uma com tema, cenário e 12 cartas próprias (73 feitas à mão; as outras 71 saem do criador automático com semente fixa, cada uma com a sua assinatura no nome).
- **Menu em 5 abas** (toque embaixo ou arraste para o lado): Feira, Cartas, Batalha, Troféus, Sítio.
- **Progressão**: baús de colheita (tempo curto, cada partida adianta 1 minuto; a abertura é rápida; baú pronto não trava a fila), Feira diária, Mascate surpresa, Caminho dos Troféus, nível do jogador, cópias + ouro para subir carta, maestria visual pelo uso, 4 baralhos.
- **Torneio da Roça**: mata-mata de 3 fases com cartas niveladas e uma regra especial sorteada.
- **Safra**: a cada 3 dias o jogo cria 2 cartas novas e 1 missão, sozinho.
- **Criador**: cartas, torres e arenas dentro do jogo, com editor de pixel 48x48 e montagem por peças.
- **Bots** com baralho, turma preferida e aprendizado próprios; 2 contra 2; ranking e temporadas.

## Onde mexer

| O quê | Arquivo |
|---|---|
| Cartas, turmas e torres oficiais (tabelas) | `Scripts/catalogo.gd` |
| Peças da arte (desenho) | `ci/tools/arte/pecas.py`, `objetos.py` → rodar `exportar.py` |
| Cenários das arenas | `ci/tools/arte/arenas.py` |
| Baús, Feira, troféus, torneio, maestria | `Scripts/progresso.gd` |
| Menu | `Scripts/hub.gd` |
| Safra e gerador de cartas | `Scripts/safra.gd`, `creator/card_generator.gd` |
| Efeitos visuais | `Scripts/fx.gd` |
| Regras da batalha (torres, tamanho das tropas, peso do golpe) | `Scripts/regras.gd` |

Os testes automáticos (partidas sem tela e capturas de tela) rodam no GitHub Actions a cada envio.

## Batalha 2.5 (nov/2026)
A torre passou a defender de verdade (toda torre atira, com mais vida, dano e alcance), as tropas ficaram maiores e com cor de time, e o golpe ganhou peso (1 s pra entrar em campo, preparo antes de bater). Tudo fica em `Scripts/regras.gd` e pode ser ligado/desligado em **Configurações → Laboratório da batalha**. O porquê e os números estão em `DIAGNOSTICO.md`; as ferramentas pra medir de novo, em `ci/lab/`.

**Temas e cartas novas (19/11)**: turmas **Mar** e **Lendas**, 16 cartas novas (Tubarão de Botas, Saci, Mapinguari, Dragão do Milharal, Tripé Invasor...), cada bicho com o seu corpo, info da carta no estilo do Clash, nível que melhora também as habilidades, e o criador da Safra conferido pelo laboratório (`ci/lab/safra.tscn`). Carta que o laboratório não mediu mostra **Força estimada** (`Scripts/duelo_papel.gd`).

**Identidade das tropas (19/11)**: bicho anda de quatro patas, cada corpo anda e bate do seu jeito, bando/matador/brigão têm papéis bem separados, e o detalhe da carta mostra a **Força medida** (duelos de verdade rodados no laboratório). Mexeu em número de carta? Rode `ci/lab/rodar.sh solo X` e `ci/lab/rodar.sh duelos X` pra atualizar o que a carta mostra.

## Raridade 3.0
- **Normal** e **Rara**: sem habilidade (a Rara é só uma carta um pouco melhor ou diferente).
- **Épica**: habilidade fraca (1-2 pontos). **Lendária**: habilidade boa (3-4). **Mística**: as melhores (5+).
- Cada habilidade vale 1, 2 ou 3 pontos (`Catalogo.unit_abilities` / `spell_abilities`). Vale pra tropas, construções, feitiços e torres (`Catalogo.base_rarity`).
- O gerador da Safra sorteia a raridade primeiro e só então dá (ou tira) habilidades.
