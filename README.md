# MCP Server

**Status**: Design Phase - Complete architectural documentation and setup framework ready for implementation.

## 🎯 Project Overview

**Production-ready Model Context Protocol (MCP) server providing foundational infrastructure for specialized AI agent development.**

This repository contains comprehensive design documentation and setup framework for building an MCP server that enables:
- **CLI Local LLM Application** with workspace awareness
- **Multi-IDE Integration** (VS Code Copilot Chat, Cursor AI Chat)
- **Tool Ecosystem** for agent-like behavior without explicit agent architecture

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/zhifengzhang-sz/mcp-server.git
cd mcp-server

# One-command setup (auto-detects location)
./env/setup.sh
```

**Complete Setup Guide**: [docs/setup/](docs/setup/)

## 📋 Current Status: Design Phase Complete

### ✅ Completed Design Documentation
- **[Phase 1 Objectives](docs/objective/phase.1.md)** - Complete requirements and success criteria
- **[C4 Model Design](docs/design/)** - Context, Container, Component, and Flow analysis
- **[Architecture Documentation](docs/architecture/)** - Strategic roadmap and integration patterns
- **[Setup Framework](docs/setup/)** - Complete environment management system

### 🔄 Next Phase: Implementation
The design phase is complete. Implementation will follow the documented architecture in `docs/design/`.

## 📁 Project Structure

```
mcp-server/
├── README.md                  # This file
├── docs/                      # Complete design documentation
│   ├── setup/                 # Setup and configuration guides
│   ├── architecture/          # Architecture documentation
│   ├── objective/             # Phase 1 objectives and requirements
│   ├── design/                # C4 model design documentation
│   └── technical/             # Implementation guides
├── env/                       # Environment management scripts
├── mcp_server/                # Implementation placeholder
├── flake.nix                  # Nix environment definition
├── pyproject.toml             # Python dependencies
└── uv.lock                    # Locked dependency versions
```

## 🏗️ Architecture Overview

### Design Approach: C4 Model
- **[Context Diagram](docs/design/context.phase.1.md)** - System context and external relationships
- **[Container Diagram](docs/design/container.phase.1.md)** - High-level system architecture
- **[Component Diagram](docs/design/component.phase.1.md)** - Detailed component design
- **[Flow Analysis](docs/design/flow.phase.1.md)** - Interaction patterns and data flow

### Core Objectives
1. **CLI Local LLM Application**: Context-enhanced local LLM with workspace awareness
2. **Multi-IDE Integration**: Tool orchestration for VS Code Copilot Chat and Cursor AI Chat

## 📚 Documentation

### Setup & Configuration
- **[Setup Guide](docs/setup/setup.md)** - Project-specific setup instructions
- **[General Setup](docs/setup/README.md)** - Main project setup overview
- **[Integration Guide](docs/setup/uv-ollama-nix-integration.md)** - Complete system integration

### Architecture & Design
- **[Strategic Roadmap](docs/architecture/strategic-roadmap.md)** - 8-phase development strategy
- **[sAgent Architecture](docs/architecture/sagent-architecture.md)** - Specialized agent patterns
- **[MCP Integration](docs/architecture/mcp-integration-strategy.md)** - Universal tool-LLM interface
- **[Development Environment](docs/architecture/development-environment.md)** - Bounded context architecture

### Design Documentation
- **[Design Overview](docs/design/phase.1.md)** - Main design index
- **[Complete Design](docs/design/)** - Full C4 model documentation

## 🛠️ Development Environment

### Prerequisites
- **Nix**: Package manager and development environment
- **uv**: Fast Python package manager
- **Ollama**: Local LLM inference engine

### Environment Management
```bash
# Enter development environment
nix develop

# Configure mirrors (optional)
source env/mirrors.sh china    # or global

# Sync dependencies
uv sync
```

## 🎯 Implementation Roadmap

### Phase 1: Foundation (Design Complete ✅)
- [x] Complete architectural documentation
- [x] C4 model design analysis
- [x] Setup framework and environment management
- [x] Requirements and success criteria definition

### Phase 2: Core Implementation (Next)
- [ ] MCP protocol server implementation
- [ ] CLI interface development
- [ ] Context engine implementation
- [ ] Tool executor framework

### Phase 3: IDE Integration (Planned)
- [ ] VS Code Copilot Chat integration
- [ ] Cursor AI Chat integration
- [ ] Multi-IDE session management
- [ ] Tool orchestration implementation

## 🚀 Getting Started

### For Developers
1. **Setup**: Follow [docs/setup/](docs/setup/) for complete environment setup
2. **Architecture**: Review [design documentation](docs/design/) for implementation guidance
3. **Objectives**: Understand [Phase 1 requirements](docs/objective/phase.1.md)
4. **Implementation**: Begin with design specifications in `docs/design/`

### For Contributors
1. **Design Review**: Study the C4 model documentation in `docs/design/`
2. **Architecture**: Understand the bounded context approach in `docs/architecture/`
3. **Standards**: Follow the established design patterns and architectural principles
4. **Implementation**: Build according to the documented component specifications

---

**Project Status**: Design Phase Complete ✅  
**Next Milestone**: Core MCP Server Implementation  
**Repository**: [github.com/zhifengzhang-sz/mcp-server](https://github.com/zhifengzhang-sz/mcp-server)
