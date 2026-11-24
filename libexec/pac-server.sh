#!/bin/bash
# Крошечный HTTP-сервер для PAC-файла. launchd (inetdCompatibility) подключает сокет к stdin/stdout,
# по процессу на запрос. Слушает только 127.0.0.1. Никаких внешних зависимостей.
PAC="/usr/local/zapret-discord/run/proxy.pac"
IFS= read -r -t 5 _req || exit 0
while IFS= read -r -t 5 h; do
	h="${h%$'\r'}"
	[ -z "$h" ] && break
done
if [ -r "$PAC" ]; then
	len="$(wc -c < "$PAC" | tr -d ' ')"
	printf 'HTTP/1.0 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nContent-Length: %s\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n' "$len"
	cat "$PAC"
else
	body='function FindProxyForURL(url, host) { return "DIRECT"; }'
	printf 'HTTP/1.0 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s' "${#body}" "$body"
fi
