# Interface Layer Implementation Design

> Python Implementation: CLI and MCP Protocol Interfaces  
> Design Phase: Implementation Architecture  
> Layer: Interface - User Interaction  
> File Structure: `mcp_server/interfaces/`

## Overview

This document specifies the Python implementation strategy for the Interface Layer, including CLI interface with typer, MCP protocol handling with FastAPI, and session management.

**Core Requirement**: Provide responsive, user-friendly interfaces with sub-100ms response times for interactive operations.

## Architecture Overview

```
Interface Layer
├── CLIInterface (typer-based command interface)
├── MCPInterface (FastAPI-based protocol handler)
├── SessionManager (Session lifecycle management)
├── RequestValidator (Input validation and sanitization)
└── ResponseFormatter (Output formatting and streaming)
```

## Package Integration Strategy

### CLI Framework: typer Integration
```python
# Implementation Design
# mcp_server/interfaces/cli/cli_handler.py

import typer
from pathlib import Path
from typing import Optional
import asyncio

app = typer.Typer(
    name="qicore",
    help="MCP Intelligent Agent Server CLI",
    add_completion=False
)

class CLIHandler:
    """typer-based CLI interface with async support"""
    
    def __init__(self):
        self.config: Optional[Path] = None
        self.verbose: int = 0
    
    @app.callback()
    def main(
        self,
        config: Optional[Path] = typer.Option(None, "--config", help="Configuration file path"),
        verbose: int = typer.Option(0, "--verbose", "-v", count=True, help="Verbose output")
    ):
        """MCP Intelligent Agent Server CLI"""
        self.config = config
        self.verbose = verbose
        setup_logging(verbose)
    
    # Core Commands
    @app.command()
    def ask(
        self,
        query: str = typer.Argument(..., help="Question to ask the agent"),
        context: Optional[str] = typer.Option(None, "--context", "-c", help="Additional context"),
        workspace: Optional[Path] = typer.Option(None, "--workspace", "-w", help="Workspace path"),
        stream: bool = typer.Option(False, "--stream", help="Stream response")
    ):
        """Ask the intelligent agent a question"""
        
        # Create request
        request = CLIRequest(
            query=query,
            context=context,
            workspace_path=workspace,
            stream_response=stream
        )
        
        # Process through orchestration
        result = asyncio.run(self.orchestrator.process_request(request))
        
        # Format and display response
        if stream:
            asyncio.run(self.stream_response(result))
        else:
            typer.echo(self.format_response(result))
    
    # Async Command Wrapper
    def async_command(f):
        """Decorator to handle async commands in typer"""
        @functools.wraps(f)
        def wrapper(*args, **kwargs):
            return asyncio.run(f(*args, **kwargs))
        return wrapper
```

