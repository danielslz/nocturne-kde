# Nocturne — Tema Global para KDE Plasma 6

Um tema escuro, inspirado no macOS, para o **KDE Plasma 6** (testado no Plasma 6.7
sob Wayland). Paleta baseada em **Tokyo Night** + **Catppuccin**, com painéis
translúcidos, blur, cantos arredondados e uma decoração de janelas Aurorae
customizada com botões monocromáticos integrados.

![Nocturne — preview](screenshots/preview.png)

> O preview acima é provisório (gerado a partir dos SVGs do tema + paleta).
> Screenshots reais da área de trabalho serão adicionados em `screenshots/`.

## O que está incluído

| Componente | Descrição |
|---|---|
| **Color scheme** | Esquema de cores escuro `Nocturne.colors` |
| **Plasma desktop theme** | Painéis/popups translúcidos com blur (`Nocturne`) |
| **Aurorae decoration** | Decoração de janelas com cantos arredondados, botões à direita e ícone à esquerda |
| **Global Theme (look-and-feel)** | Pacote que amarra tudo + layout de painéis estilo macOS |
| **GTK overrides** | `gtk.css` (GTK3 e GTK4/libadwaita) para integrar apps GTK à paleta |

### Paleta

| Papel | Cor |
|---|---|
| Fundo base | `#1a1b26` |
| Fundo de janela | `#1f2235` |
| Superfície / cartões | `#24283b` |
| Texto | `#c0caf5` |
| Accent (azul) | `#7aa2f7` |
| Roxo | `#bb9af7` |
| Verde | `#9ece6a` |
| Vermelho | `#f7768e` |
| Amarelo | `#e0af68` |

## Instalação

```bash
git clone https://github.com/<seu-usuario>/nocturne-kde.git
cd nocturne-kde
./scripts/install.sh
```

O instalador copia os artefatos para `~/.local/share` e `~/.config`, e aplica:
esquema de cores, tema de desktop, decoração de janelas (Aurorae), blur do KWin
e o tema GTK escuro.

Para apenas copiar os arquivos sem aplicar:

```bash
./scripts/install.sh --no-apply
```

### Global Theme completo (opcional)

O instalador **não** aplica o pacote look-and-feel automaticamente porque ele
reorganiza seus painéis (adiciona uma barra superior flutuante + um dock inferior
centralizado estilo macOS). Para aplicá-lo:

```bash
plasma-apply-lookandfeel org.nocturne.global
```

### Desinstalar

```bash
./scripts/uninstall.sh
```

Reverte para o Breeze Dark e remove os arquivos do tema.

## Notas de uso

- **Apps GTK** já abertos precisam ser reabertos para pegar o novo tema.
- **Janelas maximizadas** mantêm a decoração anterior até serem restauradas e
  maximizadas de novo (ou reabertas) — limitação do KWin ao recarregar a
  decoração.
- O **Global Theme completo** depende dos ícones `Tela-dark` e do cursor
  `breeze_cursors`. Ajuste em `look-and-feel/.../contents/defaults` se preferir
  outros.

## Compatibilidade

- **Plasma 6.x** (Wayland e X11). Desenvolvido no Plasma 6.7 / Wayland.
- A decoração usa a biblioteca Aurorae `org.kde.kwin.aurorae`.
- Distro de referência: Aurora (Fedora Kinoite / atomic). Funciona em qualquer
  distro com Plasma 6; o instalador usa apenas ferramentas padrão do KDE
  (`plasma-apply-*`, `kwriteconfig6`, `dbus-send`).

## Estrutura do projeto

```
nocturne-kde/
├── color-schemes/
│   └── Nocturne.colors
├── plasma/desktoptheme/Nocturne/      # tema de desktop (SVGs + cores)
├── aurorae/themes/Nocturne/           # decoração de janelas
├── look-and-feel/org.nocturne.global/ # pacote Global Theme
├── gtk/
│   ├── gtk-3.0/gtk.css
│   └── gtk-4.0/gtk.css
├── scripts/
│   ├── install.sh
│   └── uninstall.sh
├── screenshots/
├── README.md
└── docs/
    └── NOTAS-TECNICAS.md              # decisões e armadilhas (leitura recomendada)
```

## Documentação técnica

As decisões de design e as armadilhas encontradas durante o desenvolvimento
(cache do Aurorae, máscara de recorte, sombra nativa vs. custom, etc.) estão
documentadas em [`docs/NOTAS-TECNICAS.md`](docs/NOTAS-TECNICAS.md).

## Licença

GPL-3.0+. Os SVGs do tema de desktop derivam do tema Breeze (LGPL) do KDE.
