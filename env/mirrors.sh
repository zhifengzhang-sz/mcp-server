#!/usr/bin/env bash
# Session-Scoped Mirror Management for qi-v2-llm Python Server
# This file provides project-local mirror management that doesn't pollute user's global configuration
# 
# Usage: 
#   source env/mirrors.sh china    # Enable China mirrors for current session
#   source env/mirrors.sh global   # Enable global mirrors for current session  
#   source env/mirrors.sh show     # Show current mirror configuration
#
# Key Features:
# - Session-scoped only (no global pollution)
# - Project-contained (all config in this file)
# - User-friendly (works for any user, any environment)
# - Reproducible (same results everywhere)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${PURPLE}🔄 qi-v2-llm Mirror Manager${NC}"
    echo -e "${CYAN}Session-scoped, non-polluting mirror configuration${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Mirror configurations
setup_china_mirrors() {
    print_header
    print_info "Activating China mirrors for current session..."
    
    # UV/Python Package Mirrors
    export UV_CACHE_DIR="$HOME/.cache/uv"
    export UV_PYTHON_DOWNLOADS="automatic"
    export UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    export UV_EXTRA_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"
    export UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
    
    # Poetry/Pip mirrors (fallback compatibility)
    export PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    export PIP_EXTRA_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"
    export POETRY_REPOSITORIES_PYPI_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    
    # Nix Binary Cache Mirrors
    export NIX_CONFIG="experimental-features = nix-command flakes
substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
allow-unfree = true
max-jobs = auto
cores = 0"
    
    # Ollama Model Registry
    export OLLAMA_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
    
    # Additional China optimizations
    export HTTP_PROXY=""
    export HTTPS_PROXY=""
    export http_proxy=""
    export https_proxy=""
    
    print_success "China mirrors activated for this session!"
    echo ""
    print_info "Active configurations:"
    echo "  📦 Python/UV: ${UV_INDEX_URL}"
    echo "  🔧 Nix: Tsinghua + SJTU + USTC mirrors"
    echo "  🤖 Ollama: ${OLLAMA_REGISTRY}"
    echo ""
    print_info "Session-scoped only - no global pollution!"
}

setup_global_mirrors() {
    print_header
    print_info "Activating global mirrors for current session..."
    
    # UV/Python Package Mirrors (reset to defaults)
    export UV_CACHE_DIR="$HOME/.cache/uv"
    export UV_PYTHON_DOWNLOADS="automatic"
    unset UV_INDEX_URL 2>/dev/null || true
    unset UV_EXTRA_INDEX_URL 2>/dev/null || true
    unset UV_DEFAULT_INDEX 2>/dev/null || true
    
    # Poetry/Pip mirrors (reset to defaults)
    unset PIP_INDEX_URL 2>/dev/null || true
    unset PIP_EXTRA_INDEX_URL 2>/dev/null || true
    unset POETRY_REPOSITORIES_PYPI_URL 2>/dev/null || true
    
    # Nix Binary Cache Mirrors (reset to defaults)
    export NIX_CONFIG="experimental-features = nix-command flakes
substituters = https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
allow-unfree = true
max-jobs = auto
cores = 0"
    
    # Ollama Model Registry (reset to default)
    unset OLLAMA_REGISTRY 2>/dev/null || true
    
    print_success "Global mirrors activated for this session!"
    echo ""
    print_info "Active configurations:"
    echo "  📦 Python/UV: Default PyPI"
    echo "  🔧 Nix: cache.nixos.org"
    echo "  🤖 Ollama: Default registry"
    echo ""
    print_info "Session-scoped only - no global pollution!"
}

