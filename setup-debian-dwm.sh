#!/bin/bash
#
# Debian 13 Trixie + dwm + Btrfs + zram
# Скрипт автоматической настройки системы
#
# Использование:
#   chmod +x setup-debian-dwm.sh
#   sudo ./setup-debian-dwm.sh
#
# Запускать после минимальной установки Debian 13
#

set -e

# ============================================
# КОНФИГУРАЦИЯ (измените под свои нужды)
# ============================================

# Имя пользователя (текущий пользователь или укажите вручную)
USERNAME="${SUDO_USER:-$(whoami)}"
USER_HOME="/home/$USERNAME"

# zram настройки
ZRAM_PERCENT=50          # Процент от RAM
ZRAM_ALGO="zstd"         # Алгоритм сжатия

# Раскладки клавиатуры
KEYBOARD_LAYOUTS="us,ru"
KEYBOARD_TOGGLE="grp:alt_shift_toggle"

# Устанавливать дополнительное ПО?
INSTALL_EXTRAS=true

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# ФУНКЦИИ
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Запустите скрипт с sudo: sudo ./setup-debian-dwm.sh"
    fi
}

check_debian() {
    if [ ! -f /etc/debian_version ]; then
        log_error "Этот скрипт предназначен только для Debian"
    fi
    log_info "Обнаружен Debian $(cat /etc/debian_version)"
}

# ============================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# ============================================

update_system() {
    log_info "Обновление системы..."
    
    apt update -qq
    apt upgrade -y -qq
    
    log_success "Система обновлена"
}

# ============================================
# НАСТРОЙКА ZRAM
# ============================================

setup_zram() {
    log_info "Настройка zram..."
    
    apt install -y -qq zram-tools
    
    # Конфигурация zram
    cat > /etc/default/zramswap << EOF
# Конфигурация zram
# Создано setup-debian-dwm.sh

# Алгоритм сжатия
ALGO=$ZRAM_ALGO

# Процент от RAM
PERCENT=$ZRAM_PERCENT

# Приоритет (выше = предпочтительнее)
PRIORITY=100
EOF

    # Отключение файлового swap если есть
    if swapon --show | grep -q "file\|partition"; then
        log_info "Отключение файлового swap..."
        swapoff -a 2>/dev/null || true
        # Удаляем swap из fstab
        sed -i '/swap/d' /etc/fstab
    fi
    
    # Активация zram
    systemctl enable zramswap
    systemctl restart zramswap
    
    log_success "zram настроен (${ZRAM_PERCENT}% RAM, алгоритм ${ZRAM_ALGO})"
}

# ============================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# ============================================

install_dependencies() {
    log_info "Установка зависимостей для X и dwm..."
    
    # Базовые пакеты для X и dwm
    apt install -y -qq \
        xorg \
        xinit \
        libx11-dev \
        libxft-dev \
        libxinerama-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        build-essential \
        pkg-config \
        git \
        curl \
        wget
    
    # Утилиты и шрифты
    apt install -y -qq \
        fonts-dejavu \
        fonts-liberation2 \
        fonts-noto \
        picom \
        feh \
        suckless-tools \
        xclip \
        xdotool
    
    log_success "Зависимости установлены"
}

# ============================================
# УСТАНОВКА SUCKLESS СОФТА
# ============================================

install_suckless() {
    log_info "Установка dwm, st, dmenu..."
    
    SUCKLESS_DIR="$USER_HOME/suckless"
    
    # Создаём директорию
    sudo -u "$USERNAME" mkdir -p "$SUCKLESS_DIR"
    
    # Клонируем репозитории
    cd "$SUCKLESS_DIR"
    
    for repo in dwm st dmenu; do
        if [ ! -d "$repo" ]; then
            log_info "Клонирование $repo..."
            sudo -u "$USERNAME" git clone "https://git.suckless.org/$repo"
        else
            log_warning "$repo уже существует, пропускаем"
        fi
    done
    
    # Компиляция dwm
    log_info "Компиляция dwm..."
    cd "$SUCKLESS_DIR/dwm"
    
    # Создаём базовый конфиг если нет
    if [ ! -f config.h ]; then
        sudo -u "$USERNAME" cp config.def.h config.h
        
        # Базовые модификации конфига
        sudo -u "$USERNAME" sed -i 's/static const char \*fonts\[\] = { "monospace:size=10" };/static const char *fonts[] = { "DejaVu Sans Mono:size=10" };/' config.h
        # Меняем модификатор на Super (Mod4)
        sudo -u "$USERNAME" sed -i 's/#define MODKEY Mod1Mask/#define MODKEY Mod4Mask/' config.h
    fi
    
    make clean install
    
    # Компиляция st
    log_info "Компиляция st..."
    cd "$SUCKLESS_DIR/st"
    if [ ! -f config.h ]; then
        sudo -u "$USERNAME" cp config.def.h config.h
        # Увеличиваем шрифт
        sudo -u "$USERNAME" sed -i 's/pixelsize=12/pixelsize=14/' config.h
    fi
    make clean install
    
    # Компиляция dmenu
    log_info "Компиляция dmenu..."
    cd "$SUCKLESS_DIR/dmenu"
    if [ ! -f config.h ]; then
        sudo -u "$USERNAME" cp config.def.h config.h
    fi
    make clean install
    
    log_success "Suckless софт установлен"
}