### Web Framework: FastAPI Integration
```python
# Implementation Design
# mcp_server/interfaces/mcp/mcp_handler.py

class MCPHandler:
    """FastAPI-based MCP protocol implementation"""
    
    def __init__(self):
        self.app = FastAPI(
            title="MCP Intelligent Agent Server",
            version="1.0.0",
            description="Model Context Protocol server with intelligent agent capabilities"
        )
        self.setup_routes()
        self.setup_middleware()
    
    def setup_routes(self):
        """Configure MCP protocol routes"""
        
        @self.app.post("/mcp/initialize")
        async def initialize_session(request: InitializeRequest) -> InitializeResponse:
            """Initialize MCP session"""
            
            # Validate client capabilities
            supported_capabilities = self._validate_capabilities(request.capabilities)
            
            # Create session
            session = await self.session_manager.create_session(
                client_info=request.client_info,
                capabilities=supported_capabilities
            )
            
            return InitializeResponse(
                server_info=self.server_info,
                capabilities=self.server_capabilities,
                session_id=session.id
            )
        
        @self.app.post("/mcp/request")
        async def handle_request(request: MCPRequest) -> MCPResponse:
            """Handle MCP protocol request"""
            
            # Validate session
            session = await self.session_manager.get_session(request.session_id)
            if not session:
                raise HTTPException(status_code=401, detail="Invalid session")
            
            # Process request
            result = await self.orchestrator.process_request(
                ProcessingRequest.from_mcp(request, session)
            )
            
            return MCPResponse.from_processing_result(result)
        
        @self.app.websocket("/mcp/stream")
        async def websocket_endpoint(websocket: WebSocket):
            """WebSocket endpoint for streaming responses"""
            await websocket.accept()
            
            try:
                while True:
                    # Receive request
                    data = await websocket.receive_json()
                    request = StreamingRequest.parse_obj(data)
                    
                    # Process with streaming
                    async for chunk in self.orchestrator.process_streaming(request):
                        await websocket.send_json(chunk.dict())
                        
            except WebSocketDisconnect:
                logger.info("WebSocket client disconnected")
    
    def setup_middleware(self):
        """Configure middleware for security and monitoring"""
        
        # CORS middleware
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],  # Configure appropriately
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        # Request logging middleware
        @self.app.middleware("http")
        async def log_requests(request: Request, call_next):
            start_time = time.time()
            response = await call_next(request)
            process_time = time.time() - start_time
            
            logger.info(
                f"Request: {request.method} {request.url.path}",
                extra={
                    "duration_ms": int(process_time * 1000),
                    "status_code": response.status_code,
                    "client_ip": request.client.host
                }
            )
            return response
```

## Session Management Implementation

### Session Lifecycle Management
```python
# Implementation Design
# mcp_server/interfaces/sessions/session_manager.py

class SessionManager:
    """Unified session management for CLI and MCP"""
    
    def __init__(self):
        self.active_sessions: Dict[str, Session] = {}
        self.session_storage = SessionStorage()
        self.cleanup_task = None
    
    async def create_session(self, session_type: str, **kwargs) -> Session:
        """Create new session with proper initialization"""
        
        session_id = self._generate_session_id()
        
        if session_type == "cli":
            session = CLISession(
                id=session_id,
                user_id=kwargs.get('user_id'),
                workspace_path=kwargs.get('workspace_path'),
                created_at=datetime.utcnow()
            )
        elif session_type == "mcp":
            session = MCPSession(
                id=session_id,
                client_info=kwargs.get('client_info'),
                capabilities=kwargs.get('capabilities'),
                created_at=datetime.utcnow()
            )
        else:
            raise ValueError(f"Unknown session type: {session_type}")
        
        # Store session
        self.active_sessions[session_id] = session
        await self.session_storage.save_session(session)
        
        # Start session monitoring
        await self._start_session_monitoring(session)
        
        return session
    
    async def get_session(self, session_id: str) -> Optional[Session]:
        """Retrieve active session with validation"""
        
        session = self.active_sessions.get(session_id)
        if not session:
            # Try loading from storage
            session = await self.session_storage.load_session(session_id)
            if session and not session.is_expired():
                self.active_sessions[session_id] = session
        
        if session and session.is_expired():
            await self.close_session(session_id)
            return None
        
        return session
    
    # Session Context Management
    async def update_session_context(self, session_id: str, context_update: Dict):
        """Update session context with new information"""
        
        session = await self.get_session(session_id)
        if not session:
            return
        
        # Update context
        session.context.update(context_update)
        session.updated_at = datetime.utcnow()
        
        # Persist changes
        await self.session_storage.save_session(session)
    
    # Cleanup and Monitoring
    async def start_cleanup_task(self):
        """Start background task for session cleanup"""
        
        async def cleanup_loop():
            while True:
                await asyncio.sleep(300)  # Every 5 minutes
                await self._cleanup_expired_sessions()
        
        self.cleanup_task = asyncio.create_task(cleanup_loop())
    
    async def _cleanup_expired_sessions(self):
        """Clean up expired sessions"""
        
        expired_sessions = [
            session_id for session_id, session in self.active_sessions.items()
            if session.is_expired()
        ]
        
        for session_id in expired_sessions:
            await self.close_session(session_id)
```

