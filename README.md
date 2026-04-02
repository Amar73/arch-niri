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
- Подключение к интернету:
  ```bash
  ping -c2 archlinux.org
  ```

### 2. Предустановка минимального набора

На чистом Arch `git` и `rsync` могут отсутствовать. `install.sh` ставит их
автоматически если не найдёт, но лучше сделать вручную:

```bash
sudo pacman -S --needed git rsync base-devel
```

`base-devel` нужен для сборки `yay` через `makepkg`.

### 3. SSH-ключ для GitHub

#### Вариант А — есть доступ к интернету напрямую с машины

```bash
# Сгенерировать ключ
ssh-keygen -t ed25519 -C "you@email" -f ~/.ssh/id_ed25519

# Скопировать публичный ключ в буфер
cat ~/.ssh/id_ed25519.pub
```

Зайти на github.com → Settings → SSH and GPG keys → New SSH key,
вставить содержимое публичного ключа, сохранить.

```bash
# Проверить
ssh -T git@github.com
# Ожидаемый ответ: "Hi Amar73! You've successfully authenticated..."
```

#### Вариант Б — через USB-флешку с другого компьютера

Если на новой машине нет браузера или удобного доступа к GitHub:

```bash
# 1. На новой машине — сгенерировать ключ
ssh-keygen -t ed25519 -a 100 -C "you@email" -f ~/.ssh/id_ed25519

# 2. Смонтировать USB-флешку (имя устройства узнать через lsblk)
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# 3. Скопировать публичный ключ на флешку
cp ~/.ssh/id_ed25519.pub /mnt/usb/id_ed25519.pub

# 4. Размонтировать
sudo umount /mnt/usb

# 5. Перейти на другой компьютер с браузером
# Открыть файл id_ed25519.pub с флешки, скопировать содержимое
# Зайти: github.com → Settings → SSH and GPG keys → New SSH key
# Вставить ключ, сохранить

# 6. Вернуться на новую машину, проверить
ssh -T git@github.com
```

### 4. /etc/hosts для SSH-инфраструктуры

Если используешь ProxyJump-цепочки из `.ssh/config` — хосты должны резолвиться.
Без этого `amar224 → wn75 → arch03` ломается на первом прыжке:

```bash
sudo tee -a /etc/hosts << 'EOF'
192.168.1.100  amar
192.168.1.101  wn75
192.168.1.110  ui
EOF
```

Замени IP на реальные адреса своей инфраструктуры.

### 5. Клонирование репозитория

```bash
git clone git@github.com:Amar73/arch-niri.git ~/Amar73/arch-niri
cd ~/Amar73/arch-niri
chmod +x *.sh
```

### 6. Настройка git (первый раз на новой машине)

После клонирования нужно привязать git к аккаунту — иначе коммиты будут
без автора и `git push` откажет:

```bash
git config --global user.email "you@email"
git config --global user.name "you name"

# Проверить
git config --list | grep user
```

Убедиться что remote указывает на правильный репозиторий:

```bash
git remote -v
# Ожидаемый вывод:
# origin  git@github.com:Amar73/arch-niri.git (fetch)
# origin  git@github.com:Amar73/arch-niri.git (push)
```

Если remote не настроен — добавить вручную:

```bash
git remote add origin git@github.com:Amar73/arch-niri.git
git branch -M main
git push -u origin main
```

### 7. Проверка до запуска

```bash
# Синтаксис и структура файлов — без pacman/systemctl, работает везде
make check-local
```

---

## Установка

```bash
make install
sudo reboot
```

После входа в niri:

```bash
make check    # полная проверка всех компонентов
make logs     # логи сервисов текущей загрузки
```

---

## Что делает make install

Порядок выполнения:

1. `sudo pacman -Syu` — обновление системы
2. `sudo pacman -S ...` — официальные пакеты (список ниже)
3. Включение сервисов: NetworkManager, seatd, greetd
4. Добавление пользователя в группы: video, input, seat
5. Сборка и установка `yay` из AUR
6. AUR-пакеты: `bibata-cursor-theme`, `qt5-wayland`
7. `rsync` конфигов в `~/.config/`
8. Деплой `.bashrc` и `.ssh/config`
9. Деплой конфига мониторов по hostname (`deploy-outputs.sh`)
10. Включение user-сервисов: swayidle, cliphist-text, cliphist-images

