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

## Blur atrás de painéis e popups: mecanismo real (KWin + `mask-*`)

Uma tentativa anterior adicionou um `<rect id="hint-compositing-blur">` invisível
nos SVGZ de fundo acreditando que o KSvg/FrameSvg pedia blur ao compositor só
quando esse elemento existia. **Isso estava errado:** o id `hint-compositing-blur`
**não existe** no código-fonte do Plasma 6 (nem em `ksvg`, nem em `libplasma`) —
é um elemento **inerte**, ignorado pelo renderizador. Ele foi **removido** dos
quatro SVGZ (`widgets/panel-background.svgz`, `widgets/background.svgz`,
`widgets/tooltip.svgz`, `dialogs/background.svgz`).

Como o blur realmente funciona no Plasma 6:

- Quem pede o blur é o **KWin**, não o SVG. O plasmashell chama
  `KWindowEffects::enableBlurBehind(janela, theme.blurBehindEnabled(), mask)`,
  onde `mask = FrameSvg::mask()` — ou seja, a **região recortada pelos elementos
  `mask-*`** do SVG de fundo (o mesmo 9-slice `mask-center`/`mask-left`/… usado
  para os cantos arredondados). O `blurBehindEnabled` do tema é `true` por
  padrão, então o blur já é solicitado sem nenhum hint no SVG. (invent.kde.org:
  `plasma/libplasma` — `theme_p.cpp`, `dialog.cpp`, `plasmawindow.cpp`.)
- Logo, o que habilita o blur é: **(a)** as regiões `mask-*` presentes no fundo e
  **(b)** o efeito de blur do KWin ligado (`kwinrc [Plugins] blurEnabled=true`,
  que o `install.sh` garante). Nenhum atributo especial no SVG é necessário.
- Para o blur **aparecer visualmente** o `center` precisa ser translúcido
  (alpha < 1). `panel-background`, `dialogs/background` e `tooltip` usam
  `opacity:0.85` no `center`; `widgets/background` mantém o `center` **opaco**
  (`opacity:1`) por design — ali o blur fica inerte, e a opacidade NÃO deve ser
  mexida para não alterar todos os frames de widget.

### Variante `translucent/` (o que o Plasma serve com blur/contraste)

