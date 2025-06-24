# Configuration Management Specification

**References**: [Package Strategy](package.phase.1.md)  
**Package Selection**: qicore-v4.core.config (wraps pydantic + python-dotenv)  
**Purpose**: Hierarchical configuration with plugin extension points

## Requirements

### Package Strategy Compliance
- **MUST use**: qicore-v4.core.config wrapper (per package.phase.1.md)
- **MUST NOT use**: Direct pydantic imports
- **MUST implement**: Result<T> patterns for configuration loading
- **MUST support**: Environment variable overrides

### Configuration Components
1. **ServerConfig**: host, port, debug mode, timeouts
2. **LLMConfig**: provider selection, model parameters, API endpoints  
3. **PluginConfig**: per-plugin settings with enable/disable
4. **AppConfig**: master configuration object

### Configuration Loading
- **Sources** (precedence order): Environment → Files → Defaults
- **File Locations**: ./config.json, ~/.mcp-server/config.json, /etc/mcp-server/config.json
- **Environment Variables**: MCP_HOST, MCP_PORT, MCP_DEBUG, MCP_LLM_PROVIDER, etc.

### Plugin Configuration
- **Plugin Registry**: Each plugin can define config schema
- **Validation**: Plugin configs validated against plugin-defined schema
- **Isolation**: Plugin configs isolated from core config
- **Extension Points**: Plugin config can extend core config

### Error Handling
- **Invalid Config**: Return Result<Error> with specific validation failures
- **Missing Files**: Graceful fallback to defaults
- **Bad Environment**: Log warnings, use defaults
- **Plugin Config Errors**: Disable plugin, continue with core functionality

## Implementation Notes

Configuration manager should:
- Load config using qicore-v4.core.config Result<T> patterns
- Validate all config sections independently
- Support hot-reloading for development
- Cache parsed config for performance
- Provide config change notifications for plugins 