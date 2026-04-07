# rclone Google Drive — Production Mount на Arch Linux

> Tested on Arch Linux + systemd. Никаких GUI, только терминал и здравый смысл.

---

## 1. Установка

```bash
sudo pacman -S rclone fuse2
```

> `fuse2` — для `--allow-other`. На некоторых системах нужен именно он, а не `fuse3`.

Проверь версию — должна быть >= 1.60:

```bash
rclone version
```

---

## 2. FUSE: разрешить монтирование другими пользователями

Без этого `--allow-other` молча падает.

```bash
sudo nano /etc/fuse.conf
```

Раскомментировать строку:

```
user_allow_other
```

---

## 3. Авторизация в Google Drive

```bash
rclone config
```

Пошагово:

```
n  → новый remote
name: gdrive
type: drive (номер в списке)
client_id: (Enter — использовать встроенный)
client_secret: (Enter)
scope: 1  → полный доступ к диску
root_folder_id: (Enter)
service_account_file: (Enter)
Edit advanced config? n
Use auto config? y  → откроется браузер, авторизуйся
Configure as Shared Drive? n (если личный диск)
```

Проверка:

```bash
rclone lsd gdrive:
```

---

## 4. Подготовка директорий

```bash
mkdir -p ~/GoogleDrive
mkdir -p ~/.local/log
mkdir -p ~/.cache/rclone/gdrive   # vfs cache
```

---

## 5. Systemd user service

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/rclone-gdrive.service
```

```ini
[Unit]
Description=Rclone Google Drive Mount
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

# Создать точку монтирования если нет
ExecStartPre=/bin/mkdir -p %h/GoogleDrive

ExecStart=/usr/bin/rclone mount gdrive: %h/GoogleDrive \
  --config         %h/.config/rclone/rclone.conf \
  \
  --vfs-cache-mode      full \
  --vfs-cache-max-size  5G \
  --vfs-cache-max-age   12h \
  --vfs-read-chunk-size 128M \
  --cache-dir           %h/.cache/rclone/gdrive \
  \
  --dir-cache-time      72h \
  --poll-interval       30s \
  \
  --drive-chunk-size    128M \
  --drive-acknowledge-abuse \
  \
  --allow-other \
  --umask 022 \
  \
  --transfers   8 \
  --checkers    16 \
  --buffer-size 512M \
  --bwlimit     50M \
  \
  --log-level   INFO \
  --log-file    %h/.local/log/rclone-gdrive.log

ExecStop=/bin/fusermount -u %h/GoogleDrive

# Не лупить при сетевых сбоях слишком часто
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=300
StartLimitBurst=5

# Ресурсы: не давать жрать всё
MemoryMax=1G
CPUQuota=50%

[Install]
WantedBy=default.target
```

---

## 6. Активация

```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-gdrive.service
```

Проверка:

```bash
systemctl --user status rclone-gdrive.service
ls ~/GoogleDrive
```

---

## 7. Ротация логов

Без этого лог вырастет в несколько гигабайт за месяц.

```bash
nano ~/.config/logrotate-user.conf
```

```
/home/YOUR_USER/.local/log/rclone-gdrive.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
```

Добавь в crontab:

```bash
crontab -e
```

```
0 4 * * * /usr/sbin/logrotate ~/.config/logrotate-user.conf
```

---

## 8. Мониторинг: простой health-check скрипт

```bash
nano ~/bin/gdrive-check.sh
chmod +x ~/bin/gdrive-check.sh
```

```bash
#!/usr/bin/env bash
# gdrive-check.sh — проверка монтирования и доступности Google Drive

MOUNT="$HOME/GoogleDrive"
LOG="$HOME/.local/log/rclone-gdrive.log"
SERVICE="rclone-gdrive.service"

# Проверка: смонтировано?
if ! mountpoint -q "$MOUNT"; then
    echo "[$(date '+%F %T')] WARN: $MOUNT не смонтирован. Перезапускаю..." | tee -a "$LOG"
    systemctl --user restart "$SERVICE"
    sleep 10
fi

# Проверка: диск доступен?
if ! ls "$MOUNT" &>/dev/null; then
    echo "[$(date '+%F %T')] ERROR: ls $MOUNT завис. Форсирую unmount + restart..." | tee -a "$LOG"
    fusermount -u "$MOUNT" 2>/dev/null || true
    systemctl --user restart "$SERVICE"
fi

