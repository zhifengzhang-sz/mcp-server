# Tools Implementation

> **Functional Tool Registry with Adapter Pattern**  
> **Design Source**: [Component Design](../design/component.phase.1.md), [Class Design](../design/classes.phase.1.md)  
> **Implementation**: Python 3.12+ with Functional Programming Patterns  
> **Purpose**: Immutable tool system with plugin-extensible adapters

## Overview

This document implements the functional tool registry system that enables tool enhancement through adapter patterns without modifying core tools. The implementation follows functional programming principles with immutable operations and plugin extension points.

## Functional Tool Registry Architecture

### Core Tool Registry Implementation

```python
from typing import Dict, List, Optional, Any, Callable, Tuple
from dataclasses import dataclass, field
from abc import ABC, abstractmethod
import asyncio
from functools import reduce
from models import Tool, ToolId, PluginId, Context, ToolRequest, ToolResult

@dataclass(frozen=True)
class FunctionalToolRegistry:
    """
    Immutable tool registry with functional adapter patterns.
    
    Implements tool management with pure functional operations and adapter chains.
    """
    tools: Dict[ToolId, Tool] = field(default_factory=dict)
    adapters: Dict[ToolId, Tuple[Any, ...]] = field(default_factory=dict)  # ToolAdapter chains
    execution_metadata: Dict[ToolId, Dict[str, Any]] = field(default_factory=dict)
    
    def register_tool(self, tool: Tool) -> 'FunctionalToolRegistry':
        """
        Register a tool immutably.
        
        Args:
            tool: Tool to register
            
        Returns:
            New FunctionalToolRegistry with tool registered
        """
        return FunctionalToolRegistry(
            tools={**self.tools, tool.id: tool},
            adapters=self.adapters,
            execution_metadata=self.execution_metadata
        )
    
    def unregister_tool(self, tool_id: ToolId) -> 'FunctionalToolRegistry':
        """Remove tool immutably."""
        if tool_id not in self.tools:
            return self
        
        new_tools = {k: v for k, v in self.tools.items() if k != tool_id}
        new_adapters = {k: v for k, v in self.adapters.items() if k != tool_id}
        new_metadata = {k: v for k, v in self.execution_metadata.items() if k != tool_id}
        
        return FunctionalToolRegistry(
            tools=new_tools,
            adapters=new_adapters,
            execution_metadata=new_metadata
        )
    
    def add_adapter(self, tool_id: ToolId, adapter: 'ToolAdapter') -> 'FunctionalToolRegistry':
        """
        Add adapter to tool immutably.
        
        Args:
            tool_id: Tool to enhance
            adapter: Tool adapter to add
            
        Returns:
            New registry with adapter added
        """
        if tool_id not in self.tools:
            raise ValueError(f"Tool {tool_id} not found")
        
        current_adapters = self.adapters.get(tool_id, tuple())
        new_adapters = current_adapters + (adapter,)
        
        return FunctionalToolRegistry(
            tools=self.tools,
            adapters={**self.adapters, tool_id: new_adapters},
            execution_metadata=self.execution_metadata
        )
    
    def get_tool(self, tool_id: ToolId) -> Optional[Tool]:
        """Get tool by ID."""
        return self.tools.get(tool_id)
    
    def get_adapters(self, tool_id: ToolId) -> Tuple['ToolAdapter', ...]:
        """Get adapter chain for tool."""
        return self.adapters.get(tool_id, tuple())
    
    def list_tools(self) -> List[Tool]:
        """List all registered tools."""
        return list(self.tools.values())
    
    def with_metadata(self, tool_id: ToolId, metadata: Dict[str, Any]) -> 'FunctionalToolRegistry':
        """Add execution metadata immutably."""
        new_metadata = {**self.execution_metadata, tool_id: metadata}
        return FunctionalToolRegistry(
            tools=self.tools,
            adapters=self.adapters,
            execution_metadata=new_metadata
        )
```

### Tool Adapter Interface and Implementation

