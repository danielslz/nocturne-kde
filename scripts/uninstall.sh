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
# O install aplica GTK_THEME=Breeze:dark POR-APP (nunca global) aos GTK3
# clássicos; revertemos os MESMOS apps com '--reset <app-id>' (mesma lista +
# mesma detecção do install).
# NUNCA use 'flatpak override --user --reset' SEM app-id: isso apagaria TODOS os
# overrides do usuário, inclusive um '--unset-environment=QT_QPA_PLATFORMTHEME'
# pré-existente no override global que NÃO é nosso — ele é PRESERVADO aqui.
# Ressalva: '--reset <app-id>' remove TODOS os overrides DAQUELE app. É seguro
# aqui porque o Nocturne não cria outros overrides nesses apps; se você tiver
# criado overrides manuais nesses app-ids, reaplique-os depois.
if command -v flatpak >/dev/null 2>&1; then
    say "Revertendo overrides GTK por-app dos Flatpaks GTK3"
    GTK3_APPS=("com.github.jeromerobert.pdfarranger")
    if installed=$(flatpak list --app --columns=application 2>/dev/null); then
        while IFS= read -r app; do
            [[ -z "$app" ]] && continue
            if flatpak info --show-runtime "$app" 2>/dev/null | grep -q 'Gtk3theme'; then
                GTK3_APPS+=("$app")
            fi
        done <<< "$installed"
    fi
    for app in "${GTK3_APPS[@]}"; do
        if flatpak info "$app" >/dev/null 2>&1; then
            flatpak override --user --reset "$app" 2>/dev/null || true
        fi
    done
    # Remove os filesystems de leitura dos gtk.css que o install adicionou (globais).
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
