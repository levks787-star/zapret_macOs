#!/bin/bash
# Диагностика: открываются ли Discord и YouTube напрямую и через zapret.
if command -v zapret-discord >/dev/null 2>&1; then
	exec zapret-discord check "$@"
elif [ -x /usr/local/zapret-discord/bin/zapret-discord ]; then
	exec /usr/local/zapret-discord/bin/zapret-discord check "$@"
else
	echo "zapret-discord не установлен. Установка: ./install.sh"
	exit 1
fi
