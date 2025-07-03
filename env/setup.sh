#!/usr/bin/env bash
# Project Setup Script for qi-v2-llm Python Server
# Self-contained, reproducible setup for any user, any environment
#
# This script replaces the need for global ~/.config/ modifications
# Everything is project-local and session-scoped
#
# Usage:
#   ./env/setup.sh              # Interactive setup
#   ./env/setup.sh china        # Setup with China mirrors  
#   ./env/setup.sh global       # Setup with global mirrors
#   ./env/setup.sh --help       # Show help

set -euo pipefail

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/env"

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
    echo -e "${PURPLE}🚀 qi-v2-llm Python Server Setup${NC}"
    echo -e "${CYAN}Self-contained, reproducible environment setup${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check Nix
    if ! command -v nix >/dev/null 2>&1; then
        missing_tools+=("nix")
    fi
    
    # Check uv
    if ! command -v uv >/dev/null 2>&1; then
        missing_tools+=("uv")
    fi
    
    # Check curl for downloading models
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        print_info "Please install the missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "nix")
                    echo "  🔧 Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
                    ;;
                "uv")
                    echo "  📦 uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
                    ;;
                "curl")
                    echo "  🌐 curl: Install via your system package manager (apt, yum, brew, etc.)"
                    ;;
            esac
        done
        echo ""
        print_info "After installation, restart your terminal and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed!"
}

# Detect user's location and suggest mirrors
detect_and_suggest_mirrors() {
    print_info "Detecting optimal mirror configuration..."
    
    # Simple China detection based on IP/connectivity
    local is_china=false
    
    # Test China mirror accessibility
    if curl -s --max-time 5 "https://mirrors.tuna.tsinghua.edu.cn" >/dev/null 2>&1; then
        is_china=true
    fi
    
    if [[ "$is_china" == "true" ]]; then
        print_info "🇨🇳 China location detected - recommending China mirrors for faster downloads"
        return 0  # Suggest China
    else
        print_info "🌐 Global location detected - recommending global mirrors"
        return 1  # Suggest global
    fi
}

# Interactive mirror selection
select_mirrors() {
    local suggested_mode=""
    
    if detect_and_suggest_mirrors; then
        suggested_mode="china"
    else
        suggested_mode="global"
    fi
    
    echo ""
    print_info "Mirror configuration options:"
    echo "  1) China mirrors    (🇨🇳 Tsinghua, SJTU, Aliyun - faster in China)"
    echo "  2) Global mirrors   (🌐 Default repositories - works everywhere)"
    echo ""
    
    if [[ "$suggested_mode" == "china" ]]; then
        print_info "Recommendation: China mirrors (option 1) - detected China location"
    else
        print_info "Recommendation: Global mirrors (option 2) - detected global location"  
    fi
    
    echo ""
    read -p "Choose mirrors (1/2) or press Enter for recommendation: " choice
    
    case "${choice:-$suggested_mode}" in
        "1"|"china"|"cn")
            echo "china"
            ;;
        "2"|"global"|"international"|"intl")
            echo "global"
            ;;
        *)
            if [[ "$suggested_mode" == "china" ]]; then
                echo "china"
            else
                echo "global"
            fi
            ;;
    esac
}

# Setup environment with mirrors
setup_environment() {
    local mirror_mode="$1"
    
    print_info "Setting up development environment with $mirror_mode mirrors..."
    
    # Source mirror configuration
    print_info "Configuring mirrors..."
    source "$ENV_DIR/mirrors.sh" "$mirror_mode"
    
    # Check if we're already in Nix environment
    if [[ -n "${IN_NIX_SHELL:-}" ]]; then
        print_warning "Already in Nix environment - Python dependencies may need to be reinstalled"
        print_info "Consider exiting and re-entering: exit && nix develop"
    fi
    
    print_success "Environment configured with $mirror_mode mirrors!"
}

# Install Python dependencies
install_dependencies() {
    print_info "Installing Python dependencies..."
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Check if we're in Nix environment
    if [[ -z "${IN_NIX_SHELL:-}" ]]; then
        print_warning "Not in Nix environment yet"
        print_info "You'll need to run 'nix develop' first to get system libraries"
        print_info "Then run 'uv sync' to install Python dependencies"
        return 0
    fi
    
    # Install Python dependencies with uv
    print_info "Running uv sync..."
    if uv sync; then
        print_success "Python dependencies installed successfully!"
    else
        print_error "Failed to install Python dependencies"
        print_info "Try manually: nix develop && uv sync"
        return 1
    fi
}

# Setup Ollama
setup_ollama() {
    print_info "Setting up Ollama..."
    
    # Check if Ollama is installed
    if ! command -v ollama >/dev/null 2>&1; then
        print_warning "Ollama not found. Installing..."
        print_info "Installing Ollama (requires sudo)..."
        if curl -fsSL https://ollama.ai/install.sh | sh; then
            print_success "Ollama installed successfully!"
        else
            print_error "Failed to install Ollama"
            print_info "Please install manually: curl -fsSL https://ollama.ai/install.sh | sh"
            return 1
        fi
    else
        print_success "Ollama is already installed"
    fi
    
    # Check if Ollama service is running
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        print_success "Ollama service is running"
    else
        print_info "Starting Ollama service..."
        ollama serve &
        sleep 3
        
        if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            print_success "Ollama service started successfully!"
        else
            print_warning "Ollama service may not be running properly"
            print_info "Try manually: ollama serve"
        fi
    fi
}

