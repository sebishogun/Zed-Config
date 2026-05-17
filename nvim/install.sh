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
    local cfg="$HOME/.config/nvim/lua/plugins/99.lua"
    [[ -f "$cfg" ]] && grep -q 'dir = "~/neovim-configs/config-workspace/99"' "$cfg"
}

has_required_deps() {
    local missing=0
    command -v git &> /dev/null || missing=1
    command -v curl &> /dev/null || missing=1
    command -v unzip &> /dev/null || missing=1
    command -v rg &> /dev/null || missing=1
    command -v jq &> /dev/null || missing=1
    command -v luacheck &> /dev/null || missing=1
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
    local parsers=(rust go zig java elixir cpp ruby)
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
    local plugin_dir="$HOME/neovim-configs/config-workspace/99"
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

    if [[ -d "$plugin_dir" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo "- Would pull latest in $plugin_dir"
        elif git -C "$plugin_dir" rev-parse --is-inside-work-tree &> /dev/null; then
            if [[ -n "$(git -C "$plugin_dir" status --porcelain 2>/dev/null)" ]]; then
                echo "- 99 plugin repo has local changes; would skip pull"
            else
                echo "- 99 plugin repo exists; would check remote and pull only if behind"
            fi
        else
            echo "- 99 plugin directory exists but is not git; would leave as-is"
        fi
    else
        echo "- Would clone 99 plugin fork to $plugin_dir"
    fi

    local has_opencode=false has_claude=false has_copilot=false has_gemini=false has_codex=false
    command -v opencode &> /dev/null && has_opencode=true
    command -v claude &> /dev/null && has_claude=true
    command -v copilot &> /dev/null && has_copilot=true
    command -v gemini &> /dev/null && has_gemini=true
    command -v codex &> /dev/null && has_codex=true

    echo "- AI CLIs detected: opencode=$has_opencode claude=$has_claude copilot=$has_copilot gemini=$has_gemini codex=$has_codex"
    if $has_opencode; then
        echo "- Would ensure OpenCode neovim agent config is present"
    fi

    if [[ "$FORCE" == "true" || "$parsers_ok" == "false" || "$managed" == "false" || ! -d "$plugin_dir" ]]; then
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
    case "$PKG_MGR" in
        apt)
            sudo apt-get update && sudo apt-get install -y git curl unzip ripgrep fd-find nodejs npm python3 python3-pip python3-venv build-essential jq grep luarocks lua-check
            ;;
        dnf)
            sudo dnf install -y git curl unzip ripgrep fd-find nodejs npm python3 python3-pip gcc gcc-c++ jq grep luarocks
            ;;
        pacman)
            sudo pacman -Syu --noconfirm git curl unzip ripgrep fd nodejs npm python python-pip base-devel jq grep luarocks luacheck
            ;;
        brew)
            brew install git curl unzip ripgrep fd node python jq grep luarocks luacheck
            ;;
        *)
            echo -e "${RED}Unknown package manager. Install git, ripgrep, fd, node, python, jq, grep, luarocks, and luacheck manually.${NC}"
            ;;
    esac

    if ! command -v luacheck &> /dev/null && command -v luarocks &> /dev/null; then
        luarocks --lua-version=5.4 install --local luacheck || true
        export PATH="$HOME/.luarocks/bin:$PATH"
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