Seguindo o padrão do Breeze, o tema agora tem uma pasta `translucent/` espelhando
os SVGZ translúcidos corrigidos (`translucent/widgets/*`, `translucent/dialogs/*`,
sem `hint-compositing-blur`, com os `mask-*` preservados). Quando o compositor
suporta blur/contraste, o KSvg seleciona essa variante
(`Svg::setSelectors({"translucent"})` / `ImageSet`); se a pasta não existir, há
**fallback** para `widgets/`/`dialogs/`. A `opaque/` continua sendo o fallback sem
transparência (não tem `mask-*` translúcido e fica de fora de propósito).
(develop.kde.org: [Understanding Plasma Styles](https://develop.kde.org/docs/plasma/theme/theme-details/);
invent.kde.org: `frameworks/ksvg` — `imageset_p.cpp`, `svg.cpp`.)

### Invalidação de cache (bump de Version + kcache)

Limpar só `~/.cache/ksvg-elements` **não basta**: o KSvg também mantém um
`KImageCache` de pixmaps por tema em `~/.cache/plasma_theme_Nocturne.kcache`, e o
`CacheId` é derivado do caminho + `lastModified`. O caminho confiável para forçar
rebuild é: **bumpar `Version` no `metadata.json`** (gatilho oficial de
invalidação do Plasma) **E** remover `plasma_theme_Nocturne.kcache`. O
`install.sh`/`uninstall.sh` já removem esse kcache junto do `ksvg-elements`.

### `[ContrastEffect]` reforça a translucidez

O `plasmarc` do tema agora inclui `[ContrastEffect] enabled=true` (com
`contrast`/`intensity`/`saturation`), que acentua a percepção de translucidez
atrás do popup — a seção estava ausente e o contraste não carregava em runtime.
`[AdaptiveTransparency] enabled=true` é preservada.
(develop.kde.org: [Background SVG format](https://develop.kde.org/docs/plasma/theme/background-svg/).)

Lembretes de edição:

- `.svgz` é SVG gzipado: descompactar com `zcat`, editar o XML, validar com
  `xml.dom.minidom`, recompactar com `gzip -n -c > ARQ.svgz` (o `-n` evita gravar
  timestamp/nome e mantém o diff estável). Depois limpar `~/.cache/ksvg-elements`
  **e** `~/.cache/plasma_theme_Nocturne.kcache` e reaplicar, senão o cache
  mascara a mudança.

> Nota de conformidade: o conteúdo das fontes acima foi reformulado/parafraseado
> para fins de licenciamento; consulte os links para o texto original.

### Blur não aparece mesmo com tema correto? É o KWin, não o tema

Armadilha que custou várias rodadas: depois de instalar um tema translúcido com
`mask-*` corretos, `Version` bumpada e cache limpo, o painel/popup **ainda** pode
aparecer 100% sólido. Antes de culpar o SVG, verifique o **estado de runtime do
KWin** — porque o blur é desenhado pelo compositor, e um `dbus-send ...
reconfigure` **não recarrega efeitos**; só um **restart/relogin do KWin** carrega
efeito novo e recria o pipeline do blur.

Sintoma diagnóstico (sem precisar olhar a tela):

```bash
# Há quanto tempo o KWin está rodando? Se for dias e você acabou de mexer no
# tema/efeitos, o compositor está com estado velho:
ps -eo pid,etime,cmd | grep '[k]win_wayland'

# O efeito contrast carrega? Se contrastEnabled=true no kwinrc mas isto for
# false, o KWin não absorveu a config nova -> precisa reiniciar:
dbus-send --session --print-reply --dest=org.kde.KWin /Effects \
  org.kde.kwin.Effects.isEffectLoaded string:contrast
```

Cuidado com um falso negativo: a propriedade `activeEffects` é um **instantâneo
dos efeitos desenhando naquele frame**, não a lista de efeitos aptos. `blur` só
entra em `activeEffects` **enquanto há um popup translúcido aberto na tela** —
então `activeEffects` sem `blur` num instante ocioso **não** prova que o blur
está quebrado. Use `loadedEffects`/`isEffectLoaded` para "está carregado" e um
teste visual (Kickoff sobre janela clara) para "está desenhando".

Correção (interativa, não dá para script de instalação fazer): **logout/login**
da sessão Wayland recarrega o KWin do zero. Alternativa: desmarcar e remarcar
"Blur" em *System Settings → Desktop → Desktop Effects* (força unload→load).
`kwin_wayland --replace` existe mas no Wayland nem sempre é confiável.

Confirmado neste ambiente (Plasma 6.7.5, Wayland, AMD RX 550, OpenGL/EGL real):
o backend e o tema estavam corretos; o blur não desenhava porque o
`kwin_wayland` rodava há 6 dias sem reiniciar após as mudanças.
(discuss.kde.org: [Proper way to reload a KWin effect](https://discuss.kde.org/t/proper-way-to-reload-a-kwin-effect/46880).)

## GTK

Apps GTK ignoram o Plasma. Dois níveis de configuração:

- `settings.ini` (GTK3/4): `gtk-theme-name=Breeze-Dark` +
  `gtk-application-prefer-dark-theme=true`.
- `gtk.css` (GTK3/4): sobrescreve as `@define-color` com a paleta Nocturne
  (headerbar opaca combinando com a barra de título, accent `#7aa2f7`, etc.).
- `gsettings`: `gtk-theme=Breeze-Dark` e `color-scheme=prefer-dark` para apps
  que leem do dconf.

Apps GTK já abertos precisam ser reabertos para pegar o tema.

### Flatpaks GTK3 clássicos: precisam de um tema GTK3 NOMEADO no sandbox

Apps GTK3 clássicos em Flatpak (ex.: pdfarranger) não aplicavam o Nocturne,
enquanto apps GTK4/libadwaita (ex.: Calculadora) aplicavam. A causa não é acesso
a arquivo — o `gtk.css` do Nocturne já chega ao sandbox via
`xdg-config/gtk-3.0:ro` e é lido. O problema é o **tema base**:

- O GTK3 clássico só aplica o `gtk.css` (que apenas sobrescreve `@define-color`)
  **por cima de um tema base nomeado**. Se o nome do tema não existe no escopo do
  Flatpak, o GTK3 cai no **Adwaita claro** de fallback e as cores do Nocturne
  ficam aplicadas sobre o tema errado (janela clara).
- Dentro do sandbox **não existe** um tema `Breeze-Dark` — só existe `Breeze`,
  fornecido pela extensão de runtime `org.gtk.Gtk3theme.Breeze`. Logo o
  `Breeze-Dark` que o host usa não resolve no sandbox.
- A **dconf/gsettings do host NÃO chega aos sandboxes Flatpak**. Portanto o
  `gsettings set ... gtk-theme Breeze-Dark` que o `install.sh` faz é **inócuo
  para Flatpaks** (serve só para apps GTK nativos).
- **libadwaita/GTK4 não precisa de tema nomeado:** lê o `gtk-4.0/gtk.css` direto
  por cima do próprio estilo e segue o `color-scheme` do portal — por isso a
  Calculadora já funcionava.

**Correção (feita pelo `install.sh`):** definir o `GTK_THEME` dos Flatpaks para a
variante escura do tema `Breeze` que já existe no sandbox, via override de
usuário:

```bash
flatpak override --user --env=GTK_THEME=Breeze:dark
```

Use `Breeze:dark` (dois-pontos + variante `dark` do tema `Breeze` presente), NÃO
`Breeze-Dark` (inexistente no sandbox — dá fallback claro). O `gtk.css` do
Nocturne continua aplicando as cores por cima.

**Verificação** (medir o fundo da janela dentro do sandbox, sem abrir a GUI;
troque `<app-id>` por um Flatpak GTK3, ex.: `com.github.jeromerobert.pdfarranger`):

```bash
flatpak run --env=GTK_THEME=Breeze:dark --command=sh <app-id> -c '
python3 -c "import gi; gi.require_version(\"Gtk\",\"3.0\"); from gi.repository import Gtk; w=Gtk.Window(); w.realize(); c=w.get_style_context().get_background_color(Gtk.StateFlags.NORMAL); print(round(c.red*255),round(c.green*255),round(c.blue*255))"'
# -> deve imprimir cor escura (~ 32 35 38), NÃO ~ (246 245 244) do Adwaita claro.
```

Depois reabra o app (apps Flatpak já abertos não pegam o override até reiniciar):

```bash
flatpak kill <app-id> 2>/dev/null; flatpak run <app-id>
```

Fontes (documentação pública; conteúdo reescrito para conformidade de
licenciamento): temas GTK em Flatpak precisam estar presentes no sandbox como
extensão `org.gtk.Gtk3theme.<Nome>`, pois o sandbox não enxerga temas em `/usr`
do host ([gist lmintmate](https://gist.github.com/lmintmate/b512680c0d1ee8f41b8f43cd2c81dc2c));
o workaround para o tema claro em Flatpak GTK3 é forçar `GTK_THEME` via
`flatpak override` ([flathub/org.gtk.Gtk3theme.Breeze#97](https://github.com/flathub/org.gtk.Gtk3theme.Breeze/issues/97),
[flatpak/flatpak#4239](https://github.com/flatpak/flatpak/issues/4239)).

### Moldura CSD (borda/cantos) alinhada ao Aurorae

Os `gtk.css` passaram a sobrescrever também a **geometria da moldura CSD**
(client-side decoration), não só as cores. Antes, como os dois arquivos só tinham
`@define-color`, a borda/cantos da janela GTK eram 100% herdados do tema base
`Breeze-Dark`: uma faixa externa espessa (`margin` + `box-shadow` com blur largo
no nó `decoration`) que o usuário lê como "borda grande" e destoa das janelas
Qt/Aurorae.

Alvo copiado do lado Qt (decoração Aurorae do Nocturne):

- Borda ~1px — `Nocturnerc [Layout]` tem `BorderLeft/Right/Bottom=1`, `BorderTop=0`.
- Raio dos cantos superiores 10px — mesma decoração r=10 da máscara do Aurorae.
- Cor da borda `#2a2e45` (`@borders`, dentro da paleta).

Regras aplicadas:

- **GTK3** (`gtk-3.0/gtk.css`): seletor `decoration` (e `decoration:backdrop`
  para janela inativa) com `border-radius: 10px 10px 0 0` (topo arredondado,
  base reta), `border: 1px solid @borders`, `box-shadow: none` (a sombra real é
  a nativa do KWin) e `margin: 1px` (faixa mínima para ainda redimensionar pela
  borda — `margin: 0` chega a impedir o resize em alguns casos).
- **GTK4/libadwaita** (`gtk-4.0/gtk.css`): o raio é aplicado na `window`
  (`window.csd:not(.maximized):not(.tiled):not(.fullscreen):not(.solid-csd)`,
  `border-radius: 10px 10px 0 0`) e a faixa externa/sombra no nó `decoration`
  (mesmos `border 1px`, `box-shadow: none`, `margin: 1px`).

**Maximizado / encostado (tiled) / tela cheia:** precisam de `border-radius: 0`
e `margin: 0`, senão sobra canto arredondado e faixa externa numa janela que
deveria encostar na borda da tela. Tratado em `decoration.maximized`/`.tiled*`/
`.fullscreen` (GTK3) e `window.maximized`/`.tiled`/`.fullscreen`/`.solid-csd`
(GTK4).

Fontes consultadas para a forma de override no GTK4/libadwaita (conteúdo
reescrito para conformidade de licenciamento): o nó `decoration` controla
`margin`/`box-shadow`/`border-radius` da faixa CSD e o padrão para resize é
`box-shadow: none; margin: 1px`
([planify#303](https://github.com/alainm23/planner/issues/303),
[zorin-desktop-themes#11](https://github.com/ZorinOS/zorin-desktop-themes/issues/11));
o raio é zerado nos estados `.maximized`/`.tiled` via seletores de estado da
`window`
([small adwaita tweaks](https://gist.github.com/davidphilipbarr/c56e9e1c89eaae2a1535afd995141633)).
**Limitação:** alguns apps libadwaita forçam o próprio estilo e podem ignorar
estas regras ([discuss.kde.org](https://discuss.kde.org/t/approach-to-make-libadwaita-apps-look-native-on-plasma/31428)) —
o objetivo é alinhar a maioria dos apps GTK CSD, não 100%.

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
