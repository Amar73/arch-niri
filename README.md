# Arch Linux + Niri

Bootstrap-репозиторий для чистого Arch Linux.
Стек: niri (tiling Wayland compositor) + Waybar + Alacritty + Catppuccin Mocha.

---

## Что нужно сделать ПЕРЕД make install

### 1. Базовые требования к системе

- Установленный Arch Linux (base, linux, linux-firmware)
- Пользователь в группе `wheel` с настроенным sudo:
  ```bash
  groups $USER   # должна быть wheel
  sudo -v        # должно пройти без ошибки
  ```
  Если группы нет — добавить:
  ```bash
  sudo usermod -aG wheel $USER
  # Выйти и войти снова чтобы изменения применились
  ```
- Подключение к интернету:
  ```bash
  ping -c2 archlinux.org
  ```
  Если нет сети — запустить NetworkManager:
  ```bash
  sudo systemctl start NetworkManager
  nmtui   # текстовый интерфейс для подключения к Wi-Fi
  ```

### 2. Предустановка минимального набора

На чистом Arch `git` и `rsync` могут отсутствовать. `install.sh` ставит их
автоматически если не найдёт, но лучше сделать вручную — это гарантирует что
клонирование репозитория пройдёт до запуска установщика:

```bash
sudo pacman -S --needed git rsync base-devel
```

- `git` — для клонирования репозитория
- `rsync` — для синхронизации конфигов в `install.sh` и `sync.sh`
- `base-devel` — набор инструментов для сборки пакетов из исходников, нужен для `yay`

### 3. Клонирование репозитория

```bash
mkdir -p ~/Amar73
cd ~/Amar73

# Клонирование по HTTPS — работает без SSH-ключа, только для чтения
git clone https://github.com/Amar73/arch-niri.git

cd ~/Amar73/arch-niri
# Сделать все .sh файлы исполняемыми (на новой машине права могут сброситься)
chmod +x *.sh
```

### 4. Проверка до запуска

Перед установкой убеждаемся что в репо нет синтаксических ошибок и все
нужные файлы на месте. Эта проверка работает без pacman и systemctl — безопасна
в любом окружении:

```bash
make check-local
# Проверяет:
#   — синтаксис всех .sh скриптов через bash -n
#   — наличие всех конфигурационных файлов в files/
#   — наличие всех целей в Makefile
#   — отсутствие посторонних референсов
```

---

## Установка

```bash
make install
```

Скрипт устанавливает весь стек автоматически. По завершении:

```bash
sudo reboot
```

> **Если после reboot greeter не пускает** — это обычно кеш tuigreet со старой
> командой сессии. Переключиться на TTY2 (`Ctrl+Alt+F2`), войти там и:
> ```bash
> sudo rm -f /var/cache/tuigreet/*
> sudo systemctl restart greetd
> # Вернуться на TTY1 (Ctrl+Alt+F1) и попробовать снова
> ```

После входа в niri — открыть терминал (`Mod+Return`) и проверить:

```bash
make check    # полная проверка: команды, пакеты, файлы, сервисы, niri config
make logs     # просмотр логов всех сервисов текущей загрузки
```

---

## Что делает make install

`install.sh` выполняет шаги последовательно, каждый залогирован с временной
меткой. При ошибке на любом шаге скрипт останавливается (`set -Eeuo pipefail`).

Порядок выполнения:

1. **`sudo pacman -Syu`** — полное обновление системы перед установкой.
   Гарантирует что не будет конфликтов версий при установке новых пакетов.

2. **`sudo pacman -S ...`** — установка официальных пакетов.
   Использует `--needed` — пропускает уже установленные, не переустанавливает.

3. **Включение системных сервисов** — `NetworkManager`, `seatd`, `greetd`.
   - `seatd` — управление seat (доступ к устройствам без root)
   - `greetd` — display manager, запускает niri после логина

4. **Настройка локали** — создание `/etc/locale.conf` с `LANG=ru_RU.UTF-8`.
   Необходимо для русского интерфейса приложений (браузеры, редакторы и др.).
   Если файл уже существует — не перезаписывается.

