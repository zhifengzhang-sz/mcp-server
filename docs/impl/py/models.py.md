# Data Models Implementation

> **Immutable Data Structures for Plugin-Ready Architecture**  
> **Design Source**: [Class Design](../design/classes.phase.1.md), [Flow Design](../design/flow.phase.1.md)  
> **Implementation**: Python 3.12+ with Pydantic and Functional Patterns  
> **Purpose**: Type-safe immutable data models for plugin system

## Overview

This document defines all immutable data structures used throughout the MCP server implementation. All models follow functional programming principles with immutable data, validation, and plugin extension points.

## Core Data Models

### Base Types and Enums

```python
from typing import Dict, List, Optional, Any, Union, Tuple, Literal
from dataclasses import dataclass, field
from pydantic import BaseModel, Field, validator
from enum import Enum
from datetime import datetime
import uuid

# Type Aliases
SessionId = str
PluginId = str
ToolId = str
EventId = str
RequestId = str
ContextId = str
```

### MCP Protocol Models

```python
class MCPRequestMethod(str, Enum):
    """Supported MCP request methods."""
    INITIALIZE = "initialize"
    TOOLS_LIST = "tools/list"
    TOOLS_CALL = "tools/call"
    RESOURCES_LIST = "resources/list"
    RESOURCES_READ = "resources/read"
    PROMPTS_LIST = "prompts/list"
    PROMPTS_GET = "prompts/get"
    COMPLETION = "completion"

@dataclass(frozen=True)
class MCPRequest:
    """
    Immutable MCP request model.
    
    Represents all MCP protocol requests with plugin extension points.
    """
    id: RequestId = field(default_factory=lambda: str(uuid.uuid4()))
    method: MCPRequestMethod = MCPRequestMethod.INITIALIZE
    params: Dict[str, Any] = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    session_id: Optional[SessionId] = None
    # Plugin extension point
    plugin_metadata: Dict[str, Any] = field(default_factory=dict)
    
    def with_plugin_data(self, plugin_id: PluginId, data: Dict[str, Any]) -> 'MCPRequest':
        """Add plugin metadata immutably."""
        new_metadata = {**self.plugin_metadata, plugin_id: data}
        return dataclass.replace(self, plugin_metadata=new_metadata)
    
    def get_plugin_data(self, plugin_id: PluginId) -> Optional[Dict[str, Any]]:
        """Get plugin-specific metadata."""
        return self.plugin_metadata.get(plugin_id)

@dataclass(frozen=True)
class MCPResponse:
    """
    Immutable MCP response model.
    
    Represents all MCP protocol responses with plugin enhancements.
    """
    id: RequestId
    result: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    # Plugin extension point
    plugin_enhancements: Dict[str, Any] = field(default_factory=dict)
    performance_metrics: Dict[str, Union[int, float]] = field(default_factory=dict)
    
    def with_enhancement(self, plugin_id: PluginId, enhancement: Dict[str, Any]) -> 'MCPResponse':
        """Add plugin enhancement immutably."""
        new_enhancements = {**self.plugin_enhancements, plugin_id: enhancement}
        return dataclass.replace(self, plugin_enhancements=new_enhancements)
    
    def with_metrics(self, metrics: Dict[str, Union[int, float]]) -> 'MCPResponse':
        """Add performance metrics immutably."""
        new_metrics = {**self.performance_metrics, **metrics}
        return dataclass.replace(self, performance_metrics=new_metrics)
```

### Context Models

