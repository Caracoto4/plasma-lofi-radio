#!/usr/bin/env bash
#
# Lofi Player — uninstaller. Removes the widget, the helper and its unit.
set -euo pipefail

PKG_ID="org.koda.lofiplayer"
UNIT_NAME="lofi-nowplaying.service"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HELPER_DIR="$DATA_HOME/lofiplayer"
UNIT_DIR="$CONFIG_HOME/systemd/user"

info() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

if command -v systemctl >/dev/null 2>&1; then
    info "Останавливаю $UNIT_NAME"
    systemctl --user disable --now "$UNIT_NAME" 2>/dev/null || warn "сервис не был запущен"
    systemctl --user daemon-reload 2>/dev/null || true
fi

info "Удаляю systemd-юнит"
rm -f "$UNIT_DIR/$UNIT_NAME"

info "Удаляю helper"
rm -rf "$HELPER_DIR"

if command -v kpackagetool6 >/dev/null 2>&1; then
    info "Удаляю виджет $PKG_ID"
    kpackagetool6 --type Plasma/Applet --remove "$PKG_ID" || warn "виджет не был установлен"
else
    warn "kpackagetool6 не найден — удалите каталог плазмоида вручную"
fi

cat <<'EOF'

Готово. Виджет, который уже лежит на панели или рабочем столе, нужно убрать
вручную: правый клик → «Удалить виджет».
EOF