5. **Добавление в группы** — `video`, `input`, `seat`.
   Без этих групп niri не получит доступ к GPU и устройствам ввода.

6. **Установка `yay`** — сборка из AUR (`git clone` + `makepkg`).
   Нужен `base-devel`. Пропускается если yay уже установлен.

7. **AUR-пакеты** — `bibata-cursor-theme` (курсор), `qt5-wayland`.

8. **Создание `/usr/local/bin/niri-start`** — wrapper-скрипт для greetd:
   ```bash
   #!/bin/bash
   exec dbus-run-session niri
   ```
   Необходим потому что `niri-session` требует systemd user instance с
   правильным D-Bus, который не поднимается через greetd. `dbus-run-session`
   создаёт изолированную D-Bus сессию для niri.

9. **`rsync` конфигов** — синхронизация `files/home/.config/` в `~/.config/`.
   Использует `--delete` с защитой от пустого источника.

10. **Деплой `.bashrc` и `.ssh/config`** — с бэкапом существующих файлов
    (добавляется суффикс `.bak.TIMESTAMP`).

11. **Деплой конфигов мониторов и обоев** — `deploy-outputs.sh` определяет hostname,
    копирует нужный `outputs/hostname.kdl` в `conf.d/60-outputs.kdl`
    и `wallpapers/hostname.kdl` в `conf.d/45-wallpaper.kdl`.

12. **Включение user-сервисов** — `swayidle` (таймауты блокировки),
    `cliphist-text` и `cliphist-images` (история буфера обмена).

### Устанавливаемые пакеты (make install)

Это минимальный набор для работающей niri-системы. Дополнительный софт
устанавливается отдельно через `make packages`.

| Группа | Пакеты |
|--------|--------|
| Базовые | `base-devel git rsync curl wget unzip` |
| WM | `niri xwayland-satellite` |
| Статусбар | `waybar` |
| Терминал | `alacritty` |
| Лончер | `fuzzel` |
| Уведомления | `mako` |
| Фон / блокировка | `swaybg swayidle swaylock` |
| Буфер обмена | `wl-clipboard cliphist` |
| Аудио | `pipewire wireplumber pipewire-pulse pulsemixer` |
| Видео | `mesa vulkan-icd-loader` |
| Скриншоты | `grim slurp` |
| Медиаклавиши | `brightnessctl playerctl` (про запас) |
| Qt6 | `qt6-wayland qt6-svg qt6-multimedia qt6ct kvantum` |
| GTK | `nwg-look adw-gtk-theme` |
| Иконки | `papirus-icon-theme` |
| Шрифты | `noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd` |
| Порталы | `xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk` |
| Auth | `polkit-gnome` |
| Greeter | `greetd greetd-tuigreet` |
| Сеть | `networkmanager seatd` |
| SSH | `openssh keychain` |
| Диагностика | `btop jq` |
| AUR | `bibata-cursor-theme qt5-wayland` |

---

## Установка дополнительного ПО

Дополнительные пакеты сгруппированы в файлах `packages/` и устанавливаются
отдельно от основного `make install`. Это позволяет поставить базовую систему
быстро, а остальное — по мере необходимости.

### Структура packages/

```
packages/
├── base.txt   — полный набор для всех машин (включает пакеты из make install)
├── niri.txt   — специфика niri-стека (уже входит в make install)
└── aur.txt    — пакеты из AUR (браузеры, облако, утилиты)
```

> **Примечание о дублировании:** `base.txt` намеренно включает пакеты которые
> уже ставит `make install`. Это позволяет использовать `base.txt` как
> автономный полный список на уже работающей системе — например при переустановке
> отдельных компонентов или аудите пакетов. Pacman с флагом `--needed`
> автоматически пропускает уже установленные пакеты, поэтому повторной
> установки не происходит.

### Установка пакетов

```bash
# Установить всё (base + niri + aur)
make packages

# Или выборочно через install-packages.sh:
./install-packages.sh base          # только базовые
./install-packages.sh aur           # только AUR
./install-packages.sh base niri     # base + niri, без AUR
```