## Request Processing Integration

### Request Validation and Processing
```python
# Implementation Design
# mcp_server/interfaces/processing/request_processor.py

class RequestProcessor:
    """Unified request processing for all interfaces"""
    
    async def process_cli_request(self, cli_request: CLIRequest) -> CLIResponse:
        """Process CLI request with proper formatting"""
        
        # Validate request
        validation_result = await self.validator.validate_cli_request(cli_request)
        if not validation_result.is_valid:
            return CLIResponse.error(validation_result.error_message)
        
        # Convert to internal format
        processing_request = ProcessingRequest(
            id=str(uuid.uuid4()),
            query=cli_request.query,
            user_id=cli_request.user_id,
            workspace_path=cli_request.workspace_path,
            source="cli",
            created_at=datetime.utcnow()
        )
        
        # Add CLI-specific context
        if cli_request.context:
            processing_request.additional_context = cli_request.context
        
        # Process through orchestration
        result = await self.orchestrator.process_request(processing_request)
        
        # Format response for CLI
        return self.formatter.format_cli_response(result)
    
    async def process_mcp_request(self, mcp_request: MCPRequest) -> MCPResponse:
        """Process MCP request with protocol compliance"""
        
        # Validate MCP protocol compliance
        validation_result = await self.validator.validate_mcp_request(mcp_request)
        if not validation_result.is_valid:
            return MCPResponse.error(
                code=validation_result.error_code,
                message=validation_result.error_message
            )
        
        # Convert to internal format
        processing_request = ProcessingRequest(
            id=mcp_request.id,
            query=mcp_request.params.get('query'),
            session_id=mcp_request.session_id,
            source="mcp",
            streaming=mcp_request.params.get('stream', False),
            created_at=datetime.utcnow()
        )
        
        # Process through orchestration
        result = await self.orchestrator.process_request(processing_request)
        
        # Format response for MCP protocol
        return self.formatter.format_mcp_response(result, mcp_request.id)
```

## File Structure Implementation

```
mcp_server/interfaces/
├── __init__.py                      # Public API exports
├── manager.py                       # InterfaceManager main class
├── models.py                        # Interface data models
├── exceptions.py                    # Interface-specific exceptions
├── config.py                        # Interface configuration
│
├── cli/                             # CLI interface
│   ├── __init__.py
│   ├── cli_handler.py               # typer-based CLI
│   ├── commands.py                  # CLI command definitions
│   ├── formatters.py                # CLI output formatting
│   └── async_support.py             # Async utilities for typer
│
├── mcp/                             # MCP protocol interface
│   ├── __init__.py
│   ├── mcp_handler.py               # FastAPI-based MCP server
│   ├── protocol.py                  # MCP protocol implementation
│   ├── validators.py                # MCP request validation
│   ├── serializers.py               # MCP message serialization
│   └── streaming.py                 # WebSocket streaming support
│
├── sessions/                        # Session management
│   ├── __init__.py
│   ├── session_manager.py           # SessionManager
│   ├── session_models.py            # Session data models
│   ├── session_storage.py           # Session persistence
│   └── session_cleanup.py           # Session cleanup utilities
│
├── processing/                      # Request processing
│   ├── __init__.py
│   ├── request_processor.py         # RequestProcessor
│   ├── validators.py                # Request validation
│   ├── formatters.py                # Response formatting
│   └── converters.py                # Format converters
│
└── monitoring/                      # Interface monitoring
    ├── __init__.py
    ├── metrics.py                   # Interface metrics
    ├── health_check.py              # Health endpoints
    └── logging.py                   # Interface logging
```

## Response Formatting and Streaming

