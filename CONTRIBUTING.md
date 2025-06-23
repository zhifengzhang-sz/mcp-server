# Contributing to MCP Server

Thank you for your interest in contributing to the MCP Server project! 

## 🎯 Project Status

This project is currently in **Phase 1: Design Complete**. We're transitioning to **Phase 2: Implementation**.

## 📋 How to Contribute

### 1. Development Setup

```bash
# Clone the repository
git clone https://github.com/zhifengzhang-sz/mcp-server.git
cd mcp-server

# Set up development environment
nix develop  # Enter Nix development shell
uv sync      # Install Python dependencies
```

### 2. Understanding the Architecture

Before contributing, please review:
- [Design Documentation](docs/design/) - C4 model architecture
- [Phase 1 Objectives](docs/objective/phase.1.md) - Project requirements
- [Strategic Roadmap](docs/architecture/strategic-roadmap.md) - Development phases

### 3. Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Follow** the existing code style and architecture patterns
4. **Test** your changes thoroughly
5. **Commit** with clear, descriptive messages
6. **Push** to your fork and create a Pull Request

### 4. Code Standards

- **Architecture**: Follow the documented C4 model design
- **Python**: Use type hints, follow PEP 8
- **Testing**: Maintain 100% test coverage
- **Documentation**: Update docs for any API changes

### 5. Pull Request Process

1. Ensure your PR description clearly explains the changes
2. Reference any related issues
3. Ensure all tests pass
4. Update documentation if needed
5. Request review from maintainers

## 🐛 Reporting Issues

- Use the GitHub issue templates
- Provide clear reproduction steps
- Include environment details
- Check existing issues first

## 📚 Development Resources

- [Setup Guide](docs/setup/) - Complete environment setup
- [Architecture Documentation](docs/architecture/) - System design
- [Technical Documentation](docs/technical/) - Implementation guides

## 🔍 Areas for Contribution

### Phase 2: Core Implementation (Current Focus)
- MCP protocol server implementation
- CLI interface development
- Context engine implementation
- Tool executor framework

### Phase 3: IDE Integration (Planned)
- VS Code Copilot Chat integration
- Cursor AI Chat integration
- Multi-IDE session management

## 📝 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🤝 Code of Conduct

Please be respectful and professional in all interactions. We're building a collaborative environment for everyone.

---

For questions or discussion, please open an issue or reach out to the maintainers. 