`install-packages.sh` читает файлы списков, убирает комментарии и пустые строки,
передаёт результат в `pacman` или `yay` в зависимости от файла.

### Содержимое base.txt

| Группа | Пакеты |
|--------|--------|
| Wayland | `wayland wayland-protocols xorg-xwayland xdg-desktop-portal*` |
| Qt | `qt5-wayland qt6-wayland qt6ct kvantum` |
| GTK | `nwg-look adw-gtk-theme` |
| Шрифты | `ttf-jetbrains-mono-nerd otf-font-awesome noto-fonts* ttf-nerd-fonts-symbols` |
| Аудио | `pipewire* wireplumber alsa-utils pamixer playerctl pulsemixer` |
| Сеть | `networkmanager network-manager-applet nm-connection-editor inetutils` |
| Терминал | `alacritty` |
| Файловые менеджеры | `mc yazi thunar` |
| Запуск приложений | `fuzzel` |
| Уведомления | `mako` |
| Буфер обмена | `wl-clipboard cliphist` |
| Скриншоты | `grim slurp swappy` |
| Браузеры | `firefox telegram-desktop thunderbird` |
| Редакторы | `vim kate` |
| Утилиты | `wget curl git eza duf ncdu rclone lazygit s-tui jq` |
| Мониторинг | `btop htop` |
| Docker | `docker` |
| Безопасность | `keepassxc` |

### Содержимое aur.txt

| Пакет | Назначение |
|-------|-----------|
| `bibata-cursor-theme` | Курсор мыши Bibata Modern Ice |
| `qt5-wayland` | Qt5 Wayland backend |
| `google-chrome` | Браузер Google Chrome |
| `brave-bin` | Браузер Brave |
| `yandex-disk` | Клиент Яндекс.Диска |
| `birdtray` | Трей-иконка для Thunderbird |
| `neohtop` | TUI системный монитор |
| `lazydocker` | TUI для управления Docker |
| `xwaylandvideobridge` | Шаринг экрана через XWayland (Discord, Zoom) |
| `ydotool` | Эмуляция ввода на Wayland |

---

## Цели Makefile

| Команда | Действие |
|---------|----------|
| `make install` | Полная установка с нуля — пакеты, конфиги, сервисы |
| `make packages` | Установка дополнительных пакетов из `packages/` |
| `make check` | Post-install проверка (требует живой Arch + запущенные сервисы) |
| `make check-local` | Синтаксис + структура файлов, работает везде без Arch |
| `make sync` | Синхронизация конфигов из репо в систему + smoke-check сервисов |
| `make update` | Обновление: pacman → yay → orphans → daemon-reload → валидация |
| `make logs` | Логи всех сервисов текущей загрузки (greetd, waybar, swayidle, cliphist) |
| `make backup` | Резервная копия `/etc/greetd`, `~/.config`, `.bashrc`, `.ssh/config` |
| `make dots-local` | Деплой только `.bashrc` и `.ssh/config` из репо |
| `make outputs` | Деплой конфига мониторов по hostname из `outputs/` |
| `make validate` | Валидация niri config через `niri validate` |
| `make reload` | Reload niri config без перезапуска сессии |
| `make ssh-config` | Деплой `~/.ssh/config` в зависимости от hostname |

---

## Настройка после установки

### SSH config: контекстный деплой

Файл `~/.ssh/config` содержит ProxyJump-цепочки через `amar224` как jump-хост.
Проблема: если запустить `make sync` на самой `amar224` — конфиг попытается
сделать `ProxyJump amar224` с `amar224`, что невозможно.

Скрипт `deploy-ssh-config.sh` решает это автоматически:

| Hostname | Контекст | wn75 подключается через |
|----------|----------|------------------------|
| `amar224` | jump_host | напрямую по IP |
| `amar319`, `amar319-1`, ноутбуки | home_net | ProxyJump amar224 |
| всё остальное | external | конфиг не трогается |

```bash
# Применить правильный конфиг для текущей машины
make ssh-config

# Посмотреть что будет задеплоено без применения
./deploy-ssh-config.sh --dry-run
```

