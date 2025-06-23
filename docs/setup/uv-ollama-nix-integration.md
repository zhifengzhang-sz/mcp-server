# uv + Ollama + Nix Integration Guide

## Overview

This document provides comprehensive guidance on integrating uv (Python package manager), Ollama (LLM runtime), and Nix (system package manager) in a bounded context architecture that avoids conflicts while maximizing each tool's strengths.

## Architecture Principles

### Bounded Context Design

Each tool operates in its own bounded context with clear responsibilities:

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Nix Context   │  │   uv Context    │  │ Ollama Context  │
│                 │  │                 │  │                 │
│ • System deps   │  │ • Python deps   │  │ • LLM models    │
│ • Shell env     │  │ • Virtual envs  │  │ • GPU runtime   │
│ • Build tools   │  │ • Lock files    │  │ • Model serving │
│ • Reproducible  │  │ • Fast installs │  │ • API endpoints │
│   builds        │  │ • Conflict res  │  │ • Hardware opt  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌─────────────────┐
                    │ Integration     │
                    │ Layer           │
                    │                 │
                    │ • Mirror mgmt   │
                    │ • Env switching │
                    │ • Session scope │
                    │ • No pollution  │
                    └─────────────────┘
```

### Key Principles

1. **No Global Pollution**: No tool modifies global system configuration
2. **Session Scoped**: All configurations are session-specific and reversible
3. **Clear Boundaries**: Each tool handles its domain without interference
4. **Mirror Flexibility**: Easy switching between China/Global mirrors
5. **Reproducible Builds**: Deterministic environments across systems

## Component Details

### Nix Context

**Purpose**: System-level dependencies and reproducible build environments

**Scope**:
- System packages (curl, git, build tools)
- Shell environments with precise versions
- Reproducible development environments
- Cross-platform compatibility

**Boundaries**:
- ✅ Does: System packages, shell environments, build dependencies
- ❌ Doesn't: Python package management, LLM model management
- ⚠️ Careful: Avoid conflicting with uv's Python management

### uv Context

**Purpose**: Python package and environment management

**Scope**:
- Python package installation and resolution
- Virtual environment management
- Dependency locking and reproducibility
- Fast package installation with caching

**Boundaries**:
- ✅ Does: Python packages, virtual environments, dependency resolution
- ❌ Doesn't: System packages, LLM models, shell configuration
- ⚠️ Careful: Respect Nix-provided Python versions

### Ollama Context

**Purpose**: Large Language Model deployment and serving

**Scope**:
- LLM model download and storage
- GPU-optimized model serving
- API endpoint management
- Hardware resource optimization

**Boundaries**:
- ✅ Does: LLM models, GPU utilization, model serving APIs
- ❌ Doesn't: Python packages, system dependencies, shell configuration
- ⚠️ Careful: GPU driver compatibility with Nix environment

## Integration Patterns

### Pattern 1: Layered Setup

```bash
# 1. Nix provides system foundation
nix develop

# 2. uv manages Python environment
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

# 3. Ollama manages models
ollama pull llama3.2:3b
ollama serve
```

### Pattern 2: Session-Scoped Configuration

```bash
# All configurations are session-scoped
source env/mirrors.sh china    # Sets mirrors for current session
uv pip install package         # Uses configured mirrors
ollama pull model              # Uses configured mirrors
# Session ends → no global pollution
```

### Pattern 3: Conflict Avoidance

```bash
# Nix provides Python, uv manages packages
which python  # /nix/store/.../bin/python
uv python list  # Shows Nix-provided Python
uv venv --python $(which python)  # Use Nix Python for venv
```

## Setup Tutorials

### 1. Nix Setup

#### Prerequisites
```bash
# Install Nix (single-user installation recommended)
curl -L https://nixos.org/nix/install | sh
source ~/.nix-profile/etc/profile.d/nix.sh
```

#### Enable Flakes
```bash
# Enable flakes and nix-command
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

#### Create flake.nix

We provide a production-ready `flake.nix` in the Python server directory. Here's the structure:

```nix
{
  description = "AI Agent Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    # ... (see qi/python/server/flake.nix for complete implementation)
}
```

**Key Features of Our Implementation:**
- ✅ CUDA support with unfree packages enabled
- ✅ Proper library linking with LD_LIBRARY_PATH
- ✅ uv integration (no poetry compilation hell!)
- ✅ System libraries only (Python packages via uv)
- ✅ GPU detection and status reporting
- ✅ Clear separation of concerns

**See**: [`qi/python/server/flake.nix`](../../qi/python/server/flake.nix) for the complete implementation.

#### Mirror Setup for Nix (China)

```bash
# Create China mirror configuration
mkdir -p ~/.config/nix
cat << EOF >> ~/.config/nix/nix.conf
substituters = https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org/
trusted-public-keys = mirror.sjtu.edu.cn:7fh/b6zrhM/v/1bGgQEIXWKqKl3tJdJ8zLKKjgT72+g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
```

#### Usage

