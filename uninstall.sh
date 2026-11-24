#!/bin/bash
# zapret-discord-macos — полное удаление. Возвращает системный прокси и pf как были.
#   ./uninstall.sh          (или: zapret-discord uninstall)
set -u

ZD_HOME="/usr/local/zapret-discord"
ZD_LABEL="io.github.levks787-star.zapret-discord"
LD_DIR="/Library/LaunchDaemons"
APP_PATH="/Applications/Zapret Discord.app"
PAC_URL_DEFAULT="http://127.0.0.1:10988/proxy.pac"

[ "$(uname -s)" = "Darwin" ] || { echo "Это для macOS."; exit 1; }

if [ "${1:-}" != "--yes" ]; then
	printf 'Удалить zapret-discord полностью? [y/N] '
	read -r ans </dev/tty || ans=""
	case "$ans" in y|Y|д|Д|yes|да) ;; *) echo "Отменено."; exit 0 ;; esac
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "Нужны права администратора — введите пароль (символы не отображаются)."
	exec sudo /bin/bash "$0" --yes
fi

echo "==> Выключаю (возвращаю прокси и pf)…"
if [ -x "$ZD_HOME/bin/zapret-discord" ]; then
	"$ZD_HOME/bin/zapret-discord" off >/dev/null 2>&1 || true
fi

# подстраховка, если управляющий скрипт уже удалён или сломан
PAC_URL="$PAC_URL_DEFAULT"
networksetup -listallnetworkservices 2>/dev/null | sed '1d' | sed 's/^\*//' | while IFS= read -r svc; do
	[ -n "$svc" ] || continue
	cur="$(networksetup -getautoproxyurl "$svc" </dev/null 2>/dev/null | sed -n 's/^URL: //p')"
	[ "$cur" = "$PAC_URL" ] && networksetup -setautoproxystate "$svc" off </dev/null 2>/dev/null
done
pfctl -q -a com.apple/zapret-discord -F all 2>/dev/null || true
if [ -s /var/run/zapret-discord.pftoken ]; then
	pfctl -q -X "$(cat /var/run/zapret-discord.pftoken)" 2>/dev/null || true
fi
rm -f /var/run/zapret-discord.pftoken

echo "==> Останавливаю службы launchd…"
for j in tpws pac ensure; do
	launchctl bootout "system/$ZD_LABEL.$j" 2>/dev/null || launchctl unload "$LD_DIR/$ZD_LABEL.$j.plist" 2>/dev/null || true
	launchctl enable "system/$ZD_LABEL.$j" 2>/dev/null || true   # убрать запись «disabled» из базы launchd
	rm -f "$LD_DIR/$ZD_LABEL.$j.plist"
done
pkill -f "$ZD_HOME/bin/tpws" 2>/dev/null || true

echo "==> Удаляю файлы…"
[ -L /usr/local/bin/zapret-discord ] && rm -f /usr/local/bin/zapret-discord
rm -rf "$APP_PATH" "/Library/Logs/zapret-discord"
case "$ZD_HOME" in /usr/local/zapret-discord) rm -rf "$ZD_HOME" ;; esac
dscacheutil -flushcache 2>/dev/null; killall -HUP mDNSResponder 2>/dev/null

echo "==> Готово. zapret-discord удалён, настройки прокси возвращены. Перезапустите Discord и браузер."