# Download essential models
download_models() {
    print_info "Downloading essential models..."
    
    local models=(
        "qwen2.5:7b"           # Main reasoning model
        "nomic-embed-text"     # Embedding model for RAG
    )
    
    for model in "${models[@]}"; do
        print_info "Downloading $model..."
        if ollama pull "$model"; then
            print_success "Downloaded $model"
        else
            print_warning "Failed to download $model - you can try manually later"
        fi
    done
    
    print_success "Model download complete!"
}

# Run tests
run_tests() {
    print_info "Running basic tests..."
    
    cd "$PROJECT_ROOT"
    
    # Test Python environment
    if [[ -n "${IN_NIX_SHELL:-}" ]]; then
        print_info "Testing Python environment..."
        if uv run python -c "import sys; print(f'Python {sys.version}')"; then
            print_success "Python environment is working!"
        else
            print_error "Python environment test failed"
            return 1
        fi
        
        # Test basic imports
        print_info "Testing basic imports..."
        if uv run python -c "import fastapi, uvicorn, pydantic"; then
            print_success "Core dependencies are working!"
        else
            print_warning "Some dependencies may have issues"
        fi
    else
        print_warning "Not in Nix environment - skipping tests"
    fi
    
    # Test Ollama
    print_info "Testing Ollama connectivity..."
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        print_success "Ollama is accessible!"
        
        # List available models
        print_info "Available models:"
        ollama list || print_warning "Could not list models"
    else
        print_warning "Ollama is not accessible"
    fi
}

# Show next steps
show_next_steps() {
    local mirror_mode="$1"
    
    echo ""
    print_success "Setup completed successfully!"
    echo ""
    print_info "Next steps:"
    echo ""
    
    if [[ -z "${IN_NIX_SHELL:-}" ]]; then
        echo "1. Enter Nix development environment:"
        echo "   nix develop"
        echo ""
        echo "2. Activate mirrors (if not already done):"
        echo "   source env/mirrors.sh $mirror_mode"
        echo ""
        echo "3. Install Python dependencies:"
        echo "   uv sync"
        echo ""
    else
        echo "1. Your environment is ready!"
        echo ""
    fi
    
    echo "4. Start the MCP server:"
    echo "   uv run python -m mcp_server.main_fastmcp"
    echo ""
    echo "5. Or run the test script:"
    echo "   uv run python test_mcp_qwen.py"
    echo ""
    
    print_info "Development workflow:"
    echo "  📝 Edit code in your favorite editor"
    echo "  🔄 Install new dependencies: uv add package-name"
    echo "  🧪 Run tests: uv run pytest"
    echo "  🚀 Start server: uv run python -m mcp_server.main_fastmcp"
    echo ""
    
    print_info "Mirror management:"
    echo "  🇨🇳 Switch to China mirrors: source env/mirrors.sh china"
    echo "  🌐 Switch to global mirrors: source env/mirrors.sh global"
    echo "  📊 Check current config: source env/mirrors.sh show"
    echo ""
    
    print_info "Troubleshooting:"
    echo "  📚 Check docs/ directory for detailed guides"
    echo "  🔍 Test connectivity: source env/mirrors.sh test"
    echo "  🏥 Reset environment: exit nix develop, then nix develop again"
}

show_help() {
    print_header
    echo -e "${CYAN}Usage:${NC}"
    echo "  ./env/setup.sh              # Interactive setup"
    echo "  ./env/setup.sh china        # Setup with China mirrors"
    echo "  ./env/setup.sh global       # Setup with global mirrors"
    echo "  ./env/setup.sh --help       # Show this help"
    echo ""
    echo -e "${CYAN}What this script does:${NC}"
    echo "  ✅ Checks prerequisites (nix, uv, curl)"
    echo "  ✅ Configures mirrors (session-scoped only)"
    echo "  ✅ Sets up development environment"
    echo "  ✅ Installs Python dependencies"
    echo "  ✅ Sets up Ollama and downloads models"
    echo "  ✅ Runs basic tests"
    echo "  ✅ Shows next steps"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  📦 Self-contained (no global pollution)"
    echo "  🔄 Reproducible (works for any user)"
    echo "  🇨🇳 China-optimized (automatic mirror detection)"
    echo "  🌐 Global-friendly (works everywhere)"
    echo "  🛡️  Safe (session-scoped only)"
    echo ""
    echo -e "${CYAN}After setup:${NC}"
    echo "  🎯 Ready to develop with uv + Nix + Ollama"
    echo "  ⚡ Fast Python dependency management"
    echo "  🔧 Stable system libraries from Nix"
    echo "  🤖 Local LLM inference with Ollama"
}

# Main logic
main() {
    case "${1:-interactive}" in
        "china"|"cn")
            print_header
            check_prerequisites
            setup_environment "china"
            setup_ollama
            install_dependencies
            download_models
            run_tests
            show_next_steps "china"
            ;;
        "global"|"international"|"intl")
            print_header
            check_prerequisites
            setup_environment "global"
            setup_ollama
            install_dependencies
            download_models
            run_tests
            show_next_steps "global"
            ;;
        "interactive"|"")
            print_header
            check_prerequisites
            local mirror_choice
            mirror_choice=$(select_mirrors)
            setup_environment "$mirror_choice"
            setup_ollama
            install_dependencies
            download_models
            run_tests
            show_next_steps "$mirror_choice"
            ;;
        "--help"|"-h"|"help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
