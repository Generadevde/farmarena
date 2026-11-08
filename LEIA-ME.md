# Farm Arena

Jogo estilo Clash Royale, offline, contra bots. Feito em Godot 4.7 (GDScript).

## 📱 Instalar no celular

Abra este link no celular e instale:

**https://github.com/Generadevde/farmarena/releases/latest/download/farmarena.apk**

- Cada vez que algo é enviado pro GitHub, um APK novo é gerado sozinho em uns 2 minutos, no mesmo link.
- Pra atualizar, baixe e instale por cima. Seu progresso continua.
- Na primeira vez, o Android pede pra permitir "instalar apps desconhecidos" pro navegador.

## Baixar e abrir no PC

```bash
git clone https://github.com/Generadevde/farmarena.git
```

Abra a pasta no Godot 4.7. Na **primeira abertura**, o editor reimporta tudo e registra as classes novas (`BattleBrain`, `DeckBuilder`, `PixelEditor`...). Se aparecer erro de "classe não encontrada", feche e abra o projeto de novo.

## Exportar pro celular (Moto G75)

1. **Projeto → Exportar → Android** (o preset já está em `export_presets.cfg`).
2. Se pedir, use **Projeto → Instalar Template de Build Android** (gera a pasta `android/`, que é ignorada pelo git).
3. Exporte o `.apk` **fora** da pasta do projeto (por exemplo, em `~/Área de trabalho/Farm Arena/builds/`) pra ele não ir pro repositório.

## O que tem de novo

- **🛠 Criador** (menu principal), que funciona no celular:
  - **Cartas:** crie unidades e feitiços, gere carta aleatória (balanceada pela média das suas cartas) e edite qualquer carta do jogo. Tem botão "↺ Original" pra desfazer a edição.
  - **Bases:** crie e edite bases. A arte é 32x64.
  - **Arenas:** nome, emoji, troféus, recompensas e fundo em pixel art. Dá pra criar arenas novas depois da 7.
  - **Editor de pixel art:** lápis, borracha, balde, conta-gotas, espelho, contorno automático, desfazer/refazer e arte aleatória.
  - Tudo fica salvo em `user://custom/` no aparelho. Os bots também passam a usar as cartas que você cria.
- **👥 Batalha 2v2:** você e um bot aliado contra 2 bots. É amistosa: dá ouro e XP, mas não mexe em troféu.
- **Recurso x2** a partir de 1:59 (antes era 1.5x a partir de 0:59).

## Correções

- As unidades se empurram de verdade (separação estilo Clash Royale), sem virar mistureba.
- Os bots do ranking voltaram a jogar no celular: a simulação offline rodava antes de carregar o perfil. E ela não trava mais a tela.
- IA de batalha:
  - lê o campo todo;
  - defende com uma carta que acerta o tipo de ameaça (aéreo/terrestre), posicionada entre a ameaça e a base;
  - só lança feitiço quando vale a pena.
- Decks dos bots variados: cada bot tem um estilo próprio (categorias, curva de custo, nação favorita).
- Menus:
  - botão voltar do Android;
  - popup do bot fecha tocando fora;
  - missões não empilham popup;
  - carrosséis de carta e de base separados;
  - aba de estatísticas de cartas aparecendo;
  - botões maiores pra dedo;
  - listas rolam arrastando.
- A base estava numa camada de colisão errada.
- Nomes de arquivo com "ç" corrigidos.
