# MCP Server Setup Guide

## 🎯 Quick Start (Recommended)

**For AI Agent Development & Model Context Protocol:**

```bash
# Clone repository with submodules
git clone --recursive https://github.com/zhifengzhang-sz/mcp-server.git
cd mcp-server

# If you already cloned without --recursive, initialize submodules:
# git submodule init && git submodule update

# One-command setup (auto-detects your location)
./env/setup.sh
```

**That's it!** This gives you:
- ✅ Complete MCP server infrastructure
- ✅ Ollama with optimized language models
- ✅ Document Verification Agent (reference implementation)
- ✅ Session-scoped environment management
- ✅ Optimized China/Global mirror configuration

## 📖 What You Get

### Core Infrastructure
- **MCP Server**: Universal tool-LLM interface for agent development
- **Ollama Models**: Hardware-optimized model recommendations with VRAM requirements
- **Environment Management**: Clean, reproducible setup without global system pollution
- **Mirror Optimization**: Automatic detection and configuration for optimal download speeds

### Reference Implementation
- **Document Verification Agent**: Production-ready sAgent demonstrating PE + sLLM patterns
- **Function Calling**: Tool integration examples and patterns
- **Architecture Examples**: Clear implementation of sAgent design principles

### Development Tools
- **Environment Switching**: Easy mirror management for different development contexts
- **Model Management**: Efficient model download and deployment
- **Testing Framework**: Validation tools for agent development

## 🔧 Detailed Setup Options

### For Most Users (Automatic Location Detection)
```bash
cd mcp-server
./env/setup.sh
```

### China Users (Faster Downloads)
```bash
cd mcp-server
./env/setup.sh china
```

### Global Users (Standard Mirrors)
```bash
cd mcp-server
./env/setup.sh global
```

## 📚 Next Steps

After setup completes:

1. **Read the Architecture**: [sAgent Architecture](../architecture/sagent-architecture.md)
2. **Review the Implementation**: [MCP Server Structure](../../mcp_server/)
3. **Study the Patterns**: [MCP Integration Strategy](../architecture/mcp-integration-strategy.md)
4. **Check the Roadmap**: [Strategic Development Plan](../architecture/strategic-roadmap.md)

## 🏗️ Alternative Setups

### Alternative Architectures
For other agent development approaches:
- **MCP Specification**: [Model Context Protocol](https://spec.modelcontextprotocol.io/)
- **Ollama Documentation**: [Ollama Docs](https://ollama.ai/docs)
- **Official MCP SDK**: Using `mcp>=1.9.4` for protocol compliance

## 🆘 Troubleshooting

### Common Issues
- **Missing Prerequisites**: The setup script will check and guide you through installing required tools (nix, uv, curl)
- **Network Issues**: Use location-specific setup (`./env/setup.sh china` or `./env/setup.sh global`)
- **Permission Issues**: Ensure you have write access to the project directory
- **Git Submodule Issues**: If you see "qicore-v4" directory is empty or missing content:
  ```bash
  git submodule init && git submodule update
  # Or if that fails:
  git submodule update --init --recursive
  ```

### Getting Help
- **Environment Issues**: Check [Development Environment Documentation](../architecture/development-environment.md)
- **System Integration**: See [uv + Ollama + Nix Integration Guide](uv-ollama-nix-integration.md)
- **VS Code Git Issues**: See [VS Code Submodule Setup Guide](vscode-submodule-setup.md)
- **Agent Development**: See [sAgent Architecture Guide](../architecture/sagent-architecture.md)
- **Technical Details**: Browse [Project Documentation](../README.md)

## 🚀 Success Indicators

After successful setup, you should be able to:
- ✅ Run the Document Verification Agent
- ✅ Switch between China/Global mirrors seamlessly
- ✅ See Ollama models downloaded and ready
- ✅ Execute MCP server commands
- ✅ Access development documentation locally

---

**Welcome to AI Agent Development!**  
*Building the future of specialized AI agents with MCP and sAgent architecture*