# ============================================
# НАСТРОЙКА АВТОЗАПУСКА X
# ============================================

setup_xinit() {
    log_info "Настройка .xinitrc..."
    
    cat > "$USER_HOME/.xinitrc" << EOF
#!/bin/sh
# .xinitrc - конфигурация запуска X
# Создано setup-debian-dwm.sh

# Раскладка клавиатуры
setxkbmap -layout $KEYBOARD_LAYOUTS -option $KEYBOARD_TOGGLE

# Скорость повтора клавиш
xset r rate 300 50

# Отключить DPMS (энергосбережение экрана)
xset s off
xset -dpms

# Курсор мыши
xsetroot -cursor_name left_ptr

# Композитор (прозрачность, тени, без vsync для старого железа)
picom -b --vsync || true

# Обои (если есть)
[ -f ~/.wallpaper.jpg ] && feh --bg-scale ~/.wallpaper.jpg
[ -f ~/.wallpaper.png ] && feh --bg-scale ~/.wallpaper.png

# Статусбар (фоновый процесс)
~/.local/bin/dwm-status.sh &

# Запуск dwm (с перезапуском при крахе)
while true; do
    dwm 2> ~/.dwm.log
done
EOF
    
    chown "$USERNAME:$USERNAME" "$USER_HOME/.xinitrc"
    chmod +x "$USER_HOME/.xinitrc"
    
    log_success ".xinitrc создан"
}

# ============================================
# НАСТРОЙКА АВТОЛОГИНА В X
# ============================================

setup_autologin() {
    log_info "Настройка автозапуска X при логине..."
    
    # Добавляем в .bash_profile
    PROFILE="$USER_HOME/.bash_profile"
    
    if [ ! -f "$PROFILE" ] || ! grep -q "startx" "$PROFILE"; then
        cat >> "$PROFILE" << 'EOF'

# Автозапуск X на tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec startx
fi
EOF
        chown "$USERNAME:$USERNAME" "$PROFILE"
    fi
    
    log_success "Автозапуск X настроен"
}

# ============================================
# СОЗДАНИЕ СКРИПТА СТАТУСБАРА
# ============================================

create_statusbar() {
    log_info "Создание скрипта статусбара..."
    
    mkdir -p "$USER_HOME/.local/bin"
    
    cat > "$USER_HOME/.local/bin/dwm-status.sh" << 'EOF'
#!/bin/bash
# dwm-status.sh - простой статусбар для dwm

while true; do
    # Дата и время
    DATE=$(date '+%a %d %b %H:%M')
    
    # Батарея (если есть)
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        BAT=$(cat /sys/class/power_supply/BAT0/capacity)
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$BAT_STATUS" = "Charging" ]; then
            BAT_ICON="⚡"
        else
            BAT_ICON="🔋"
        fi
        BATTERY="$BAT_ICON ${BAT}%"
    else
        BATTERY=""
    fi
    
    # Память
    MEM=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    
    # CPU температура (если есть)
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        CPU_TEMP="${TEMP}°C"
    else
        CPU_TEMP=""
    fi
    
    # Громкость (если pactl доступен)
    if command -v pactl &>/dev/null; then
        VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1)
        MUTE=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP 'yes|no')
        if [ "$MUTE" = "yes" ]; then
            VOLUME="🔇"
        else
            VOLUME="🔊 $VOL"
        fi
    else
        VOLUME=""
    fi
    
    # Формируем строку статуса
    STATUS=""
    [ -n "$CPU_TEMP" ] && STATUS="$STATUS $CPU_TEMP |"
    STATUS="$STATUS 💾 $MEM"
    [ -n "$VOLUME" ] && STATUS="$STATUS | $VOLUME"
    [ -n "$BATTERY" ] && STATUS="$STATUS | $BATTERY"
    STATUS="$STATUS | 📅 $DATE"
    
    xsetroot -name "$STATUS"
    
    sleep 5
