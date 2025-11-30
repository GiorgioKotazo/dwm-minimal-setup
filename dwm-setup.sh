#!/bin/bash
#
# Debian 13 Trixie Minimal dwm Setup Script
# Optimized for USB SSD + btrfs + zram
# Updated: November 30, 2025
#
# This script installs a minimal, productive dwm environment
# Philosophy: CLI-first, keyboard-driven, minimal bloat
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CONFIG_DIR="$HOME/.config/suckless"
SUCKLESS_DIR="$HOME/suckless"

# Log file
LOG_FILE="/tmp/dwm-install-$(date +%Y%m%d-%H%M%S).log"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

ask() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Debian 13 Trixie - Minimal dwm Setup                   ║
║   CLI-First | Keyboard-Driven | Zero Bloat               ║
║                                                           ║
║   Updated: November 30, 2025                             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    sleep 2
}

check_debian() {
    log "Checking Debian version..."
    if [ ! -f /etc/debian_version ]; then
        error "This script is for Debian-based systems only!"
    fi
    
    debian_version=$(cat /etc/debian_version | cut -d. -f1)
    if [ "$debian_version" != "13" ]; then
        warn "This script is optimized for Debian 13 Trixie"
        if ! ask "Continue anyway?"; then
            exit 0
        fi
    fi
    log "Debian 13 Trixie detected ✓"
}

check_btrfs_zram() {
    log "Checking for btrfs and zram..."
    
    if ! mount | grep -q "type btrfs"; then
        warn "btrfs not detected on root filesystem"
    else
        log "btrfs detected ✓"
    fi
    
    if ! swapon --show | grep -q "zram"; then
        warn "zram swap not detected"
    else
        log "zram detected ✓"
    fi
}

system_update() {
    log "Updating system packages..."
    sudo apt update || error "Failed to update package lists"
    sudo apt upgrade -y || error "Failed to upgrade packages"
    log "System updated ✓"
}

install_core_packages() {
    log "Installing core packages..."
    
    local packages=(
        # Build essentials
        build-essential
        git
        curl
        wget
        cmake
        pkg-config
        
        # X11 and libraries
        xorg
        xinit
        libx11-dev
        libxft-dev
        libxinerama-dev
        libxrandr-dev
        libimlib2-dev
        
        # System tools
        htop
        btop
        ncdu
        tree
        net-tools
        network-manager
        pavucontrol
        alsa-utils
        
        # Fonts
        fonts-hack
        fonts-firacode
        fonts-noto
        fonts-noto-color-emoji
        
        # Utilities
        feh
        sxiv
        zathura
        zathura-pdf-poppler
        mpv
        maim
        xclip
        xdotool
        dunst
        libnotify-bin
        brightnessctl
        
        # Essential CLI tools
        tmux
        neovim
        fzf
        ripgrep
        fd-find
        bat
        tldr
        pass
        age
        gnupg
        
        # Development
        python3
        python3-pip
        nodejs
        npm
        
        # Firewall
        ufw
        
        # Snapshot management
        snapper
        
        # Compression
        p7zip-full
        unzip
        unrar
    )
    
    sudo apt install -y "${packages[@]}" || error "Failed to install core packages"
    log "Core packages installed ✓"
}

install_rust_tools() {
    log "Installing Rust and Rust-based tools..."
    
    if ! command -v rustc &> /dev/null; then
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        log "Rust already installed"
    fi
    
    log "Installing Rust utilities..."
    cargo install zoxide eza dust tokei yazi-fm yazi-cli || warn "Some Rust tools failed to install"
    
    log "Rust tools installed ✓"
}

install_starship() {
    log "Installing Starship prompt..."
    if ! command -v starship &> /dev/null; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        log "Starship installed ✓"
    else
        log "Starship already installed"
    fi
}

install_git_tools() {
    log "Installing Git tools..."
    
    # lazygit
    if ! command -v lazygit &> /dev/null; then
        sudo apt install -y lazygit || warn "lazygit not available in repos, install manually"
    fi
    
    # delta
    sudo apt install -y git-delta || warn "git-delta not available"
    
    log "Git tools installed ✓"
}

install_browsers() {
    log "Installing browsers..."
    
    # LibreWolf
    if ask "Install LibreWolf (privacy-focused Firefox fork)?"; then
        log "Installing LibreWolf..."
        sudo apt install -y extrepo
        sudo extrepo enable librewolf
        sudo apt update
        sudo apt install -y librewolf || warn "LibreWolf installation failed"
    fi
    
    # Brave
    if ask "Install Brave browser?"; then
        log "Installing Brave..."
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
            sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        
        sudo apt update
        sudo apt install -y brave-browser || warn "Brave installation failed"
    fi
    
    log "Browsers installed ✓"
}