show_current_config() {
    print_header
    print_info "Current mirror configuration:"
    echo ""
    
    # UV/Python Configuration
    echo -e "${CYAN}📦 Python/UV Configuration:${NC}"
    if [[ -n "${UV_INDEX_URL:-}" ]]; then
        echo "  Index URL: ${UV_INDEX_URL}"
        echo "  Extra Index: ${UV_EXTRA_INDEX_URL:-none}"
        echo "  Mode: 🇨🇳 China mirrors"
    else
        echo "  Index URL: Default PyPI"
        echo "  Mode: 🌐 Global mirrors"
    fi
    echo ""
    
    # Nix Configuration  
    echo -e "${CYAN}🔧 Nix Configuration:${NC}"
    if [[ "${NIX_CONFIG:-}" == *"tsinghua"* ]]; then
        echo "  Substituters: China mirrors (Tsinghua + SJTU + USTC)"
        echo "  Mode: 🇨🇳 China mirrors"
    else
        echo "  Substituters: cache.nixos.org"
        echo "  Mode: 🌐 Global mirrors"
    fi
    echo ""
    
    # Ollama Configuration
    echo -e "${CYAN}🤖 Ollama Configuration:${NC}"
    if [[ -n "${OLLAMA_REGISTRY:-}" ]]; then
        echo "  Registry: ${OLLAMA_REGISTRY}"
        echo "  Mode: 🇨🇳 China mirror"
    else
        echo "  Registry: Default Ollama registry"
        echo "  Mode: 🌐 Global mirror"
    fi
    echo ""
    
    # Session info
    echo -e "${CYAN}🔄 Session Information:${NC}"
    echo "  Scope: Current terminal session only"
    echo "  Pollution: None (no global config modified)"
    echo "  Reset: Close terminal or source with different mode"
}

test_connectivity() {
    print_header
    print_info "Testing mirror connectivity..."
    echo ""
    
    # Test Python mirrors
    if [[ -n "${UV_INDEX_URL:-}" ]]; then
        print_info "Testing China PyPI mirror..."
        if curl -s --max-time 10 "${UV_INDEX_URL}" >/dev/null; then
            print_success "China PyPI mirror: ✅ Accessible"
        else
            print_error "China PyPI mirror: ❌ Not accessible"
        fi
    else
        print_info "Testing global PyPI..."
        if curl -s --max-time 10 "https://pypi.org/simple/" >/dev/null; then
            print_success "Global PyPI: ✅ Accessible"
        else
            print_error "Global PyPI: ❌ Not accessible"
        fi
    fi
    
    # Test Nix mirrors
    if [[ "${NIX_CONFIG:-}" == *"tsinghua"* ]]; then
        print_info "Testing China Nix mirror..."
        if curl -s --max-time 10 "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/nix-cache-info" >/dev/null; then
            print_success "China Nix mirror: ✅ Accessible"
        else
            print_error "China Nix mirror: ❌ Not accessible"
        fi
    else
        print_info "Testing global Nix cache..."
        if curl -s --max-time 10 "https://cache.nixos.org/nix-cache-info" >/dev/null; then
            print_success "Global Nix cache: ✅ Accessible"
        else
            print_error "Global Nix cache: ❌ Not accessible"
        fi
    fi
    
    echo ""
    print_info "Connectivity test complete!"
}

show_help() {
    print_header
    echo -e "${CYAN}Usage:${NC}"
    echo "  source env/mirrors.sh china     # Enable China mirrors"
    echo "  source env/mirrors.sh global    # Enable global mirrors"
    echo "  source env/mirrors.sh show      # Show current config"
    echo "  source env/mirrors.sh test      # Test connectivity"
    echo "  source env/mirrors.sh help      # Show this help"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  ✅ Session-scoped (no global pollution)"
    echo "  ✅ Project-contained (reproducible for all users)"
    echo "  ✅ Multi-tool support (UV, Nix, Ollama)"
    echo "  ✅ Easy switching between China and global mirrors"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  # Enable China mirrors and install dependencies"
    echo "  source env/mirrors.sh china"
    echo "  nix develop"
    echo "  uv sync"
    echo ""
    echo "  # Switch to global mirrors for deployment"
    echo "  source env/mirrors.sh global"
    echo "  uv run python -m mcp_server.main_fastmcp"
    echo ""
    echo -e "${CYAN}Integration with development workflow:${NC}"
    echo "  # Quick setup for China users"
    echo "  source env/mirrors.sh china && nix develop && uv sync"
    echo ""
    echo "  # Quick setup for global users"
    echo "  source env/mirrors.sh global && nix develop && uv sync"
}

# Main logic
case "${1:-help}" in
    "china"|"cn")
        setup_china_mirrors
        ;;
    "global"|"international"|"intl")
        setup_global_mirrors
        ;;
    "show"|"status"|"check")
        show_current_config
        ;;
    "test"|"connectivity")
        test_connectivity
        ;;
    "help"|"-h"|"--help"|*)
        show_help
        ;;
esac