echo "[$(date '+%F %T')] OK: $MOUNT доступен."
```

Добавь в crontab:

```bash
*/15 * * * * ~/bin/gdrive-check.sh >> ~/.local/log/gdrive-check.log 2>&1
```

---

## 9. Параметры: что и зачем

| Параметр | Значение | Смысл |
|---|---|---|
| `--vfs-cache-mode full` | full | Полный кэш: чтение + запись без тормозов seek |
| `--vfs-cache-max-size` | 5G | Лимит дискового кэша |
| `--vfs-cache-max-age` | 12h | Протухание кэша |
| `--vfs-read-chunk-size` | 128M | Чанк чтения, ускоряет большие файлы |
| `--drive-chunk-size` | 128M | Чанк загрузки на Drive |
| `--buffer-size` | 512M | RAM-буфер между mount и сетью |
| `--transfers` | 8 | Параллельные передачи |
| `--checkers` | 16 | Параллельные проверки метаданных |
| `--bwlimit` | 50M | Лимит пропускной способности (байт/с × 8 = ~400Mbit) |
| `--poll-interval` | 30s | Как часто проверять изменения на Drive |
| `--dir-cache-time` | 72h | Кэш списков директорий |
| `--allow-other` | — | Доступ к mount другим пользователям/процессам |
| `--umask 022` | — | Права на файлы: 644/755 |

---

## 10. Тюнинг под сценарий

### Медленный интернет / VPS с лимитом трафика

```bash
--bwlimit       5M
--transfers     2
--checkers      4
--buffer-size   64M
--vfs-cache-mode writes   # экономия: только запись кэшируется
```

### Работа с большими медиафайлами (видео, архивы)

```bash
--vfs-read-chunk-size        256M
--vfs-read-chunk-size-limit  0       # без лимита роста чанков
--drive-chunk-size           256M
--buffer-size                1G
--bwlimit                    0       # без лимита
```

### Только резервное копирование (без mount)

```bash
rclone sync /local/path gdrive:Backups \
  --transfers 8 \
  --drive-chunk-size 128M \
  --progress \
  --log-file ~/.local/log/rclone-sync.log
```

---

## 11. Шифрование (опционально, но правильно)

Если в Drive лежат приватные данные — оберни в `crypt` remote:

```bash
rclone config
```

```
n → новый remote
name: gdrive-crypt
type: crypt
remote: gdrive:Encrypted         # папка на диске
filename_encryption: standard
directory_name_encryption: true
password: (задай надёжный пароль)
```

Используй `gdrive-crypt:` вместо `gdrive:` в service файле.  
Файлы на диске будут нечитаемы без пароля — даже если Google сольёт бэкап.

---

## 12. Двусторонняя синхронизация (bisync)

Для сценария «работаю с файлами локально, синхронизирую с Drive»:

```bash
# Первый запуск — обязательно с --resync
rclone bisync ~/Documents/Sync gdrive:Sync \
  --resync \
  --drive-chunk-size 128M \
  --progress

# Последующие запуски
rclone bisync ~/Documents/Sync gdrive:Sync \
  --drive-chunk-size 128M \
  --log-file ~/.local/log/rclone-bisync.log
```

В crontab:

```
0 */2 * * * /usr/bin/rclone bisync ~/Documents/Sync gdrive:Sync --drive-chunk-size 128M >> ~/.local/log/rclone-bisync.log 2>&1
```

---

## 13. Диагностика

```bash
# Статус service
systemctl --user status rclone-gdrive.service

# Живой хвост лога
tail -f ~/.local/log/rclone-gdrive.log

# Смонтировано?
mountpoint ~/GoogleDrive

# Что там с кэшем
du -sh ~/.cache/rclone/gdrive

# Тест скорости чтения/записи
rclone test makefiles gdrive:_bench --files 10 --file-size 100M
rclone delete gdrive:_bench

# Принудительный unmount (если завис)
fusermount -u ~/GoogleDrive

# Жёсткий unmount (если fusermount не помогает)
sudo umount -l ~/GoogleDrive
```

---

## Итоговый чеклист

- [ ] `fuse.conf` → `user_allow_other` раскомментирован
- [ ] `rclone config` → remote `gdrive` создан и проверен (`rclone lsd gdrive:`)
- [ ] Директории созданы: `~/GoogleDrive`, `~/.local/log`, `~/.cache/rclone/gdrive`
- [ ] `rclone-gdrive.service` создан и активирован
- [ ] `logrotate` настроен
- [ ] `gdrive-check.sh` в crontab каждые 15 минут
- [ ] (опц.) `crypt` remote для приватных данных
- [ ] (опц.) `bisync` для двусторонней синхронизации

---

*Если что-то не стартует — сначала `journalctl --user -u rclone-gdrive.service -n 50`, потом уже паника.*