```python
@dataclass(frozen=True)
class Interaction:
    """Immutable interaction record."""
    timestamp: str
    query: str
    response: str
    tool_calls: Tuple[str, ...] = field(default_factory=tuple)
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass(frozen=True)
class WorkspaceSnapshot:
    """Immutable workspace state snapshot."""
    root_path: str
    files_modified: Tuple[str, ...] = field(default_factory=tuple)
    git_branch: Optional[str] = None
    git_commit: Optional[str] = None
    project_type: Optional[str] = None
    dependencies: Dict[str, str] = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())

@dataclass(frozen=True)
class SystemInfo:
    """Immutable system context information."""
    platform: str
    architecture: str
    python_version: str
    memory_available: int
    cpu_count: int
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())

@dataclass(frozen=True)
class Context:
    """
    Immutable context model with plugin extension points.
    
    Central context object enhanced by plugin adapter chains.
    """
    context_id: ContextId = field(default_factory=lambda: str(uuid.uuid4()))
    session_id: SessionId = ""
    conversation_history: Tuple[Interaction, ...] = field(default_factory=tuple)
    workspace_state: Optional[WorkspaceSnapshot] = None
    system_context: Optional[SystemInfo] = None
    query_context: Dict[str, Any] = field(default_factory=dict)
    # Plugin extension point - Phase 2-4 adapters add data here
    extension_context: Dict[str, Any] = field(default_factory=dict)
    assembly_metadata: Dict[str, Any] = field(default_factory=dict)
    token_count: int = 0
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    
    def add_interaction(self, interaction: Interaction) -> 'Context':
        """Add interaction to conversation history immutably."""
        new_history = self.conversation_history + (interaction,)
        return dataclass.replace(self, conversation_history=new_history)
    
    def with_workspace(self, workspace: WorkspaceSnapshot) -> 'Context':
        """Set workspace state immutably."""
        return dataclass.replace(self, workspace_state=workspace)
    
    def with_extension(self, plugin_id: PluginId, data: Dict[str, Any]) -> 'Context':
        """Add plugin extension data immutably."""
        new_extensions = {**self.extension_context, plugin_id: data}
        return dataclass.replace(self, extension_context=new_extensions)
    
    def get_extension(self, plugin_id: PluginId) -> Optional[Dict[str, Any]]:
        """Get plugin extension data."""
        return self.extension_context.get(plugin_id)
    
    def with_metadata(self, metadata: Dict[str, Any]) -> 'Context':
        """Add assembly metadata immutably."""
        new_metadata = {**self.assembly_metadata, **metadata}
        return dataclass.replace(self, assembly_metadata=new_metadata)
    
    def with_token_count(self, count: int) -> 'Context':
        """Set token count immutably."""
        return dataclass.replace(self, token_count=count)
```

### Tool Models

```python
class ToolParameterType(str, Enum):
    """Tool parameter types."""
    STRING = "string"
    INTEGER = "integer"
    NUMBER = "number"
    BOOLEAN = "boolean"
    OBJECT = "object"
    ARRAY = "array"

@dataclass(frozen=True)
class ToolParameter:
    """Immutable tool parameter definition."""
    name: str
    type: ToolParameterType
    description: str
    required: bool = True
    default: Optional[Any] = None
    enum_values: Optional[Tuple[Any, ...]] = None

@dataclass(frozen=True)
class ToolSchema:
    """Immutable tool schema definition."""
    name: str
    description: str
    parameters: Tuple[ToolParameter, ...] = field(default_factory=tuple)
    returns: Optional[str] = None

@dataclass(frozen=True)
class ToolRequest:
    """Immutable tool execution request."""
    tool_id: ToolId
    parameters: Dict[str, Any] = field(default_factory=dict)
    context: Optional[Context] = None
    request_id: RequestId = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())

@dataclass(frozen=True)
class ToolResult:
    """Immutable tool execution result."""
    request_id: RequestId
    success: bool
    result: Optional[Any] = None
    error: Optional[str] = None
    execution_time_ms: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    
    def with_metadata(self, metadata: Dict[str, Any]) -> 'ToolResult':
        """Add metadata immutably."""
        new_metadata = {**self.metadata, **metadata}
        return dataclass.replace(self, metadata=new_metadata)

@dataclass(frozen=True)
class Tool:
    """
    Immutable tool model with plugin enhancement points.
    
    Tools can be enhanced by ToolAdapter plugins without modification.
    """
    id: ToolId
    name: str
    description: str
    # Plugin extension point
    adapter_metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    
    def with_adapter_data(self, plugin_id: PluginId, data: Dict[str, Any]) -> 'Tool':
        """Add adapter metadata immutably."""
        new_metadata = {**self.adapter_metadata, plugin_id: data}
        return dataclass.replace(self, adapter_metadata=new_metadata)
```

### Session and Event Models

