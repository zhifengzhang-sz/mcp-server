# MCP Server Documentation

## Component Overview

**📋 For component objectives and mission, see:**
- **[phase.1.md](objective/phase.1.md)** - Phase 1 objectives and feature requirements

**🚀 To get started:**
```bash
git clone https://github.com/zhifengzhang-sz/mcp-server.git
cd mcp-server
```

## Quick Start

For complete setup instructions, see [setup.md](setup/setup.md) (project-specific) or [setup README](setup/README.md) (general).

```bash
# One-command setup
./env/setup.sh

# Or manual setup
nix develop
source env/mirrors.sh china  # or global
uv sync
uv run python -m mcp_server.main_fastmcp
```

## Architecture Overview

This Python server implements the MCP (Model Context Protocol) interface as part of the larger sAgent system architecture.

**📚 For complete architectural documentation, see:**
- [Strategic Roadmap](architecture/strategic-roadmap.md)
- [sAgent Architecture](architecture/sagent-architecture.md)
- [MCP Integration Strategy](architecture/mcp-integration-strategy.md)
- [Development Environment](architecture/development-environment.md)

## Project Structure

```
mcp-server/
├── env/                    # Environment management (mirrors, setup)
├── mcp_server/            # Main application code
├── docs/                  # Project-specific documentation
│   ├── setup/             # Setup and configuration guides
│   ├── architecture/      # Architecture documentation (local copies)
│   ├── objective/         # Phase 1 objectives and requirements
│   ├── design/            # Phase 1 design documentation (C4 model)
│   └── technical/         # Implementation details and optimization guides
├── flake.nix             # Nix environment definition
├── pyproject.toml        # Python dependencies (uv managed)
└── uv.lock              # Locked dependency versions
```

## Technical Documentation

### [technical/](technical/)
- **[models.md](technical/models.md)** - Hardware-aware model selection and requirements
- **[ollama-gpu-optimization.md](technical/ollama-gpu-optimization.md)** - GPU optimization and configuration

## Phase 1 Documentation

### [setup/](setup/)
- **[setup.md](setup/setup.md)** - Complete Python server setup guide (project-specific)
- **[README.md](setup/README.md)** - Main project setup guide (general mcp-server)
- **[uv-ollama-nix-integration.md](setup/uv-ollama-nix-integration.md)** - Complete system integration tutorial

### [architecture/](architecture/)
- **[sagent-architecture.md](architecture/sagent-architecture.md)** - Specialized agent patterns (PE + sLLM)
- **[strategic-roadmap.md](architecture/strategic-roadmap.md)** - 8-phase development strategy
- **[mcp-integration-strategy.md](architecture/mcp-integration-strategy.md)** - Universal tool-LLM interface strategy
- **[development-environment.md](architecture/development-environment.md)** - Bounded context architecture

### [objective/](objective/)
- **[phase.1.md](objective/phase.1.md)** - Complete Phase 1 objectives including CLI Local LLM and Multi-IDE integration

### [design/](design/)
- **[phase.1.md](design/phase.1.md)** - Main design index and overview
- **[context.phase.1.md](design/context.phase.1.md)** - C1: System context and external relationships
- **[container.phase.1.md](design/container.phase.1.md)** - C2: High-level container architecture
- **[component.phase.1.md](design/component.phase.1.md)** - C3: Detailed component design
- **[classes.phase.1.md](design/classes.phase.1.md)** - C4: Class design and implementation specifications
- **[flow.phase.1.md](design/flow.phase.1.md)** - Logical flow analysis and interaction patterns

## Development Workflow

### Daily Development
1. **Enter environment**: `nix develop`
2. **Configure mirrors**: `source env/mirrors.sh china` (optional)
3. **Sync dependencies**: `uv sync`
4. **Start server**: `uv run python -m mcp_server.main_fastmcp`

### Adding Dependencies
```bash
uv add package-name    # Add new dependency
uv sync               # Install/update all dependencies
```

### Model Management
```bash
ollama list           # Show available models
ollama pull model     # Download new model
ollama serve          # Start model server
```

## Key Features

- **MCP Protocol**: Universal tool-LLM interface
- **Multi-Model Support**: 11+ specialized models for different tasks
- **GPU Optimization**: Efficient VRAM usage and performance
- **Environment Isolation**: Clean boundaries between system components
- **Mirror Support**: Optimized downloads for China and global users

## Integration Points

This server integrates with:
- **Ollama**: Local LLM inference
- **MCP Clients**: Copilot Chat, Claude Desktop, custom agents
- **Tools**: File system, APIs, databases through MCP protocol

## Troubleshooting

Common issues and solutions:

1. **Environment not found**: Ensure you're in `nix develop`
2. **Package conflicts**: Run `uv sync` inside Nix environment
3. **GPU issues**: Check CUDA drivers in Nix configuration
4. **Slow downloads**: Configure appropriate mirrors with `env/mirrors.sh`

For detailed troubleshooting, see the technical documentation and main project setup guides.

## External Resources

- **Main Project**: [mcp-server Repository](https://github.com/zhifengzhang-sz/mcp-server)
- **MCP Specification**: [Model Context Protocol](https://spec.modelcontextprotocol.io/)
- **Ollama**: [Ollama Documentation](https://ollama.ai/docs)

---

**Current Status**: Foundation complete, sAgent development in progress  
**Next Phase**: Document Verification Agent implementation
