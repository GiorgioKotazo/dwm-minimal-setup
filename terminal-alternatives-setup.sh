#!/bin/bash
#
# Alternative Terminal Emulators Setup
# Alacritty and Ghostty installation for Debian 13
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
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

install_alacritty() {
    log "Installing Alacritty..."
    
    sudo apt install -y alacritty
    
    # Create config
    mkdir -p ~/.config/alacritty
    
    cat > ~/.config/alacritty/alacritty.toml << 'EOF'
[window]
opacity = 0.95
padding = { x = 5, y = 5 }

[font]
size = 11.0

[font.normal]
family = "Hack"
style = "Regular"

[colors.primary]
background = "#1d1f21"
foreground = "#c5c8c6"

[cursor]
style = "Block"

[keyboard]
bindings = [
    { key = "V", mods = "Control|Shift", action = "Paste" },
    { key = "C", mods = "Control|Shift", action = "Copy" },
]
EOF
    
    log "Alacritty installed and configured ✓"
    log "Edit: ~/.config/alacritty/alacritty.toml"
}

install_ghostty() {
    log "Installing Ghostty..."
    
    if command -v ghostty &> /dev/null; then
        log "Ghostty already installed"
        return
    fi
    
    warn "Ghostty is not in Debian repos yet"
    
    if ask "Build Ghostty from source? (requires Zig)"; then
        log "Installing Zig..."
        
        # Download Zig
        cd /tmp
        wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz
        tar -xf zig-linux-x86_64-0.11.0.tar.xz
        sudo mv zig-linux-x86_64-0.11.0 /opt/zig
        
        # Add to PATH
        export PATH="/opt/zig:$PATH"
        
        log "Cloning Ghostty..."
        cd /tmp
        git clone https://github.com/ghostty-org/ghostty
        cd ghostty
        
        log "Building Ghostty (this may take a while)..."
        zig build -Doptimize=ReleaseFast
        
        log "Installing Ghostty..."
        sudo cp zig-out/bin/ghostty /usr/local/bin/
        
        # Create config
        mkdir -p ~/.config/ghostty
        cat > ~/.config/ghostty/config << 'EOF'
font-family = Hack
font-size = 11

background-opacity = 0.95
theme = gruvbox-dark

cursor-style = block

# Keybindings
keybind = ctrl+shift+c=copy_to_clipboard
keybind = ctrl+shift+v=paste_from_clipboard
EOF
        
        log "Ghostty installed and configured ✓"
        log "Edit: ~/.config/ghostty/config"
    else
        warn "Skipping Ghostty installation"
    fi
}

update_xinitrc() {
    log "Would you like to change default terminal in .xinitrc?"
    
    echo "Current terminal: st"
    echo "Options:"
    echo "  1) Keep st (default)"
    echo "  2) Use Alacritty"
    echo "  3) Use Ghostty"
    
    read -p "Choose [1/2/3]: " choice
    
    case $choice in
        2)
            sed -i 's/st/alacritty/g' ~/.xinitrc
            log "Default terminal changed to Alacritty"
            ;;
        3)
            sed -i 's/st/ghostty/g' ~/.xinitrc
            log "Default terminal changed to Ghostty"
            ;;
        *)
            log "Keeping st as default"
            ;;
    esac
}

update_sxhkdrc() {
    if [ -f ~/.config/sxhkd/sxhkdrc ]; then
        log "Updating sxhkdrc..."
        
        echo "Which terminal for sxhkd?"
        echo "  1) st"
        echo "  2) alacritty"
        echo "  3) ghostty"
        
        read -p "Choose [1/2/3]: " choice
        
        case $choice in
            2)
                sed -i 's/super + Return.*/super + Return\n    alacritty/' ~/.config/sxhkd/sxhkdrc
                ;;
            3)
                sed -i 's/super + Return.*/super + Return\n    ghostty/' ~/.config/sxhkd/sxhkdrc
                ;;
            *)
                log "Keeping st"
                ;;
        esac
        
        # Reload sxhkd
        pkill -USR1 -x sxhkd 2>/dev/null || true
    fi
}

main() {
    echo "Terminal Alternatives Setup"
    echo "==========================="
    echo ""
    
    if ask "Install Alacritty?"; then
        install_alacritty
    fi
    
    if ask "Install Ghostty?"; then
        install_ghostty
    fi
    
    echo ""
    update_xinitrc
    update_sxhkdrc
    
    echo ""
    log "Terminal setup complete!"
    echo ""
    echo "To test terminals:"
    echo "  • alacritty"
    echo "  • ghostty"
    echo ""
}

main "$@"
