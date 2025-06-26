#!/bin/bash

# MCP Server Migration Installer
# Handles migration from old setup to new self-contained environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
OLD_VENV_PATH=".venv"
BACKUP_DIR=".migration-backup"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Help function
show_help() {
    cat << EOF
MCP Server Migration Installer

USAGE:
    ./migrate-installer.sh [OPTIONS]

OPTIONS:
    --no-backup       Skip backup of existing environment
    --force           Force migration even if new setup exists
    --location LOCATION   Set location (china/global/auto)
    --help, -h        Show this help message

DESCRIPTION:
    This script migrates your existing MCP Server setup to the new
    self-contained environment system using Nix + uv.

    The migration will:
    1. Detect your existing setup (venv, conda, etc.)
    2. Backup your current environment
    3. Preserve any custom configurations
    4. Install the new self-contained environment
    5. Verify the migration was successful

EXAMPLES:
    ./migrate-installer.sh                    # Auto-detect and migrate
    ./migrate-installer.sh --location china   # Migrate with China mirrors
    ./migrate-installer.sh --no-backup        # Skip backup step

EOF
}

# Parse command line arguments
BACKUP_ENABLED=true
FORCE_MIGRATION=false
LOCATION="auto"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            BACKUP_ENABLED=false
            shift
            ;;
        --force)
            FORCE_MIGRATION=true
            shift
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Header
log_header "🔄 MCP Server Migration Installer"
log_header "   Migrating to self-contained environment"
log_header ""

# Check if already using new setup
check_new_setup() {
    log_info "Checking for existing new setup..."
    
    if [[ -f "$PROJECT_ROOT/env/setup.sh" ]] && [[ -f "$PROJECT_ROOT/.envrc" ]]; then
        if [[ "$FORCE_MIGRATION" == "false" ]]; then
            log_warning "New setup already exists!"
            log_info "Use --force to re-run migration"
            exit 0
        else
            log_warning "Forcing migration despite existing setup"
        fi
    fi
}

# Detect existing environment
detect_existing_env() {
    log_info "Detecting existing environment..."
    
    local env_type="none"
    local env_details=""
    
    # Check for Python virtual environment
    if [[ -d "$OLD_VENV_PATH" ]]; then
        env_type="venv"
        env_details="Python virtual environment at $OLD_VENV_PATH"
        
        # Check if it's active
        if [[ -n "${VIRTUAL_ENV:-}" ]]; then
            log_warning "Virtual environment is currently active"
            log_info "Please deactivate it first with: deactivate"
            exit 1
        fi
    fi
    
    # Check for conda environment
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
        env_type="conda"
        env_details="Conda environment: $CONDA_DEFAULT_ENV"
        log_warning "Conda environment is active"
        log_info "Please deactivate it first with: conda deactivate"
        exit 1
    fi
    
    # Check for poetry
    if [[ -f "poetry.lock" ]]; then
        env_type="poetry"
        env_details="Poetry project detected"
    fi
    
    # Check for pipenv
    if [[ -f "Pipfile.lock" ]]; then
        env_type="pipenv"
        env_details="Pipenv project detected"
    fi
    
    if [[ "$env_type" == "none" ]]; then
        log_info "No existing Python environment detected"
    else
        log_success "Found: $env_details"
    fi
    
    echo "$env_type"
}