Скрипт запускается автоматически при `make install` и `make sync`.

> **Важно:** для работы ProxyJump имена хостов (`amar`, `wn75`, `ui`) должны
> резолвиться через `/etc/hosts` или DNS. Без этого первый прыжок упадёт.

### Мониторы

Конфиг мониторов деплоится автоматически в конце `make install` по hostname
из `files/home/.config/niri/outputs/`. Если hostname не совпадает ни с одним
файлом — применяется `default.kdl` (auto/preferred режим).

Проверить текущие выходы и их параметры:
```bash
niri msg outputs
# Показывает имена, разрешение, позицию, scale для каждого монитора
```

Применить конфиг мониторов вручную (например после смены hostname):
```bash
make outputs
```

Файлы мониторов в репо:

| Файл | Машина | Конфигурация |
|------|--------|--------------|
| `amar224.kdl` | amar224 | 3× 1920×1080 @ DP-2, DP-3, DP-4 — три монитора в ряд |
| `amar319.kdl` | amar319 | 2× 1920×1080 @ DVI-I-1, HDMI-A-1 — два монитора |
| `amar319-1.kdl` | amar319-1 | 1× 2560×1600 @ DVI-I-2 — Apple Cinema HD |
| `default.kdl` | ноутбуки, прочие | auto/preferred — niri сам определяет параметры |

Добавить конфиг для новой машины:
```bash
# Узнать имена и параметры выходов
niri msg outputs

# Создать файл конфига (имя файла = hostname машины)
nano files/home/.config/niri/outputs/$(hostname).kdl

# Применить
make outputs
```

### Обои (per-output)

Обои деплоятся автоматически при `make install` / `make sync` через `deploy-outputs.sh`
— каждый монитор получает свой wallpaper через `swaybg -o <output>`.

Файлы обоев в репо:

| Файл | Машина | Конфигурация |
|------|--------|--------------|
| `amar224.kdl` | amar224 | DP-2: arch.jpeg / DP-3: arch3.jpeg / DP-4: wallpaper.jpg |
| `amar319.kdl` | amar319 | DVI-I-1: arch.jpeg / HDMI-A-1: arch3.jpeg |
| `amar319-1.kdl` | amar319-1 | DVI-I-2: wallpaper.jpg |
| `default.kdl` | ноутбуки, прочие | один монитор без `-o` флага |

Обои хранятся в `Wallpapers/` внутри репозитория:

```
Wallpapers/
├── arch.jpeg
├── arch3.jpeg
├── archlinux-commands.jpg
└── wallpaper.jpg
```

Путь в kdl-файлах: `/home/amar/Amar73/arch-niri/Wallpapers/<file>`.

Сменить обои вручную (без перезапуска niri):
```bash
pkill swaybg
swaybg -o DP-2 -i ~/Amar73/arch-niri/Wallpapers/arch.jpeg -m fill &
swaybg -o DP-3 -i ~/Amar73/arch-niri/Wallpapers/arch3.jpeg -m fill &
swaybg -o DP-4 -i ~/Amar73/arch-niri/Wallpapers/wallpaper.jpg -m fill &
```

Добавить обои для новой машины:
```bash
niri msg outputs   # узнать имена выходов
nano files/home/.config/niri/wallpapers/$(hostname).kdl
make outputs       # задеплоить
```

### Блокировка и таймауты простоя

Управляется через `swayidle`, который запускается через `spawn-at-startup`
в niri (не через systemd — из-за особенностей dbus-run-session окружения).

Текущая схема таймаутов (`40-startup.kdl`):

| Время простоя | Действие |
|---------------|----------|
| 30 мин 1800 с) | Блокировка экрана через `swaylock -f` |
| 10 мин (600 с) | Выключить мониторы через `niri msg action power-off-monitors` |
| При засыпании | Блокировка перед сном (`before-sleep`) |

Изменить таймауты:
```bash
nano ~/.config/niri/conf.d/40-startup.kdl
# Числа — время в секундах: 300 = 5 мин, 600 = 10 мин

# Применить (перезапускает swayidle)
niri msg action load-config-file
```

