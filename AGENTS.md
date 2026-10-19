# AGENTS.md

Instruções para agentes de IA (e humanos) que forem desenvolver o tema
**Nocturne** para KDE Plasma 6. Este repositório não é código de aplicação — são
artefatos de tema (SVG, INI, JSON, QML, CSS). As "regras de build" aqui são
sobre **validar**, **instalar** e **aplicar** temas corretamente.

Leia também [`docs/NOTAS-TECNICAS.md`](docs/NOTAS-TECNICAS.md): ele documenta as
armadilhas reais encontradas no desenvolvimento. A maioria dos erros abaixo já
custou horas uma vez.

## Ambiente de referência

- KDE Plasma 6.7+, **Wayland**.
- Distro: Aurora (Fedora Kinoite, imutável/ostree). Sem Kvantum.
- Ferramentas disponíveis: `plasma-apply-colorscheme`, `plasma-apply-desktoptheme`,
  `plasma-apply-lookandfeel`, `kwriteconfig6`, `kreadconfig6`, `dbus-send`,
  `magick` (ImageMagick 7), `python3`.
- `qdbus` **não** existe aqui; use `dbus-send` (ver abaixo).
- Shell interativo do dono é **fish**; os scripts em `scripts/` são **bash**.
  Não use heredoc nem `for ... in` presumindo bash no shell interativo.
- **Apps são majoritariamente Flatpak** (host imutável, quase nada nativo).
  Flatpaks são sandboxed, mas neste ambiente já herdam o tema GTK do host via um
  `flatpak override --user` global com `filesystems=xdg-config/gtk-4.0:ro`
  (confirmado: `org.gnome.Calculator` pega o tema sem config extra). Portanto NÃO
  force overrides nem mexa no `install.sh` para isso sem necessidade.
  - Apps **GTK3** clássicos em Flatpak exigem um tema GTK3 **nomeado presente no
    sandbox**: `flatpak override --user --env=GTK_THEME=Breeze:dark` (variante
    escura do `Breeze` da extensão `org.gtk.Gtk3theme.Breeze`, NÃO `Breeze-Dark`,
    que não existe no sandbox). Sem isso o GTK3 cai no Adwaita claro e o
    `gtk.css` do host fica aplicado sobre o tema errado; com isso ele aplica por
    cima. O `install.sh` já faz esse override. GTK4/libadwaita não precisa dele.
    Detalhes em `docs/NOTAS-TECNICAS.md` (seção GTK).
  - Para testar um Flatpak: `flatpak info --show-permissions <app-id>` mostra os
    `filesystems` efetivos; apps já abertos precisam ser reabertos.

## Acesso à internet

- **Consulta a documentação é livre.** Pode pesquisar e acessar sites de
  documentação (KDE/Plasma, Aurorae, GNOME/GTK/libadwaita, freedesktop,
  ImageMagick, specs) sem pedir confirmação a cada acesso. Prefira fontes
  oficiais a blogs quando houver conflito.
- Sempre cite a fonte (link) quando trouxer uma informação da internet, para
  rastreabilidade.
- Não envie conteúdo do repositório, dados pessoais ou segredos para serviços
  externos. Acesso à internet é só para **leitura** de documentação pública.

## Estrutura

```
color-schemes/Nocturne.colors          # cores do sistema (Qt/KDE)
plasma/desktoptheme/Nocturne/          # painéis/popups (SVG + colors)
aurorae/themes/Nocturne/               # decoração de janelas (SVG + rc)
look-and-feel/org.nocturne.global/     # pacote Global Theme
gtk/gtk-3.0/gtk.css, gtk/gtk-4.0/gtk.css   # integração de apps GTK
scripts/install.sh, scripts/uninstall.sh
docs/NOTAS-TECNICAS.md
```

## Comandos essenciais

### Validar um SVG antes de aplicar (SEMPRE faça isto)
```bash
python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('CAMINHO.svg')"
```

### Inspecionar um botão/glyph renderizado (não confie só na tela — ela usa cache)
```bash
magick aurorae/themes/Nocturne/restore.svg restore.png   # abra e verifique
# recortar só o estado 'active' (2º tile de 32px):
magick arquivo.svg -crop 32x32+32+0 +repage estado.png
```
Atenção: no ImageMagick 7 beta deste ambiente, a opção vem **depois** das
imagens: `magick in1 in2 +append out` (não `magick +append in1 in2 out`).

