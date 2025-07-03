# Environment Management for qi-v2-llm Python Server

This directory contains self-contained, reproducible environment management scripts for the qi-v2-llm Python server project.

## 🎯 Philosophy

- **Self-contained**: Everything needed is in this project
- **Session-scoped**: No global pollution of user's environment
- **Reproducible**: Same results for any user, any environment
- **User-friendly**: Automatic detection and helpful guidance

## 📁 Files

- `setup.sh` - Complete project setup (interactive or automated)
- `mirrors.sh` - Session-scoped mirror management
- `README.md` - This file

## 🚀 Quick Start

### For New Users (Any Location)

```bash
# Clone the repository
git clone <repository-url>
cd qi-v2-llm/qi/python/server

# Run interactive setup (detects location and suggests mirrors)
./env/setup.sh
```

### For China Users (Fast Setup)

```bash
# Setup with China mirrors for faster downloads
./env/setup.sh china
```

### For Global Users (Standard Setup)

```bash
# Setup with global mirrors
./env/setup.sh global
```

## 🔄 Mirror Management

After setup, you can switch mirrors anytime:

```bash
# Switch to China mirrors for faster downloads in China
source env/mirrors.sh china

# Switch to global mirrors
source env/mirrors.sh global

# Check current configuration
source env/mirrors.sh show

# Test connectivity
source env/mirrors.sh test
```

## 🛠️ Development Workflow

1. **Initial Setup** (one-time):
   ```bash
   ./env/setup.sh
   ```

2. **Daily Development**:
   ```bash
   # Enter development environment
   nix develop
   
   # Activate preferred mirrors (optional)
   source env/mirrors.sh china  # or global
   
   # Install/update dependencies
   uv sync
   
   # Start development
   uv run python -m mcp_server.main_fastmcp
   ```

3. **Adding Dependencies**:
   ```bash
   uv add package-name
   uv sync
   ```

## 🌐 Mirror Configuration Details

### China Mirrors (Optimized for China Users)
- **Python/PyPI**: Tsinghua University + Aliyun
- **Nix**: Tsinghua + SJTU + USTC + cache.nixos.org
- **Ollama**: Aliyun registry

### Global Mirrors (Standard Configuration)
- **Python/PyPI**: Default PyPI
- **Nix**: cache.nixos.org
- **Ollama**: Default Ollama registry

## 🛡️ Safety Features

- **Session-scoped only**: Changes only affect current terminal session
- **No global pollution**: Never modifies ~/.bashrc, ~/.zshrc, or global configs
- **Reversible**: Close terminal or source different mirror config to reset
- **Project-contained**: All configuration is in this project directory

## 🔧 Advanced Usage

### Manual Environment Setup

If you prefer manual control:

```bash
# 1. Configure mirrors
source env/mirrors.sh china  # or global

# 2. Enter Nix environment
nix develop

# 3. Install Python dependencies  
uv sync

# 4. Start services
ollama serve &  # In another terminal

# 5. Run the server
uv run python -m mcp_server.main_fastmcp
```

### Environment Variables Set

The mirror scripts set these environment variables:

**China Mode:**
- `UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple`
- `UV_EXTRA_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/`
- `NIX_CONFIG` with China mirrors
- `OLLAMA_REGISTRY=registry.cn-hangzhou.aliyuncs.com`

**Global Mode:**
- Unsets China-specific variables
- Uses default configurations

## 🆚 Comparison with Other Approaches

| Approach | Global Pollution | Reproducibility | User-Friendly | Maintenance |
|----------|------------------|-----------------|----------------|-------------|
| **This Solution** | ❌ None | ✅ Perfect | ✅ Excellent | ✅ Minimal |
| Global ~/.config/ | ⚠️ Moderate | ⚠️ User-dependent | ⚠️ Setup Required | ⚠️ Per-user |
| Project scripts writing to ~ | ❌ High | ❌ Poor | ❌ Confusing | ❌ High |
| Docker only | ❌ None | ✅ Good | ⚠️ Learning curve | ⚠️ Complex |

## 🐛 Troubleshooting

### Common Issues

1. **"Command not found" errors**:
   ```bash
   # Check prerequisites
   ./env/setup.sh --help
   ```

2. **Slow downloads**:
   ```bash
   # Switch to appropriate mirrors
   source env/mirrors.sh china   # if in China
   source env/mirrors.sh global  # if elsewhere
   ```

3. **Dependency conflicts**:
   ```bash
   # Reset environment
   exit  # Exit nix develop
   nix develop  # Re-enter
   uv sync  # Reinstall
   ```

4. **Mirror connectivity issues**:
   ```bash
   # Test connectivity
   source env/mirrors.sh test
   ```

### Getting Help

1. **Check this README** for common patterns
2. **Run setup script with --help**: `./env/setup.sh --help`
3. **Check mirror status**: `source env/mirrors.sh show`
4. **Test connectivity**: `source env/mirrors.sh test`

## 🎉 Benefits

- **No global pollution**: Your global environment stays clean
- **Easy onboarding**: New team members can get started immediately
- **Location-aware**: Automatically suggests optimal mirrors
- **Consistent**: Same environment for everyone
- **Fast**: China mirrors provide significant speedup in China
- **Flexible**: Easy to switch between mirror configurations
- **Safe**: Session-scoped changes only

## 🔮 Future Enhancements

- Automatic mirror switching based on connectivity tests
- Integration with CI/CD pipelines
- Support for additional mirror providers
- Environment validation scripts
- Performance monitoring and optimization

---

**This environment management system replaces the need for global ~/.config/ modifications and provides a clean, reproducible development experience for all users.**