install_vlc() {
    if ask "Install VLC media player?"; then
        log "Installing VLC..."
        sudo apt install -y vlc || warn "VLC installation failed"
        log "VLC installed ✓"
    fi
}

configure_ssd_optimizations() {
    log "Applying USB SSD optimizations..."
    
    # I/O Scheduler
    log "Setting up I/O scheduler for SSD..."
    sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null << 'EOF'
# SSD
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# HDD
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    
    # Sysctl optimizations
    log "Setting up sysctl optimizations..."
    sudo tee /etc/sysctl.d/99-ssd.conf > /dev/null << 'EOF'
# Reduce writes to disk
vm.dirty_ratio=80
vm.dirty_background_ratio=50
vm.dirty_expire_centisecs=12000
vm.dirty_writeback_centisecs=3000

# Swappiness (for zram)
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.page-cluster=0
EOF
    
    # Journald optimization
    log "Optimizing journald..."
    sudo tee /etc/systemd/journald.conf > /dev/null << 'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=100M
SystemMaxUse=200M
EOF
    
    # Enable fstrim
    log "Enabling fstrim.timer..."
    sudo systemctl enable fstrim.timer
    sudo systemctl start fstrim.timer
    
    sudo sysctl -p /etc/sysctl.d/99-ssd.conf
    sudo systemctl restart systemd-journald
    
    log "SSD optimizations applied ✓"
}

configure_snapper() {
    log "Configuring snapper for automatic snapshots..."
    
    # Create config for root
    if [ ! -f /etc/snapper/configs/root ]; then
        sudo snapper -c root create-config /
        
        # Adjust snapshot limits
        sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
        sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
        sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' /etc/snapper/configs/root
        sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="6"/' /etc/snapper/configs/root
    fi
    
    # Enable timers
    sudo systemctl enable snapper-timeline.timer
    sudo systemctl enable snapper-cleanup.timer
    sudo systemctl start snapper-timeline.timer
    sudo systemctl start snapper-cleanup.timer
    
    # APT integration
    sudo tee /etc/apt/apt.conf.d/80snapper > /dev/null << 'EOF'
DPkg::Pre-Invoke {"if [ -x /usr/bin/snapper ]; then /usr/bin/snapper -c root create --description 'apt-pre' --cleanup-algorithm number; fi";};
DPkg::Post-Invoke {"if [ -x /usr/bin/snapper ]; then /usr/bin/snapper -c root create --description 'apt-post' --cleanup-algorithm number; fi";};
EOF
    
    log "Snapper configured ✓"
}

configure_firewall() {
    log "Configuring UFW firewall..."
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw --force enable
    
    log "Firewall configured ✓"
}

install_suckless() {
    log "Installing suckless tools (dwm, st, dmenu, slstatus)..."
    
    mkdir -p "$SUCKLESS_DIR"
    cd "$SUCKLESS_DIR"
    
    # Clone repositories
    log "Cloning suckless repositories..."
    [ ! -d "dwm" ] && git clone https://git.suckless.org/dwm
    [ ! -d "st" ] && git clone https://git.suckless.org/st
    [ ! -d "dmenu" ] && git clone https://git.suckless.org/dmenu
    [ ! -d "slstatus" ] && git clone https://git.suckless.org/slstatus
    
    # Compile and install dwm
    log "Building dwm..."
    cd "$SUCKLESS_DIR/dwm"
    [ -f config.h ] && rm config.h
    sudo make clean install || error "Failed to build dwm"
    
    # Compile and install st
    log "Building st..."
    cd "$SUCKLESS_DIR/st"
    [ -f config.h ] && rm config.h
    sudo make clean install || error "Failed to build st"
    
    # Compile and install dmenu
    log "Building dmenu..."
    cd "$SUCKLESS_DIR/dmenu"
    [ -f config.h ] && rm config.h
    sudo make clean install || error "Failed to build dmenu"
    
    # Compile and install slstatus
    log "Building slstatus..."
    cd "$SUCKLESS_DIR/slstatus"
    [ -f config.h ] && rm config.h
    sudo make clean install || error "Failed to build slstatus"
    
    log "Suckless tools installed ✓"
}

install_sxhkd() {
    log "Installing sxhkd..."
    sudo apt install -y sxhkd
    log "sxhkd installed ✓"
}

