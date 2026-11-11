# Farm Arena 2.0

Jogo de cartas e torres offline (estilo Clash Royale, tema roça), feito em Godot 4.7 para celular em pé.

**Instalar no celular:** https://github.com/Generadevde/farmarena/releases/latest/download/farmarena.apk
(cada alteração enviada para o GitHub gera um APK novo sozinho, em uns 5 minutos)

## O que tem

- **Batalha**: arena simétrica, 2 torres por lado, rio com 3 passagens. Derrube as duas torres. Recurso de 0 a 100, em dobro a partir de 1:59.
- **57 cartas em 6 turmas** (Curral, Galinheiro, Brejo, Roçado, Peões, Coisa Estranha), incluindo cartas com unidades diferentes juntas.
- **7 arenas**, uma por faixa de troféu, cada uma com cenário próprio.
- **Menu em 5 abas** (toque embaixo ou arraste para o lado): Feira, Cartas, Batalha, Troféus, Sítio.
- **Progressão**: baús de colheita (abrem na hora, com um toque), Feira diária, Mascate surpresa, Caminho dos Troféus, nível do jogador, cópias + ouro para subir carta, maestria visual pelo uso, 4 baralhos.
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

## Raridade 3.0
- **Normal** e **Rara**: sem habilidade (a Rara é só uma carta um pouco melhor ou diferente).
- **Épica**: habilidade fraca (1-2 pontos). **Lendária**: habilidade boa (3-4). **Mística**: as melhores (5+).
- Cada habilidade vale 1, 2 ou 3 pontos (`Catalogo.unit_abilities` / `spell_abilities`). Vale pra tropas, construções, feitiços e torres (`Catalogo.base_rarity`).
- O gerador da Safra sorteia a raridade primeiro e só então dá (ou tira) habilidades.
