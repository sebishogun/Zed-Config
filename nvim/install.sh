#!/bin/bash
set -e

echo "=== LazyVim Custom Config Installer ==="

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Platform detection
OS="$(uname -s)"
ARCH="$(uname -m)"
OS_FAMILY=""
DISTRO="unknown"
PKG_MGR=""
GREP_BIN="grep"
FORCE=false
DRY_RUN=false
NEED_PLUGIN_SYNC=false

if [[ -d "$HOME/.luarocks/bin" ]]; then
    export PATH="$HOME/.luarocks/bin:$PATH"
fi

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

detect_platform() {
    case "$OS" in
        Linux)
            OS_FAMILY="linux"
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                DISTRO="${ID:-unknown}"
            fi

            if command -v apt-get &> /dev/null; then
                PKG_MGR="apt"
            elif command -v dnf &> /dev/null; then
                PKG_MGR="dnf"
            elif command -v pacman &> /dev/null; then
                PKG_MGR="pacman"
            else
                PKG_MGR="unknown"
            fi
            ;;
        Darwin)
            OS_FAMILY="macos"
            DISTRO="macos"
            if command -v brew &> /dev/null; then
                PKG_MGR="brew"
            else
                PKG_MGR="unknown"
            fi

            if command -v ggrep &> /dev/null; then
                GREP_BIN="ggrep"
            fi
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            echo -e "${YELLOW}This installer currently supports Linux and macOS only.${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Detected platform: OS=$OS_FAMILY distro=$DISTRO pkg=$PKG_MGR arch=$ARCH${NC}"
}

is_managed_config() {
    [[ -f "$HOME/.config/nvim/lua/plugins/dap.lua" && -f "$HOME/.config/nvim/lua/plugins/lsp.lua" ]]
}

has_required_deps() {
    local missing=0
    command -v git &> /dev/null || missing=1
    command -v curl &> /dev/null || missing=1
    command -v unzip &> /dev/null || missing=1
    command -v rg &> /dev/null || missing=1
    command -v jq &> /dev/null || missing=1
    command -v luacheck &> /dev/null || missing=1
    command -v magick &> /dev/null || missing=1
    command -v dot &> /dev/null || missing=1
    command -v mmdc &> /dev/null || missing=1
    if ! command -v fd &> /dev/null && ! command -v fdfind &> /dev/null; then
        missing=1
    fi
    return $missing
}

nvim_meets_requirement() {
    if ! command -v nvim &> /dev/null; then
        return 1
    fi
    local ver
    ver=$(nvim --version | head -1 | "$GREP_BIN" -oP '\d+\.\d+')
    [[ -n "$ver" ]] || return 1
    local min_ver="0.10"
    [[ "$(printf '%s\n%s\n' "$min_ver" "$ver" | sort -V | tail -n1)" == "$ver" ]]
}

all_required_parsers_installed() {
    local parsers=(rust go zig java elixir cpp ruby markdown markdown_inline mermaid dot latex)
    local p
    for p in "${parsers[@]}"; do
        if [[ ! -f "$HOME/.local/share/nvim/site/parser/${p}.so" ]] && [[ ! -f "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser/${p}.so" ]]; then
            return 1
        fi
    done
    return 0
}

has_nerd_font() {
    command -v fc-list &> /dev/null && fc-list 2>/dev/null | grep -qi "nerd"
}