setup_nvchad() {
    log "Setting up Neovim with NvChad..."
    
    # Backup existing config
    if [ -d "$HOME/.config/nvim" ]; then
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d)"
    fi
    
    # Clone NvChad starter
    git clone https://github.com/NvChad/starter "$HOME/.config/nvim"
    
    log "NvChad installed ✓"
    log "Run 'nvim' to complete installation"
}

create_config_structure() {
    log "Creating configuration directory structure..."
    
    mkdir -p "$CONFIG_DIR"/{dwm,st,dmenu,slstatus,sxhkd,scripts,dunst,picom}
    mkdir -p "$HOME/.config"/{alacritty,starship,yazi}
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/Pictures/Screenshots"
    
    log "Directory structure created ✓"
}

setup_xinitrc() {
    log "Creating .xinitrc..."
    
    cat > "$HOME/.xinitrc" << 'EOF'
#!/bin/sh

# Load resources
userresources=$HOME/.Xresources
[ -f $userresources ] && xrdb -merge $userresources

# Keyboard settings
xset r rate 300 50
xset b off

# Power management
xset dpms 600 600 600

# Start services
dunst &
nm-applet &
volumeicon &

# Compositor (optional, uncomment if needed)
# picom -b &

# Wallpaper
if [ -f ~/.wallpaper.jpg ]; then
    feh --bg-scale ~/.wallpaper.jpg &
else
    xsetroot -solid "#1d1f21"
fi

# Status bar
slstatus &

# Hotkey daemon
sxhkd &

# Start dwm
exec dwm
EOF
    
    chmod +x "$HOME/.xinitrc"
    log ".xinitrc created ✓"
}

setup_sxhkdrc() {
    log "Creating sxhkdrc..."
    
    mkdir -p "$HOME/.config/sxhkd"
    
    cat > "$HOME/.config/sxhkd/sxhkdrc" << 'EOF'
# Terminal
super + Return
    st

# Browser (adjust based on what's installed)
super + b
    librewolf || brave-browser || firefox-esr

# File manager
super + f
    st -e yazi

# Application launcher
super + d
    dmenu_run

# Screenshot
Print
    maim ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png

shift + Print
    maim -s ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png

ctrl + Print
    maim -s | xclip -selection clipboard -t image/png

# Volume control
XF86AudioRaiseVolume
    amixer set Master 5%+

XF86AudioLowerVolume
    amixer set Master 5%-

XF86AudioMute
    amixer set Master toggle

# Brightness
XF86MonBrightnessUp
    brightnessctl set +10%

XF86MonBrightnessDown
    brightnessctl set 10%-

# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd
EOF
    
    log "sxhkdrc created ✓"
}

setup_dunstrc() {
    log "Creating dunst config..."
    
    mkdir -p "$HOME/.config/dunst"
    
    cat > "$HOME/.config/dunst/dunstrc" << 'EOF'
[global]
    font = Hack 10
    origin = top-right
    offset = 10x50
    width = 300
    height = 300
    transparency = 10
    frame_width = 2
    frame_color = "#89AAEB"
    icon_position = left
    max_icon_size = 64
    history_length = 20
    timeout = 5

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#89b4fa"
    timeout = 5

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#89b4fa"
    timeout = 10

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#f38ba8"
    timeout = 0
EOF
    
    log "dunst config created ✓"
}

setup_tmux() {
    log "Creating tmux config..."
    
    cat > "$HOME/.tmux.conf" << 'EOF'
# Prefix
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Vim mode
setw -g mode-keys vi
set -g status-keys vi

# Splits
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Vim navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Settings
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -sg escape-time 0
set -g status-interval 5

# True color
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Mouse
set -g mouse on

# Copy mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel

# Reload
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Status bar
set -g status-style bg=black,fg=white
set -g status-left "[#S] "
set -g status-right "%d %b %H:%M"
EOF
    
    log "tmux config created ✓"
}

setup_git() {
    log "Configuring Git with delta..."
    
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default
    
    log "Git configured ✓"
}

setup_bashrc() {
    log "Updating .bashrc..."
    
    # Create aliases file
    cat > "$HOME/.bash_aliases" << 'EOF'
# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ls replacements (using eza)
alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias lg='lazygit'

# System
alias update='sudo apt update && sudo apt upgrade'
alias clean='sudo apt autoremove && sudo apt clean'
alias snapshot='sudo btrfs subvolume snapshot / /.snapshots/manual-$(date +%Y%m%d-%H%M)'

# Utilities
alias cat='batcat'
alias find='fdfind'
alias du='dust'
alias top='btop'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Yazi with cd on exit
function yy() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
EOF
    
    # Add to .bashrc
    if ! grep -q "source ~/.bash_aliases" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Custom aliases
[ -f ~/.bash_aliases ] && source ~/.bash_aliases

# Starship prompt
eval "$(starship init bash)"

# Zoxide
eval "$(zoxide init bash)"

# FZF keybindings
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

# Cargo environment
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF
    fi
    
    log ".bashrc updated ✓"
}

