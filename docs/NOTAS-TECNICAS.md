# Notas técnicas — Nocturne

Decisões de design e armadilhas encontradas durante o desenvolvimento. Serve
como referência para manutenção futura e para quem for adaptar o tema.

## Arquitetura do tema

Um "Global Theme" do Plasma é a soma de peças independentes:

1. **Color scheme** (`.colors`) — cores do sistema (Qt/KDE).
2. **Plasma desktop theme** — SVGs de painéis, popups, tooltips, system tray.
3. **Aurorae decoration** — a moldura das janelas (barra de título, botões).
4. **Look-and-feel** — pacote que referencia as peças acima + layout de painéis.
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

## GTK

Apps GTK ignoram o Plasma. Dois níveis de configuração:

- `settings.ini` (GTK3/4): `gtk-theme-name=Breeze-Dark` +
  `gtk-application-prefer-dark-theme=true`.
- `gtk.css` (GTK3/4): sobrescreve as `@define-color` com a paleta Nocturne
  (headerbar opaca combinando com a barra de título, accent `#7aa2f7`, etc.).
- `gsettings`: `gtk-theme=Breeze-Dark` e `color-scheme=prefer-dark` para apps
  que leem do dconf.

Apps GTK já abertos precisam ser reabertos para pegar o tema.

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
