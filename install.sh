#!/bin/bash
# zapret-discord-macos — установщик.
#   curl -fsSL https://raw.githubusercontent.com/levks787-star/zapret_macOs/main/install.sh | bash
# или
#   git clone https://github.com/levks787-star/zapret_macOs.git && cd zapret_macOs && ./install.sh
#
# Запускайте от обычного пользователя, БЕЗ sudo — пароль спросится сам.
# Совместимо с /bin/bash 3.2 (штатный в macOS).

set -euo pipefail

# Всё в функции main — если скрипт скачался не полностью через curl | bash, ничего не выполнится.
main() {

REPO_OWNER="levks787-star"
REPO_NAME="zapret_macOs"
REPO_TARBALL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/main.tar.gz"

# Официальный релиз bol-van/zapret (зафиксирован и проверяется по SHA-256).
ZAPRET_VER="v72.13"
ZAPRET_URL="https://github.com/bol-van/zapret/releases/download/${ZAPRET_VER}/zapret-${ZAPRET_VER}.tar.gz"
ZAPRET_SHA256="25c74e6c5f48963fa244c2955e76694a07c39447245a0457e2efdc74b3317e68"
TPWS_SHA256="441524a76f52597a0e5c816d25ed1adfd93e5c34cc56c56e0dc00533929d1761"  # binaries/mac64/tpws (universal x86_64+arm64)

ZD_HOME="/usr/local/zapret-discord"
ZD_LABEL="io.github.levks787-star.zapret-discord"
LD_DIR="/Library/LaunchDaemons"
APP_PATH="/Applications/Zapret Discord.app"

STRATEGY=""
QUIC_BLOCK=1
WITH_APP=1
AUTO_PICK=1

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> Внимание:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==> Ошибка:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<USAGE
Установка zapret-discord для macOS (Discord + YouTube, движок tpws из bol-van/zapret).

  ./install.sh                  установить и включить (стратегия подбирается автоматически)
  ./install.sh --strategy N     сразу выбрать стратегию N (без автоподбора)
  ./install.sh --no-quic-block  не блокировать QUIC (UDP 443)
  ./install.sh --no-app         не создавать приложение «Zapret Discord» в /Applications
  ./install.sh --no-auto        не подбирать стратегию автоматически
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
		--strategy) [ $# -ge 2 ] || die "--strategy требует номер"; STRATEGY="$2"; AUTO_PICK=0; shift ;;
		--strategy=*) STRATEGY="${1#*=}"; AUTO_PICK=0 ;;
		--no-quic-block) QUIC_BLOCK=0 ;;
		--no-app) WITH_APP=0 ;;
		--no-auto) AUTO_PICK=0 ;;
		-h|--help) usage; exit 0 ;;
		*) usage; die "неизвестный параметр: $1" ;;
	esac
	shift
done

[ "$(uname -s)" = "Darwin" ] || die "это установщик для macOS. Для Arch Linux: https://github.com/${REPO_OWNER}/zapret-discord-arch"
[ "$(id -u)" -ne 0 ] || die "запускайте без sudo: ./install.sh (пароль спросится сам)"

ARCH="$(uname -m)"
OSVER="$(sw_vers -productVersion 2>/dev/null || echo '?')"
case "$ARCH" in
	arm64)  msg "macOS $OSVER, Apple Silicon (M1/M2/M3/M4…)" ;;
	x86_64) msg "macOS $OSVER, Intel" ;;
	*) die "неизвестная архитектура: $ARCH" ;;
esac
case "$OSVER" in 10.[0-9]|10.[0-9].*|10.1[0-2]|10.1[0-2].*) warn "macOS $OSVER очень старая — не проверялось." ;; esac

for t in curl shasum tar launchctl networksetup pfctl nc; do
	command -v "$t" >/dev/null 2>&1 || die "не найдена системная утилита $t"
done

# ---------- исходники этого репозитория ----------
SRC=""
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
	d="$(cd "$(dirname "$SELF")" && pwd)"
	[ -f "$d/bin/zapret-discord" ] && SRC="$d"
fi
TMP="$(mktemp -d /tmp/zapret-discord.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
if [ -z "$SRC" ]; then
	msg "Скачиваю $REPO_OWNER/$REPO_NAME…"
	curl -fsSL --retry 3 "$REPO_TARBALL" -o "$TMP/repo.tar.gz" || die "не удалось скачать $REPO_TARBALL"
	mkdir -p "$TMP/repo" && tar -xzf "$TMP/repo.tar.gz" -C "$TMP/repo" --strip-components 1
	SRC="$TMP/repo"