```python
class ToolAdapter(ABC):
    """
    Abstract base class for tool adapters.
    
    Tool adapters enhance tools through functional composition without modifying originals.
    """
    
    @property
    @abstractmethod
    def adapter_name(self) -> str:
        """Adapter identifier."""
        pass
    
    @property
    @abstractmethod
    def adapter_version(self) -> str:
        """Adapter version."""
        pass
    
    @abstractmethod
    async def enhance_tool(self, tool: Tool) -> Tool:
        """
        Enhance tool immutably.
        
        Args:
            tool: Original tool
            
        Returns:
            Enhanced tool (original unchanged)
        """
        pass
    
    @abstractmethod
    async def enhance_request(self, request: ToolRequest, tool: Tool) -> ToolRequest:
        """
        Enhance tool request before execution.
        
        Args:
            request: Original request
            tool: Tool being executed
            
        Returns:
            Enhanced request
        """
        pass
    
    @abstractmethod
    async def enhance_result(self, result: ToolResult, tool: Tool, request: ToolRequest) -> ToolResult:
        """
        Enhance tool result after execution.
        
        Args:
            result: Original result
            tool: Tool that was executed  
            request: Original request
            
        Returns:
            Enhanced result
        """
        pass

# Base tool adapters for Phase 1
class SecurityToolAdapter(ToolAdapter):
    """Security adapter for tool access control."""
    
    @property
    def adapter_name(self) -> str:
        return "security_adapter"
    
    @property
    def adapter_version(self) -> str:
        return "1.0.0"
    
    async def enhance_tool(self, tool: Tool) -> Tool:
        """Add security metadata to tool."""
        security_data = {
            "permissions_required": ["tool_execute"],
            "sandbox_enabled": True,
            "security_level": "standard"
        }
        return tool.with_adapter_data(self.adapter_name, security_data)
    
    async def enhance_request(self, request: ToolRequest, tool: Tool) -> ToolRequest:
        """Validate security context before execution."""
        # TODO: Implement security validation
        return request
    
    async def enhance_result(self, result: ToolResult, tool: Tool, request: ToolRequest) -> ToolResult:
        """Add security audit trail to result."""
        security_metadata = {
            "security_validated": True,
            "audit_timestamp": datetime.utcnow().isoformat(),
            "permissions_checked": True
        }
        return result.with_metadata(security_metadata)

class PerformanceToolAdapter(ToolAdapter):
    """Performance monitoring adapter."""
    
    @property
    def adapter_name(self) -> str:
        return "performance_adapter"
    
    @property
    def adapter_version(self) -> str:
        return "1.0.0"
    
    async def enhance_tool(self, tool: Tool) -> Tool:
        """Add performance tracking metadata."""
        perf_data = {
            "tracking_enabled": True,
            "metrics_collected": ["execution_time", "memory_usage", "cpu_usage"]
        }
        return tool.with_adapter_data(self.adapter_name, perf_data)
    
    async def enhance_request(self, request: ToolRequest, tool: Tool) -> ToolRequest:
        """Add performance tracking to request."""
        return request
    
    async def enhance_result(self, result: ToolResult, tool: Tool, request: ToolRequest) -> ToolResult:
        """Add performance metrics to result."""
        perf_metadata = {
            "execution_time_ms": result.execution_time_ms,
            "memory_peak_mb": 0,  # TODO: Implement memory tracking
            "cpu_usage_percent": 0  # TODO: Implement CPU tracking
        }
        return result.with_metadata(perf_metadata)
```

### Functional Tool Execution Engine

