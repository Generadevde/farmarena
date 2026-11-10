# Farm Arena 2.0 — reforma total

Jogo só pro celular do João (Moto G75). Decisões fechadas em 10/nov/2026.

## Decisões
- **Cartas:** apagar todas as atuais e começar um conjunto novo do zero.
- **Gráficos:** pixel art 48x48, mais detalhada, com sombreado de 3 tons, contorno e animação simples por código (respirar, balançar ao andar, golpe, piscar ao levar dano, sumir com poeira ao morrer).
- **Gerador:** a arte das cartas novas é montada a partir de uma biblioteca de **peças** (cabeças, corpos, pernas, chapéus, armas, acessórios) desenhada no mesmo estilo. O gerador do Criador e o autogerador usam a mesma biblioteca, então tudo fica com cara de um jogo só.
- **Como conseguir cartas:**
  - **Baús de colheita** rápidos (de segundos a poucos minutos, nada de horas), ganhos por vitória.
  - **Feira da roça:** loja que muda todo dia, com ouro.
  - **Caminho dos troféus:** prêmios fixos conforme sobe.
  - Achar uma carta desbloqueia ela; as cópias repetidas mais ouro evoluem a carta.
  - Surpresa: **Mascate**, um vendedor ambulante que aparece de vez em quando com uma oferta rara.
- **Torres:** 2 torres por lado, lado a lado com espaço entre elas, e mapa simétrico entre jogador e bot. Ganha quem derrubar as duas. Se o tempo acabar, ganha quem derrubou mais torres; se empatar, quem tirou mais vida no total.
- **Autogerador ("Safra"):** a cada 3 dias nascem 2 cartas novas e 1 missão especial. As cartas entram nos baús, na feira e nos bots.

## Etapas (uma por vez, cada uma sobe pro GitHub)
1. **Bugs de batalha:** unidade aérea presa atrás do tanque; tornado teletransportando em vez de puxar.
2. **Mapa novo** simétrico com 2 torres por lado e a regra de vitória.
3. **Biblioteca de peças 48x48** e o gerador de arte novo.
4. **Cartas novas do zero:** conjunto completo, balanceado, com as nações novas.
5. **Efeitos:** feitiços, golpes, dano, morte, projéteis.
6. **Progressão:** baús, feira, caminho dos troféus, Mascate, evolução por cópias.
7. **Menus novos:**
   - barra de abas embaixo, deslizando o dedo pra trocar;
   - coleção nova;
   - 4 slots de deck;
   - estatísticas com mais e menos jogadas da temporada.
8. **Autogerador Safra**, ligado ao Criador.
9. **Criador** atualizado pro estilo novo (48x48, peças, nações novas).
10. **Revisão geral e testes** no GitHub.


## Situação (10/11/2026)

Etapas 1 a 9 feitas e testadas no GitHub Actions. Extras pedidos no caminho: cartas com unidades diferentes, 7 arenas com cenário próprio, Torneio da Roça, clima maluco, falas das tropas.

Ideias para depois: mais peças de arte, animação de ataque por arma, som nos efeitos, torneios com chave visual, mais regras especiais.