Проверить что swayidle запущен:
```bash
pgrep -a swayidle
```

### Midnight Commander

Конфиг mc деплоится автоматически при `make install` и `make sync`.

Файлы в репо:
- `files/home/.config/mc/ini` — основной конфиг (скин, редактор, панели)
- `files/home/.config/mc/skins/catppuccin-mocha.ini` — тема Catppuccin Mocha

Если рамки панелей не отображаются (символы псевдографики) — проверь `TERM`:

```bash
echo $TERM   # должно быть xterm-256color
```

`TERM=xterm-256color` прописан в `30-environment.kdl` и применяется автоматически.

Сменить скин вручную — **F9 → Настройки → Внешний вид** или:

```bash
mc --skin=catppuccin-mocha
```

Доступные встроенные скины:

```bash
ls /usr/share/mc/skins/
```

### Waybar: раскладка клавиатуры

Модуль `niri/language` использует полные XKB-имена. Узнать реальные:

```bash
niri msg --json keyboard-layouts | jq .
```

Стандартные для `us+ru`: `"English (US)"` и `"Russian"`.
Если имена отличаются — отредактировать `~/.config/waybar/config.jsonc`:

```jsonc
"niri/language": {
  "format-English (US)": "󰌌 EN",
  "format-Russian":      "󰌌 RU"
}
```

После правки:
```bash
pkill waybar && waybar &
```

### Waybar: температура CPU

Если модуль `#temperature` не показывает значение:

```bash
for f in /sys/class/hwmon/hwmon*/temp1_input; do
    echo "$f: $(( $(cat $f) / 1000 ))°C"
done
```

Добавить путь к нужному сенсору в `~/.config/waybar/config.jsonc`:

```jsonc
"temperature": {
  "hwmon-path": "/sys/class/hwmon/hwmon0/temp1_input"
}
```

### Alacritty: мышь и буфер обмена

- **Выделение левой кнопкой** → автоматически копирует в системный буфер обмена
- **Правая кнопка** → вставляет из буфера обмена
- **Ctrl+Shift+C / Ctrl+Shift+V** → копировать / вставить
- **Ctrl+клик по URL** → открыть в браузере

### Яндекс.Браузер: русский интерфейс

На Linux Яндекс.Браузер берёт язык интерфейса из системной переменной `LANG`.
Если в `/etc/locale.conf` прописан `LANG=en_US.UTF-8` — интерфейс будет
английским независимо от настроек внутри браузера.

**Решение** — добавить русскую локаль в `/etc/locale.conf`:

```bash
echo "LANG=ru_RU.UTF-8" | sudo tee /etc/locale.conf
```

После этого перезагрузить компьютер — браузер (и все остальные приложения)
будут на русском.

> Бинарник на Arch называется `yandex-browser-stable`, не `yandex-browser`.

Биндинг `Mod+B` в `50-binds.kdl` для быстрого запуска:

```kdl
Mod+B { spawn "yandex-browser-stable"; }
```

> Если нужен только русский UI приложений без изменения форматов CLI —
> добавь в `~/.bashrc`:
> ```bash
> export LC_MESSAGES=ru_RU.UTF-8
> ```

---

## Биндинги Niri

`Mod` = Super (клавиша Windows/Command).

### Приложения

| Клавиша | Действие |
|---------|----------|
| `Mod+Return` | Открыть Alacritty (терминал) |
| `Mod+D` | Открыть Fuzzel (лончер приложений) |
| `Mod+B` | Яндекс.Браузер |
| `Mod+Q` | Закрыть активное окно |
| `Mod+Shift+E` | Выйти из niri (завершить сессию) |

### Навигация по окнам

| Клавиша | Действие |
|---------|----------|
| `Mod+←→` | Переключить фокус между колонками |
| `Mod+↑↓` | Переключить фокус между окнами в колонке |
| `Mod+Shift+←→` | Переместить колонку влево/вправо |
| `Mod+Shift+↑↓` | Переместить окно вверх/вниз внутри колонки |

### Размер и компоновка