```python
class FunctionalToolExecutor:
    """
    Tool execution engine with functional adapter composition.
    
    Executes tools through adapter chains using pure functional patterns.
    """
    
    def __init__(self, registry: FunctionalToolRegistry):
        self.registry = registry
    
    async def execute_tool(self, tool_id: ToolId, request: ToolRequest) -> ToolResult:
        """
        Execute tool with full adapter chain processing.
        
        Args:
            tool_id: Tool to execute
            request: Tool request
            
        Returns:
            Enhanced tool result
        """
        tool = self.registry.get_tool(tool_id)
        if not tool:
            return ToolResult(
                request_id=request.request_id,
                success=False,
                error=f"Tool {tool_id} not found"
            )
        
        adapters = self.registry.get_adapters(tool_id)
        
        try:
            # Step 1: Apply tool enhancements through adapter chain
            enhanced_tool = await self._apply_tool_adapters(tool, adapters)
            
            # Step 2: Apply request enhancements through adapter chain
            enhanced_request = await self._apply_request_adapters(request, enhanced_tool, adapters)
            
            # Step 3: Execute the tool
            result = await self._execute_core_tool(enhanced_tool, enhanced_request)
            
            # Step 4: Apply result enhancements through adapter chain
            enhanced_result = await self._apply_result_adapters(result, enhanced_tool, enhanced_request, adapters)
            
            return enhanced_result
            
        except Exception as e:
            return ToolResult(
                request_id=request.request_id,
                success=False,
                error=f"Tool execution failed: {str(e)}"
            )
    
    async def _apply_tool_adapters(self, tool: Tool, adapters: Tuple[ToolAdapter, ...]) -> Tool:
        """
        Apply tool adapter chain using functional composition.
        
        Functional pattern: fold(adapter.enhance_tool, tool, adapters)
        """
        async def apply_adapter(current_tool: Tool, adapter: ToolAdapter) -> Tool:
            try:
                return await adapter.enhance_tool(current_tool)
            except Exception as e:
                # Log error but continue with current tool
                print(f"Tool adapter {adapter.adapter_name} failed: {e}")
                return current_tool
        
        # Functional composition using asyncio
        result_tool = tool
        for adapter in adapters:
            result_tool = await apply_adapter(result_tool, adapter)
        
        return result_tool
    
    async def _apply_request_adapters(self, request: ToolRequest, tool: Tool, adapters: Tuple[ToolAdapter, ...]) -> ToolRequest:
        """Apply request enhancement adapter chain."""
        async def apply_adapter(current_request: ToolRequest, adapter: ToolAdapter) -> ToolRequest:
            try:
                return await adapter.enhance_request(current_request, tool)
            except Exception as e:
                print(f"Request adapter {adapter.adapter_name} failed: {e}")
                return current_request
        
        result_request = request
        for adapter in adapters:
            result_request = await apply_adapter(result_request, adapter)
        
        return result_request
    
    async def _apply_result_adapters(self, result: ToolResult, tool: Tool, request: ToolRequest, adapters: Tuple[ToolAdapter, ...]) -> ToolResult:
        """Apply result enhancement adapter chain."""
        async def apply_adapter(current_result: ToolResult, adapter: ToolAdapter) -> ToolResult:
            try:
                return await adapter.enhance_result(current_result, tool, request)
            except Exception as e:
                print(f"Result adapter {adapter.adapter_name} failed: {e}")
                return current_result
        
        result_result = result
        for adapter in adapters:
            result_result = await apply_adapter(result_result, adapter)
        
        return result_result
    
    async def _execute_core_tool(self, tool: Tool, request: ToolRequest) -> ToolResult:
        """Execute the core tool functionality."""
        # This would delegate to actual tool implementations
        # For now, return a placeholder result
        return ToolResult(
            request_id=request.request_id,
            success=True,
            result={"tool_executed": tool.id, "request_params": request.parameters}
        )
```

### Core Tool Implementations

