#!/bin/bash
# Запускается launchd (io.github.levks787-star.zapret-discord.tpws) от пользователя nobody.
# Читает config и стратегию, затем exec tpws в SOCKS-режиме на 127.0.0.1.
ZD_HOME="/usr/local/zapret-discord"
STRATEGY=1
SOCKS_PORT=10987
# shellcheck disable=SC1091
[ -r "$ZD_HOME/config" ] && . "$ZD_HOME/config"

line="$(grep -E "^${STRATEGY}\|" "$ZD_HOME/lists/strategies.txt" 2>/dev/null | head -n 1)"
args="${line#*|}"; args="${args#*|}"
[ -n "$line" ] && [ -n "$args" ] || args="--tlsrec=midsld --split-pos=1 --oob"

HOSTS="$ZD_HOME/run/hosts.txt"
[ -s "$HOSTS" ] || HOSTS="$ZD_HOME/lists/discord.txt"

echo "$(date '+%Y-%m-%d %H:%M:%S') start tpws: strategy=$STRATEGY [$args] port=$SOCKS_PORT"
# $args намеренно без кавычек — это список параметров tpws
# shellcheck disable=SC2086
exec "$ZD_HOME/bin/tpws" --socks --bind-addr=127.0.0.1 --port="$SOCKS_PORT" \
	--filter-tcp=80 --hostlist="$HOSTS" --methodeol --new \
	--filter-tcp=443 --hostlist="$HOSTS" $args