# Install 99 AI agent plugin from fork
install_99_plugin() {
    echo -e "${YELLOW}Installing 99 AI agent plugin...${NC}"
    PLUGIN_DIR="$HOME/neovim-configs/config-workspace/99"
    
    if [[ -d "$PLUGIN_DIR" ]]; then
        echo -e "${GREEN}99 plugin directory exists${NC}"

        if [[ "$FORCE" == "true" ]]; then
            echo -e "${YELLOW}--force enabled, pulling latest...${NC}"
            cd "$PLUGIN_DIR" && git pull origin master
            NEED_PLUGIN_SYNC=true
        elif git -C "$PLUGIN_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
            if [[ -n "$(git -C "$PLUGIN_DIR" status --porcelain 2>/dev/null)" ]]; then
                echo -e "${YELLOW}99 repo has local changes, skipping pull to preserve worktree${NC}"
            else
                git -C "$PLUGIN_DIR" fetch origin master --quiet || true
                LOCAL_SHA=$(git -C "$PLUGIN_DIR" rev-parse HEAD 2>/dev/null || echo "")
                REMOTE_SHA=$(git -C "$PLUGIN_DIR" rev-parse origin/master 2>/dev/null || echo "")
                if [[ -n "$LOCAL_SHA" && -n "$REMOTE_SHA" && "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
                    echo -e "${YELLOW}99 plugin update available, pulling latest...${NC}"
                    git -C "$PLUGIN_DIR" pull origin master
                    NEED_PLUGIN_SYNC=true
                else
                    echo -e "${GREEN}99 plugin already up to date${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}$PLUGIN_DIR exists but is not a git repo, leaving as-is${NC}"
        fi
    else
        echo -e "${YELLOW}Cloning 99 plugin fork...${NC}"
        mkdir -p "$HOME/neovim-configs/config-workspace"
        git clone https://github.com/sebishogun/99.git "$PLUGIN_DIR"
        NEED_PLUGIN_SYNC=true
    fi
    
    # Setup AI CLI providers
    setup_ai_providers
}

# Detect and setup AI CLI providers for 99 plugin
setup_ai_providers() {
    echo ""
    echo -e "${YELLOW}=== AI CLI Provider Setup ===${NC}"
    
    # Detect installed providers
    HAS_OPENCODE=false
    HAS_CLAUDE=false
    HAS_COPILOT=false
    HAS_GEMINI=false
    HAS_CODEX=false
    
    if command -v opencode &> /dev/null; then
        HAS_OPENCODE=true
        echo -e "${GREEN}✓ OpenCode CLI found${NC}"
    else
        echo -e "${RED}✗ OpenCode CLI not found${NC}"
    fi
    
    if command -v claude &> /dev/null; then
        HAS_CLAUDE=true
        echo -e "${GREEN}✓ Claude Code CLI found${NC}"
    else
        echo -e "${RED}✗ Claude Code CLI not found${NC}"
    fi
    
    if command -v copilot &> /dev/null; then
        HAS_COPILOT=true
        echo -e "${GREEN}✓ GitHub Copilot CLI found${NC}"
    else
        echo -e "${RED}✗ GitHub Copilot CLI not found${NC}"
    fi
    
    if command -v gemini &> /dev/null; then
        HAS_GEMINI=true
        echo -e "${GREEN}✓ Gemini CLI found${NC}"
    else
        echo -e "${RED}✗ Gemini CLI not found${NC}"
    fi
    
    if command -v codex &> /dev/null; then
        HAS_CODEX=true
        echo -e "${GREEN}✓ Codex CLI found${NC}"
    else
        echo -e "${RED}✗ Codex CLI not found${NC}"
    fi
    
    echo ""
    
    # If OpenCode is installed, configure it
    if $HAS_OPENCODE; then
        configure_opencode_agent
        echo -e "${GREEN}Configured OpenCode as default provider${NC}"
    fi
    
    # Show available provider switch commands
    echo -e "${YELLOW}Available provider commands in neovim (Tab completion supported):${NC}"
    echo "  :NNProvider <tab>  - Switch provider with completion"
    echo "  :NNModel <tab>     - Change model with completion"
    echo "  :NNStatus          - Show current provider status"
    echo ""
    echo -e "${YELLOW}Quick switch commands:${NC}"
    $HAS_OPENCODE && echo "  :NNOpenCode  - Anthropic Claude via OpenCode"
    $HAS_OPENCODE && echo "  :NNOpenAI    - OpenAI models via OpenCode"
    $HAS_CLAUDE && echo "  :NNClaude    - Claude Code CLI"
    $HAS_COPILOT && echo "  :NNCopilot   - GitHub Copilot CLI"
    $HAS_GEMINI && echo "  :NNGemini    - Google Gemini CLI"
    $HAS_CODEX && echo "  :NNCodex     - OpenAI Codex CLI"
    
    # Offer to install missing providers
    if ! $HAS_OPENCODE || ! $HAS_CLAUDE || ! $HAS_COPILOT; then
        echo ""
        read -p "Would you like to install missing AI CLI providers? [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_ai_providers "$HAS_OPENCODE" "$HAS_CLAUDE" "$HAS_COPILOT"
        fi
    fi
    
    # Warn if still no providers installed
    if ! $HAS_OPENCODE && ! $HAS_CLAUDE && ! $HAS_COPILOT && ! $HAS_GEMINI && ! $HAS_CODEX; then
        # Re-check after potential installation
        command -v opencode &> /dev/null && HAS_OPENCODE=true
        command -v claude &> /dev/null && HAS_CLAUDE=true
        command -v copilot &> /dev/null && HAS_COPILOT=true
        
        if ! $HAS_OPENCODE && ! $HAS_CLAUDE && ! $HAS_COPILOT && ! $HAS_GEMINI && ! $HAS_CODEX; then
            echo ""
            echo -e "${YELLOW}Warning: No AI CLI providers installed. 99 plugin won't work without one.${NC}"
            echo -e "${YELLOW}Install options:${NC}"
            echo "  OpenCode:  curl -fsSL https://opencode.ai/install | bash"
            echo "  Claude:    npm install -g @anthropic-ai/claude-code"
            echo "  Copilot:   curl -fsSL https://gh.io/copilot-install | bash"
            echo "  Gemini:    npm install -g @google/gemini-cli"
            echo "  Codex:     npm install -g @openai/codex"
        fi
    fi
}

# Install AI CLI providers
install_ai_providers() {
    local has_opencode=$1
    local has_claude=$2
    local has_copilot=$3
    
    echo ""
    
    # Install OpenCode
    if [[ "$has_opencode" == "false" ]]; then
        echo ""
        read -p "Install OpenCode CLI? (recommended) [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installing OpenCode CLI...${NC}"
            if curl -fsSL https://opencode.ai/install | bash; then
                echo -e "${GREEN}OpenCode CLI installed!${NC}"
                # Refresh PATH
                export PATH="$HOME/.opencode/bin:$PATH"
                if command -v opencode &> /dev/null; then
                    configure_opencode_agent
                    echo -e "${GREEN}OpenCode configured as default provider${NC}"
                fi
            else
                echo -e "${RED}Failed to install OpenCode CLI${NC}"
            fi
        fi
    fi
    
    # Install Claude Code
    if [[ "$has_claude" == "false" ]]; then
        echo ""
        read -p "Install Claude Code CLI? [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installing Claude Code CLI...${NC}"
            if command -v npm &> /dev/null; then
                if npm install -g @anthropic-ai/claude-code; then
                    echo -e "${GREEN}Claude Code CLI installed!${NC}"
                    echo -e "${YELLOW}Note: Run 'claude' once to authenticate with Anthropic${NC}"
                else
                    echo -e "${RED}Failed to install Claude Code CLI${NC}"
                fi
            else
                echo -e "${RED}npm not found. Install Node.js first.${NC}"
            fi
        fi
    fi
    
    # Install GitHub Copilot CLI
    if [[ "$has_copilot" == "false" ]]; then
        echo ""
        read -p "Install GitHub Copilot CLI? [Y/n] " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installing GitHub Copilot CLI...${NC}"
            if curl -fsSL https://gh.io/copilot-install | bash; then
                echo -e "${GREEN}GitHub Copilot CLI installed!${NC}"
                echo -e "${YELLOW}Note: Run 'copilot' once to authenticate and select account${NC}"
            else
                echo -e "${RED}Failed to install GitHub Copilot CLI${NC}"
            fi
        fi
    fi
}

# Configure OpenCode with neovim agent for 99 plugin
configure_opencode_agent() {
    OPENCODE_CONFIG="$HOME/.config/opencode/config.json"
    mkdir -p "$HOME/.config/opencode"
    
    # Neovim agent config - allows external file writes for 99 plugin temp files
    NEOVIM_AGENT='{
  "neovim": {
    "description": "Agent for neovim 99 plugin - allows all file writes",
    "mode": "all",
    "permission": {
      "external_directory": "allow",
      "read": "allow",
      "edit": "allow",
      "bash": "allow",
      "glob": "allow",
      "grep": "allow",
      "list": "allow",
      "question": "deny",
      "doom_loop": "deny"
    }
  }
}'

    if [[ -f "$OPENCODE_CONFIG" ]]; then
        # Check if neovim agent already configured
        if grep -q '"neovim"' "$OPENCODE_CONFIG" 2>/dev/null; then
            echo -e "${GREEN}OpenCode neovim agent already configured${NC}"
            return
        fi
        
        # Add neovim agent to existing config using jq if available
        if command -v jq &> /dev/null; then
            # Merge agent config into existing config
            jq --argjson agent "$NEOVIM_AGENT" '.agent = (.agent // {}) + $agent' "$OPENCODE_CONFIG" > "$OPENCODE_CONFIG.tmp" && mv "$OPENCODE_CONFIG.tmp" "$OPENCODE_CONFIG"
            echo -e "${GREEN}Added neovim agent to OpenCode config${NC}"
        else
            echo -e "${YELLOW}jq not found - please manually add neovim agent to $OPENCODE_CONFIG${NC}"
            echo -e "${YELLOW}See: https://github.com/sebishogun/99#opencode-setup${NC}"
        fi
    else
        # Create new config with neovim agent
        cat > "$OPENCODE_CONFIG" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "neovim": {
      "description": "Agent for neovim 99 plugin - allows all file writes",
      "mode": "all",
      "permission": {
        "external_directory": "allow",
        "read": "allow",
        "edit": "allow",
        "bash": "allow",
        "glob": "allow",
        "grep": "allow",
        "list": "allow",
        "question": "deny",
        "doom_loop": "deny"
      }
    }
  }
}
EOF
        echo -e "${GREEN}Created OpenCode config with neovim agent${NC}"
    fi
}