### Устанавливаемые пакеты

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

## Цели Makefile

| Команда | Действие |
|---------|----------|
| `make install` | Полная установка с нуля |
| `make check` | Post-install проверка (требует живой Arch + запущенные сервисы) |
| `make check-local` | Синтаксис + структура файлов, работает везде (CI) |
| `make sync` | Синхронизация конфигов + smoke-check сервисов |
| `make update` | pacman → yay → orphans → daemon-reload → валидация |
| `make logs` | Логи всех сервисов текущей сессии |
| `make backup` | Резервная копия `/etc/greetd`, `~/.config`, `.bashrc`, `.ssh/config` |
| `make dots-local` | Деплой только `.bashrc` и `.ssh/config` |
| `make outputs` | Деплой конфига мониторов по hostname |
| `make validate` | Валидация niri config |
| `make reload` | Reload niri config без перезапуска |

---

## Настройка после установки

### Мониторы

Конфиг мониторов деплоится автоматически по hostname из `files/home/.config/niri/outputs/`.
Если hostname не совпадает ни с одним файлом — применяется `default.kdl` (auto).

Проверить текущие выходы:
```bash
niri msg outputs
```

Применить вручную:
```bash
make outputs
```

Файлы мониторов в репо:

| Файл | Машина | Мониторы |
|------|--------|----------|
| `amar224.kdl` | amar224 | 3× 1920×1080 @ DP-2, DP-3, DP-4 |
| `amar319.kdl` | amar319 | 2× 1920×1080 @ DVI-I-1, HDMI-A-1 |
| `amar319-1.kdl` | amar319-1 | 1× 2560×1600 @ DVI-I-2 |
| `default.kdl` | ноутбуки | auto/preferred |

### Waybar: раскладка клавиатуры

Модуль `niri/language` использует полные XKB-имена. Проверить реальные:

```bash
niri msg --json keyboard-layouts | jq .
```

Стандартные для `us+ru`: `"English (US)"` и `"Russian"`.
Если у тебя другие — отредактировать `~/.config/waybar/config.jsonc`:

```jsonc
"niri/language": {
  "format-English (US)": "󰌌 EN",
  "format-Russian":      "󰌌 RU"
}
```

После правки: `pkill waybar && waybar &` или `make reload`.

### Waybar: температура CPU

Если модуль не показывает температуру:

```bash
for f in /sys/class/hwmon/hwmon*/temp1_input; do echo "$f: $(cat $f)"; done
```

Добавить в `~/.config/waybar/config.jsonc`:

```jsonc
"temperature": {
  "hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input"
}
```

---

## Биндинги Niri

| Клавиша | Действие |
|---------|----------|
| `Mod+Return` | Alacritty |
| `Mod+D` | Fuzzel (лончер) |
| `Mod+Q` | Закрыть окно |
| `Mod+Shift+E` | Выйти из niri |
| `Mod+←→↑↓` | Навигация по колонкам/окнам |
| `Mod+Shift+←→↑↓` | Перемещение колонок/окон |
| `Mod+1..9, Mod+0` | Воркспейсы 1-10 (независимые на каждом мониторе) |
| `Mod+Shift+1..9, Mod+Shift+0` | Перенос колонки на воркспейс 1-10 |
| `Mod+Page_Up/Down` | Соседний воркспейс |
| `Mod+Tab` | Следующий монитор |
| `Mod+Shift+Tab` | Предыдущий монитор |
| `Mod+Shift+,` | Перенести окно на монитор влево |
| `Mod+Shift+.` | Перенести окно на монитор вправо |
| `Mod+F` | Развернуть колонку |
| `Mod+Shift+F` | Полноэкранный режим |
| `Mod+C` | Центрировать колонку |
| `Mod+R` | Переключить пресет ширины |
| `Mod+−/=` | Ширина колонки ±10% |
| `Mod+V` | Cliphist picker |
| `Print` | Скриншот области |
| `Mod+Print` | Скриншот экрана |
| `XF86Audio*` | Громкость (wpctl) — закомментировано, раскомментировать в `50-binds.kdl` при появлении медиаклавиш |
| `XF86Brightness*` | Яркость (brightnessctl) — закомментировано, раскомментировать в `50-binds.kdl` при появлении медиаклавиш |

