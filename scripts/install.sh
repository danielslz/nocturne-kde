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

say "Instalando papéis de parede"
mkdir -p "$DATA/wallpapers/Nocturne"
cp -f "$SRC"/wallpapers/*.png "$DATA/wallpapers/Nocturne/" 2>/dev/null || true
cp -f "$SRC"/wallpapers/*.svg "$DATA/wallpapers/Nocturne/" 2>/dev/null || true

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

# Apps GTK3 clássicos em Flatpak caem no Adwaita claro sem um tema GTK3 NOMEADO
# presente no sandbox; a dconf/gsettings do host NÃO chega ao sandbox, então o
# gsettings acima é inócuo para Flatpaks. A correção é definir GTK_THEME para a
# variante escura do tema 'Breeze' que JÁ existe no sandbox (org.gtk.Gtk3theme.
# Breeze). Use 'Breeze:dark' (dois-pontos + variante), NÃO 'Breeze-Dark' (não
# existe no sandbox e dá fallback claro). O gtk.css do Nocturne aplica por cima.
# Ver docs/NOTAS-TECNICAS.md (seção GTK).
if command -v flatpak >/dev/null 2>&1; then
    say "Configurando tema GTK dos Flatpaks (GTK_THEME=Breeze:dark)"
    flatpak override --user --env=GTK_THEME=Breeze:dark 2>/dev/null || true
    # Defensivamente garante leitura dos gtk.css do host dentro dos sandboxes.
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
    flatpak override --user --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
else
    say "flatpak não encontrado; pulei o tema GTK de Flatpaks (ok em ambientes não-Flatpak)"
fi

say "Aplicando tema de ícones Tela-dark"
# Só aplica se o tema existir; caso contrário mantém o atual.
if [ -f "$DATA/icons/Tela-dark/index.theme" ] || [ -f /usr/share/icons/Tela-dark/index.theme ]; then
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "Tela-dark"
    # IMPORTANTE: o cache de ícones retém os antigos; sem limpá-lo + reiniciar o
    # plasmashell, a troca de ícones não aparece (plasma-changeicons sozinho não
    # basta nesta versão).
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/icon-cache.kcache" 2>/dev/null || true
    [ -x /usr/libexec/plasma-changeicons ] && /usr/libexec/plasma-changeicons Tela-dark >/dev/null 2>&1 || true
    RESTART_SHELL=1
else
    say "  (Tela-dark não encontrado; pulei o tema de ícones)"
fi

say "Aplicando papel de parede Nocturne"
if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$DATA/wallpapers/Nocturne/nocturne-1920x1080.png" >/dev/null 2>&1 || true
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

# O KImageCache de pixmaps do tema (plasma_theme_Nocturne.kcache) retém
# renders antigos e mascara mudanças de SVG; removê-lo força rebuild.
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/plasma_theme_Nocturne.kcache" 2>/dev/null || true

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

# Reinicia o plasmashell se o tema de ícones mudou (para o cache ser relido).
if [ "${RESTART_SHELL:-0}" -eq 1 ] && command -v kquitapp6 >/dev/null 2>&1; then
    say "Reiniciando o plasmashell para aplicar os ícones"
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 2
    (setsid plasmashell >/dev/null 2>&1 &) || true
fi

say "Pronto! Nocturne instalado e aplicado."
echo
echo "  Opcional — Global Theme completo (cores+tema+decoração num pacote):"
echo "      plasma-apply-lookandfeel org.nocturne.global"
echo "  (NÃO reorganiza seus painéis — o layout de painéis é preservado.)"
echo
echo "  Apps GTK já abertos precisam ser reabertos para pegar o tema."
echo "  Janelas maximizadas: restaure e maximize de novo para atualizar a decoração."