```python
class SessionEventType(str, Enum):
    """Session event types for event sourcing."""
    SESSION_CREATED = "session_created"
    INTERACTION_RECORDED = "interaction_recorded"
    CONTEXT_ASSEMBLED = "context_assembled"
    TOOL_EXECUTED = "tool_executed"
    PLUGIN_PROCESSED = "plugin_processed"
    ERROR_OCCURRED = "error_occurred"
    SESSION_ENDED = "session_ended"

@dataclass(frozen=True)
class SessionEvent:
    """
    Immutable session event for event sourcing.
    
    Events can be processed by EventHandler plugins.
    """
    event_id: EventId = field(default_factory=lambda: str(uuid.uuid4()))
    event_type: SessionEventType = SessionEventType.SESSION_CREATED
    session_id: SessionId = ""
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    payload: Dict[str, Any] = field(default_factory=dict)
    # Plugin extension point
    handler_metadata: Dict[str, Any] = field(default_factory=dict)
    
    def with_handler_data(self, plugin_id: PluginId, data: Dict[str, Any]) -> 'SessionEvent':
        """Add handler metadata immutably."""
        new_metadata = {**self.handler_metadata, plugin_id: data}
        return dataclass.replace(self, handler_metadata=new_metadata)

class SessionStatus(str, Enum):
    """Session status states."""
    ACTIVE = "active"
    IDLE = "idle"
    ENDED = "ended"
    ERROR = "error"

@dataclass(frozen=True)
class SessionState:
    """
    Immutable session state reconstructed from events.
    
    State is derived from event stream through functional projection.
    """
    session_id: SessionId
    status: SessionStatus = SessionStatus.ACTIVE
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    last_activity: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    interaction_count: int = 0
    context_cache: Optional[Context] = None
    # Plugin extension point
    plugin_state: Dict[str, Any] = field(default_factory=dict)
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def with_interaction(self) -> 'SessionState':
        """Increment interaction count immutably."""
        return dataclass.replace(
            self,
            interaction_count=self.interaction_count + 1,
            last_activity=datetime.utcnow().isoformat()
        )
    
    def with_context(self, context: Context) -> 'SessionState':
        """Cache context immutably."""
        return dataclass.replace(self, context_cache=context)
    
    def with_plugin_state(self, plugin_id: PluginId, state: Dict[str, Any]) -> 'SessionState':
        """Update plugin state immutably."""
        new_plugin_state = {**self.plugin_state, plugin_id: state}
        return dataclass.replace(self, plugin_state=new_plugin_state)
    
    def with_status(self, status: SessionStatus) -> 'SessionState':
        """Update status immutably."""
        return dataclass.replace(
            self,
            status=status,
            last_activity=datetime.utcnow().isoformat()
        )

@dataclass(frozen=True)
class Session:
    """
    Immutable session model with event sourcing.
    
    Complete session representation with event history.
    """
    session_id: SessionId = field(default_factory=lambda: str(uuid.uuid4()))
    events: Tuple[SessionEvent, ...] = field(default_factory=tuple)
    current_state: SessionState = field(default_factory=lambda: SessionState(session_id=""))
    
    def append_event(self, event: SessionEvent) -> 'Session':
        """Append event immutably."""
        new_events = self.events + (event,)
        return dataclass.replace(self, events=new_events)
    
    def with_state(self, state: SessionState) -> 'Session':
        """Update current state immutably."""
        return dataclass.replace(self, current_state=state)
```

### Configuration Models

```python
class LogLevel(str, Enum):
    """Logging levels."""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

@dataclass(frozen=True)
class PluginConfig:
    """Plugin-specific configuration."""
    enabled: bool = True
    config: Dict[str, Any] = field(default_factory=dict)
    priority: int = 100

@dataclass(frozen=True)
class ServerConfig:
    """
    Immutable server configuration model.
    
    Central configuration with plugin extension points.
    """
    # Core server settings
    host: str = "localhost"
    port: int = 8000
    debug: bool = False
    log_level: LogLevel = LogLevel.INFO
    
    # LLM settings
    default_model: str = "llama3.1:8b"
    max_tokens: int = 4000
    temperature: float = 0.7
    
    # Performance settings
    max_concurrent_requests: int = 10
    request_timeout_seconds: int = 30
    cache_size_mb: int = 100
    
    # Plugin settings
    plugin_configs: Dict[str, PluginConfig] = field(default_factory=dict)
    plugin_directories: Tuple[str, ...] = field(default_factory=tuple)
    
    # Extension point for Phase 2-4 configs
    phase_configs: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    
    def with_plugin_config(self, plugin_id: str, config: PluginConfig) -> 'ServerConfig':
        """Set plugin configuration immutably."""
        new_configs = {**self.plugin_configs, plugin_id: config}
        return dataclass.replace(self, plugin_configs=new_configs)
    
    def with_phase_config(self, phase: str, config: Dict[str, Any]) -> 'ServerConfig':
        """Set phase configuration immutably."""
        new_phase_configs = {**self.phase_configs, phase: config}
        return dataclass.replace(self, phase_configs=new_phase_configs)
```

