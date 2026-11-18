# Diagnóstico — "perdeu a fluidez / a graça"

Lista viva de coisas que deixam o Farm Arena diferente do Clash Royale na
sensação de jogo. Nada aqui foi mudado ainda: é a lista pra decidir junto.
(Números medidos no código em 18/11/2026; 1 quadrado ≈ 31 px, campo 576×960
≈ 18×31 quadrados, igual ao Clash 18×32.)

## Batalha

### 1. Torre fraca demais (principal suspeito)
No Clash uma tropa sozinha quase nunca derruba a torre: a torre aguenta e mata
antes, então o jogo é defender e contra-atacar. Aqui é o contrário — quem
chega na torre ganha, por isso a luta vira "ou passa ou morre".

| Carta | Derruba a torre em | Torre mata ela em |
|---|---|---|
| Galo Rei | 6 s | 31 s |
| Cavalo Coiceiro | 9 s | 24 s |
| Bode Cabeçudo | 8 s | 42 s |
| Vaca Brava | 15 s | 72 s |
| Robô Balde | 10 s | 112 s |

Clash (referência aproximada): Cavaleiro derruba em ~18 s e morre em ~13 s;
Gigante derruba em ~18 s e morre em ~30 s.
Torre Celeiro: 845 de vida (65% de 1300), 32 de dano por segundo.

### 2. Alcance da torre curto
Celeiro alcança 125 px (~4 quadrados). No Clash a torre de princesa alcança
~7,5 e cobre a saída da ponte — a defesa começa antes da tropa chegar.

### 3. Tropas rápidas demais
Mais rápida do Clash ("muito rápida") ≈ 2 quadrados/s. Aqui várias passam disso:
Moda de Viola 3,1 · Cavalo 2,7 · Mosquitada 2,7 · Abóbora 2,7 · Pintaiada 2,6 ·
Bezerrada 2,4 · Pato Ninja 2,4 · Abelhas 2,4. Atravessam o campo antes de dar
tempo de reagir.

### 4. Ritmo da partida
- Começa com 5 de 100 de recurso (Clash começa com metade: 5 de 10).
- Partida de 5 min (Clash: 3 min + prorrogação).
- Recurso: 4/s (≈ 1 elixir a cada 2,5 s; Clash 2,8 s) — ok.

### 5. Só 3 cartas na mão
Clash tem 4 na mão + a próxima. Com 3 há menos escolha a cada momento.

### 6. Primeiro golpe instantâneo
O tempo de recarga do ataque corre mesmo andando, então a tropa bate na hora
que encosta. No Clash há um "primeiro golpe" com pequeno atraso e animação de
preparo — dá pra ver o golpe vindo.

### 7. Nível pesa muito (o João achou que NÃO é o principal)
+15% de vida E dano por nível (nível 9 = 2,2×). Clash ≈ 10% e pareia níveis.

## Informação das cartas

- Números soltos sem referência: "2300 de vida" não diz se é muito. Ideia:
  mostrar "aguenta X s na torre", "derruba torre em Y s" e barras comparando
  com a média das cartas do mesmo custo.
- Comum/Rara dizem "Sem habilidade: é só vida e pancada" — desvaloriza a carta.
  Trocar pela FUNÇÃO dela ("puxa o tiro da torre enquanto o resto bate").
- Falta "bom contra / fraco contra" com cartas de verdade.
- Nível aparece 3 vezes (selo Nv, "Nível 1", "Números no nível 1").
- Duas fontes misturadas (pixel + normal), rótulos minúsculos nos quadrinhos.
- Velocidade "Muito lenta (28)": número sem unidade; alcance "perto".
- Faltam: tempo de entrada em campo, primeiro golpe, quantidade (x3) nos números.
- Maestria e "na temporada: sem partidas" ocupam espaço sem ajudar a decidir.
- Bug: popup do baú abre POR CIMA da carta aberta.

## Ainda a investigar
- Gravar uma partida (vídeo) no CI e olhar quadro a quadro: amontoamento na
  ponte, tropas se empurrando, troca de alvo.
- Sons e peso do golpe (todos usam o mesmo "bote" e flash).
- Visual do campo: área vazia atrás das torres, torres longe do rio.
