# Configuration Implementation

> **Configuration Management with Plugin Extension Support**  
> **Design Source**: [Container Design](../design/container.phase.1.md), [Class Design](../design/classes.phase.1.md)  
> **Implementation**: Python 3.12+ with Functional Configuration Patterns  
> **Purpose**: Immutable configuration system with plugin-extensible settings

## Overview

This document implements the configuration management system that provides immutable configuration with plugin extension points and environment-based overrides. The implementation follows functional programming principles with validation and plugin integration.

## Configuration Architecture

### Core Configuration Models

```python
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, field
from enum import Enum
import os
import json
from pathlib import Path
from models import PluginId

class LogLevel(str, Enum):
    """Logging levels."""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

@dataclass(frozen=True)
class ServerConfig:
    """Core server configuration."""
    host: str = "localhost"
    port: int = 8000
    debug: bool = False
    log_level: LogLevel = LogLevel.INFO
    max_concurrent_requests: int = 10
    request_timeout_seconds: int = 30

@dataclass(frozen=True)
class LLMConfig:
    """LLM provider configuration."""
    default_provider: str = "ollama"
    default_model: str = "llama3.1:8b"
    max_tokens: int = 4000
    temperature: float = 0.7
    ollama_base_url: str = "http://localhost:11434"

@dataclass(frozen=True)
class PluginConfig:
    """Plugin-specific configuration."""
    enabled: bool = True
    config: Dict[str, Any] = field(default_factory=dict)
    priority: int = 100

@dataclass(frozen=True)
class AppConfig:
    """
    Immutable application configuration with plugin extension points.
    
    Central configuration object enhanced by plugin configurations.
    """
    server: ServerConfig = field(default_factory=ServerConfig)
    llm: LLMConfig = field(default_factory=LLMConfig)
    
    # Plugin configurations
    plugin_configs: Dict[str, PluginConfig] = field(default_factory=dict)
    plugin_directories: tuple[str, ...] = field(default_factory=tuple)
    
    # Extension point for Phase 2-4 configs
    phase_configs: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    
    # Environment and runtime settings
    config_path: Optional[str] = None
    environment: str = "development"
    
    def with_server_config(self, server_config: ServerConfig) -> 'AppConfig':
        """Update server configuration immutably."""
        return dataclass.replace(self, server=server_config)
    
    def with_llm_config(self, llm_config: LLMConfig) -> 'AppConfig':
        """Update LLM configuration immutably."""
        return dataclass.replace(self, llm=llm_config)
    
    def with_plugin_config(self, plugin_id: str, plugin_config: PluginConfig) -> 'AppConfig':
        """Set plugin configuration immutably."""
        new_configs = {**self.plugin_configs, plugin_id: plugin_config}
        return dataclass.replace(self, plugin_configs=new_configs)
    
    def with_phase_config(self, phase: str, config: Dict[str, Any]) -> 'AppConfig':
        """Set phase configuration immutably."""
        new_phase_configs = {**self.phase_configs, phase: config}
        return dataclass.replace(self, phase_configs=new_phase_configs)
    
    def get_plugin_config(self, plugin_id: str) -> Optional[PluginConfig]:
        """Get plugin configuration."""
        return self.plugin_configs.get(plugin_id)
    
    def get_phase_config(self, phase: str) -> Optional[Dict[str, Any]]:
        """Get phase-specific configuration."""
        return self.phase_configs.get(phase)
    
    def is_plugin_enabled(self, plugin_id: str) -> bool:
        """Check if plugin is enabled."""
        plugin_config = self.plugin_configs.get(plugin_id)
        return plugin_config.enabled if plugin_config else False
```

### Configuration Loader and Manager