---

## Что изменилось в v6.3

### Исправлено

- `gp`/`gl`/`gpf` — функции вместо алиасов (ветка читается в runtime)
- `rsync --delete` — защита от пустого src в `sync.sh` и `install.sh`
- `trap EXIT` в `install_yay()` — явная очистка tmpdir
- `paru` → `yay` везде
- `qt5-compat` (несуществующий) → `qt5-wayland` через yay с `|| true`
- `bibata-cursor-theme` → перенесён в AUR (yay)
- Добавлены пропущенные пакеты: `wireplumber`, `pipewire-pulse`, `pulsemixer`, `jq`, `xdg-desktop-portal-gtk`
- `need git/rsync` → `install.sh` сам ставит их на чистом Arch
- `waybar.service enable` → убран (waybar стартует через `niri spawn-at-startup`)
- CSS-переменные в `waybar/style.css` → прямые hex-значения (GTK CSS не поддерживает `var()`)
- `#window:empty` и дочерние селекторы `>` → убраны (не поддерживаются GTK CSS)
- Мёртвая переменная `REPO_URL="${2:-}"` убрана из `bootstrap-dotfiles.sh`

### Новое

| Файл | Описание |
|------|----------|
| `alacritty/alacritty.toml` | Catppuccin Mocha, beam cursor, 10k scrollback, URL hints |
| `swaylock/config` | Catppuccin Mocha, согласован с waybar |
| `waybar/config.jsonc` | niri/workspaces, window, cpu, mem, disk, temp, audio, net, lang |
| `waybar/style.css` | Catppuccin Mocha, прямые hex-значения, без CSS-переменных |
| `cliphist-text.service` | История текстового буфера обмена |
| `cliphist-images.service` | История буфера изображений |
| `check-local.sh` + `make check-local` | Синтаксис + структура без pacman/systemctl |
| `update.sh` + `make update` | Комплексное обновление системы |
| `deploy-outputs.sh` + `make outputs` | Авто-деплой конфига мониторов по hostname |
| `niri/outputs/*.kdl` | Конфиги мониторов для amar224, amar319, amar319-1, default |
| `50-binds.kdl` | Воркспейсы 1-10, навигация между мониторами |

---

## Структура репозитория

```
arch-niri/
├── Makefile
├── install.sh
├── deploy-outputs.sh
├── check-local.sh
├── post-install-check.sh
├── sync.sh
├── update.sh
├── logs.sh
├── backup.sh
├── bootstrap-dotfiles.sh
└── files/
    ├── etc/greetd/config.toml
    └── home/
        ├── .bashrc
        ├── .ssh/config
        └── .config/
            ├── niri/
            │   ├── config.kdl
            │   ├── conf.d/
            │   │   ├── 10-input.kdl
            │   │   ├── 20-layout.kdl
            │   │   ├── 30-environment.kdl
            │   │   ├── 40-startup.kdl
            │   │   ├── 50-binds.kdl
            │   │   ├── 60-outputs.kdl  ← создаётся deploy-outputs.sh
            │   │   └── keymap.xkb
            │   └── outputs/
            │       ├── amar224.kdl
            │       ├── amar319.kdl
            │       ├── amar319-1.kdl
            │       └── default.kdl
            ├── alacritty/alacritty.toml
            ├── swaylock/config
            ├── waybar/
            │   ├── config.jsonc
            │   └── style.css
            ├── mako/config
            ├── fuzzel/fuzzel.ini
            ├── qt6ct/qt6ct.conf
            ├── gtk-3.0/settings.ini
            ├── gtk-4.0/settings.ini
            └── systemd/user/
                ├── swayidle.service
                ├── cliphist-text.service
                └── cliphist-images.service
```