### Multi-Format Response Handling
```python
# Implementation Design
# mcp_server/interfaces/formatting/response_formatter.py

class ResponseFormatter:
    """Multi-format response formatting"""
    
    def format_cli_response(self, result: ProcessingResult) -> str:
        """Format response for CLI display"""
        
        if result.success:
            formatted = self._format_success_response(result)
            
            # Add context information if verbose
            if result.show_context:
                formatted += self._format_context_info(result.context)
            
            # Add performance metrics if requested
            if result.show_metrics:
                formatted += self._format_performance_metrics(result.metrics)
            
            return formatted
        else:
            return self._format_error_response(result.error)
    
    def format_mcp_response(self, result: ProcessingResult, request_id: str) -> MCPResponse:
        """Format response for MCP protocol"""
        
        if result.success:
            return MCPResponse(
                id=request_id,
                result={
                    "content": result.content,
                    "metadata": result.metadata,
                    "context_used": result.context_summary
                }
            )
        else:
            return MCPResponse(
                id=request_id,
                error={
                    "code": result.error.code,
                    "message": result.error.message,
                    "data": result.error.details
                }
            )
    
    # Streaming Support
    async def stream_cli_response(self, result_stream: AsyncIterator[ProcessingChunk]):
        """Stream response chunks to CLI"""
        
        async for chunk in result_stream:
            if chunk.type == "content":
                typer.echo(chunk.content, nl=False)
            elif chunk.type == "status":
                typer.echo(f"\n[{chunk.status}]", err=True)
            elif chunk.type == "error":
                typer.echo(f"\nError: {chunk.error}", err=True)
                break
        
        typer.echo()  # Final newline
    
    async def stream_mcp_response(self, websocket: WebSocket, 
                                result_stream: AsyncIterator[ProcessingChunk]):
        """Stream response chunks via WebSocket"""
        
        async for chunk in result_stream:
            message = {
                "type": "chunk",
                "data": {
                    "chunk_type": chunk.type,
                    "content": chunk.content,
                    "metadata": chunk.metadata
                }
            }
            await websocket.send_json(message)
        
        # Send completion message
        await websocket.send_json({"type": "complete"})
```

## Error Handling and Validation

### Comprehensive Input Validation
```python
# Implementation Design
# mcp_server/interfaces/validation/request_validator.py

class RequestValidator:
    """Comprehensive request validation for all interfaces"""
    
    async def validate_cli_request(self, request: CLIRequest) -> ValidationResult:
        """Validate CLI request parameters"""
        
        errors = []
        
        # Query validation
        if not request.query or len(request.query.strip()) == 0:
            errors.append("Query cannot be empty")
        
        if len(request.query) > 10000:
            errors.append("Query too long (max 10,000 characters)")
        
        # Workspace validation
        if request.workspace_path:
            if not os.path.exists(request.workspace_path):
                errors.append(f"Workspace path does not exist: {request.workspace_path}")
        
        # Security validation
        if self._contains_suspicious_content(request.query):
            errors.append("Query contains potentially harmful content")
        
        return ValidationResult(
            is_valid=len(errors) == 0,
            errors=errors
        )
    
    async def validate_mcp_request(self, request: MCPRequest) -> ValidationResult:
        """Validate MCP protocol request"""
        
        errors = []
        
        # Protocol version check
        if request.jsonrpc != "2.0":
            errors.append("Invalid JSON-RPC version")
        
        # Method validation
        if request.method not in self.ALLOWED_METHODS:
            errors.append(f"Unknown method: {request.method}")
        
        # Parameter validation
        if not self._validate_method_params(request.method, request.params):
            errors.append("Invalid parameters for method")
        
        # Rate limiting check
        if not await self._check_rate_limit(request.session_id):
            errors.append("Rate limit exceeded")
        
        return ValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            error_code=-32602 if errors else None
        )
```

---

**Implementation Status**: Design complete, ready for interface development  
**Next Steps**:
1. Implement typer-based CLI with async support
2. Create FastAPI MCP protocol handler
3. Build session management system
4. Develop request validation and formatting

**Dependencies**: typer, FastAPI, WebSockets, Pydantic 