# Backup existing environment
backup_environment() {
    if [[ "$BACKUP_ENABLED" == "false" ]]; then
        log_info "Skipping backup (--no-backup specified)"
        return
    fi
    
    log_info "Creating backup of existing environment..."
    
    # Create backup directory
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$PROJECT_ROOT/$BACKUP_DIR/$timestamp"
    mkdir -p "$backup_path"
    
    # Backup virtual environment if exists
    if [[ -d "$OLD_VENV_PATH" ]]; then
        log_info "Backing up virtual environment..."
        # Only backup pip freeze, not the entire venv
        if [[ -f "$OLD_VENV_PATH/bin/pip" ]]; then
            "$OLD_VENV_PATH/bin/pip" freeze > "$backup_path/requirements.txt" || true
        fi
    fi
    
    # Backup any custom configurations
    local configs=(
        ".env"
        "config.yaml"
        "config.json"
        "settings.json"
        ".env.local"
    )
    
    for config in "${configs[@]}"; do
        if [[ -f "$PROJECT_ROOT/$config" ]]; then
            log_info "Backing up $config..."
            cp "$PROJECT_ROOT/$config" "$backup_path/" || true
        fi
    done
    
    # Backup poetry/pipenv files if they exist
    if [[ -f "poetry.lock" ]]; then
        cp poetry.lock pyproject.toml "$backup_path/" 2>/dev/null || true
    fi
    
    if [[ -f "Pipfile.lock" ]]; then
        cp Pipfile Pipfile.lock "$backup_path/" 2>/dev/null || true
    fi
    
    log_success "Backup created at: $backup_path"
}