# Install treesitter parsers required by 99 plugin
install_treesitter_parsers() {
    echo -e "${YELLOW}Installing treesitter parsers for 99 plugin...${NC}"

    if [[ "$FORCE" == "false" ]] && all_required_parsers_installed; then
        echo -e "${GREEN}Required treesitter parsers already installed, skipping${NC}"
        return
    fi
    
    # Parsers needed for 99 plugin language support
    # These are required for the 99 AI plugin to find functions via treesitter
    PARSERS="rust go zig java elixir cpp ruby"
    
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
    install_99_plugin
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
    echo ""
    echo "99 AI Agent (supports OpenCode/Claude/Copilot/Gemini/Codex CLI):"
    echo "  <leader>9f  = Fill in function (AI generates body)"
    echo "  <leader>9F  = Fill in function with prompt"
    echo "  <leader>9v  = Process visual selection"
    echo "  <leader>9V  = Process selection with prompt"
    echo "  <leader>9s  = Stop all AI requests"
    echo "  <leader>9l  = View logs"
    echo ""
    echo "99 Provider/Model Commands (Tab completion supported):"
    echo "  :NNProvider <tab>  = Switch provider (opencode/claude/copilot/gemini/codex)"
    echo "  :NNModel <tab>     = Set model with completion"
    echo "  :NNStatus          = Show current provider and model"
    echo "  :NNOpenCode        = Quick switch to OpenCode"
    echo "  :NNClaude          = Quick switch to Claude CLI"
    echo "  :NNCopilot         = Quick switch to Copilot CLI"
    echo "  :NNGemini          = Quick switch to Gemini CLI"
    echo "  :NNCodex           = Quick switch to Codex CLI"
}

main "$@"