print_dry_run_plan() {
    local cfg_dir="$HOME/.config/nvim"
    local managed=false
    local deps_ok=false
    local nvim_ok=false
    local parsers_ok=false
    local font_ok=false

    is_managed_config && managed=true
    has_required_deps && deps_ok=true
    nvim_meets_requirement && nvim_ok=true
    all_required_parsers_installed && parsers_ok=true
    has_nerd_font && font_ok=true

    echo -e "${YELLOW}=== Dry Run: No changes will be made ===${NC}"
    echo -e "${GREEN}Mode:${NC} force=$FORCE dry-run=$DRY_RUN"
    echo ""
    echo -e "${YELLOW}System checks${NC}"
    echo "- Nerd Font: $($font_ok && echo installed || echo missing)"
    echo "- Core dependencies: $($deps_ok && echo installed || echo missing)"
    echo "- Neovim >= 0.10: $($nvim_ok && echo installed || echo missing/outdated)"
    echo "- Managed nvim config: $($managed && echo yes || echo no)"
    echo "- Required treesitter parsers: $($parsers_ok && echo installed || echo missing)"
    echo ""

    echo -e "${YELLOW}Planned actions${NC}"
    if ! $font_ok; then
        echo "- Would prompt to install JetBrainsMono Nerd Font"
    else
        echo "- Nerd Font step: no changes"
    fi

    if [[ "$FORCE" == "true" || "$deps_ok" == "false" ]]; then
        echo "- Would prompt to install dependencies via $PKG_MGR"
    else
        echo "- Dependency step: no changes"
    fi

    if [[ "$FORCE" == "true" || "$nvim_ok" == "false" ]]; then
        echo "- Would prompt to install/update Neovim"
    else
        echo "- Neovim step: no changes"
    fi

    if [[ "$FORCE" == "true" || "$managed" == "false" ]]; then
        if [[ -d "$cfg_dir" ]]; then
            echo "- Would back up existing $cfg_dir and reset Neovim cache/state dirs"
        fi
        echo "- Would install config into $cfg_dir"
    else
        echo "- Config install step: no changes"
    fi

    if [[ "$FORCE" == "true" || "$parsers_ok" == "false" || "$managed" == "false" ]]; then
        echo "- Would run Lazy sync and treesitter parser install"
    else
        echo "- Plugin sync/parsers step: no changes"
    fi

    echo ""
    echo -e "${GREEN}Tip:${NC} Run ./install.sh to apply, or ./install.sh --force to force refresh"
}

# Check and install Nerd Font (required for icons)
check_nerd_font() {
    echo -e "${YELLOW}Checking for Nerd Font...${NC}"
    
    # Check if any Nerd Font is installed
    if fc-list 2>/dev/null | grep -qi "nerd"; then
        NERD_FONT=$(fc-list 2>/dev/null | grep -i "nerd" | head -1 | cut -d: -f2 | xargs)
        echo -e "${GREEN}Nerd Font found: $NERD_FONT${NC}"
        return 0
    fi
    
    echo -e "${RED}No Nerd Font detected!${NC}"
    echo -e "${YELLOW}Nerd Fonts are required for icons in neo-tree, statusline, etc.${NC}"
    
    read -p "Install JetBrainsMono Nerd Font? [Y/n] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        install_nerd_font
    else
        echo -e "${YELLOW}Warning: Icons may not display correctly without a Nerd Font.${NC}"
        echo -e "${YELLOW}Install manually: https://www.nerdfonts.com/${NC}"
        echo -e "${YELLOW}Then configure your terminal to use the Nerd Font.${NC}"
    fi
}