# Check prerequisites for new setup
check_prerequisites() {
    log_info "Checking prerequisites for new setup..."
    
    local missing_deps=()
    
    # Check nix
    if ! command -v nix >/dev/null 2>&1; then
        log_warning "Nix not found"
        missing_deps+=("nix")
    else
        log_success "Nix found"
    fi
    
    # Check curl
    if ! command -v curl >/dev/null 2>&1; then
        log_warning "curl not found"
        missing_deps+=("curl")
    else
        log_success "curl found"
    fi
    
    # Check git
    if ! command -v git >/dev/null 2>&1; then
        log_warning "git not found"
        missing_deps+=("git")
    else
        log_success "git found"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing prerequisites: ${missing_deps[*]}"
        log_info ""
        log_info "Install missing prerequisites:"
        
        if [[ " ${missing_deps[@]} " =~ " nix " ]]; then
            log_info "  Install Nix:"
            log_info "    curl -L https://nixos.org/nix/install | sh"
            log_info "    (Follow the prompts and restart your shell)"
        fi
        
        if [[ " ${missing_deps[@]} " =~ " curl " ]] || [[ " ${missing_deps[@]} " =~ " git " ]]; then
            log_info "  Ubuntu/Debian: sudo apt update && sudo apt install ${missing_deps[*]}"
            log_info "  macOS: brew install ${missing_deps[*]}"
        fi
        
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Clean old environment
clean_old_environment() {
    log_info "Cleaning old environment files..."
    
    # Remove old virtual environment
    if [[ -d "$OLD_VENV_PATH" ]]; then
        log_info "Removing old virtual environment..."
        rm -rf "$OLD_VENV_PATH"
    fi
    
    # Clean pip cache if needed
    if [[ -d "$HOME/.cache/pip" ]]; then
        log_info "Cleaning pip cache (optional)..."
        # Just inform, don't actually clean - user might want it
        log_info "You can manually clean with: rm -rf ~/.cache/pip"
    fi
    
    log_success "Old environment cleaned"
}

# Install new environment
install_new_environment() {
    log_info "Installing new self-contained environment..."
    
    # Check if env directory exists
    if [[ ! -d "$PROJECT_ROOT/env" ]]; then
        log_error "env/ directory not found!"
        log_info "Make sure you're in the mcp-server project root"
        exit 1
    fi
    
    # Check if setup.sh exists
    if [[ ! -f "$PROJECT_ROOT/env/setup.sh" ]]; then
        log_error "env/setup.sh not found!"
        log_info "Your repository might be outdated. Try:"
        log_info "  git pull origin main"
        exit 1
    fi
    
    # Run the new setup script
    log_info "Running new setup script with location: $LOCATION"
    
    cd "$PROJECT_ROOT"
    if [[ "$LOCATION" == "auto" ]]; then
        ./env/setup.sh
    else
        ./env/setup.sh "$LOCATION"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "New environment installed successfully!"
    else
        log_error "Setup script failed"
        log_info "Check the error messages above"
        exit 1
    fi
}

# Migrate configurations
migrate_configurations() {
    log_info "Migrating configurations..."
    
    # Check if we have a backup with configs
    if [[ -d "$PROJECT_ROOT/$BACKUP_DIR" ]]; then
        local latest_backup=$(ls -t "$PROJECT_ROOT/$BACKUP_DIR" | head -1)
        if [[ -n "$latest_backup" ]]; then
            local backup_path="$PROJECT_ROOT/$BACKUP_DIR/$latest_backup"
            
            # Restore .env files if they don't exist
            for env_file in .env .env.local; do
                if [[ -f "$backup_path/$env_file" ]] && [[ ! -f "$PROJECT_ROOT/$env_file" ]]; then
                    log_info "Restoring $env_file..."
                    cp "$backup_path/$env_file" "$PROJECT_ROOT/"
                fi
            done
        fi
    fi
    
    log_success "Configuration migration complete"
}

# Verify migration
verify_migration() {
    log_info "Verifying migration..."
    
    # Enter nix shell and check
    cd "$PROJECT_ROOT"
    
    # Test nix develop
    log_info "Testing Nix environment..."
    if nix develop --command echo "Nix environment OK" >/dev/null 2>&1; then
        log_success "Nix environment working"
    else
        log_error "Nix environment not working"
        return 1
    fi
    
    # Test uv
    log_info "Testing uv installation..."
    if nix develop --command uv --version >/dev/null 2>&1; then
        log_success "uv is available"
    else
        log_error "uv not found in environment"
        return 1
    fi
    
    log_success "Migration verified successfully!"
    return 0
}

# Show migration summary
show_migration_summary() {
    log_header ""
    log_header "🎉 Migration Complete!"
    log_header ""
    
    log_success "Your MCP Server has been migrated to the new setup"
    
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        log_info "📁 Backup location: $PROJECT_ROOT/$BACKUP_DIR/"
    fi
    
    echo ""
    log_info "📚 Next Steps:"
    echo "   1. Enter development environment:  nix develop"
    echo "   2. Run the server:                 uv run python -m mcp_server.main"
    echo "   3. Manage mirrors:                 source env/mirrors.sh [china|global]"
    
    echo ""
    log_info "🔧 Key Differences:"
    echo "   - No more 'source .venv/bin/activate' - use 'nix develop' instead"
    echo "   - Python packages managed by 'uv' instead of 'pip'"
    echo "   - Self-contained environment with no global pollution"
    echo "   - Automatic GPU support through Nix"
    
    echo ""
    log_info "📖 Documentation:"
    echo "   - New setup guide:    docs/setup/setup.md"
    echo "   - Environment docs:   env/README.md"
    echo "   - Architecture:       docs/architecture/"
    
    echo ""
    log_warning "⚠️  Important Notes:"
    echo "   - Old .venv/ directory has been removed"
    echo "   - Use 'uv add <package>' instead of 'pip install'"
    echo "   - Always work inside 'nix develop' shell"
    
    if [[ -d "$PROJECT_ROOT/$BACKUP_DIR" ]]; then
        echo ""
        log_info "🗄️  Your old environment was backed up"
        echo "   You can safely remove backups with: rm -rf $BACKUP_DIR/"
    fi
}

# Main migration flow
main() {
    check_new_setup
    
    local env_type=$(detect_existing_env)
    
    if [[ "$env_type" == "none" ]] && [[ "$FORCE_MIGRATION" == "false" ]]; then
        log_info "No existing environment found, proceeding with fresh setup..."
    else
        backup_environment
    fi
    
    check_prerequisites
    
    if [[ "$env_type" != "none" ]]; then
        clean_old_environment
    fi
    
    install_new_environment
    migrate_configurations
    
    if verify_migration; then
        show_migration_summary
    else
        log_error "Migration verification failed"
        log_info "Please check the errors above and try again"
        exit 1
    fi
}

# Run main function
main