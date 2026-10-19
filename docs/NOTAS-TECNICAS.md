# Notas técnicas — Nocturne

Decisões de design e armadilhas encontradas durante o desenvolvimento. Serve
como referência para manutenção futura e para quem for adaptar o tema.

## Arquitetura do tema

Um "Global Theme" do Plasma é a soma de peças independentes:

1. **Color scheme** (`.colors`) — cores do sistema (Qt/KDE).
2. **Plasma desktop theme** — SVGs de painéis, popups, tooltips, system tray.
3. **Aurorae decoration** — a moldura das janelas (barra de título, botões).
4. **Look-and-feel** — pacote que referencia as peças acima (sem layout de painéis; veja a seção sobre layout abaixo).
5. **GTK** — apps GTK não respeitam o Plasma; precisam de config própria.

Cada peça foi tratada separadamente porque falham de formas diferentes.

## Plasma desktop theme: herdar do Breeze

Escrever todos os SVGs do tema de desktop à mão é inviável — o Plasma espera
dezenas de elementos nomeados (`hint-*`, `mask-*`, shadow regions) em cada SVG.
Qualquer região faltando quebra a renderização.

**Solução:** herdar a geometria do tema `default` (Breeze) e sobrescrever apenas
o arquivo `colors` + copiar os SVGs de `panel-background`/`background` que dão o
visual translúcido. O `breeze-dark` do sistema faz exatamente isso: só tem
`colors` + `metadata.json`, e cai no fallback do `default` para os SVGs.

`X-Plasma-API` foi fixado em `5.0` (como o breeze-dark) para máxima
compatibilidade no Plasma 6.

## Aurorae: as armadilhas (a maior parte do tempo foi aqui)

### 1. A biblioteca precisa ser exatamente `org.kde.kwin.aurorae`

O bug mais custoso. Em algum momento a chave
`kwinrc → [org.kde.kdecoration2] → library` foi para `org.kde.kwin.aurorae.v2`
(valor inválido). Com uma library errada, **o KWin ignora a troca de decoração
silenciosamente** e mantém o Breeze — nenhuma edição do tema aparece, e a
decoração nem "pisca" ao reaplicar.

Sempre garanta:

```ini
[org.kde.kdecoration2]
library=org.kde.kwin.aurorae
theme=__aurorae__svg__Nocturne
```

### 2. Cache do KSvg (`~/.cache/ksvg-elements`)

O Aurorae usa `KSvg`, que mantém um cache de elementos renderizados em
`~/.cache/ksvg-elements` **e** em memória no processo do KWin. Um
`dbus-send ... reconfigure` nem sempre recarrega os SVGs — ele serve o bitmap
antigo. Sintoma: "editei o SVG mas nada muda".

Mitigações usadas:
- Apagar `~/.cache/ksvg-elements` antes de reaplicar.
- Toggle de decoração **Breeze → Nocturne** (força reconstrução).
- Em último caso, renomear o tema (nome novo = sem cache associado). Isso virou
  a bagunça `Nocturne-v2/v3/v4` durante o debug — todos removidos depois; o tema
  final é só `Nocturne`.

### 3. Botões: tamanho constante entre estados

Os botões "pulavam de tamanho" no hover porque o estado normal só tinha o glyph
e o hover adicionava um círculo de fundo maior que o botão. **Correção:** todos
os 5 estados (`active`, `inactive`, `hover`, `pressed`, `deactivated`) têm a
mesma geometria — um círculo `r=14` centralizado, transparente no normal e com
preenchimento sutil no hover/pressed. O glyph nunca se move.

Estados obrigatórios por botão: `active-center`, `inactive-center`,
`hover-center`, `pressed-center`, `deactivated-center`.

### 4. Botão restaurar (janela maximizada)

Quando maximizada, o Aurorae mostra `restore.svg` em vez de `maximize.svg`
(ver `AuroraeMaximizeButton.qml`: usa `restoreButtonPath` quando
`client.maximized`). O glyph de "dois quadrados sobrepostos" é difícil de ler em
32px — a primeira versão ficou apertada/confusa. A versão final usa um quadrado
na frente (inferior-esquerdo) + o segundo quadrado espiando atrás
(superior-direito), com traços de 1.5px.

