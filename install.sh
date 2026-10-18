#!/usr/bin/env bash
#
# Lofi Player — installer.
#
# Installs two things:
#   1. the Plasma widget itself (kpackagetool6 -> ~/.local/share/plasma/plasmoids)
#   2. a tiny helper service that publishes the track lofiradio.ru is playing
#
# Everything goes into the user's home directory. No root, no system packages.
set -euo pipefail

PKG_ID="org.koda.lofiplayer"
UNIT_NAME="lofi-nowplaying.service"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HELPER_DIR="$DATA_HOME/lofiplayer"
UNIT_DIR="$CONFIG_HOME/systemd/user"

info() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "не найден «$1». $2"
}

info "Проверяю зависимости"
need kpackagetool6 "Установите plasma-workspace (KDE Plasma 6)."
need python3 "Установите python."
[ -f "$SRC_DIR/package/metadata.json" ] || die "не найден package/metadata.json — запускайте скрипт из корня репозитория."
[ -f "$SRC_DIR/helper/lofi-nowplaying.py" ] || die "не найден helper/lofi-nowplaying.py"

# --- 1. виджет -------------------------------------------------------------
info "Устанавливаю виджет $PKG_ID"
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$PKG_ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC_DIR/package"
    info "Обновил существующую установку"
else
    kpackagetool6 --type Plasma/Applet --install "$SRC_DIR/package"
fi

# --- 2. helper -------------------------------------------------------------
info "Устанавливаю helper в $HELPER_DIR"
install -d -m 755 "$HELPER_DIR"
install -m 755 "$SRC_DIR/helper/lofi-nowplaying.py" "$HELPER_DIR/lofi-nowplaying.py"

info "Устанавливаю systemd-юнит $UNIT_NAME"
install -d -m 755 "$UNIT_DIR"
# %h в шаблоне юнита — это $HOME, но ExecStart всё равно подставляем целиком,
# чтобы установка работала и при нестандартном XDG_DATA_HOME.
sed "s|^ExecStart=.*|ExecStart=$(command -v python3) $HELPER_DIR/lofi-nowplaying.py|" \
    "$SRC_DIR/helper/$UNIT_NAME" > "$UNIT_DIR/$UNIT_NAME"
chmod 644 "$UNIT_DIR/$UNIT_NAME"

# --- 3. запуск -------------------------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
    info "Запускаю сервис"
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT_NAME"
    sleep 1
    if systemctl --user is-active --quiet "$UNIT_NAME"; then
        info "Сервис активен"
    else
        warn "Сервис не запустился. Смотрите: journalctl --user -u $UNIT_NAME -n 50"
    fi
else
    warn "systemctl не найден — запустите helper вручную: python3 $HELPER_DIR/lofi-nowplaying.py"
fi

cat <<EOF

Готово.

  Виджет:  правый клик по панели или рабочему столу → «Добавить виджеты…» → «Lofi Player»
  Титулы:  http://127.0.0.1:8731/nowplaying.json
  Логи:    journalctl --user -u $UNIT_NAME -f

Если виджета нет в списке — перезапустите оболочку:
  systemctl --user restart plasma-plasmashell.service
EOF
