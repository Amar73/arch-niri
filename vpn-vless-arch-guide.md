# Настройка VPN (VLESS + REALITY) на Arch Linux с выборочным роутингом

## Оглавление

1. [Что используем и почему](#1-что-используем-и-почему)
2. [Установка Xray на клиенте](#2-установка-xray-на-клиенте)
3. [Конфигурация клиента](#3-конфигурация-клиента)
4. [Запуск и проверка](#4-запуск-и-проверка)
5. [Настройка браузера Chrome](#5-настройка-браузера-chrome)
6. [Запуск Chrome через fuzzel](#6-запуск-chrome-через-fuzzel)
7. [Серверная часть: WARP для обхода блокировок](#7-серверная-часть-warp-для-обхода-блокировок)
8. [Добавление WARP в Xray на сервере](#8-добавление-warp-в-xray-на-сервере)
9. [Выборочный роутинг: справочник доменов](#9-выборочный-роутинг-справочник-доменов)
10. [Диагностика и частые ошибки](#10-диагностика-и-частые-ошибки)

---

## 1. Что используем и почему

| Компонент | Роль |
|-----------|------|
| **Xray** | VPN-клиент на локальной машине |
| **VLESS + REALITY** | Протокол туннеля — устойчив к DPI, маскируется под HTTPS |
| **3x-ui** | Веб-панель управления Xray на сервере |
| **Cloudflare WARP** | На сервере — смена exit IP для обхода блокировок по IP |

**Почему Xray, а не v2ray:** Xray — активно развиваемый форк v2ray с полной поддержкой VLESS + REALITY и лучшей производительностью.

**Принцип работы выборочного роутинга:** приложение отправляет трафик в Xray (SOCKS5/HTTP прокси), Xray по правилам решает — пустить через туннель или напрямую. Вся логика в одном месте — `config.json`.

---

## 2. Установка Xray на клиенте

```bash
# Установка через AUR
yay -S xray

# Проверка
xray version
```

---

## 3. Конфигурация клиента

Создаём `/etc/xray/config.json`. Ниже — готовый шаблон с пояснениями.

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    },
    {
      "port": 1081,
      "listen": "127.0.0.1",
      "protocol": "http"
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "YOUR_SERVER_IP",
            "port": 443,
            "users": [
              {
                "id": "YOUR_UUID",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "serverName": "www.cloudflare.com",
          "fingerprint": "chrome",
          "publicKey": "YOUR_PUBLIC_KEY",
          "shortId": "YOUR_SHORT_ID"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "domain": [
          "youtube.com",
          "youtu.be",
          "ytimg.com",
          "googlevideo.com",
          "yt3.ggpht.com",

          "gemini.google.com",
          "notebooklm.google.com",
          "aistudio.google.com",

          "chatgpt.com",
          "openai.com",
          "oaistatic.com",
          "oaiusercontent.com",
          "auth.openai.com",

          "claude.ai",
          "anthropic.com",
          "api.anthropic.com",

          "github.com",
          "api.github.com",
          "copilot.github.com",
          "githubcopilot.com",
          "github.githubassets.com",
          "raw.githubusercontent.com",

          "vscode.dev",
          "marketplace.visualstudio.com",
          "update.code.visualstudio.com",
          "vscode-cdn.net",
          "gallery.vsassets.io",
          "obsidian.md",
          "api.obsidian.md",
          "releases.obsidian.md",
          "regexp:sync-\\d+\\.obsidian\\.md"
        ],
        "outboundTag": "proxy"
      },
      {
        "type": "field",
        "ip": [
          "1.1.1.1",
          "8.8.8.8",
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      }
    ]
  }
}
```

### Где взять параметры подключения

Все параметры берутся из панели 3x-ui на сервере (`http://SERVER_IP:2053`):

| Параметр | Где найти |
|----------|-----------|
| `YOUR_SERVER_IP` | IP адрес сервера |
| `YOUR_UUID` | Inbounds → редактировать → UUID пользователя |
| `YOUR_PUBLIC_KEY` | Inbounds → realitySettings → publicKey |
| `YOUR_SHORT_ID` | Inbounds → realitySettings → один из shortIds |
| `serverName` | Должен совпадать с `serverNames` на сервере |

> **Критично:** `serverName` в клиенте должен совпадать с `serverNames` в realitySettings на сервере. Несовпадение — главная причина EOF при handshake.

---

## 4. Запуск и проверка

```bash
# Валидация конфига перед запуском
sudo xray run -test -confdir /etc/xray/

# Включаем и запускаем
sudo systemctl enable --now xray

# Статус
systemctl status xray

# Логи в реальном времени
journalctl -u xray -f
```

### Проверка туннеля

```bash
# Через SOCKS5 — должен вернуть IP сервера, не твой
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me

# Через HTTP прокси
curl --proxy http://127.0.0.1:1081 https://ifconfig.me

# Прямой запрос — твой реальный IP (для сравнения)
curl https://ifconfig.me
```

Если первые два возвращают IP сервера — туннель работает.

---

## 5. Настройка браузера Chrome

Chrome нужно явно направить через Xray. Делается через флаг запуска:

```bash
google-chrome-stable --proxy-server="socks5://127.0.0.1:1080"
```

После этого весь трафик Chrome идёт через Xray, а Xray уже сам решает — что через туннель, что напрямую — по правилам в `config.json`.

---

## 6. Запуск Chrome через fuzzel

Создаём скрипт-обёртку:

```bash
sudo tee /usr/local/bin/chrome-proxy <<'EOF'
#!/bin/bash
exec google-chrome-stable \
  --proxy-server="socks5://127.0.0.1:1080" \
  "$@"
EOF
sudo chmod +x /usr/local/bin/chrome-proxy
```

Переопределяем `.desktop` файл:

```bash
cp /usr/share/applications/google-chrome.desktop \
   ~/.local/share/applications/google-chrome.desktop

sed -i 's|Exec=/usr/bin/google-chrome-stable|Exec=/usr/local/bin/chrome-proxy|g' \
  ~/.local/share/applications/google-chrome.desktop

update-desktop-database ~/.local/share/applications/
```

Проверяем:

```bash
grep Exec ~/.local/share/applications/google-chrome.desktop
# Должно быть:
# Exec=/usr/local/bin/chrome-proxy %U
# Exec=/usr/local/bin/chrome-proxy
# Exec=/usr/local/bin/chrome-proxy --incognito
```

Проверка — IP должен быть серверный:

```bash
/usr/local/bin/chrome-proxy --headless --dump-dom \
  "https://ifconfig.me" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1
```

---

## 7. Серверная часть: WARP для обхода блокировок

Некоторые сервисы (Anthropic, OpenAI) блокируют датацентровые IP. Решение — Cloudflare WARP на сервере: трафик выходит через IP Cloudflare, которые не заблокированы.

**Установка на сервере (Debian/Ubuntu):**

```bash
# Устанавливаем зависимости
sudo apt update && sudo apt install -y gpg curl apt-transport-https

# Создаём директорию для ключей
sudo mkdir -p /usr/share/keyrings

# Добавляем ключ Cloudflare
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

# Добавляем репозиторий (замени bookworm на свой codename)
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] \
  https://pkg.cloudflareclient.com/ bookworm main" | \
  sudo tee /etc/apt/sources.list.d/cloudflare-client.list

# Устанавливаем
sudo apt update && sudo apt install -y cloudflare-warp
```

**Настройка и запуск:**

```bash
warp-cli registration new   # принять ToS → y
warp-cli mode proxy         # режим прокси (не меняет системный роутинг)
warp-cli proxy port 40000   # порт SOCKS5
warp-cli connect

# Проверка — должен вернуть IP Cloudflare
sleep 3
curl -x socks5://127.0.0.1:40000 https://ifconfig.me
```

WARP слушает на `127.0.0.1:40000` как SOCKS5 прокси.

---

## 8. Добавление WARP в Xray на сервере

После запуска WARP нужно добавить его в конфиг Xray на сервере как outbound и настроить routing. Это позволит направлять конкретные домены через WARP.

**Автоматический патч через Python:**

```bash
cat > /tmp/patch.py << 'EOF'
import json

with open('/usr/local/x-ui/bin/config.json', 'r') as f:
    cfg = json.load(f)

# Добавляем WARP outbound
warp = {
    "tag": "warp",
    "protocol": "socks",
    "settings": {
        "servers": [{"address": "127.0.0.1", "port": 40000}]
    }
}
cfg['outbounds'].append(warp)

# Добавляем routing rule — эти домены пойдут через WARP
rule = {
    "type": "field",
    "domain": [
        "claude.ai",
        "anthropic.com",
        "api.anthropic.com",
        "statsig.anthropic.com",
        "openai.com",
        "chatgpt.com"
    ],
    "outboundTag": "warp"
}
cfg['routing']['rules'].insert(0, rule)

with open('/usr/local/x-ui/bin/config.json', 'w') as f:
    json.dump(cfg, f, indent=2)

print("Done")
EOF

sudo python3 /tmp/patch.py
sudo systemctl restart x-ui
sudo systemctl status x-ui | head -5
```

**Схема работы после настройки:**

```
Браузер/приложение
       ↓
   Xray (клиент) :1080/:1081
       ↓
  routing rules (клиент)
   ├── youtube.com      → туннель → сервер → internet
   ├── claude.ai        → туннель → сервер → WARP → Cloudflare IP → internet
   ├── chatgpt.com      → туннель → сервер → WARP → Cloudflare IP → internet
   └── всё остальное    → direct → твой реальный IP
```

---

## 9. Выборочный роутинг: справочник доменов

Полный список доменов для типовых сервисов — вставляется в `routing.rules[0].domain` в клиентском `config.json`:

```json
"domain": [
  // YouTube — нужны CDN домены, иначе видео не грузится
  "youtube.com",
  "youtu.be",
  "ytimg.com",
  "googlevideo.com",
  "yt3.ggpht.com",

  // Google AI сервисы
  "gemini.google.com",
  "notebooklm.google.com",
  "aistudio.google.com",

  // OpenAI / ChatGPT
  "chatgpt.com",
  "openai.com",
  "oaistatic.com",
  "oaiusercontent.com",
  "auth.openai.com",

  // Anthropic / Claude
  "claude.ai",
  "anthropic.com",
  "api.anthropic.com",

  // GitHub + Copilot
  "github.com",
  "api.github.com",
  "copilot.github.com",
  "githubcopilot.com",
  "github.githubassets.com",
  "raw.githubusercontent.com",

  // VSCode
  "vscode.dev",
  "marketplace.visualstudio.com",
  "update.code.visualstudio.com",
  "vscode-cdn.net",
  "gallery.vsassets.io",
  
  // Obsidian
  "obsidian.md",
  "api.obsidian.md",
  "releases.obsidian.md",
  "regexp:sync-\\d+\\.obsidian\\.md"
]
```

Добавление нового домена: вставить строку в список, перезапустить `sudo systemctl restart xray`.

---

## 10. Диагностика и частые ошибки

### Xray не запускается (status=23)

```bash
sudo xray run -test -confdir /etc/xray/
```

Самые частые причины:
- Нет тега `"tag": "proxy"` у vless outbound
- `shortId` — массив вместо строки (в клиенте должна быть одна строка)

### EOF при handshake / туннель не работает

```bash
journalctl -u xray -f
```

Причины по частоте:
1. `serverName` не совпадает с `serverNames` на сервере
2. `publicKey` неверный — берётся из панели 3x-ui
3. `shortId` не входит в список разрешённых на сервере

### Сайт открывается напрямую, а не через туннель

```bash
# Проверить что домен попадает в proxy-правило
curl --socks5-hostname 127.0.0.1:1080 https://домен.com -I 2>&1 | head -3
```

Если возвращает IP сервера — работает. Если твой IP — домен не в routing rules или Chrome не использует прокси.

### ERR_CONNECTION_RESET в браузере

Chrome резолвит DNS локально, Xray получает IP вместо домена, правила не срабатывают. Флаг `--proxy-server="socks5://127.0.0.1:1080"` решает проблему — DNS резолвится на стороне Xray.

### 403 от сервиса

Сервис блокирует IP датацентра. Решение — WARP на сервере (раздел 7-8). Если WARP тоже даёт 403 через curl — это нормально для Anthropic/OpenAI, браузерный OAuth проходит через JS-challenge автоматически.

### Включить debug-логи временно

```bash
sudo sed -i 's/"warning"/"debug"/' /etc/xray/config.json
sudo systemctl restart xray
journalctl -u xray -f
# После диагностики вернуть обратно:
sudo sed -i 's/"debug"/"warning"/' /etc/xray/config.json
sudo systemctl restart xray
```

**Рабочий /etc/xray/config.json**
```json
{
  "log": {
    "loglevel": "worning"
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    },
    {
      "port": 1081,
      "listen": "127.0.0.1",
      "protocol": "http"
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "YOUR_SERVER_IP",
            "port": 443,
            "users": [
              {
                "id": "YOUR_UUID",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "serverName": "www.cloudflare.com",
          "fingerprint": "chrome",
          "publicKey": "YOUR_PUBLIC_KEY",
          "shortId": "YOUR_SHORT_ID"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "domain": [
	  // YouTube — нужны CDN домены, иначе видео не грузится
          "youtube.com",
          "youtu.be",
          "ytimg.com",
          "googlevideo.com",
          "yt3.ggpht.com",

	  // Google AI сервисы
          "gemini.google.com",
          "notebooklm.google.com",
          "aistudio.google.com",

	  // OpenAI / ChatGPT
          "chatgpt.com",
          "openai.com",
          "oaistatic.com",
          "oaiusercontent.com",
          "auth.openai.com",

	  // Anthropic / Claude
          "claude.ai",
          "anthropic.com",
          "api.anthropic.com",

	  // GitHub + Copilot
          "github.com",
          "api.github.com",
          "copilot.github.com",
          "githubcopilot.com",
          "github.githubassets.com",
          "raw.githubusercontent.com",

	  // VSCode
          "vscode.dev",
          "marketplace.visualstudio.com",
          "update.code.visualstudio.com",
          "vscode-cdn.net",
          "gallery.vsassets.io",

	  // Obsidian
	  "obsidian.md",
	  "api.obsidian.md",
          "releases.obsidian.md",
          "regexp:sync-\\d+\\.obsidian\\.md"
        ],
        "outboundTag": "proxy"
      },
      {
        "type": "field",
        "ip": [
          "1.1.1.1",
          "8.8.8.8",
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      }
    ]
  }
}
```


---

## Быстрый чеклист при первой установке

```
[ ] yay -S xray
[ ] Заполнить /etc/xray/config.json (SERVER_IP, UUID, publicKey, shortId, serverName)
[ ] sudo xray run -test -confdir /etc/xray/   → "Configuration OK"
[ ] sudo systemctl enable --now xray
[ ] curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me → IP сервера
[ ] Создать /usr/local/bin/chrome-proxy
[ ] Переопределить ~/.local/share/applications/google-chrome.desktop
[ ] Открыть YouTube в Chrome — работает
```