```python
class ConfigurationLoader:
    """
    Configuration loader with multiple sources and validation.
    
    Loads configuration from files, environment variables, and defaults.
    """
    
    def __init__(self):
        self.default_config_paths = [
            "config.json",
            "config/app.json",
            os.path.expanduser("~/.mcp-server/config.json"),
            "/etc/mcp-server/config.json"
        ]
    
    def load_configuration(self, config_path: Optional[str] = None) -> AppConfig:
        """
        Load configuration from multiple sources with precedence.
        
        Args:
            config_path: Optional path to config file
            
        Returns:
            Loaded and validated configuration
        """
        # Start with default configuration
        config = AppConfig()
        
        # Load from file if available
        file_config = self._load_from_file(config_path)
        if file_config:
            config = self._merge_configurations(config, file_config)
        
        # Override with environment variables
        env_config = self._load_from_environment()
        config = self._merge_configurations(config, env_config)
        
        # Validate final configuration
        self._validate_configuration(config)
        
        return config
    
    def _load_from_file(self, config_path: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Load configuration from JSON file."""
        paths_to_try = [config_path] if config_path else self.default_config_paths
        
        for path in paths_to_try:
            if path and Path(path).exists():
                try:
                    with open(path, 'r') as f:
                        return json.load(f)
                except Exception as e:
                    print(f"Failed to load config from {path}: {e}")
        
        return None
    
    def _load_from_environment(self) -> Dict[str, Any]:
        """Load configuration overrides from environment variables."""
        env_config: Dict[str, Any] = {}
        
        # Server configuration
        if host := os.getenv("MCP_HOST"):
            env_config.setdefault("server", {})["host"] = host
        
        if port := os.getenv("MCP_PORT"):
            env_config.setdefault("server", {})["port"] = int(port)
        
        if debug := os.getenv("MCP_DEBUG"):
            env_config.setdefault("server", {})["debug"] = debug.lower() == "true"
        
        if log_level := os.getenv("MCP_LOG_LEVEL"):
            env_config.setdefault("server", {})["log_level"] = log_level
        
        # LLM configuration
        if provider := os.getenv("MCP_LLM_PROVIDER"):
            env_config.setdefault("llm", {})["default_provider"] = provider
        
        if model := os.getenv("MCP_LLM_MODEL"):
            env_config.setdefault("llm", {})["default_model"] = model
        
        if ollama_url := os.getenv("MCP_OLLAMA_URL"):
            env_config.setdefault("llm", {})["ollama_base_url"] = ollama_url
        
        # Environment
        if environment := os.getenv("MCP_ENVIRONMENT"):
            env_config["environment"] = environment
        
        return env_config
    
    def _merge_configurations(self, base: AppConfig, override: Dict[str, Any]) -> AppConfig:
        """Merge configuration override into base configuration."""
        current_config = base
        
        # Update server config
        if "server" in override:
            server_dict = self._dataclass_to_dict(current_config.server)
            server_dict.update(override["server"])
            server_config = ServerConfig(**server_dict)
            current_config = current_config.with_server_config(server_config)
        
        # Update LLM config
        if "llm" in override:
            llm_dict = self._dataclass_to_dict(current_config.llm)
            llm_dict.update(override["llm"])
            llm_config = LLMConfig(**llm_dict)
            current_config = current_config.with_llm_config(llm_config)
        
        # Update plugin configs
        if "plugins" in override:
            for plugin_id, plugin_data in override["plugins"].items():
                plugin_config = PluginConfig(**plugin_data)
                current_config = current_config.with_plugin_config(plugin_id, plugin_config)
        
        # Update phase configs
        if "phases" in override:
            for phase, phase_data in override["phases"].items():
                current_config = current_config.with_phase_config(phase, phase_data)
        
        # Update other fields
        for key in ["environment", "plugin_directories"]:
            if key in override:
                current_config = dataclass.replace(current_config, **{key: override[key]})
        
        return current_config
    
    def _dataclass_to_dict(self, obj: Any) -> Dict[str, Any]:
        """Convert dataclass to dictionary."""
        if hasattr(obj, '__dataclass_fields__'):
            return {field.name: getattr(obj, field.name) for field in obj.__dataclass_fields__.values()}
        return {}
    
    def _validate_configuration(self, config: AppConfig) -> None:
        """Validate configuration values."""
        # Validate server config
        if not (1 <= config.server.port <= 65535):
            raise ValueError(f"Invalid port: {config.server.port}")
        
        if config.server.max_concurrent_requests <= 0:
            raise ValueError("max_concurrent_requests must be positive")
        
        # Validate LLM config
        if config.llm.max_tokens <= 0:
            raise ValueError("max_tokens must be positive")
        
        if not (0.0 <= config.llm.temperature <= 2.0):
            raise ValueError("temperature must be between 0.0 and 2.0")
        
        # Validate plugin directories exist
        for plugin_dir in config.plugin_directories:
            if not Path(plugin_dir).exists():
                print(f"Warning: Plugin directory does not exist: {plugin_dir}")

class ConfigurationManager:
    """
    High-level configuration management with plugin integration.
    
    Manages configuration lifecycle, updates, and plugin configurations.
    """
    
    def __init__(self, config_path: Optional[str] = None):
        self.loader = ConfigurationLoader()
        self._config = self.loader.load_configuration(config_path)
        self._config_callbacks: List[Callable[[AppConfig], None]] = []
    
    @property
    def config(self) -> AppConfig:
        """Get current configuration."""
        return self._config
    
    def reload_configuration(self, config_path: Optional[str] = None) -> None:
        """Reload configuration from sources."""
        new_config = self.loader.load_configuration(config_path)
        self.update_configuration(new_config)
    
    def update_configuration(self, new_config: AppConfig) -> None:
        """Update configuration and notify callbacks."""
        old_config = self._config
        self._config = new_config
        
        # Notify callbacks of configuration change
        for callback in self._config_callbacks:
            try:
                callback(new_config)
            except Exception as e:
                print(f"Configuration callback failed: {e}")
    
    def register_config_callback(self, callback: Callable[[AppConfig], None]) -> None:
        """Register callback for configuration changes."""
        self._config_callbacks.append(callback)
    
    def update_plugin_config(self, plugin_id: str, plugin_config: PluginConfig) -> None:
        """Update plugin configuration."""
        updated_config = self._config.with_plugin_config(plugin_id, plugin_config)
        self.update_configuration(updated_config)
    
    def enable_plugin(self, plugin_id: str) -> None:
        """Enable plugin."""
        current_plugin_config = self._config.get_plugin_config(plugin_id) or PluginConfig()
        enabled_config = dataclass.replace(current_plugin_config, enabled=True)
        self.update_plugin_config(plugin_id, enabled_config)
    
    def disable_plugin(self, plugin_id: str) -> None:
        """Disable plugin."""
        current_plugin_config = self._config.get_plugin_config(plugin_id) or PluginConfig()
        disabled_config = dataclass.replace(current_plugin_config, enabled=False)
        self.update_plugin_config(plugin_id, disabled_config)
    
    def set_plugin_config_value(self, plugin_id: str, key: str, value: Any) -> None:
        """Set plugin configuration value."""
        current_plugin_config = self._config.get_plugin_config(plugin_id) or PluginConfig()
        new_plugin_config_dict = {**current_plugin_config.config, key: value}
        updated_config = dataclass.replace(current_plugin_config, config=new_plugin_config_dict)
        self.update_plugin_config(plugin_id, updated_config)
    
    def get_plugin_config_value(self, plugin_id: str, key: str, default: Any = None) -> Any:
        """Get plugin configuration value."""
        plugin_config = self._config.get_plugin_config(plugin_id)
        if plugin_config:
            return plugin_config.config.get(key, default)
        return default
    
    def save_configuration(self, config_path: str) -> bool:
        """Save current configuration to file."""
        try:
            config_dict = self._config_to_dict(self._config)
            
            # Ensure directory exists
            Path(config_path).parent.mkdir(parents=True, exist_ok=True)
            
            with open(config_path, 'w') as f:
                json.dump(config_dict, f, indent=2, default=str)
            
            return True
            
        except Exception as e:
            print(f"Failed to save configuration: {e}")
            return False
    
    def _config_to_dict(self, config: AppConfig) -> Dict[str, Any]:
        """Convert configuration to dictionary for serialization."""
        return {
            "server": self.loader._dataclass_to_dict(config.server),
            "llm": self.loader._dataclass_to_dict(config.llm),
            "plugins": {
                plugin_id: {
                    "enabled": plugin_config.enabled,
                    "config": plugin_config.config,
                    "priority": plugin_config.priority
                }
                for plugin_id, plugin_config in config.plugin_configs.items()
            },
            "phases": dict(config.phase_configs),
            "plugin_directories": list(config.plugin_directories),
            "environment": config.environment
        }
```

