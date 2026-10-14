#!/usr/bin/env bash
#
# Nocturne — desinstalador. Remove os artefatos e volta aos padrões do Breeze.
#
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

say() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

say "Revertendo para Breeze Dark"
plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
plasma-apply-desktoptheme default   >/dev/null 2>&1 || true

say "Revertendo decoração de janelas para Breeze"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.breeze"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   "Breeze"
dbus-send --session --dest=org.kde.KWin --type=method_call \
    /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true

say "Removendo arquivos do tema"
rm -rf "$DATA/color-schemes/Nocturne.colors"
rm -rf "$DATA/plasma/desktoptheme/Nocturne"
rm -rf "$DATA/aurorae/themes/Nocturne"
rm -rf "$DATA/plasma/look-and-feel/org.nocturne.global"

say "Removendo overrides GTK (gtk.css)"
rm -f "$CONF/gtk-3.0/gtk.css" "$CONF/gtk-4.0/gtk.css"

say "Limpando cache de SVG"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ksvg-elements" 2>/dev/null || true

say "Nocturne removido. Pode ser necessário reabrir apps GTK."