## Model Validation with Pydantic

```python
from pydantic import BaseModel, validator
from typing import Any

class MCPRequestValidator(BaseModel):
    """Pydantic model for MCP request validation."""
    id: str
    method: MCPRequestMethod
    params: Dict[str, Any]
    session_id: Optional[str] = None
    
    @validator('method')
    def validate_method(cls, v):
        if v not in MCPRequestMethod:
            raise ValueError(f"Invalid method: {v}")
        return v
    
    @validator('params')
    def validate_params(cls, v):
        if not isinstance(v, dict):
            raise ValueError("Params must be a dictionary")
        return v

class ContextValidator(BaseModel):
    """Pydantic model for context validation."""
    context_id: str
    session_id: str
    token_count: int
    
    @validator('token_count')
    def validate_token_count(cls, v):
        if v < 0:
            raise ValueError("Token count cannot be negative")
        return v
```

## Model Factories

```python
class ModelFactory:
    """Factory for creating model instances with defaults."""
    
    @staticmethod
    def create_mcp_request(method: MCPRequestMethod, params: Dict[str, Any], session_id: Optional[str] = None) -> MCPRequest:
        """Create MCP request with defaults."""
        return MCPRequest(
            method=method,
            params=params,
            session_id=session_id
        )
    
    @staticmethod
    def create_context(session_id: SessionId) -> Context:
        """Create empty context for session."""
        return Context(session_id=session_id)
    
    @staticmethod
    def create_session(session_id: Optional[SessionId] = None) -> Session:
        """Create new session with initial state."""
        sid = session_id or str(uuid.uuid4())
        initial_state = SessionState(session_id=sid)
        return Session(session_id=sid, current_state=initial_state)
    
    @staticmethod
    def create_tool_schema(name: str, description: str, parameters: List[ToolParameter]) -> ToolSchema:
        """Create tool schema with validation."""
        return ToolSchema(
            name=name,
            description=description,
            parameters=tuple(parameters)
        )
```

## Integration with Plugin System

These models integrate with the plugin system through extension points:

- **MCPRequest/MCPResponse**: Plugin metadata for request/response enhancement
- **Context**: Extension context for plugin-specific data (RAG, agents, autonomy)  
- **Tool**: Adapter metadata for tool enhancements
- **SessionEvent**: Handler metadata for event processing
- **ServerConfig**: Plugin and phase-specific configurations

## Usage Examples

```python
# Create context with plugin extensions
context = ModelFactory.create_context("session-123")
context = context.with_extension("rag_plugin", {"semantic_context": "..."})
context = context.with_extension("agent_plugin", {"agent_state": "..."})

# Create tool request with context
tool_request = ToolRequest(
    tool_id="file_read",
    parameters={"path": "/src/main.py"},
    context=context
)

# Create session event with handler data
event = SessionEvent(
    event_type=SessionEventType.TOOL_EXECUTED,
    session_id="session-123",
    payload={"tool_id": "file_read", "success": True}
)
event = event.with_handler_data("monitoring_plugin", {"logged": True})
```

## Type Safety and Validation

All models provide:
- **Immutability**: Dataclass frozen=True prevents mutation
- **Type Safety**: Full type hints for IDE support and mypy
- **Validation**: Pydantic validators for runtime safety
- **Plugin Extension**: Extension points maintain type safety
- **Factory Methods**: Consistent object creation patterns

This model system enables the functional programming patterns throughout the implementation while providing clean plugin extension points for future phases. 