## Integration with Plugin System

The configuration system integrates with the plugin system through:

1. **Plugin Configuration**: Each plugin has its own configuration section
2. **Dynamic Updates**: Plugin configurations can be updated at runtime
3. **Phase Configuration**: Phase-specific settings for future development
4. **Validation**: Plugin configurations are validated before application

## Usage Example

```python
# Initialize configuration manager
config_manager = ConfigurationManager("config.json")

# Access configuration
print(f"Server running on {config_manager.config.server.host}:{config_manager.config.server.port}")
print(f"Using LLM: {config_manager.config.llm.default_model}")

# Configure plugin
config_manager.set_plugin_config_value("security_plugin", "strict_mode", True)
config_manager.enable_plugin("security_plugin")

# Register for configuration changes
def on_config_change(new_config: AppConfig):
    print(f"Configuration updated: environment = {new_config.environment}")

config_manager.register_config_callback(on_config_change)

# Save configuration
config_manager.save_configuration("updated_config.json")
```

## Configuration File Format

Example configuration file format:

```json
{
  "server": {
    "host": "localhost",
    "port": 8000,
    "debug": false,
    "log_level": "INFO",
    "max_concurrent_requests": 10,
    "request_timeout_seconds": 30
  },
  "llm": {
    "default_provider": "ollama",
    "default_model": "llama3.1:8b",
    "max_tokens": 4000,
    "temperature": 0.7,
    "ollama_base_url": "http://localhost:11434"
  },
  "plugins": {
    "security_plugin": {
      "enabled": true,
      "config": {
        "strict_mode": true,
        "audit_log": true
      },
      "priority": 100
    },
    "performance_plugin": {
      "enabled": true,
      "config": {
        "collect_metrics": true
      },
      "priority": 90
    }
  },
  "phases": {
    "phase2_rag": {
      "vector_db_url": "http://localhost:6333",
      "embedding_model": "all-MiniLM-L6-v2"
    }
  },
  "plugin_directories": ["./plugins", "/usr/local/lib/mcp-plugins"],
  "environment": "development"
}
```

## Future Phase Extensions

This configuration system provides extension points for future phases:

- **Phase 2 RAG**: Vector database and embedding configurations
- **Phase 3 sAgents**: Agent coordination and communication settings
- **Phase 4 Autonomy**: Self-improvement and learning parameters

All extensions use the phase configuration pattern without modifying core configuration structure. 