create_cheatsheet() {
    log "Creating keybindings cheatsheet..."
    
    cat > "$HOME/KEYBINDINGS.md" << 'EOF'
# Keybindings Cheatsheet

## dwm (Window Manager)
- `Super + Shift + Enter` - Launch terminal
- `Super + d` - Launch dmenu
- `Super + b` - Launch browser
- `Super + f` - Launch file manager (yazi)
- `Super + j/k` - Focus next/previous window
- `Super + h/l` - Decrease/increase master width
- `Super + 1-9` - Switch to tag
- `Super + Shift + 1-9` - Move window to tag
- `Super + Tab` - Toggle between last two tags
- `Super + Shift + c` - Close window
- `Super + Shift + q` - Quit dwm

## tmux (Terminal Multiplexer)
- `Ctrl + a` - Prefix key
- `Prefix |` - Vertical split
- `Prefix -` - Horizontal split
- `Prefix h/j/k/l` - Navigate panes
- `Prefix c` - New window
- `Prefix n/p` - Next/previous window
- `Prefix d` - Detach
- `Prefix [` - Copy mode

## Neovim (NvChad)
- `Space ff` - Find files
- `Space fw` - Find word (grep)
- `Space e` - File explorer
- `Space th` - Change theme
- `gd` - Go to definition
- `gr` - Find references
- `K` - Hover documentation

## System
- `Print` - Full screenshot
- `Shift + Print` - Area screenshot
- `Ctrl + Print` - Screenshot to clipboard
- `XF86AudioRaiseVolume` - Volume up
- `XF86AudioLowerVolume` - Volume down
- `XF86AudioMute` - Toggle mute
EOF
    
    log "Cheatsheet created at ~/KEYBINDINGS.md"
}

final_instructions() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Installation Complete!                                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "1. Reboot your system:"
    echo "   sudo reboot"
    echo ""
    echo "2. After reboot, start X:"
    echo "   startx"
    echo ""
    echo "3. Open Neovim to finish NvChad setup:"
    echo "   nvim"
    echo "   (Wait for plugins to install)"
    echo ""
    echo "4. Customize dwm config:"
    echo "   cd ~/suckless/dwm"
    echo "   nano config.def.h"
    echo "   sudo make clean install"
    echo ""
    echo "5. View keybindings:"
    echo "   cat ~/KEYBINDINGS.md"
    echo ""
    echo -e "${GREEN}Installed Components:${NC}"
    echo "  ✓ dwm + st + dmenu + slstatus"
    echo "  ✓ sxhkd (hotkey daemon)"
    echo "  ✓ tmux + neovim + NvChad"
    echo "  ✓ yazi (file manager)"
    echo "  ✓ fzf + ripgrep + zoxide + eza + bat"
    echo "  ✓ lazygit + delta"
    echo "  ✓ snapper (auto-snapshots)"
    echo "  ✓ UFW firewall"
    echo "  ✓ SSD optimizations applied"
    
    if command -v librewolf &> /dev/null; then
        echo "  ✓ LibreWolf browser"
    fi
    
    if command -v brave-browser &> /dev/null; then
        echo "  ✓ Brave browser"
    fi
    
    if command -v vlc &> /dev/null; then
        echo "  ✓ VLC media player"
    fi
    
    echo ""
    echo -e "${BLUE}Configuration Directories:${NC}"
    echo "  • Suckless: ~/suckless/"
    echo "  • Config: ~/.config/suckless/"
    echo "  • Neovim: ~/.config/nvim/"
    echo ""
    echo -e "${YELLOW}Log file: $LOG_FILE${NC}"
    echo ""
}

# Main installation flow
main() {
    banner
    
    # Checks
    check_debian
    check_btrfs_zram
    
    # System update
    system_update
    
    # Core installation
    install_core_packages
    install_rust_tools
    install_starship
    install_git_tools
    
    # Optional software
    install_browsers
    install_vlc
    
    # Optimizations
    configure_ssd_optimizations
    configure_snapper
    configure_firewall
    
    # Suckless software
    install_suckless
    install_sxhkd
    
    # Modern tools
    setup_nvchad
    
    # Configuration
    create_config_structure
    setup_xinitrc
    setup_sxhkdrc
    setup_dunstrc
    setup_tmux
    setup_git
    setup_bashrc
    create_cheatsheet
    
    # Done
    final_instructions
}

# Run main function
main "$@"
