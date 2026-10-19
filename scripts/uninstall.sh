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

# Reverte CIRURGICAMENTE só os overrides de Flatpak que o install.sh criou.
# NÃO use 'flatpak override --user --reset': isso apagaria TODOS os overrides do
# usuário, inclusive os que não são nossos (ex.: um unset-environment=
# QT_QPA_PLATFORMTHEME pré-existente no override global). Removemos apenas o
# GTK_THEME e os nossos filesystems de leitura dos gtk.css.
# Ressalva: --unset-environment=GTK_THEME é incondicional (o flatpak não remove
# "só se o valor for X"). Se você tiver definido um GTK_THEME próprio no override
# global por outro motivo, ele será removido junto. No fluxo normal do Nocturne o
# único GTK_THEME é o nosso (Breeze:dark), então isso não é um problema.
if command -v flatpak >/dev/null 2>&1; then
    say "Revertendo overrides GTK de Flatpaks"
    flatpak override --user --unset-environment=GTK_THEME 2>/dev/null || true
    flatpak override --user --nofilesystem=xdg-config/gtk-3.0 2>/dev/null || true
    flatpak override --user --nofilesystem=xdg-config/gtk-4.0 2>/dev/null || true
fi

say "Limpando cache de SVG"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ksvg-elements" 2>/dev/null || true
# O KImageCache de pixmaps do tema é removido junto para não reter renders do
# Nocturne após a desinstalação. A pasta translucent/ instalada já sai no
# 'rm -rf "$DATA/plasma/desktoptheme/Nocturne"' acima (é subpasta do tema).
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/plasma_theme_Nocturne.kcache" 2>/dev/null || true

say "Nocturne removido. Pode ser necessário reabrir apps GTK."
