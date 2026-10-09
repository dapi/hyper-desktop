# Hyper Desktop

Тонкая macOS-оболочка для локального Hyper. Приложение показывает существующий веб-интерфейс в `WKWebView` и при необходимости просит `launchd` запустить установленный сервис.

## Вкладки

- `⌘T` — новая вкладка.
- `⌘W` — закрыть текущую; закрытие последней вкладки закрывает окно.
- `⌘1` и `⌘2` — перейти к первой или второй вкладке.

## Границы

- Исходники Hyper остаются изменяемыми в `~/code/hyper-code`.
- `.hyper/` остаётся runtime-overlay рядом с checkout и не упаковывается в `.app`.
- PostgreSQL внешний; оболочка не устанавливает и не запускает базу.
- Порт приложения сейчас `3010`, адрес — только `127.0.0.1`.
- Процесс Hyper и его обновления остаются под управлением существующего LaunchAgent.

## Сборка

Нужны macOS 13+, Swift 6 и установленный LaunchAgent Hyper.

```sh
swift build
./scripts/package-app.sh
open dist/Hyper.app
```

`scripts/package-app.sh` создаёт локально подписанный `.app` для разработки. LaunchAgent label можно задать через `HYPER_LAUNCH_AGENT_LABEL`; по умолчанию используется `com.hypercode.server`. Для распространения потребуются Developer ID signing и notarization.
