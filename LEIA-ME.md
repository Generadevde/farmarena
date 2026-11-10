# Farm Arena 2.0

Jogo de cartas e torres offline (estilo Clash Royale, tema roça), feito em Godot 4.7 para celular em pé.

**Instalar no celular:** https://github.com/Generadevde/farmarena/releases/latest/download/farmarena.apk
(cada alteração enviada para o GitHub gera um APK novo sozinho, em uns 5 minutos)

## O que tem

- **Batalha**: arena simétrica, 2 torres por lado, rio com 3 passagens. Derrube as duas torres. Recurso de 0 a 100, em dobro a partir de 1:59.
- **53 cartas em 6 turmas** (Curral, Galinheiro, Brejo, Roçado, Peões, Coisa Estranha), incluindo cartas com unidades diferentes juntas.
- **7 arenas**, uma por faixa de troféu, cada uma com cenário próprio.
- **Menu em 5 abas** (toque embaixo ou arraste para o lado): Feira, Cartas, Batalha, Troféus, Sítio.
- **Progressão**: baús de colheita (tempo curto, cada partida adianta 1 minuto), Feira diária, Mascate surpresa, Caminho dos Troféus, nível do jogador, cópias + ouro para subir carta, maestria visual pelo uso, 4 baralhos.
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

Os testes automáticos (partidas sem tela e capturas de tela) rodam no GitHub Actions a cada envio.