```bash
# Enter development environment
cd qi/python/server
nix develop

# Or for specific shell
nix develop --command zsh
```

**Real-World Example:**
```bash
$ cd qi/python/server
$ nix develop
🚀 QiCore Agent Orchestration Platform - Development Environment
📦 Package Management: uv (fast, modern Python package manager)
🛠️  System Libraries: Nix-provided (C++, CUDA, etc.)

🎮 GPU: NVIDIA GeForce RTX 4090
🤖 Ollama: Available via system installation wrapper  
🐍 Python: Python 3.12.7
⚡ uv: uv 0.5.4

Quick start:
  uv sync                         # Install Python dependencies (FAST!)
  ollama serve                    # Start Ollama (auto-detects GPU)
  ollama pull llama3.2:3b        # Download recommended model
  uv run python -m mcp_server.main_fastmcp  # Run MCP server
```

### 2. uv Setup

#### Installation

```bash
# Install uv (inside Nix environment)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.cargo/env
```

#### Mirror Setup for uv

**China Mirrors:**
```bash
# Set PyPI mirror for current session
export UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
export PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
export UV_EXTRA_INDEX_URL="https://pypi.org/simple/"

# Or use uv configuration
mkdir -p ~/.config/uv
cat << EOF > ~/.config/uv/pip.conf
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
extra-index-url = https://pypi.org/simple/
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
```

**Global Mirrors:**
```bash
# Reset to global PyPI
unset UV_INDEX_URL PIP_INDEX_URL UV_EXTRA_INDEX_URL
rm -f ~/.config/uv/pip.conf
```

#### Usage with Nix

```bash
# In Nix environment
cd qi/python/server
nix develop

# Check Python version (should be from Nix)
python --version  # Python 3.12.7

# Install dependencies (no venv needed with uv sync)
uv sync

# Run application
uv run python -m mcp_server.main_fastmcp

# Add new dependencies
uv add fastapi uvicorn

# Run specific commands
uv run pytest
uv run python -c "import torch; print(torch.cuda.is_available())"
```

**Why uv + Nix is Superior:**
- ✅ **10-100x faster** than poetry (pre-built wheels)
- ✅ **No compilation hell** for PyTorch, NumPy, etc.
- ✅ **System libraries from Nix** (proper CUDA, C++ libs)
- ✅ **Simple dependency management** with pyproject.toml
- ✅ **Reproducible across systems**

#### Lock Files and Reproducibility

```bash
# Generate lock file
uv pip freeze > requirements.lock

# Install from lock file
uv pip install -r requirements.lock

# Update dependencies
uv pip compile requirements.in --output-file requirements.lock
```

### 3. Ollama Setup

#### Installation

```bash
# Download and install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Or manual installation
curl -L https://ollama.com/download/ollama-linux-amd64 -o ollama
chmod +x ollama
sudo mv ollama /usr/local/bin/
```

#### Mirror Setup for Ollama

**China Mirrors:**
```bash
# Set Ollama mirror for model downloads
export OLLAMA_HOST="0.0.0.0:11434"
export OLLAMA_MODELS="/path/to/models"

# Use China CDN for faster downloads
export OLLAMA_CDN="https://ollama.com.cn"
```

**Global Setup:**
```bash
# Default Ollama configuration
export OLLAMA_HOST="127.0.0.1:11434"
unset OLLAMA_CDN
```

#### Model Management

```bash
# Start Ollama service
ollama serve &

# Pull models (adjust for hardware)
ollama pull llama3.2:1b      # 1.3GB - Low-end GPUs
ollama pull llama3.2:3b      # 2.0GB - Mid-range GPUs  
ollama pull qwen2.5:7b       # 4.4GB - High-end GPUs
ollama pull qwen2.5:14b      # 8.2GB - Professional GPUs

# List installed models
ollama list

# Run model
ollama run llama3.2:3b
```

#### GPU Setup

```bash
# Check GPU availability
nvidia-smi

# Install NVIDIA container toolkit (if using containers)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list

sudo apt-get update
sudo apt-get install nvidia-container-runtime
```

## Mirror Management

### Session-Scoped Mirror Switching

Our `env/mirrors.sh` script provides session-scoped mirror management:

```bash
# Switch to China mirrors
source env/mirrors.sh china

# Switch to global mirrors  
source env/mirrors.sh global

# Show current configuration
source env/mirrors.sh show

# Test connectivity
source env/mirrors.sh test
```

### Mirror Configuration Details

**China Mirrors:**
- **Nix**: `https://mirror.sjtu.edu.cn/nix-channels/store`
- **PyPI**: `https://pypi.tuna.tsinghua.edu.cn/simple`
- **Ollama**: Uses CDN acceleration when available

**Global Mirrors:**
- **Nix**: `https://cache.nixos.org/`
- **PyPI**: `https://pypi.org/simple`
- **Ollama**: Direct downloads from official sources

### Automatic Detection