done
EOF
    
    chown "$USERNAME:$USERNAME" "$USER_HOME/.local/bin/dwm-status.sh"
    chmod +x "$USER_HOME/.local/bin/dwm-status.sh"
    
    log_success "Скрипт статусбара создан"
}

# ============================================
# ОПТИМИЗАЦИЯ BTRFS
# ============================================

optimize_btrfs() {
    log_info "Проверка и оптимизация Btrfs..."
    
    # Проверяем, используется ли Btrfs
    if ! mount | grep -q "on / type btrfs"; then
        log_warning "Корневая ФС не Btrfs, пропускаем оптимизацию"
        return
    fi
    
    # Получаем UUID корневого раздела
    ROOT_UUID=$(findmnt -no UUID /)
    
    # Проверяем текущие опции монтирования
    CURRENT_OPTS=$(findmnt -no OPTIONS /)
    
    log_info "Текущие опции: $CURRENT_OPTS"
    
    # Рекомендуемые опции (добавляем если нет)
    RECOMMENDED="noatime,compress=zstd:3,space_cache=v2"
    
    # Проверяем, есть ли SSD
    ROOTDEV=$(findmnt -no SOURCE /)
    ROTATIONAL=$(cat /sys/block/$(lsblk -no PKNAME "$ROOTDEV" | head -1)/queue/rotational 2>/dev/null || echo "1")
    
    if [ "$ROTATIONAL" = "0" ]; then
        log_info "Обнаружен SSD, добавляем discard=async"
        RECOMMENDED="$RECOMMENDED,discard=async"
    fi
    
    # Создаём скрипт для ручной оптимизации fstab
    cat > "$USER_HOME/optimize-fstab.sh" << EOF
#!/bin/bash
# Скрипт для оптимизации fstab для Btrfs
# Запустите: sudo ./optimize-fstab.sh

echo "Текущий fstab:"
cat /etc/fstab

echo ""
echo "Рекомендуемые опции для Btrfs:"
echo "UUID=$ROOT_UUID  /  btrfs  $RECOMMENDED  0  0"
echo ""
echo "Отредактируйте /etc/fstab вручную и перезагрузитесь"
EOF
    
    chown "$USERNAME:$USERNAME" "$USER_HOME/optimize-fstab.sh"
    chmod +x "$USER_HOME/optimize-fstab.sh"
    
    # Создаём директорию для снапшотов
    if [ ! -d /.snapshots ]; then
        mkdir -p /.snapshots
        log_info "Создана директория /.snapshots"
    fi
    
    # Создаём скрипт для снапшотов
    cat > /usr/local/bin/btrfs-snapshot << 'EOF'
#!/bin/bash
# Простой скрипт для создания снапшотов Btrfs
# Использование: btrfs-snapshot [имя]

NAME="${1:-$(date +%Y%m%d_%H%M%S)}"
SNAPSHOT_DIR="/.snapshots"

if [ "$EUID" -ne 0 ]; then
    echo "Запустите с sudo"
    exit 1
fi

btrfs subvolume snapshot -r / "$SNAPSHOT_DIR/$NAME"
echo "Создан снапшот: $SNAPSHOT_DIR/$NAME"
echo ""
echo "Список снапшотов:"
ls -la "$SNAPSHOT_DIR"
EOF
    
    chmod +x /usr/local/bin/btrfs-snapshot
    
    log_success "Btrfs оптимизирован. Запустите ~/optimize-fstab.sh для настройки fstab"
}

# ============================================
# ДОПОЛНИТЕЛЬНОЕ ПО
# ============================================

install_extras() {
    if [ "$INSTALL_EXTRAS" != "true" ]; then
        log_info "Пропуск установки дополнительного ПО"
        return
    fi
    
    log_info "Установка дополнительного ПО..."
    
    # Браузер
    apt install -y -qq firefox-esr
    
    # Файловый менеджер
    apt install -y -qq pcmanfm
    
    # Просмотр изображений и PDF
    apt install -y -qq feh zathura zathura-pdf-poppler
    
    # Аудио
    apt install -y -qq pipewire pipewire-pulse wireplumber pavucontrol
    systemctl --user --machine="$USERNAME@.host" enable pipewire pipewire-pulse wireplumber 2>/dev/null || true
    
    # Сеть
    apt install -y -qq network-manager
    systemctl enable NetworkManager
    systemctl start NetworkManager
    
    # Добавляем пользователя в группу netdev
    usermod -aG netdev "$USERNAME"
    
    # Утилиты
    apt install -y -qq \
        htop \
        neofetch \
        unzip \
        p7zip-full \
        rsync \
        vim \
        ranger \
        scrot
    
    # Firmware для Wi-Fi (Intel)
    apt install -y -qq firmware-iwlwifi 2>/dev/null || true
    
    log_success "Дополнительное ПО установлено"
}