Dica de depuração: renderizar o SVG com `magick` e inspecionar diretamente, em
vez de depender da tela (que pode estar em cache):

```bash
magick aurorae/themes/Nocturne/restore.svg restore.png
```

### 5. Simetria dos cantos superiores

O canto esquerdo ficava distorcido enquanto o direito ficava liso. Causa:
`TitleBorderLeft`/`TitleEdgeLeft` diferentes de `TitleBorderRight`/
`TitleEdgeRight`. O Aurorae estica a região de canto proporcionalmente à borda,
então valores assimétricos distorcem só um lado. **Correção:** manter esquerda e
direita iguais (ambos 10, = raio da curva). Além disso, as regiões de canto no
SVG têm largura exatamente igual ao raio, para não haver área esticável dentro
da curva.

### 6. Cantos arredondados de verdade: máscara de recorte

O Aurorae no Wayland **não recorta a janela inteira** por padrão — ele só
arredonda a decoração, e o fundo quadrado do app vaza no canto. A solução não é
um efeito externo (o Aurora/Fedora Kinoite não empacota `shapecorners`,
`klassy` nem `lightlyshaders`), e sim o suporte **nativo a máscara** do Aurorae:

`aurorae.qml` (linha ~46): `supportsMask: hasElementPrefix("mask")`.

Se o `decoration.svg` tiver regiões `mask-*` (9-slice: `mask-center`,
`mask-top`, `mask-topleft`, etc.), o KWin usa isso como máscara de recorte da
janela inteira — arredondando o conteúdo do app também. Branco = mantém,
transparente = recorta.

Detalhe: o `maskItem` tem `anchors.margins: 1`, deixando a máscara 1px menor que
a decoração. Isso deixa um pixel de anti-aliasing na borda da curva. Mitigado
fazendo a máscara com raio 1px **maior** que a decoração (decoração r=10,
máscara r=11).

### 7. Sombra: usar a nativa do KWin, não custom

Sombras `shadow-*` desenhadas à mão no SVG produziram um halo assimétrico (uma
"segunda janela" fantasma no canto superior esquerdo), porque os gradientes
radiais dos cantos não ficavam simétricos e as sombras laterais sólidas se
somavam. **Solução:** remover todas as regiões `shadow-*`. Sem sombra custom, o
KWin aplica a própria sombra nativa, que é simétrica e suave.

## Blur atrás de painéis e popups: exige `hint-compositing-blur`

Mesmo com o efeito de blur do KWin ligado (`kwinrc [Plugins] blurEnabled=true`)
e o tema Nocturne ativo, os painéis e popups não borravam o fundo. Causa: no
Plasma 6 o KSvg/FrameSvg só pede blur ao compositor quando o SVG de fundo tem um
elemento com `id="hint-compositing-blur"`. Os SVGZ de fundo tinham apenas
`hint-*-margin`, `hint-*-inset`, `hint-tile-center` e `mask-*` — nenhum pedia
blur.

**Correção:** adicionar um `<rect id="hint-compositing-blur">` (invisível,
`fill:none`) cobrindo a área do tile `center` em cada SVG de fundo translúcido:

- `widgets/panel-background.svgz` (painel — primário)
- `widgets/background.svgz`
- `dialogs/background.svgz` (popups)
- `widgets/tooltip.svgz`

Detalhes que valem lembrar:

- O KWin usa só a **existência e os limites (bounds)** do elemento, não o
  preenchimento. Os bounds do rect definem a região borrada, então ele cobre a
  mesma área do `center`.
- O fundo precisa ser **translúcido** (alpha < 1) para o blur aparecer. O
  `panel-background`, `dialogs/background` e `tooltip` já usam `opacity:0.85` com
  `ColorScheme-Background`, então o blur surge só com o hint presente. O
  `widgets/background` tem o `center` opaco (`opacity:1`); o hint foi adicionado
  mesmo assim (fica inerte enquanto o fundo for opaco) e a opacidade NÃO foi
  mexida, para não alterar o visual de todos os frames de widget — mudança
  mínima e sem efeito colateral.
