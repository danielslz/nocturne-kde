#!/usr/bin/env bash
#
# Nocturne — instalador do tema global para KDE Plasma 6
# Copia todos os artefatos para ~/.local/share e ~/.config e aplica o tema.
#
# Uso:
#   ./scripts/install.sh            # instala e aplica tudo
#   ./scripts/install.sh --no-apply # só instala os arquivos, não aplica
#
set -euo pipefail

# Diretório raiz do projeto (um nível acima de scripts/)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

APPLY=1
[[ "${1:-}" == "--no-apply" ]] && APPLY=0

say() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. Copiar artefatos
# ---------------------------------------------------------------------------
say "Instalando esquema de cores Nocturne"
mkdir -p "$DATA/color-schemes"
cp -f "$SRC/color-schemes/Nocturne.colors" "$DATA/color-schemes/"

say "Instalando tema de desktop do Plasma (Nocturne)"
mkdir -p "$DATA/plasma/desktoptheme"
rm -rf "$DATA/plasma/desktoptheme/Nocturne"
cp -r "$SRC/plasma/desktoptheme/Nocturne" "$DATA/plasma/desktoptheme/"

say "Instalando decoração de janelas Aurorae (Nocturne)"
mkdir -p "$DATA/aurorae/themes"
rm -rf "$DATA/aurorae/themes/Nocturne"
cp -r "$SRC/aurorae/themes/Nocturne" "$DATA/aurorae/themes/"

say "Instalando pacote Global Theme (org.nocturne.global)"
mkdir -p "$DATA/plasma/look-and-feel"
rm -rf "$DATA/plasma/look-and-feel/org.nocturne.global"
cp -r "$SRC/look-and-feel/org.nocturne.global" "$DATA/plasma/look-and-feel/"

say "Instalando overrides GTK (paleta Nocturne)"
mkdir -p "$CONF/gtk-3.0" "$CONF/gtk-4.0"
cp -f "$SRC/gtk/gtk-3.0/gtk.css" "$CONF/gtk-3.0/gtk.css"
cp -f "$SRC/gtk/gtk-4.0/gtk.css" "$CONF/gtk-4.0/gtk.css"

if [[ "$APPLY" -eq 0 ]]; then
    say "Arquivos instalados. Pulei a aplicação (--no-apply)."
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Aplicar
# ---------------------------------------------------------------------------
say "Aplicando esquema de cores e tema de desktop"
plasma-apply-colorscheme Nocturne  >/dev/null 2>&1 || true
plasma-apply-desktoptheme Nocturne >/dev/null 2>&1 || true

say "Configurando GTK para escuro + Breeze-Dark"
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme    "Breeze-Dark"  2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"  2>/dev/null || true
fi

say "Aplicando decoração de janelas (Aurorae / Nocturne)"
# IMPORTANTE: a biblioteca correta é 'org.kde.kwin.aurorae' (sem sufixos).
# Uma library errada faz o KWin ignorar a troca silenciosamente.
reconfig() {
    dbus-send --session --dest=org.kde.KWin --type=method_call \
        /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

# O cache de elementos SVG do KSvg retém renderizações antigas; limpar
# garante que as curvas/botões novos apareçam.
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ksvg-elements" 2>/dev/null || true

# Toggle Breeze -> Nocturne força o KWin a reconstruir a decoração.
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.breeze"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   "Breeze"
reconfig
sleep 2
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   "__aurorae__svg__Nocturne"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft  "M"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "IAX"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize "None"
reconfig

say "Habilitando blur e contraste do KWin"
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled     true
kwriteconfig6 --file kwinrc --group Plugins --key contrastEnabled true
reconfig

say "Pronto! Nocturne instalado e aplicado."
echo
echo "  Opcional — aplicar o Global Theme completo (reorganiza painéis):"
echo "      plasma-apply-lookandfeel org.nocturne.global"
echo
echo "  Apps GTK já abertos precisam ser reabertos para pegar o tema."
echo "  Janelas maximizadas: restaure e maximize de novo para atualizar a decoração."
