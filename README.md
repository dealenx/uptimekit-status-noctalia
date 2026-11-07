# uptimekit-status-noctalia

Бар-виджет [Noctalia Shell](https://noctalia.dev) v5+: статус вашей UptimeKit статус-страницы прямо в панели.
Работает **без API-ключа** — читает публичный `summary.json` (`<база>[/<слаг>]/summary.json`, кэш 30 с, CORS `*`).

Показывает `N/M up` с цветным глифом (зелёный — все up, жёлтый — частично/деградация/инцидент, красный — все down / нет связи),
тултип с компонентами по группам, активными инцидентами и техработами, панель с детализацией по клику.

## Установка

Скопируйте каталог в источники плагинов Noctalia и включите:

```bash
cp -r uptimekit-status-noctalia ~/.local/share/noctalia/plugins/uptimekit-status
noctalia msg plugins enable dealenx/uptimekit-status
```

Затем добавьте виджет: **Settings → Bar → Add widget → "UptimeKit Status"**, или вручную в `config.toml`:

```toml
[bar.default]
end = [ "ukit-monitor", ... ]

[widget.ukit-monitor]
type = "dealenx/uptimekit-status:ukit"
base_url = "https://status.example.com"
status_page_slug = ""          # пусто — корень домена; иначе слаг из URL
```

## Настройки виджета

| Ключ | По умолчанию | Описание |
|---|---|---|
| `base_url` | *(пусто)* | База UptimeKit, например `https://status.example.com` |
| `status_page_slug` | *(пусто)* | Слаг страницы статуса (`/<слаг>` в URL); пусто — корень домена |
| `interval_sec` | `30` | Интервал опроса (10–3600 c) |
| `open_url_on_click` | `true` | Открывать статус-страницу браузером по клику |
| `compact` | `false` | Компактный текст без «up» |

## Источник данных

Публичный JSON-саммари статус-страницы UptimeKit (см. [доку](https://docs.uptimekit.dev/configuration/status_pages/)):
`page`, `status` (`operational`/`degraded`/`outage`/`maintenance`/`unknown`), `components` (`up`/`down`/`degraded`/`maintenance`/`pending`),
активные `incidents` и `maintenances` (активные + за последние 24 ч). Ключ не нужен; защищённые паролем страницы отдают 404.

## Файлы

- `plugin.toml` — манифест (widget + panel) и схема настроек
- `widget.luau` — опрос `summary.json`, рендер на баре, публикация state для панели
- `panel.luau` — панель: статус страницы, инциденты, техработы, компоненты по группам
- `translations/{en,ru}.json` — локализация
