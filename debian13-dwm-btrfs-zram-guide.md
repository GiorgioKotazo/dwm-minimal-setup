# Установка и настройка Debian 13 Trixie + dwm + Btrfs + zram

Полное руководство по установке минималистичной, быстрой и восстанавливаемой системы на базе Debian 13.

## Содержание

1. [Подготовка](#1-подготовка)
2. [Установка базовой системы](#2-установка-базовой-системы)
3. [Разметка диска с Btrfs](#3-разметка-диска-с-btrfs)
4. [Пост-установка](#4-пост-установка)
5. [Настройка zram](#5-настройка-zram)
6. [Установка и настройка dwm](#6-установка-и-настройка-dwm)
7. [Дополнительная настройка](#7-дополнительная-настройка)
8. [Обслуживание системы](#8-обслуживание-системы)

---

## 1. Подготовка

### 1.1 Скачивание образа

Скачайте netinst образ с официального сайта:

```
https://www.debian.org/CD/netinst/
```

Для старых ноутбуков рекомендуется netinst (около 600 МБ) — он загружает только необходимые пакеты.

### 1.2 Создание загрузочной флешки

**Linux:**
```bash
# Определите устройство флешки
lsblk

# Запишите образ (замените /dev/sdX на ваше устройство)
sudo dd if=debian-13.0.0-amd64-netinst.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

**Windows:** Используйте Rufus или balenaEtcher.

### 1.3 Настройка BIOS/UEFI

- Отключите Secure Boot (опционально, но упрощает установку)
- Установите приоритет загрузки с USB
- Для старых ноутбуков: включите Legacy Boot если UEFI не поддерживается

---

## 2. Установка базовой системы

### 2.1 Запуск установщика

1. Загрузитесь с USB
2. Выберите **Install** (текстовый режим — быстрее и надёжнее)
3. Выберите язык, локаль, раскладку клавиатуры

### 2.2 Настройка сети

- Для Wi-Fi: выберите сеть и введите пароль
- Для Ethernet: обычно настраивается автоматически через DHCP

### 2.3 Имя хоста и пользователи

- Введите имя хоста (например: `debian-laptop`)
- Оставьте пароль root пустым (будет использоваться sudo)
- Создайте обычного пользователя

---

## 3. Разметка диска с Btrfs

### 3.1 Схема разделов

Рекомендуемая схема для UEFI:

| Раздел | Размер | Файловая система | Точка монтирования |
|--------|--------|------------------|-------------------|
| EFI    | 512 МБ | FAT32            | /boot/efi         |
| Root   | Остаток| Btrfs            | /                 |

Для Legacy BIOS добавьте раздел /boot (ext4, 1 ГБ).

### 3.2 Ручная разметка в установщике

1. Выберите **Manual** в разделе разметки
2. Создайте таблицу разделов GPT (для UEFI) или MBR (для Legacy)
3. Создайте EFI раздел:
   - Размер: 512 МБ
   - Использовать как: EFI System Partition
4. Создайте корневой раздел:
   - Размер: всё оставшееся место
   - Использовать как: **btrfs journaling file system**
   - Точка монтирования: /

### 3.3 Subvolumes (после установки)

Установщик Debian создаёт один subvolume. После первой загрузки мы настроим правильную структуру subvolumes.

**Рекомендуемая структура subvolumes:**

```
@           -> /
@home       -> /home
@snapshots  -> /.snapshots
@var_log    -> /var/log
@var_cache  -> /var/cache
```

---

## 4. Пост-установка

### 4.1 Выбор программ в установщике

На экране **Software selection** снимите все галочки кроме:
- [x] standard system utilities

Мы установим всё необходимое вручную.

### 4.2 Первая загрузка

После установки загрузитесь в систему. Вы окажетесь в текстовой консоли.

### 4.3 Базовая настройка

```bash
# Войдите под своим пользователем и получите root
sudo -i

# Обновите систему
apt update && apt upgrade -y

# Установите базовые инструменты
apt install -y vim git curl wget htop neofetch
```

---

## 5. Настройка zram

### 5.1 Установка zram-tools

```bash
apt install -y zram-tools
```

### 5.2 Конфигурация

Отредактируйте `/etc/default/zramswap`:

```bash
cat > /etc/default/zramswap << 'EOF'
# Алгоритм сжатия (zstd - лучший баланс скорости и сжатия)
ALGO=zstd

# Процент от RAM для zram (50-100%)
PERCENT=50

# Приоритет swap (выше = предпочтительнее)
PRIORITY=100
EOF
```

### 5.3 Отключение файлового swap (если есть)

```bash
# Проверьте текущий swap
swapon --show

# Если есть файловый swap, отключите его
swapoff -a

# Закомментируйте swap в fstab
sed -i '/swap/d' /etc/fstab
```

### 5.4 Активация zram

```bash
systemctl enable zramswap
systemctl start zramswap

# Проверка
zramctl
swapon --show
```

---

## 6. Установка и настройка dwm

### 6.1 Установка зависимостей

```bash
apt install -y xorg xinit libx11-dev libxft-dev libxinerama-dev \
    build-essential pkg-config libfreetype6-dev libfontconfig1-dev \
    fonts-dejavu fonts-liberation2 picom feh suckless-tools
```

### 6.2 Клонирование dwm

```bash
# Создайте директорию для suckless программ
mkdir -p ~/suckless
cd ~/suckless

# Клонируйте dwm
git clone https://git.suckless.org/dwm
git clone https://git.suckless.org/st
git clone https://git.suckless.org/dmenu
```

### 6.3 Базовая конфигурация dwm

```bash
cd ~/suckless/dwm

# Скопируйте конфиг
cp config.def.h config.h
```

Отредактируйте `config.h` под свои нужды:

```c
/* Пример изменений в config.h */

/* Шрифт */
static const char *fonts[] = { "DejaVu Sans Mono:size=10" };

/* Цвета (тёмная тема) */
static const char col_gray1[] = "#222222";
static const char col_gray2[] = "#444444";
static const char col_gray3[] = "#bbbbbb";
static const char col_gray4[] = "#eeeeee";
static const char col_cyan[]  = "#005577";

/* Модификатор (Mod4 = Super/Win) */
#define MODKEY Mod4Mask

/* Терминал */
static const char *termcmd[] = { "st", NULL };
```

### 6.4 Компиляция и установка

```bash
# dwm
cd ~/suckless/dwm
sudo make clean install

# st (терминал)
cd ~/suckless/st
sudo make clean install

# dmenu (лаунчер)
cd ~/suckless/dmenu
sudo make clean install
```

### 6.5 Настройка автозапуска X

Создайте `~/.xinitrc`:

```bash
cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Раскладка клавиатуры
setxkbmap -layout us,ru -option grp:alt_shift_toggle

# Композитор (прозрачность, тени)
picom -b

# Обои
feh --bg-scale ~/.wallpaper.jpg 2>/dev/null

# Автоповтор клавиш
xset r rate 300 50

# Запуск dwm
exec dwm
EOF

chmod +x ~/.xinitrc
```

### 6.6 Автоматический запуск X при логине

Добавьте в `~/.bash_profile` или `~/.profile`:

```bash
cat >> ~/.bash_profile << 'EOF'

# Автозапуск X на tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec startx
fi
EOF
```

---

## 7. Дополнительная настройка

### 7.1 Настройка Btrfs

#### Оптимизация fstab

Отредактируйте `/etc/fstab`:

```
UUID=xxx  /  btrfs  defaults,noatime,compress=zstd:3,space_cache=v2,discard=async  0  0
```

Опции:
- `noatime` — не обновлять время доступа (ускоряет работу)
- `compress=zstd:3` — сжатие zstd уровня 3 (баланс скорости/сжатия)
- `space_cache=v2` — улучшенный кэш свободного места
- `discard=async` — асинхронный TRIM для SSD

#### Создание subvolumes (опционально)

```bash
# Загрузитесь с Live USB или в recovery mode

# Монтируйте корень
mount /dev/sdXY /mnt

# Создайте subvolumes
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log

# Переместите данные
mv /mnt/home/* /mnt/@home/
mv /mnt/var/log/* /mnt/@var_log/

# Обновите fstab соответственно
```

### 7.2 Установка дополнительного ПО

```bash
# Браузер
apt install -y firefox-esr

# Файловый менеджер
apt install -y pcmanfm

# Просмотр изображений/PDF
apt install -y feh zathura

# Аудио
apt install -y pipewire pipewire-pulse pavucontrol

# Сеть
apt install -y network-manager network-manager-gnome

# Инструменты
apt install -y unzip p7zip-full rsync
```

### 7.3 Настройка NetworkManager

```bash
# Отключите старое управление сетью
systemctl disable networking
systemctl stop networking

# Включите NetworkManager
systemctl enable NetworkManager
systemctl start NetworkManager

# Добавьте пользователя в группу netdev
usermod -aG netdev $USER
```

### 7.4 Снапшоты Btrfs

Установите Snapper или используйте вручную:

```bash
# Создание снапшота
btrfs subvolume snapshot / /.snapshots/$(date +%Y%m%d_%H%M%S)

# Список снапшотов
btrfs subvolume list /

# Удаление снапшота
btrfs subvolume delete /.snapshots/snapshot_name
```

---

## 8. Обслуживание системы

### 8.1 Регулярное обслуживание

```bash
# Обновление системы
sudo apt update && sudo apt upgrade

# Очистка кэша пакетов
sudo apt autoclean
sudo apt autoremove

# Баланс Btrfs (раз в месяц)
sudo btrfs balance start -dusage=50 /

# Scrub (проверка целостности, раз в месяц)
sudo btrfs scrub start /
```

### 8.2 Мониторинг

```bash
# Использование Btrfs
btrfs filesystem df /
btrfs filesystem usage /

# zram статистика
zramctl
cat /proc/swaps

# Общая информация
htop
neofetch
```

### 8.3 Откат системы (при проблемах)

```bash
# Загрузитесь с Live USB
mount /dev/sdXY /mnt

# Найдите нужный снапшот
btrfs subvolume list /mnt

# Переименуйте текущий корень
mv /mnt/@ /mnt/@broken

# Создайте снапшот из рабочей версии
btrfs subvolume snapshot /mnt/@snapshots/working /mnt/@

# Перезагрузитесь
reboot
```

---

## Быстрые клавиши dwm (по умолчанию)

| Комбинация | Действие |
|------------|----------|
| `Mod + Enter` | Открыть терминал |
| `Mod + p` | Открыть dmenu |
| `Mod + j/k` | Переключение между окнами |
| `Mod + h/l` | Изменение размера master |
| `Mod + Shift + c` | Закрыть окно |
| `Mod + Shift + q` | Выход из dwm |
| `Mod + 1-9` | Переключение тегов |
| `Mod + Shift + 1-9` | Переместить окно на тег |
| `Mod + t` | Tiled layout |
| `Mod + f` | Floating layout |
| `Mod + m` | Monocle layout |

---

## Полезные патчи для dwm

Популярные патчи (скачивайте с https://dwm.suckless.org/patches/):

- **autostart** — автозапуск скриптов
- **systray** — системный трей
- **pertag** — разные layouts для разных тегов
- **fullgaps** — отступы между окнами
- **statuspadding** — отступы в статусбаре
- **alwayscenter** — плавающие окна всегда по центру

Применение патча:
```bash
cd ~/suckless/dwm
patch -p1 < /path/to/patch.diff
# Если конфликты — исправьте вручную
sudo make clean install
```

---

## Решение проблем

### Нет звука
```bash
# Проверьте PipeWire
systemctl --user status pipewire
pactl info
```

### Wi-Fi не работает
```bash
# Проверьте firmware
dmesg | grep -i firmware
apt install firmware-iwlwifi  # для Intel
```

### Экран мерцает
```bash
# Отключите picom или измените backend
picom --backend xrender
```

### Низкая производительность
```bash
# Проверьте CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Установите performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

---

*Последнее обновление: Декабрь 2025*
