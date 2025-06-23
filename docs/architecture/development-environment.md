# Development Environment Architecture

## Overview

This document details the bounded context architecture that resolves historical Nix integration challenges through clear component separation and defined boundaries.

## Architecture Principles

### Component Isolation
Each tool operates within its domain of expertise:
- **Nix**: System-level dependencies and environment isolation
- **uv**: Python package management and virtual environments
- **Ollama**: Model lifecycle and inference management

### Boundary Definition
```
┌─────────────────────────────────────────────────────────┐
│ Nix Development Shell                                   │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│ │ System Libraries│ │ uv Environment  │ │ Ollama      │ │
│ │ - libstdc++     │ │ - Python deps   │ │ - Models    │ │
│ │ - CUDA drivers  │ │ - Virtual env   │ │ - Inference │ │
│ │ - Dev tools     │ │ - Lock files    │ │ - GPU mgmt  │ │
│ └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation Details

### Nix Configuration
- Provides system libraries without Python package management
- Enables CUDA support and GPU access
- Maintains reproducible development environments
- Sets LD_LIBRARY_PATH for binary compatibility

### UV Integration
- Manages Python dependencies independently
- Creates isolated virtual environments
- Handles lock file generation and dependency resolution
- Provides fast package installation via pre-built wheels

### Ollama Management
- Operates independently from Python environment
- Manages model downloading, storage, and inference
- Provides GPU optimization and resource allocation
- Enables concurrent model access

## Mirror Management

### Session-Scoped Configuration
Project-local mirror management eliminates global configuration pollution:

```bash
# Project-contained mirror switching
source env/mirrors.sh china   # China-optimized mirrors
source env/mirrors.sh global  # International mirrors
```

### Benefits
- No global environment modification
- Session-scoped changes only
- Reproducible across different users
- Easy mirror switching for optimal performance

## Performance Characteristics

### Component Performance
- **Nix**: Sub-second environment activation
- **uv**: 10-100x faster than poetry2nix
- **Ollama**: Native GPU performance

### Development Workflow
```bash
nix develop              # Enter environment (system libs)
source env/mirrors.sh    # Configure mirrors (optional)
uv sync                  # Install Python deps (fast)
ollama serve            # Start model server
uv run python -m app    # Execute application
```

## Troubleshooting

### Common Issues
1. **Library path errors**: Ensure Nix environment is active
2. **Package conflicts**: Use `uv sync` within Nix shell
3. **GPU access**: Verify CUDA drivers in Nix configuration
4. **Mirror connectivity**: Test with `source env/mirrors.sh test`

### Debugging Tools
```bash
echo $IN_NIX_SHELL      # Verify Nix environment
echo $LD_LIBRARY_PATH   # Check library paths
uv pip list             # Verify Python packages
ollama list             # Check available models
```

## Migration Benefits

### Previous Approach Issues
- Component coupling within Nix
- Complex dependency management
- Frequent build failures
- Poor performance characteristics

### Current Approach Advantages
- Clear component boundaries
- Independent tool evolution
- Improved reliability
- Enhanced performance
- Better debugging capabilities

## Conclusion

The bounded context architecture provides a robust foundation for AI development by respecting tool boundaries while enabling seamless integration. This approach resolves historical Nix challenges and establishes a scalable platform for complex AI agent development.