```bash
# The setup script auto-detects location
./env/setup.sh  # Detects China/Global automatically

# Manual override
./env/setup.sh china   # Force China mirrors
./env/setup.sh global  # Force global mirrors
```

## Troubleshooting

### Common Issues

#### Nix and uv Python Conflicts

**Problem**: uv installs its own Python, conflicting with Nix
**Solution**: Use Nix-provided Python for uv virtual environments

```bash
# Check Python source
which python  # Should show /nix/store/...

# Create venv with Nix Python
uv venv --python $(which python)
```

#### Ollama GPU Issues

**Problem**: GPU not detected in Nix environment
**Solution**: Ensure CUDA drivers are available

```bash
# Check GPU in Nix shell
nix develop
nvidia-smi

# If not available, add to flake.nix:
cudaPackages.cuda_cudart
```

#### Mirror Connectivity

**Problem**: Slow downloads or connection failures
**Solution**: Test and switch mirrors

```bash
# Test current setup
source env/mirrors.sh test

# Switch if needed
source env/mirrors.sh china  # or global
```

#### Package Resolution Conflicts

**Problem**: uv and pip install different versions
**Solution**: Use consistent package managers

```bash
# Always use uv in our environment
alias pip='uv pip'

# Or explicitly use uv
uv pip install package
```

### Best Practices

1. **Always enter Nix environment first**:
   ```bash
   nix develop  # Before any other commands
   ```

2. **Use session-scoped configurations**:
   ```bash
   source env/mirrors.sh china  # Session only
   ```

3. **Verify tool boundaries**:
   ```bash
   which python  # Should be from Nix
   uv python list  # Should show Nix Python
   ollama list  # Should show downloaded models
   ```

4. **Clean environment testing**:
   ```bash
   # Test in fresh shell
   exit  # Exit current shell
   nix develop  # Fresh environment
   ./env/setup.sh  # Verify setup works
   ```

## Performance Optimization

### Download Optimization

1. **Parallel Downloads**: Enable parallel downloads where supported
2. **Mirror Selection**: Use closest mirrors for your location
3. **Caching**: Leverage each tool's caching mechanisms
4. **Network Tuning**: Optimize network settings for large model downloads

### Hardware Optimization

1. **GPU Memory**: Choose models based on VRAM availability
2. **CPU Cores**: Configure parallel builds in Nix
3. **Storage**: Use fast storage for model cache directories
4. **Memory**: Ensure sufficient RAM for model operations

This integration approach provides a robust, reproducible, and efficient development environment that leverages the strengths of each tool while avoiding common pitfalls and conflicts.

## Complete Workflow Example

Here's a real-world example of the complete development workflow:

```bash
# 1. Clone and enter project
git clone <repository-url>
cd qi-v2-llm/qi/python/server

# 2. Enter Nix environment (provides system libs + Python + uv)
nix develop
# 🚀 QiCore Agent Orchestration Platform - Development Environment
# 🎮 GPU: NVIDIA GeForce RTX 4090
# 🐍 Python: Python 3.12.7
# ⚡ uv: uv 0.5.4

# 3. Set up mirrors for your location (session-scoped)
source env/mirrors.sh china  # or 'global' for outside China

# 4. Install Python dependencies (super fast with uv)
uv sync
# Resolved 45 packages in 243ms
# Downloaded 23 packages in 1.2s

# 5. Start Ollama in background
ollama serve &

# 6. Download models (using configured mirrors)
ollama pull llama3.2:3b     # 2.0GB, good for development
ollama pull qwen2.5:7b      # 4.4GB, better quality

# 7. Run the MCP server
uv run python -m mcp_server.main_fastmcp
# Server running on http://localhost:8000

# 8. In another terminal, test the agent
cd qi/python/server
nix develop  # Enter same environment
source env/mirrors.sh china  # Apply same mirrors
uv run python document_verification_agent.py

# 9. Development workflow
uv add pydantic-ai  # Add new dependency
uv run pytest      # Run tests
uv run python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"

# 10. Exit cleanly (no global pollution)
exit  # All session configurations are lost, system stays clean
```

## Benefits of This Architecture

### For Developers
- **Fast Setup**: One command gets you a complete development environment
- **No Conflicts**: Each tool stays in its lane, no version conflicts
- **Reproducible**: Same environment on any Linux system with Nix
- **Clean System**: No global configuration pollution
- **Location Aware**: Automatic mirror optimization for faster downloads

### For Teams
- **Consistent Environments**: Everyone gets identical development setup
- **Easy Onboarding**: New team members productive in minutes
- **Version Locked**: Exact dependency versions across team
- **CI/CD Ready**: Same environment in development and production

### For DevOps
- **Container Ready**: Easy to containerize with Nix
- **Hardware Optimized**: GPU detection and optimization
- **Mirror Flexible**: Easy to configure for different deployment regions
- **Troubleshoot Friendly**: Clear boundaries make debugging easier

This architecture has been battle-tested in the AI agent development workflow and provides the foundation for scaling to multi-agent systems.
