-- Zapret Discord — простое окно вкл/выкл для zapret-discord.
-- Собирается установщиком: osacompile -o "/Applications/Zapret Discord.app" ZapretDiscord.applescript
set ctl to "/usr/local/bin/zapret-discord"
try
	set st to do shell script ctl & " status --short"
on error
	display dialog "zapret-discord не установлен." buttons {"OK"} default button 1 with title "Zapret Discord" with icon stop
	return
end try
set choices to {"Включить", "Выключить", "Подобрать стратегию автоматически", "Следующая стратегия", "Проверить"}
set picked to choose from list choices with title "Zapret Discord" with prompt ("Сейчас: " & st & return & return & "Что сделать?") default items {"Включить"} OK button name "Выполнить" cancel button name "Закрыть"
if picked is false then return
set act to item 1 of picked
try
	if act is "Включить" then
		do shell script ctl & " on" with administrator privileges
		display dialog "Включено." & return & "Полностью закройте Discord и браузер (Cmd+Q) и откройте снова." buttons {"OK"} default button 1 with title "Zapret Discord"
	else if act is "Выключить" then
		do shell script ctl & " off" with administrator privileges
		display dialog "Выключено. Прокси возвращены как были." buttons {"OK"} default button 1 with title "Zapret Discord"
	else if act is "Подобрать стратегию автоматически" then
		set res to do shell script ctl & " auto 2>&1 | tail -n 1" with administrator privileges
		display dialog res buttons {"OK"} default button 1 with title "Zapret Discord"
	else if act is "Следующая стратегия" then
		set res to do shell script ctl & " strategy next 2>&1 | tail -n 1" with administrator privileges
		display dialog res buttons {"OK"} default button 1 with title "Zapret Discord"
	else if act is "Проверить" then
		set res to do shell script ctl & " check 2>&1"
		display dialog res buttons {"OK"} default button 1 with title "Zapret Discord"
	end if
on error errMsg
	display dialog "Не получилось: " & errMsg buttons {"OK"} default button 1 with title "Zapret Discord" with icon caution
end try