fi
[ -f "$SRC/bin/zapret-discord" ] || die "в $SRC нет bin/zapret-discord"

# ---------- tpws из официального релиза ----------
msg "Скачиваю bol-van/zapret $ZAPRET_VER (официальный релиз GitHub)…"
curl -fL --retry 3 --progress-bar "$ZAPRET_URL" -o "$TMP/zapret.tar.gz" || die "не удалось скачать $ZAPRET_URL"
got="$(shasum -a 256 "$TMP/zapret.tar.gz" | awk '{print $1}')"
[ "$got" = "$ZAPRET_SHA256" ] || die "контрольная сумма архива не совпала (ожидалась $ZAPRET_SHA256, получена $got)"
msg "SHA-256 архива совпал"
tar -xzf "$TMP/zapret.tar.gz" -C "$TMP" "zapret-${ZAPRET_VER}/binaries/mac64/tpws" || die "в архиве нет binaries/mac64/tpws"
TPWS="$TMP/zapret-${ZAPRET_VER}/binaries/mac64/tpws"
got="$(shasum -a 256 "$TPWS" | awk '{print $1}')"
[ "$got" = "$TPWS_SHA256" ] || die "контрольная сумма tpws не совпала"
# карантин Gatekeeper (curl его обычно не ставит, но при скачивании через браузер — ставит)
xattr -c "$TPWS" 2>/dev/null || true
chmod 755 "$TPWS"
# arm64-часть в релизе подписана ad-hoc. Если macOS всё же убивает процесс (код >= 128, обычно SIGKILL
# от проверки подписи) — переподписываем ad-hoc локально. Контрольная сумма уже проверена выше.
rc=0; "$TPWS" --version >/dev/null 2>&1 || rc=$?
if [ "$rc" -ge 128 ] && command -v codesign >/dev/null 2>&1; then
	warn "macOS не дала запустить tpws (код $rc) — переподписываю ad-hoc (codesign -s -)"
	codesign --force --sign - "$TPWS" 2>/dev/null || true
fi

# ---------- предупреждения о конфликтах ----------
if [ -d /opt/zapret ] || [ -f "$LD_DIR/zapret.plist" ]; then
	warn "найден официальный zapret (/opt/zapret). Два обхода сразу мешают друг другу."
	warn "Удалите его: sudo /opt/zapret/uninstall_easy.sh — или продолжайте на свой риск."
fi

msg "Устанавливаю в $ZD_HOME (нужен пароль администратора — символы при вводе не видны)…"
sudo -v || die "без прав администратора установка невозможна"

# старая установка — аккуратно выключить, сохранив user.txt и config
if [ -x "$ZD_HOME/bin/zapret-discord" ]; then
	msg "Найдена прошлая установка — обновляю"
	sudo "$ZD_HOME/bin/zapret-discord" off >/dev/null 2>&1 || true
fi

sudo /bin/bash -s -- "$SRC" "$TPWS" "$ZD_HOME" "$ZD_LABEL" "$LD_DIR" "$ZAPRET_VER" "$QUIC_BLOCK" "${STRATEGY:-}" <<'ROOT'
set -euo pipefail
SRC="$1"; TPWS="$2"; ZD_HOME="$3"; ZD_LABEL="$4"; LD_DIR="$5"; ZAPRET_VER="$6"; QUIC_BLOCK="$7"; STRATEGY="$8"

install -d -m 755 -o root -g wheel "$ZD_HOME" "$ZD_HOME/bin" "$ZD_HOME/libexec" "$ZD_HOME/lists" "$ZD_HOME/run" "$ZD_HOME/state"
install -m 755 -o root -g wheel "$TPWS" "$ZD_HOME/bin/tpws"
install -m 755 -o root -g wheel "$SRC/bin/zapret-discord" "$ZD_HOME/bin/zapret-discord"
install -m 755 -o root -g wheel "$SRC/libexec/run-tpws.sh" "$ZD_HOME/libexec/run-tpws.sh"
install -m 755 -o root -g wheel "$SRC/libexec/pac-server.sh" "$ZD_HOME/libexec/pac-server.sh"
install -m 755 -o root -g wheel "$SRC/uninstall.sh" "$ZD_HOME/uninstall.sh"
for f in discord.txt youtube.txt strategies.txt; do
	install -m 644 -o root -g wheel "$SRC/lists/$f" "$ZD_HOME/lists/$f"