- Os arquivos em `.../opaque/` ficam **de fora de propósito** (fallback sem
  transparência): não têm o hint e não devem ter.
- `.svgz` é SVG gzipado: descompactar com `zcat`, editar o XML, validar com
  `xml.dom.minidom`, recompactar com `gzip -n -c > ARQ.svgz` (o `-n` evita gravar
  timestamp/nome e mantém o diff estável). Depois limpar `~/.cache/ksvg-elements`
  e reaplicar, senão o cache mascara a mudança.

## GTK

Apps GTK ignoram o Plasma. Dois níveis de configuração:

- `settings.ini` (GTK3/4): `gtk-theme-name=Breeze-Dark` +
  `gtk-application-prefer-dark-theme=true`.
- `gtk.css` (GTK3/4): sobrescreve as `@define-color` com a paleta Nocturne
  (headerbar opaca combinando com a barra de título, accent `#7aa2f7`, etc.).
- `gsettings`: `gtk-theme=Breeze-Dark` e `color-scheme=prefer-dark` para apps
  que leem do dconf.

Apps GTK já abertos precisam ser reabertos para pegar o tema.

## Layout de painéis (por que foi removido)

A versão inicial do look-and-feel trazia um `contents/layouts/*.js` que criava um
layout estilo macOS (painel superior + dock inferior centralizado). Isso foi
**removido** por dois motivos descobertos em teste real no Plasma 6 / Aurora:

1. **Risco de desktop sem painel.** A primeira versão usava propriedades
   inexistentes na API de script (`panel.floating`, `panel.lengthMode`,
   `dock.alignment` como setter) e `desktops()` em vez de
   `desktopsForActivity()`. Qualquer exceção abortava o script e o desktop ficava
   **sem nenhum painel**. Mesmo após corrigir a API (validada via
   `evaluateScript`: `TOP_OK DOCK_OK`), permaneceu o problema 2.

2. **Alinhamento de painel não é respeitado.** Mesmo com `alignment=132`
   (center) e `min/maxLength` gravados no grupo principal de
   `[PlasmaViews][Panel N]` no `plasmashellrc`, o plasmashell desta versão
   mantinha o dock **preso à esquerda**. Nem a API de script (`panel.alignment`),
   nem a config + reinício completo do plasmashell surtiram efeito visual. O
   runtime reportava `align=center` enquanto a tela mostrava o painel à esquerda.

Conclusão: o alinhamento/centralização de painel só é confiável pela **interface
gráfica** (modo de edição do painel). Como um tema não deve depender de passos
manuais nem arriscar deixar o usuário sem painel, o `layout.js` foi removido. O
Global Theme agora **preserva o layout de painéis** existente.

Se um dia for reintroduzido um dock, o caminho é: criar o painel via
`new Panel()`, e para o alinhamento instruir o usuário a centralizar pela GUI, ou
investigar a API mais nova de `floating panel` do Plasma.

## Tema de ícones não aplica (cache)

Trocar `[Icons] Theme` no `kdeglobals` e rodar `plasma-changeicons` **não basta**:
o `~/.cache/icon-cache.kcache` retém os ícones antigos. É preciso apagar esse
cache e reiniciar o plasmashell para a mudança aparecer. O `install.sh` faz isso.

## Pontos em aberto / melhorias futuras

- **Cantos das janelas:** a máscara arredonda bem, mas ainda pode sobrar ~1px de
  AA em certas combinações. Caminho ideal (quando empacotado): efeito
  `kwin-effect-shapecorners` para recorte perfeito da janela inteira.
- **Janelas maximizadas** não re-renderizam a decoração num `reconfigure`;
  precisam ser restauradas/maximizadas de novo.

## Ambiente de referência

- Aurora (Fedora Kinoite 44), sistema imutável (ostree).
- KDE Plasma 6.7.4, Wayland.
- KWin 6.7.4. Sem Kvantum.