| Клавиша | Действие |
|---------|----------|
| `Mod+F` | Развернуть колонку на всю ширину экрана |
| `Mod+Shift+F` | Полноэкранный режим |
| `Mod+C` | Центрировать активную колонку |
| `Mod+R` | Циклически переключать пресеты ширины (33%/50%/67%/100%) |
| `Mod+−` | Уменьшить ширину колонки на 10% |
| `Mod+=` | Увеличить ширину колонки на 10% |

### Воркспейсы

Воркспейсы в niri **независимые на каждом мониторе**.

| Клавиша | Действие |
|---------|----------|
| `Mod+1..9` | Переключить на воркспейс 1-9 текущего монитора |
| `Mod+0` | Переключить на воркспейс 10 |
| `Mod+Shift+1..9` | Перенести колонку на воркспейс 1-9 |
| `Mod+Shift+0` | Перенести колонку на воркспейс 10 |
| `Mod+Page_Up` | Переключить на воркспейс выше |
| `Mod+Page_Down` | Переключить на воркспейс ниже |
| `Mod+Shift+Page_Up` | Перенести колонку на воркспейс выше |
| `Mod+Shift+Page_Down` | Перенести колонку на воркспейс ниже |

### Мониторы

| Клавиша | Действие |
|---------|----------|
| `Mod+Tab` | Перенести фокус на монитор вправо |
| `Mod+Shift+Tab` | Перенести фокус на монитор влево |
| `Mod+Shift+,` | Переместить окно на монитор влево |
| `Mod+Shift+.` | Переместить окно на монитор вправо |

### Блокировка и экран

| Клавиша | Действие |
|---------|----------|
| `Mod+L` | Заблокировать экран (swaylock) |
| `Mod+Shift+L` | Выключить мониторы (без блокировки) |
| `Mod+Ctrl+L` | Заблокировать + выключить мониторы |

### Утилиты

| Клавиша | Действие |
|---------|----------|
| `Mod+V` | Открыть историю буфера обмена (cliphist + fuzzel) |
| `Print` | Скриншот выделенной области → `~/Screenshots/` |
| `Mod+Print` | Скриншот всего экрана → `~/Screenshots/` |

### Звук

| Клавиша | Действие |
|---------|----------|
| `Shift+F1` | Mute / unmute |
| `Shift+F2` | Громкость −5% |
| `Shift+F3` | Громкость +5% |
| `XF86Audio*` | Медиаклавиши — **закомментированы** в `50-binds.kdl` |
| `XF86Brightness*` | Яркость — **закомментированы** в `50-binds.kdl` |

> Раскомментировать при появлении медиаклавиш:
> ```bash
> nano ~/.config/niri/conf.d/50-binds.kdl
> make reload
> ```

---

## Для владельца репозитория

Этот раздел содержит настройки специфичные для автора репозитория.
Обычным пользователям этот раздел не нужен.

### SSH-ключ для GitHub

Необходим для `git push` и клонирования по SSH.
Генерируем ключ (если ещё нет):

```bash
ssh-keygen -t ed25519 -C "user@email" -f ~/.ssh/id_ed25519
# Создаст два файла:
#   ~/.ssh/id_ed25519      — приватный ключ (НИКОМУ не передавать)
#   ~/.ssh/id_ed25519.pub  — публичный ключ (добавляем на GitHub)
```

Добавить публичный ключ на GitHub — выбери удобный способ:

#### Вариант А — GitHub CLI

```bash
sudo pacman -S github-cli
gh auth login

# Меню:
#   Account    → GitHub.com
#   Protocol   → SSH
#   Upload key → ~/.ssh/id_ed25519.pub
#   Auth       → Login with a web browser
#
# На экране появится код ABCD-1234
# Телефон → github.com/login/device → ввести код → подтвердить
```

#### Вариант Б — curl + Personal Access Token

```bash
# На телефоне: github.com → Settings → Developer settings
#   → Tokens (classic) → New → scope: admin:public_key → Generate
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

curl -s -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/user/keys \
     -d "{\"title\":\"arch-$(hostname)\",\"key\":\"$(cat ~/.ssh/id_ed25519.pub)\"}"
```