### Instalar e aplicar
```bash
./scripts/install.sh              # instala + aplica tudo
./scripts/install.sh --no-apply   # só copia os arquivos
./scripts/uninstall.sh            # reverte para Breeze
```
Valide a sintaxe dos scripts com `bash -n scripts/install.sh`. Para testar a
cópia sem tocar na config real, aponte `XDG_DATA_HOME`/`XDG_CONFIG_HOME` para um
diretório temporário antes de rodar com `--no-apply`.

### Recarregar o KWin (aplicar mudanças na decoração)
```bash
dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure
```

## Regras críticas (NÃO quebre estas)

1. **Library do Aurorae é exatamente `org.kde.kwin.aurorae`.** Qualquer sufixo
   (ex.: `.v2`) faz o KWin ignorar a decoração silenciosamente — nada aplica e a
   tela nem pisca. Sempre confira:
   ```bash
   kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library
   ```

2. **Cache do KSvg mascara mudanças.** Se "editei o SVG mas nada muda", apague o
   cache e faça o toggle de decoração:
   ```bash
   rm -rf ~/.cache/ksvg-elements
   # toggle Breeze -> Nocturne força reconstrução (ver install.sh)
   ```
   Não recorra a renomear o tema (`Nocturne-v2`, `-v3`...) a não ser em último
   caso — isso gerou lixo difícil de limpar. Prefira limpar cache + toggle.

3. **Botões Aurorae: todos os 5 estados com geometria idêntica.** `active`,
   `inactive`, `hover`, `pressed`, `deactivated` (ids `*-center`). O fundo
   circular (`r=14`) deve existir em TODOS, transparente no normal, para o
   botão não "pular de tamanho" no hover.

4. **Simetria dos cantos.** `TitleBorderLeft == TitleBorderRight` e
   `TitleEdgeLeft == TitleEdgeRight` no `Nocturnerc`, e as regiões de canto no
   SVG com largura == raio da curva. Assimetria distorce só um lado.

5. **Cantos arredondados = regiões `mask-*` no `decoration.svg`.** O Aurorae
   recorta a janela inteira pela máscara (9-slice). Raio da máscara 1px maior que
   o da decoração (10 → 11) para cobrir o anti-aliasing. Não dependa de efeitos
   externos (`shapecorners`/`klassy` não existem nos repos desta distro).

6. **Sombra: use a nativa do KWin.** Não desenhe regiões `shadow-*` no SVG — elas
   geram halo assimétrico. Sem `shadow-*`, o KWin aplica sombra simétrica.

7. **Não adicione `layout.js` ao look-and-feel.** Foi removido de propósito: no
   Plasma 6 desta distro o plasmashell não respeita o alinhamento de painel por
   script (dock fica preso à esquerda) e um erro no script deixa o desktop SEM
   painel. O Global Theme deve preservar o layout de painéis do usuário.

8. **Tema de ícones exige limpar cache.** Trocar `[Icons] Theme` +
   `plasma-changeicons` não basta; apague `~/.cache/icon-cache.kcache` e
   reinicie o plasmashell, senão os ícones antigos continuam.

9. **Não comprometa dados pessoais.** Nunca faça commit de screenshots que
   mostrem conteúdo de tela com texto (conversas, e-mails, caminhos). Antes de
   commitar, rode uma varredura:
   ```bash
   grep -riE 'senha|password|secret|token|/home/[a-z]+|@' . --include='*.md' --include='*.sh'
   ```

## Convenções

- **Paleta** (não introduza cores fora desta lista sem motivo):
  base `#1a1b26`, janela `#1f2235`, superfície `#24283b`, texto `#c0caf5`,
  azul `#7aa2f7`, roxo `#bb9af7`, verde `#9ece6a`, vermelho `#f7768e`,
  amarelo `#e0af68`.
- **Botões da janela:** à direita, ordem minimizar · maximizar · fechar
  (`RightButtons=IAX`); ícone da janela à esquerda (`LeftButtons=M`).
  Monocromáticos, sem o semáforo colorido do macOS.
- **Indentação:** SVG/XML com 1 espaço (segue o estilo dos arquivos existentes);
  scripts bash com 4 espaços.
- **Idioma:** README e docs em português; comentários de código podem ser em
  português ou inglês.

## Checklist antes de commitar

- [ ] SVGs editados validam com `xml.dom.minidom`.
- [ ] `bash -n` passa nos scripts.
- [ ] Mudança foi aplicada e verificada numa janela real (não só no cache).
- [ ] `kreadconfig6 ... library` ainda é `org.kde.kwin.aurorae`.
- [ ] Nenhum screenshot com texto de tela / dado pessoal foi adicionado.
- [ ] `docs/NOTAS-TECNICAS.md` atualizado se a mudança revelou uma nova armadilha.