# ============================================
# СОЗДАНИЕ ПОЛЕЗНЫХ АЛИАСОВ
# ============================================

create_aliases() {
    log_info "Создание полезных алиасов..."
    
    cat > "$USER_HOME/.bash_aliases" << 'EOF'
# Алиасы для Debian + dwm + Btrfs
# Создано setup-debian-dwm.sh

# Навигация
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -la'
alias la='ls -A'

# Безопасность
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Apt
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias clean='sudo apt autoclean && sudo apt autoremove'

# Btrfs
alias btrfs-usage='sudo btrfs filesystem usage /'
alias btrfs-df='sudo btrfs filesystem df /'
alias btrfs-list='sudo btrfs subvolume list /'
alias snapshot='sudo btrfs-snapshot'

# zram
alias zram-status='zramctl && echo "" && swapon --show'

# dwm
alias dwm-rebuild='cd ~/suckless/dwm && sudo make clean install && killall dwm'
alias st-rebuild='cd ~/suckless/st && sudo make clean install'
alias dmenu-rebuild='cd ~/suckless/dmenu && sudo make clean install'

# Система
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias temps='sensors 2>/dev/null || cat /sys/class/thermal/thermal_zone*/temp'

# Сеть
alias myip='curl -s ifconfig.me'
alias ports='ss -tuln'
EOF
    
    chown "$USERNAME:$USERNAME" "$USER_HOME/.bash_aliases"
    
    # Подключаем алиасы в .bashrc если ещё не подключены
    if ! grep -q ".bash_aliases" "$USER_HOME/.bashrc" 2>/dev/null; then
        echo '[ -f ~/.bash_aliases ] && . ~/.bash_aliases' >> "$USER_HOME/.bashrc"
    fi
    
    log_success "Алиасы созданы"
}

# ============================================
# ФИНАЛЬНАЯ ИНФОРМАЦИЯ
# ============================================

print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}Установка завершена!${NC}"
    echo "============================================"
    echo ""
    echo "Что было сделано:"
    echo "  ✓ Система обновлена"
    echo "  ✓ zram настроен (${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO})"
    echo "  ✓ dwm, st, dmenu установлены в ~/suckless/"
    echo "  ✓ X настроен на автозапуск"
    echo "  ✓ Статусбар создан"
    if [ "$INSTALL_EXTRAS" = "true" ]; then
        echo "  ✓ Дополнительное ПО установлено"
    fi
    echo ""
    echo "Что делать дальше:"
    echo "  1. Перезагрузитесь: sudo reboot"
    echo "  2. При логине X запустится автоматически"
    echo "  3. Настройте dwm под себя: vim ~/suckless/dwm/config.h"
    echo "  4. После изменений: dwm-rebuild"
    echo ""
    echo "Клавиши dwm:"
    echo "  Super + Enter     = терминал"
    echo "  Super + p         = dmenu"
    echo "  Super + Shift + c = закрыть окно"
    echo "  Super + Shift + q = выход"
    echo ""
    echo "Btrfs снапшоты:"
    echo "  sudo btrfs-snapshot [имя]   = создать снапшот"
    echo "  btrfs-list                  = список subvolumes"
    echo ""
    echo "Оптимизация Btrfs:"
    echo "  Запустите: ~/optimize-fstab.sh"
    echo ""
    echo "============================================"
}

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

main() {
    echo ""
    echo "============================================"
    echo "  Debian 13 + dwm + Btrfs + zram"
    echo "  Автоматическая настройка системы"
    echo "============================================"
    echo ""
    
    check_root
    check_debian
    
    echo ""
    echo "Пользователь: $USERNAME"
    echo "Домашняя директория: $USER_HOME"
    echo ""
    read -p "Продолжить? [y/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Отменено"
        exit 0
    fi
    
    update_system
    setup_zram
    install_dependencies
    install_suckless
    setup_xinit
    setup_autologin
    create_statusbar
    optimize_btrfs
    install_extras
    create_aliases
    
    print_summary
}

# Запуск
main "$@"