```python
class FileReadTool(Tool):
    """File reading tool implementation."""
    
    def __init__(self):
        super().__init__(
            id="file_read",
            name="File Reader", 
            description="Read file contents from filesystem"
        )
    
    async def execute(self, request: ToolRequest) -> ToolResult:
        """Execute file read operation."""
        try:
            file_path = request.parameters.get("path")
            if not file_path:
                return ToolResult(
                    request_id=request.request_id,
                    success=False,
                    error="Missing 'path' parameter"
                )
            
            # TODO: Implement actual file reading with security checks
            content = f"File content from {file_path}"
            
            return ToolResult(
                request_id=request.request_id,
                success=True,
                result={"content": content, "path": file_path}
            )
            
        except Exception as e:
            return ToolResult(
                request_id=request.request_id,
                success=False,
                error=str(e)
            )

class ExecuteCommandTool(Tool):
    """Command execution tool implementation."""
    
    def __init__(self):
        super().__init__(
            id="execute_command",
            name="Command Executor",
            description="Execute shell commands safely"
        )
    
    async def execute(self, request: ToolRequest) -> ToolResult:
        """Execute shell command."""
        try:
            command = request.parameters.get("command")
            if not command:
                return ToolResult(
                    request_id=request.request_id,
                    success=False,
                    error="Missing 'command' parameter"
                )
            
            # TODO: Implement actual command execution with security sandbox
            output = f"Command output from: {command}"
            
            return ToolResult(
                request_id=request.request_id,
                success=True,
                result={"output": output, "command": command, "exit_code": 0}
            )
            
        except Exception as e:
            return ToolResult(
                request_id=request.request_id,
                success=False,
                error=str(e)
            )
```

### Tool Registry Manager

```python
class ToolRegistryManager:
    """
    High-level tool registry management.
    
    Coordinates tool registration, adapter management, and execution.
    """
    
    def __init__(self, initial_registry: Optional[FunctionalToolRegistry] = None):
        self.registry = initial_registry or FunctionalToolRegistry()
        self.executor = FunctionalToolExecutor(self.registry)
    
    async def register_tool(self, tool: Tool) -> None:
        """Register a tool with the registry."""
        self.registry = self.registry.register_tool(tool)
        self.executor = FunctionalToolExecutor(self.registry)
    
    async def add_tool_adapter(self, tool_id: ToolId, adapter: ToolAdapter) -> None:
        """Add adapter to a tool."""
        self.registry = self.registry.add_adapter(tool_id, adapter)
        self.executor = FunctionalToolExecutor(self.registry)
    
    async def execute_tool(self, tool_id: ToolId, parameters: Dict[str, Any], context: Optional[Context] = None) -> ToolResult:
        """Execute tool with parameters."""
        request = ToolRequest(
            tool_id=tool_id,
            parameters=parameters,
            context=context
        )
        return await self.executor.execute_tool(tool_id, request)
    
    def get_available_tools(self) -> List[Tool]:
        """Get list of all available tools."""
        return self.registry.list_tools()
    
    def get_tool_adapters(self, tool_id: ToolId) -> List[str]:
        """Get list of adapter names for a tool."""
        adapters = self.registry.get_adapters(tool_id)
        return [adapter.adapter_name for adapter in adapters]
```

## Integration with Plugin System

The tool system integrates with the plugin system through:

1. **ToolAdapter as Plugin**: Tool adapters implement the plugin interface
2. **Adapter Registration**: Plugins can register tool adapters dynamically
3. **Functional Composition**: Adapter chains use functional composition patterns
4. **Extension Points**: Tools have adapter metadata for plugin enhancements

## Usage Example

```python
# Initialize tool registry
tool_manager = ToolRegistryManager()

# Register core tools
await tool_manager.register_tool(FileReadTool())
await tool_manager.register_tool(ExecuteCommandTool())

# Add security and performance adapters
security_adapter = SecurityToolAdapter()
performance_adapter = PerformanceToolAdapter()

await tool_manager.add_tool_adapter("file_read", security_adapter)
await tool_manager.add_tool_adapter("file_read", performance_adapter)

# Execute tool with adapter chain
result = await tool_manager.execute_tool(
    "file_read", 
    {"path": "/src/main.py"}
)
```

## Future Phase Extensions

This tool system provides extension points for future phases:

- **Phase 2 RAG**: Semantic tool adapters for context-aware execution
- **Phase 3 sAgents**: Agent coordination adapters for multi-agent tool usage
- **Phase 4 Autonomy**: Self-improving tool adapters that optimize based on usage patterns

All extensions use the same adapter pattern without modifying core tool implementations. 