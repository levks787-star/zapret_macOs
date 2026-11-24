# zapret-discord-macos

**Обход блокировок Discord и YouTube для macOS** — на движке `tpws` из [bol-van/zapret](https://github.com/bol-van/zapret).
Ставится одной командой, включается и выключается одной командой (или приложением «Zapret Discord»).
Подходит для Mac на Apple Silicon (M1/M2/M3/M4) и на Intel.

> **Честно о том, что это.** Это **не форк zapret** и не новый движок обхода. Это обёртка для macOS:
> - движок — `tpws` из [bol-van/zapret](https://github.com/bol-van/zapret) (официальный релиз скачивается при установке и проверяется по SHA-256);
> - списки доменов Discord и YouTube — из [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube);
> - набор tpws-стратегий для macOS — по мотивам [SoKnight/zapret-discord-youtube-macos](https://github.com/SoKnight/zapret-discord-youtube-macos)
>   и документации bol-van; идея «SOCKS + PAC вместо прозрачного режима» — как в [dsemak/zapret-macos-easy](https://github.com/dsemak/zapret-macos-easy).
>
> **Наше** — установщик в одну команду, команда `zapret-discord`, службы launchd, автоподбор стратегии,
> аккуратная работа с системным прокси и pf (всё возвращается как было), удаление.
> Чужих бинарников в репозитории нет.

## Что работает, а что нет

| | Работает? |
|---|---|
| Discord: вход, чат, сервера, картинки, обновления | ✅ должно (TCP) |
| YouTube: сайт, превью, видео | ✅ должно (TCP; QUIC блокируется, чтобы видео шло через обход) |
| **Голосовые каналы, звонки, демонстрация экрана в Discord** | ❌ **нет** — это UDP, а на macOS у zapret есть только `tpws` (умеет только TCP). См. раздел [Голос](#голос-discord) |
| Браузеры Safari, Chrome, Яндекс, Edge, Arc | ✅ берут системный PAC сами |
| Firefox | ⚠️ нужно включить «Использовать системные настройки прокси» (см. ниже) |

Обход работает не у всех провайдеров. Если провайдер режет по IP, а не по DPI, — поможет только VPN.

## Установка одной командой

1. Откройте **Терминал**: `Cmd + Пробел` → наберите «Терминал» → Enter.
2. Вставьте строку и нажмите Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/levks787-star/zapret-discord-macos/main/install.sh | bash
```

3. Когда попросит **Password** — введите пароль от своей учётной записи Mac (буквы при вводе не видны — так и надо) и нажмите Enter.
4. Дождитесь «Готово!». Установщик сам проверит Discord и YouTube и, если надо, подберёт рабочую стратегию.
5. **Полностью закройте Discord и браузер (Cmd+Q)** и откройте снова.

Запускать без `sudo` — пароль спросится сам.

Вариант через git:

```bash
git clone https://github.com/levks787-star/zapret-discord-macos.git && cd zapret-discord-macos && ./install.sh
```

Если скачали ZIP через Safari, сначала снимите «карантин» Gatekeeper, иначе macOS может не дать запустить скрипты:

```bash
cd ~/Downloads/zapret-discord-macos-main && xattr -cr . && ./install.sh
```

### Параметры установщика

| Команда | Что делает |
|---|---|
| `./install.sh` | установить, включить, автоподбор стратегии, приложение в «Программах» |
| `./install.sh --strategy 3` | сразу стратегия 3, без автоподбора |
| `./install.sh --no-auto` | без автоподбора (стратегия 1) |
| `./install.sh --no-quic-block` | не блокировать QUIC (UDP 443) |
| `./install.sh --no-app` | без приложения «Zapret Discord» |

Через curl параметры передаются так: `curl -fsSL …/install.sh | bash -s -- --strategy 3`.

## Включить / выключить

Приложение **«Zapret Discord»** в Launchpad / Программах: Включить, Выключить, Подобрать стратегию, Следующая стратегия, Проверить.

Или в Терминале:

| Команда | Что делает |
|---|---|
| `zapret-discord on` | включить (и автозапуск после перезагрузки) |
| `zapret-discord off` | выключить, вернуть настройки прокси как были |
| `zapret-discord status` | состояние и текущая стратегия |
| `zapret-discord check` | открываются ли Discord и YouTube — напрямую и через обход |
| `zapret-discord auto` | перебрать стратегии и выбрать рабочую |
| `zapret-discord strategy` | список стратегий |
| `zapret-discord strategy 4` | выбрать стратегию 4 (`strategy next` — следующую) |
| `zapret-discord quic on\|off` | блокировать QUIC, чтобы YouTube шёл через обход |
| `zapret-discord restart` | перечитать списки доменов |
| `zapret-discord log` | журнал tpws |
| `zapret-discord uninstall` | удалить всё |

После любой смены — перезапустите Discord и браузер (Cmd+Q).

## Стратегии

Стратегии Flowseal для Windows (`general*.bat`: `fake`, `multisplit`, `.bin`-фейки) на macOS **не переносятся** —
там нет `nfqws`/WinDivert. На Mac работает только `tpws`, его приёмы: разрез TLS ClientHello (`--split-pos`),
TLS-запись из двух частей (`--tlsrec`), OOB-байт (`--oob`), обратный порядок (`--disorder`).
На macOS `--oob` и `--disorder` вместе не работают.

| № | Название | Параметры tpws (порт 443) |
|---|---|---|
| 1 | oob-tlsrec-midsld | `--tlsrec=midsld --split-pos=1 --oob` |
| 2 | oob-split1 | `--split-pos=1 --oob` |
| 3 | disorder-split1-midsld | `--split-pos=1,midsld --disorder` (умолчание bol-van) |
| 4 | oob-tlsrec-sniext1 | `--tlsrec=sniext+1 --split-pos=1 --oob` |
| 5 | disorder-tlsrec-midsld | `--tlsrec=midsld --split-pos=1 --disorder` |
| 6 | oob-split1-midsld | `--split-pos=1,midsld --oob` |
| 7 | tlsrec-midsld | `--tlsrec=midsld --split-pos=1` |
| 8 | disorder-midsld | `--split-pos=midsld --disorder` |
| 9 | split1-midsld | `--split-pos=1,midsld` |
| 10 | oob-midsld | `--split-pos=midsld --oob` |

Для HTTP (порт 80) всегда добавляется `--methodeol`. Свою стратегию можно дописать строкой
`11|моя|--параметры` в `/usr/local/zapret-discord/lists/strategies.txt` (через `sudo nano`) и выбрать `zapret-discord strategy 11`.
`zapret-discord auto` проверяет discord.com, gateway.discord.gg, youtube.com и картинку с i.ytimg.com через каждую стратегию.

## Как это устроено

```
Discord / браузер ──(системный PAC)──┬── домены Discord и YouTube ──> tpws SOCKS 127.0.0.1:10987 ──> интернет
                                     └── всё остальное ──────────────> напрямую
```

- **tpws** (bol-van/zapret v72.13, универсальный бинарник x86_64 + arm64) работает в **SOCKS-режиме** на `127.0.0.1:10987`
  от пользователя `nobody` (служба launchd `io.github.levks787-star.zapret-discord.tpws`, перезапускается сама).
- **PAC-файл** отдаёт крошечный HTTP-обработчик на `127.0.0.1:10988` (launchd-сокет, без Python и прочих зависимостей).
  В PAC — только домены из `lists/discord.txt`, `lists/youtube.txt` и вашего `lists/user.txt`, с запасным `DIRECT`:
  если tpws вдруг упадёт, сайты пойдут напрямую, а не пропадут.
- **Системный прокси**: на всех сетевых службах (Wi-Fi, Ethernet, …) включается «Автоматическая настройка прокси» с этим PAC.
  Прежние настройки сохраняются в `/usr/local/zapret-discord/state/proxy-backup.tsv` и возвращаются при `off`/удалении.
- **Блок QUIC** (UDP 443): одно правило `block return out quick proto udp to port 443` в pf-якоре
  `com.apple/zapret-discord`. **`/etc/pf.conf` не меняется** — штатный pf.conf macOS уже вызывает `anchor "com.apple/*"`.
  pf включается через `pfctl -E` (со счётчиком-токеном) и отпускается `pfctl -X <токен>`, так что если pf был
  выключен до нас — после `off` он снова выключен. QUIC блокируется для всех сайтов (браузеры просто переходят на TCP);
  выключить: `zapret-discord quic off`.
- **Автозапуск и самопочинка**: служба `…ensure` при загрузке и каждые 5 минут проверяет, что всё на месте
  (новая сеть, перезагруженный pf, упавший tpws). Когда выключено — ничего не делает.

Почему не прозрачный режим через pf (как в `install_easy.sh`)? На macOS 14.5+ он у многих ломается:
`ioctl(DIOCNATLOOK) failed: Operation not permitted` ([bol-van/zapret#1482](https://github.com/bol-van/zapret/issues/1482)).
SOCKS + PAC от этого не зависит и не трогает чужой трафик.

**Права и защита macOS.** Нужен пароль администратора (sudo): установка в `/usr/local`, службы в `/Library/LaunchDaemons`,
сетевые настройки, pf. **SIP отключать не нужно.** Gatekeeper: файлы, скачанные curl'ом, карантина не получают;
установщик на всякий случай снимает атрибуты (`xattr -c`) и, если macOS всё же не даёт запустить `tpws`,
переподписывает его локально ad-hoc (`codesign -s -`) — уже после проверки SHA-256.

Файлы: `/usr/local/zapret-discord/` (tpws, скрипты, списки, config), `/usr/local/bin/zapret-discord`,
`/Library/LaunchDaemons/io.github.levks787-star.zapret-discord.{tpws,pac,ensure}.plist`, журналы в `/Library/Logs/zapret-discord/`,
приложение `/Applications/Zapret Discord.app`.

## Голос Discord

**Голосовые каналы, звонки и стримы через этот инструмент на macOS не заработают.** Голос Discord — это UDP
(порты 19294–19344 и 50000–50100 до серверов `*.discord.media`). На Windows и Linux zapret обходит его через
`nfqws`/WinDivert, подмешивая фейковые пакеты. На macOS этого механизма нет: divert-сокеты Apple выпилила, `dvtws`
«собирается, но бесполезен» (документация bol-van), а `tpws` — только TCP. Автор zapret прямо пишет:
«nfqws нет на macos, discord voice нельзя обойти при помощи tpws» ([#610](https://github.com/bol-van/zapret/issues/610)).

Что можно сделать:

1. **Просто попробовать.** У части провайдеров голос не режут: если чат открылся, зайдите в голосовой канал.
   Если висит «Подключение к RTC» / «Не установлен маршрут» — значит, режут.
2. **Самое простое и надёжное — VPN только на время звонков** (например, AmneziaVPN/AmneziaWG или любой другой рабочий у вас).
   Перед включением VPN выключите обход: `zapret-discord off`, после — `zapret-discord on`.
3. **Звонки с телефона.** На Android есть ByeDPI/zapret-приложения, у которых голос Discord иногда работает.
4. **Для энтузиастов (не автоматизировано, нами не проверено):** ByeDPI (`ciadpi`, умеет SOCKS5 UDP и `--udp-fake`)
   собрать из исходников + [tun2socks](https://github.com/xjasonlyu/tun2socks) (есть сборки darwin) +
   маршруты на IP голосовых серверов Discord ([пример](https://gist.github.com/atomlab/674cf1fbcec6e5642c78e7c2e613bb19)).
   Сам Discord desktop SOCKS для голоса не поддерживает, поэтому нужен именно TUN. Списки IP меняются, работает не у всех.
   [SonicDPI](https://github.com/by-sonic/sonicdpi) обещает голос на macOS только в будущей версии (через NetworkExtension).

## Если не работает

| Проблема | Что сделать |
|---|---|
| Discord бесконечно «подключается» | `zapret-discord check` → `zapret-discord auto` → перезапустить Discord (Cmd+Q) |
| Всё равно не грузится | `zapret-discord strategy next` по очереди, после каждой — перезапуск Discord |
| YouTube открывается, видео не идёт | `zapret-discord quic on`; в Chrome: `chrome://flags/#enable-quic` → **Disabled**; перезапустить браузер |
| Firefox не обходит | Настройки → Основные → Параметры сети → **Использовать системные настройки прокси**; если не помогло — `about:config` → `network.proxy.default_pac_script_socks_version` = `5` |
| Сайты не открываются по имени, подменённые страницы провайдера | DNS провайдера: Системные настройки → Сеть → Wi-Fi → Подробнее → DNS → `8.8.8.8` и `1.1.1.1` |
| «Пропал интернет» | `zapret-discord off`. Если команда недоступна: Системные настройки → Сеть → Wi-Fi → Подробнее → Прокси → выключить «Автоматическая настройка прокси» |
| Стоит VPN / корпоративный прокси | Они спорят за настройки прокси. Выключите один из них |
| «Общий доступ к интернету» (Internet Sharing) | Для раздачи на другие устройства обход не работает — только для этого Mac |
| Стоит официальный zapret в `/opt/zapret` | Удалите его (`sudo /opt/zapret/uninstall_easy.sh`) — два обхода мешают друг другу |
| Ни одна стратегия не помогает | Провайдер режет по IP — нужен VPN |

Свои домены (например, ещё какой-то сайт): `sudo nano /usr/local/zapret-discord/lists/user.txt`, по одному в строке, затем `zapret-discord restart`.

## Удаление

```bash
zapret-discord uninstall
```

или из папки репозитория `./uninstall.sh`. Удаляются службы, файлы, приложение; системный прокси и pf
возвращаются в прежнее состояние, `/etc/pf.conf` не трогался вообще.

## Что не проверено

Скрипты написаны и проверены `shellcheck`, логика (генерация PAC, сохранение/возврат прокси, pf-токен) прогнана
на Linux с заглушками системных утилит, параметры всех стратегий проверены на Linux-сборке того же `tpws v72.13`.
**На живом Mac установка пока не прогонялась.** Если что-то не так — откройте issue с выводом `zapret-discord check` и `zapret-discord log`.

## Структура

```
install.sh              установщик (от пользователя, sudo спросит сам)
uninstall.sh            удаление
check.sh                диагностика (= zapret-discord check)
bin/zapret-discord      управляющая команда
libexec/run-tpws.sh     запуск tpws со стратегией из config (служба launchd)
libexec/pac-server.sh   отдача PAC-файла на 127.0.0.1:10988 (launchd inetd)
launchd/*.plist         службы: tpws, pac, ensure
lists/discord.txt       домены Discord          lists/youtube.txt  домены YouTube
lists/user.txt          свои домены              lists/strategies.txt  стратегии tpws
app/ZapretDiscord.applescript  приложение «Zapret Discord» (собирается osacompile при установке)
```

## Лицензии и благодарности

Код этого репозитория — **MIT** (см. [LICENSE](LICENSE)).

| Проект | Что берём | Лицензия |
|---|---|---|
| [bol-van/zapret](https://github.com/bol-van/zapret) | `tpws` (скачивается при установке, релиз v72.13, SHA-256 сверяется) | MIT |
| [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) | списки доменов Discord / YouTube | MIT |
| [SoKnight/zapret-discord-youtube-macos](https://github.com/SoKnight/zapret-discord-youtube-macos) | набор tpws-стратегий для macOS (идеи) | MIT |
| [dsemak/zapret-macos-easy](https://github.com/dsemak/zapret-macos-easy) | идея SOCKS + PAC + блок QUIC на macOS | см. репозиторий автора |

Спасибо **bol-van**, **Flowseal**, **SoKnight** и **dsemak** — вся магия обхода сделана ими.