#### Вариант В — через USB-флешку

```bash
lsblk                              # найти имя флешки
sudo mount /dev/sdb1 /mnt/usb
cp ~/.ssh/id_ed25519.pub /mnt/usb/
sudo umount /mnt/usb
# На другом компьютере: github.com → Settings → SSH keys → New SSH key
```

#### Проверка

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com
# Hi Amar73! You've successfully authenticated...
```

### Клонирование по SSH (с правом на push)

```bash
mkdir -p ~/Amar73
cd ~/Amar73
git clone git@github.com:Amar73/arch-niri.git
cd ~/Amar73/arch-niri
chmod +x *.sh
```

### Настройка git на новой машине

```bash
git config --global user.email "user@email"
git config --global user.name "user name"
git config --global pull.rebase false

# Проверить
git config --list | grep user
git remote -v
# origin  git@github.com:Amar73/arch-niri.git (fetch)
# origin  git@github.com:Amar73/arch-niri.git (push)
```

Если remote указывает на HTTPS — сменить на SSH:

```bash
git remote set-url origin git@github.com:Amar73/arch-niri.git
```

### /etc/hosts для SSH-инфраструктуры

Для работы ProxyJump-цепочек из `.ssh/config` хосты должны резолвиться:

```bash
sudo tee -a /etc/hosts << 'EOF'
192.168.1.100  amar
192.168.1.101  wn75
192.168.1.110  ui
EOF

# Проверить
ping -c1 amar
ssh -G amar224
```

---

## Что изменилось в v6.3

### Исправлено

- `gp`/`gl`/`gpf` — функции вместо алиасов (ветка читается в runtime)
- `rsync --delete` — защита от пустого src в `sync.sh` и `install.sh`
- `trap EXIT` в `install_yay()` — явная очистка tmpdir
- `paru` → `yay` везде
- `qt5-compat` → `qt5-wayland` через yay с `|| true`
- `bibata-cursor-theme` → перенесён в AUR
- Добавлены пропущенные пакеты: `wireplumber`, `pipewire-pulse`, `pulsemixer`, `jq`, `xdg-desktop-portal-gtk`
- `waybar.service enable` → убран (waybar стартует через `niri spawn-at-startup`)
- CSS-переменные в `waybar/style.css` → прямые hex-значения
- `#window:empty` и `>` селекторы → убраны (GTK CSS не поддерживает)
- `focus-monitor-next/prev` → `focus-monitor-right/left` (нет в niri 25.11)
- `[hints]` в `alacritty.toml` → `[[hints.enabled]]` (TOML multiline fix)
- `shell` в `alacritty.toml` → перенесён из `[general]` в `[terminal]`
- PS1 `git_status()` — `$'\033'` вместо `"\033"`, `\001`/`\002` для правильного подсчёта длины строки
- `swayidle` → перенесён из systemd в `spawn-at-startup` (D-Bus доступен в окружении niri)

### Новое

| Компонент | Описание |
|-----------|----------|
| `alacritty/alacritty.toml` | Catppuccin Mocha, Underline cursor, 10k scrollback, ПКМ=вставка |
| `swaylock/config` | Catppuccin Mocha |
| `waybar/config.jsonc` | niri/workspaces, window, cpu, mem, disk, temp, audio, net, lang |
| `waybar/style.css` | Catppuccin Mocha, прямые hex |
| `cliphist-text.service` | История текстового буфера |
| `cliphist-images.service` | История буфера изображений |
| `check-local.sh` + `make check-local` | Синтаксис + структура без pacman/systemctl |
| `update.sh` + `make update` | Комплексное обновление системы |
| `deploy-outputs.sh` + `make outputs` | Авто-деплой конфига мониторов по hostname |
| `niri/outputs/*.kdl` | Конфиги мониторов для amar224, amar319, amar319-1, default |
| `install-packages.sh` + `make packages` | Установка пакетов из `packages/*.txt` |
| `packages/base.txt` | Базовый набор ПО для всех машин |
| `packages/niri.txt` | Пакеты niri-стека |
| `packages/aur.txt` | AUR-пакеты |
| `50-binds.kdl` | Воркспейсы 1-10, мониторы, Shift+F1/F2/F3, Mod+L блокировка |
| `/usr/local/bin/niri-start` | Wrapper `dbus-run-session niri` |