install_nerd_font() {
    echo -e "${YELLOW}Installing JetBrainsMono Nerd Font...${NC}"
    
    FONT_DIR=""
    if [[ "$OS" == "Linux" ]]; then
        FONT_DIR="$HOME/.local/share/fonts"
    elif [[ "$OS" == "Darwin" ]]; then
        FONT_DIR="$HOME/Library/Fonts"
    fi
    
    mkdir -p "$FONT_DIR"
    
    # Download and install JetBrainsMono Nerd Font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    TEMP_DIR=$(mktemp -d)
    
    if curl -fsSL "$FONT_URL" -o "$TEMP_DIR/JetBrainsMono.zip"; then
        unzip -q "$TEMP_DIR/JetBrainsMono.zip" -d "$TEMP_DIR/fonts"
        cp "$TEMP_DIR/fonts"/*.ttf "$FONT_DIR/" 2>/dev/null || true
        rm -rf "$TEMP_DIR"
        
        # Refresh font cache on Linux
        if [[ "$OS" == "Linux" ]] && command -v fc-cache &> /dev/null; then
            fc-cache -f
        fi
        
        echo -e "${GREEN}JetBrainsMono Nerd Font installed!${NC}"
        echo -e "${YELLOW}IMPORTANT: Configure your terminal to use 'JetBrainsMono Nerd Font'${NC}"
        echo -e "${YELLOW}Terminal settings > Font > JetBrainsMono Nerd Font${NC}"
    else
        echo -e "${RED}Failed to download Nerd Font${NC}"
        echo -e "${YELLOW}Install manually: https://www.nerdfonts.com/${NC}"
    fi
}

# Install dependencies
install_deps() {
    echo -e "${YELLOW}Installing dependencies...${NC}"

    # Prefer mise for CLI tools & runtimes when available
    if command -v mise &> /dev/null; then
        echo -e "${GREEN}Using mise for CLI/diagram tools...${NC}"
        command -v node &> /dev/null || mise use -g node@latest || true
        command -v python3 &> /dev/null || mise use -g python@latest || true
        command -v rg &> /dev/null || mise use -g ripgrep@latest || true
        if ! command -v fd &> /dev/null && ! command -v fdfind &> /dev/null; then
            mise use -g fd@latest || true
        fi
        command -v jq &> /dev/null || mise use -g jq@latest || true
        command -v lazygit &> /dev/null || mise use -g lazygit@latest || true
        command -v tree-sitter &> /dev/null || mise use -g tree-sitter@latest || true
        command -v mmdc &> /dev/null || mise use -g 'npm:@mermaid-js/mermaid-cli[trust_policy_excludes=chromium-bidi,allow_builds=puppeteer]@latest' || true
    fi

    case "$PKG_MGR" in
        apt)
            sudo apt-get update && sudo apt-get install -y git curl unzip ripgrep fd-find python3 python3-pip python3-venv build-essential jq grep luarocks lua-check imagemagick graphviz
            ;;
        dnf)
            sudo dnf install -y git curl unzip ripgrep fd-find python3 python3-pip gcc gcc-c++ jq grep luarocks ImageMagick graphviz
            ;;
        pacman)
            sudo pacman -Syu --noconfirm --needed git curl unzip ripgrep fd base-devel jq grep luarocks luacheck imagemagick graphviz
            ;;
        brew)
            brew install git curl unzip ripgrep fd jq grep luarocks luacheck imagemagick graphviz
            ;;
        *)
            echo -e "${RED}Unknown package manager. Install git, ripgrep, fd, node, python, jq, grep, luarocks, luacheck, imagemagick, graphviz, and mmdc manually.${NC}"
            ;;
    esac

    if ! command -v luacheck &> /dev/null && command -v luarocks &> /dev/null; then
        luarocks --lua-version=5.4 install --local luacheck || true
        export PATH="$HOME/.luarocks/bin:$PATH"
    fi

    if ! command -v mmdc &> /dev/null; then
        if command -v mise &> /dev/null; then
            mise use -g 'npm:@mermaid-js/mermaid-cli[trust_policy_excludes=chromium-bidi,allow_builds=puppeteer]@latest' || true
        elif command -v npm &> /dev/null; then
            echo -e "${YELLOW}Installing @mermaid-js/mermaid-cli (mmdc) for Markdown diagram rendering...${NC}"
            npm install -g @mermaid-js/mermaid-cli || true
        elif [[ "$PKG_MGR" == "brew" ]]; then
            brew install mermaid-cli || true
        fi
    fi
}

# Install Neovim
install_neovim() {
    echo -e "${YELLOW}Installing Neovim...${NC}"
    if command -v nvim &> /dev/null; then
        NVIM_VER=$(nvim --version | head -1 | "$GREP_BIN" -oP '\d+\.\d+')
        if [[ -n "$NVIM_VER" ]] && [[ "$(printf '%s\n%s\n' "0.10" "$NVIM_VER" | sort -V | tail -n1)" == "$NVIM_VER" ]]; then
            echo -e "${GREEN}Neovim $NVIM_VER already installed${NC}"
            return
        fi
    fi

    if command -v mise &> /dev/null; then
        echo -e "${GREEN}Installing Neovim via mise...${NC}"
        mise use -g neovim@latest && return
    fi
    
    if [[ "$OS_FAMILY" == "linux" ]]; then
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
        sudo rm -rf /opt/nvim && sudo tar -C /opt -xzf nvim-linux64.tar.gz
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
        rm nvim-linux64.tar.gz
    elif [[ "$OS_FAMILY" == "macos" ]]; then
        if command -v brew &> /dev/null; then
            brew install neovim
        else
            echo -e "${RED}Homebrew not found. Install Homebrew first: https://brew.sh${NC}"
            return 1
        fi
    fi
    echo -e "${GREEN}Neovim installed: $(nvim --version | head -1)${NC}"
}

# Backup existing config
backup_config() {
    if [[ "$FORCE" == "false" ]] && is_managed_config; then
        echo -e "${GREEN}Managed Neovim config already installed, skipping backup/reset${NC}"
        return
    fi

    if [[ -d "$HOME/.config/nvim" ]]; then
        BACKUP="$HOME/.config/nvim.backup.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}Backing up existing config to $BACKUP${NC}"
        mv "$HOME/.config/nvim" "$BACKUP"
    fi
    rm -rf "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim" 2>/dev/null || true
}

# Install config
install_config() {
    echo -e "${YELLOW}Installing config...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ "$FORCE" == "false" ]] && is_managed_config; then
        echo -e "${GREEN}Config already installed and managed by this setup, skipping copy${NC}"
        return
    fi

    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR" "$HOME/.config/nvim"
    rm -f "$HOME/.config/nvim/install.sh" "$HOME/.config/nvim/uninstall.sh" "$HOME/.config/nvim/README.md" "$HOME/.config/nvim/.git" 2>/dev/null || true
    rm -rf "$HOME/.config/nvim/.git" 2>/dev/null || true
    NEED_PLUGIN_SYNC=true
}

# Install treesitter parsers
install_treesitter_parsers() {
    echo -e "${YELLOW}Installing treesitter parsers...${NC}"

    if [[ "$FORCE" == "false" ]] && all_required_parsers_installed; then
        echo -e "${GREEN}Required treesitter parsers already installed, skipping${NC}"
        return
    fi
    
    PARSERS="rust go zig java elixir cpp ruby markdown markdown_inline mermaid dot latex typst scss svelte vue"
    
    # Install parsers with TSInstall! (the ! makes it synchronous)
    # Use sleep to ensure async compilation completes before quitting
    echo -e "${YELLOW}This may take 1-2 minutes...${NC}"
    nvim --headless -c "TSInstall! $PARSERS" -c "sleep 45" -c "qa" 2>&1 | grep -E "(Installing|Compiling|Language installed|Installed)" || true
    
    # Verify installation
    INSTALLED=$(ls ~/.local/share/nvim/site/parser/*.so 2>/dev/null | wc -l)
    echo -e "${GREEN}Treesitter parsers installed! ($INSTALLED parsers available)${NC}"
}

# Sync plugins
sync_plugins() {
    if [[ "$FORCE" == "false" ]] && [[ "$NEED_PLUGIN_SYNC" == "false" ]] && all_required_parsers_installed; then
        echo -e "${GREEN}Plugins and required parsers already installed, skipping sync${NC}"
        return
    fi

    echo -e "${YELLOW}Installing plugins (this may take a minute)...${NC}"
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || nvim --headless -c "lua require('lazy').sync()" -c "qa" 2>/dev/null || true
    echo -e "${GREEN}Plugins installed!${NC}"
    
    # Install treesitter parsers after plugins are synced
    install_treesitter_parsers
}

# Main
main() {
    echo ""
    detect_platform
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run_plan
        return
    fi
    
    # Check Nerd Font first (required for icons)
    check_nerd_font
    echo ""
    
    if [[ "$FORCE" == "false" ]] && has_required_deps; then
        echo -e "${GREEN}Core dependencies already installed, skipping dependency install${NC}"
    else
        read -p "Install system dependencies? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] && install_deps
    fi

    if [[ "$FORCE" == "false" ]] && nvim_meets_requirement; then
        echo -e "${GREEN}Neovim requirement already satisfied, skipping Neovim install${NC}"
    else
        read -p "Install/Update Neovim? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] && install_neovim
    fi
    
    backup_config
    install_config
    sync_plugins
    
    echo ""
    echo -e "${GREEN}=== Installation Complete! ===${NC}"
    echo "Run 'nvim' to start. First launch will install remaining plugins."
    echo ""
    echo "Quick tips:"
    echo "  Space       = Leader key"
    echo "  <leader>e   = File explorer"
    echo "  <leader>ff  = Find files"
    echo "  <leader>fg  = Live grep"
    echo ""
    echo "Debugging (all languages):"
    echo "  <leader>db  = Toggle breakpoint"
    echo "  <leader>dc  = Start/continue debug"
    echo "  <leader>di  = Step into"
    echo "  <leader>do  = Step over"
    echo "  <leader>dt  = Terminate"
    echo ""
    echo "Rust (rustaceanvim - in .rs files):"
    echo "  <leader>rr  = Run at cursor"
    echo "  <leader>rd  = Debug at cursor"
    echo "  <leader>rt  = Test at cursor"
    echo "  <leader>rm  = Expand macro"
    echo "  <leader>re  = Explain error"
    echo "  <leader>rc  = Open Cargo.toml"
}

main "$@"