done
# свой список пользователя не перезаписываем
[ -f "$ZD_HOME/lists/user.txt" ] || install -m 644 -o root -g wheel "$SRC/lists/user.txt" "$ZD_HOME/lists/user.txt"
printf '%s\n' "$ZAPRET_VER" > "$ZD_HOME/ZAPRET_VERSION"
cat "$SRC/VERSION" > "$ZD_HOME/VERSION" 2>/dev/null || echo "1.0.0" > "$ZD_HOME/VERSION"
xattr -cr "$ZD_HOME" 2>/dev/null || true

# config: сохраняем прошлые значения, недостающие — по умолчанию
touch "$ZD_HOME/config"
grep -q '^STRATEGY=' "$ZD_HOME/config" || echo "STRATEGY=1" >> "$ZD_HOME/config"
grep -q '^QUIC_BLOCK=' "$ZD_HOME/config" || echo "QUIC_BLOCK=$QUIC_BLOCK" >> "$ZD_HOME/config"
grep -q '^SOCKS_PORT=' "$ZD_HOME/config" || echo "SOCKS_PORT=10987" >> "$ZD_HOME/config"
grep -q '^PAC_PORT=' "$ZD_HOME/config" || echo "PAC_PORT=10988" >> "$ZD_HOME/config"
grep -q '^ENABLED=' "$ZD_HOME/config" || echo "ENABLED=0" >> "$ZD_HOME/config"
chmod 644 "$ZD_HOME/config"

install -d -m 755 -o nobody -g nobody /Library/Logs/zapret-discord

install -d -m 755 /usr/local/bin
ln -sf "$ZD_HOME/bin/zapret-discord" /usr/local/bin/zapret-discord

for j in tpws pac ensure; do
	install -m 644 -o root -g wheel "$SRC/launchd/$ZD_LABEL.$j.plist" "$LD_DIR/$ZD_LABEL.$j.plist"
done
# ensure-задача грузится всегда (сама ничего не делает, когда выключено)
launchctl bootout "system/$ZD_LABEL.ensure" 2>/dev/null || true
launchctl enable "system/$ZD_LABEL.ensure" 2>/dev/null || true
launchctl bootstrap system "$LD_DIR/$ZD_LABEL.ensure.plist" 2>/dev/null || launchctl load -w "$LD_DIR/$ZD_LABEL.ensure.plist" 2>/dev/null || true

/usr/local/bin/zapret-discord quic "$( [ "$QUIC_BLOCK" = 1 ] && echo on || echo off)" >/dev/null
if [ -n "$STRATEGY" ]; then /usr/local/bin/zapret-discord strategy "$STRATEGY"; fi
/usr/local/bin/zapret-discord on
ROOT

if [ "$AUTO_PICK" = 1 ]; then
	msg "Проверяю, открываются ли Discord и YouTube, и при необходимости подбираю стратегию…"
	sudo /usr/local/bin/zapret-discord auto --if-needed || true
fi

if [ "$WITH_APP" = 1 ] && command -v osacompile >/dev/null 2>&1; then
	msg "Создаю приложение «Zapret Discord» в /Applications"
	sudo rm -rf "$APP_PATH"
	if sudo osacompile -o "$APP_PATH" "$SRC/app/ZapretDiscord.applescript" >/dev/null 2>&1; then
		sudo xattr -cr "$APP_PATH" 2>/dev/null || true
	else
		warn "не удалось собрать приложение (не страшно — есть команда zapret-discord)"
	fi
fi

echo
msg "Готово!"
cat <<DONE

  1. Полностью закройте Discord и браузер (Cmd+Q, не просто крестик) и откройте снова.
  2. Включить / выключить:   zapret-discord on   |   zapret-discord off
     или приложение «Zapret Discord» в Программах (Launchpad).
  3. Не открывается — подобрать стратегию:  zapret-discord auto
  4. Проверка:  zapret-discord check        Удаление:  zapret-discord uninstall

  Чат, картинки, сервера Discord и YouTube — должны работать.
  Голосовые каналы Discord (UDP) на macOS этот способ НЕ обходит — см. README, раздел «Голос».
DONE
}

main "$@"