---

## Структура репозитория

```
arch-niri/
├── Makefile                        — цели для управления системой
├── install.sh                      — полная установка с нуля
├── install-packages.sh             — установка пакетов из packages/
├── deploy-outputs.sh               — деплой конфига мониторов по hostname
├── deploy-ssh-config.sh            — деплой ~/.ssh/config по контексту машины
├── check-local.sh                  — проверка без pacman/systemctl
├── post-install-check.sh           — полная проверка на живой системе
├── sync.sh                         — синхронизация конфигов + smoke-check
├── update.sh                       — обновление системы
├── logs.sh                         — просмотр логов сервисов
├── backup.sh                       — резервная копия конфигов
├── bootstrap-dotfiles.sh           — деплой dotfiles из репо или git URL
├── packages/
│   ├── base.txt                    — базовые пакеты (все машины)
│   ├── niri.txt                    — пакеты niri-стека
│   └── aur.txt                     — пакеты из AUR
├── Wallpapers/                     — обои (путь используется в wallpapers/*.kdl)
└── files/
    ├── etc/greetd/config.toml      — конфиг display manager
    └── home/
        ├── .bashrc                 — bash: PS1, алиасы, keychain, git-функции
        ├── .ssh/config             — SSH с ProxyJump цепочками
        └── .config/
            ├── niri/
            │   ├── config.kdl      — главный конфиг (include conf.d)
            │   ├── conf.d/
            │   │   ├── 10-input.kdl        — клавиатура, тачпад, мышь
            │   │   ├── 20-layout.kdl       — gaps, ширина колонок
            │   │   ├── 30-environment.kdl  — Wayland env переменные
            │   │   ├── 40-startup.kdl      — автозапуск: waybar, mako, swayidle
            │   │   ├── 45-wallpaper.kdl    — ← создаётся deploy-outputs.sh (swaybg per-output)
            │   │   ├── 50-binds.kdl        — биндинги клавиш
            │   │   ├── 60-outputs.kdl      — ← создаётся deploy-outputs.sh (мониторы)
            │   │   └── keymap.xkb          — Alt_L=EN, Alt_R=RU
            │   ├── outputs/
            │   │   ├── amar224.kdl         — 3× 1920×1080 @ DP-2, DP-3, DP-4
            │   │   ├── amar319.kdl         — 2× 1920×1080 @ DVI-I-1, HDMI-A-1
            │   │   ├── amar319-1.kdl       — 1× 2560×1600 @ DVI-I-2
            │   │   └── default.kdl         — auto для ноутбуков
            │   └── wallpapers/
            │       ├── amar224.kdl         — DP-2/DP-3/DP-4 → arch/arch3/wallpaper
            │       ├── amar319.kdl         — DVI-I-1/HDMI-A-1
            │       ├── amar319-1.kdl       — DVI-I-2
            │       └── default.kdl         — один монитор
            ├── alacritty/alacritty.toml    — терминал: Catppuccin Mocha
            ├── swaylock/config             — блокировщик: Catppuccin Mocha
            ├── waybar/
            │   ├── config.jsonc            — модули waybar для niri
            │   └── style.css               — Catppuccin Mocha
            ├── mako/config                 — уведомления
            ├── fuzzel/fuzzel.ini           — лончер
            ├── mc/
            │   ├── ini                     — основной конфиг mc
            │   └── skins/
            │       └── catppuccin-mocha.ini — тема Catppuccin Mocha
            ├── qt6ct/qt6ct.conf            — Qt6 тема/шрифты
            ├── gtk-3.0/settings.ini        — GTK3 тема/иконки/курсор
            ├── gtk-4.0/settings.ini        — GTK4 тема/иконки/курсор
            └── systemd/user/
                ├── swayidle.service        — таймауты простоя (резерв)
                ├── cliphist-text.service   — история текстового буфера
                └── cliphist-images.service — история буфера изображений
```
