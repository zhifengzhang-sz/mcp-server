# Claude Code SDK Integration Tutorial

## Complete Guide to Integrating Claude Code SDK with MCP Architecture

This tutorial provides a step-by-step guide for integrating Claude Code SDK into your MCP application architecture, focusing on agent work delegation, context management, and workflow execution.

## Table of Contents

1. [Prerequisites and Setup](#prerequisites-and-setup)
2. [Basic SDK Integration](#basic-sdk-integration)
3. [MCP Protocol Integration](#mcp-protocol-integration)
4. [RAG-Enhanced Context Management](#rag-enhanced-context-management)
5. [Workflow Orchestration](#workflow-orchestration)
6. [Advanced Patterns](#advanced-patterns)
7. [Production Deployment](#production-deployment)
8. [Troubleshooting](#troubleshooting)

## Prerequisites and Setup

### 1. Install Claude Code SDK

```bash
# Install the Claude Code SDK
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version

# Set up authentication
export ANTHROPIC_API_KEY="your-api-key-here"
```

### 2. Install Dependencies

```bash
# Python dependencies for MCP integration
pip install asyncio subprocess typing dataclasses
pip install pydantic fastapi uvicorn  # for API layer
pip install chromadb qdrant-client     # vector databases
pip install llama-index langchain     # RAG frameworks
```

### 3. Project Structure

```
mcp-claude-integration/
├── src/
│   ├── mcp/
│   │   ├── __init__.py
│   │   ├── server.py           # MCP server implementation
│   │   ├── protocol.py         # MCP protocol handlers
│   │   └── tools/              # MCP tools directory
│   ├── claude/
│   │   ├── __init__.py
│   │   ├── sdk_controller.py   # Claude Code SDK controller
│   │   ├── task_delegator.py   # Task delegation logic
│   │   └── response_parser.py  # Response processing
│   ├── rag/
│   │   ├── __init__.py
│   │   ├── vector_store.py     # Vector database interface
│   │   ├── retrieval.py        # Knowledge retrieval
│   │   └── context_manager.py  # Context assembly
│   ├── workflow/
│   │   ├── __init__.py
│   │   ├── orchestrator.py     # Workflow execution
│   │   ├── task_queue.py       # Task management
│   │   └── agent_pool.py       # Agent coordination
│   └── main.py                 # Application entry point
├── config/
│   ├── app_config.yaml
│   └── logging_config.yaml
├── tests/
├── docs/
└── requirements.txt
```

## Basic SDK Integration

### 1. Claude Code SDK Controller

```python
# src/claude/sdk_controller.py
import asyncio
import json
import subprocess
import logging
from typing import Dict, Any, AsyncGenerator, Optional
from dataclasses import dataclass
from pathlib import Path

@dataclass
class ClaudeTask:
    """Represents a task to be executed by Claude Code SDK"""
    id: str
    prompt: str
    project_path: Optional[str] = None
    output_format: str = "json"
    timeout: int = 300
    context: Optional[Dict[str, Any]] = None

@dataclass
class ClaudeResponse:
    """Represents a response from Claude Code SDK"""
    task_id: str
    success: bool
    output: Any
    error: Optional[str] = None
    execution_time: float = 0.0

class ClaudeCodeSDKController:
    """
    Controller for managing Claude Code SDK subprocess execution
    """
    
    def __init__(self, max_concurrent_processes: int = 5):
        self.max_concurrent_processes = max_concurrent_processes
        self.active_processes: Dict[str, subprocess.Popen] = {}
        self.logger = logging.getLogger(__name__)
        
    async def execute_task(self, task: ClaudeTask) -> ClaudeResponse:
        """
        Execute a single task using Claude Code SDK
        """
        start_time = asyncio.get_event_loop().time()
        
        try:
            # Prepare command
            command = self._build_command(task)
            
            # Execute subprocess
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=task.project_path
            )
            
            # Store active process
            self.active_processes[task.id] = process
            
            # Wait for completion with timeout
            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(), 
                    timeout=task.timeout
                )
            except asyncio.TimeoutError:
                process.kill()
                raise TimeoutError(f"Task {task.id} timed out after {task.timeout}s")
            
            # Process results
            execution_time = asyncio.get_event_loop().time() - start_time
            
            if process.returncode == 0:
                output = self._parse_output(stdout.decode(), task.output_format)
                return ClaudeResponse(
                    task_id=task.id,
                    success=True,
                    output=output,
                    execution_time=execution_time
                )
            else:
                error_msg = stderr.decode()
                self.logger.error(f"Task {task.id} failed: {error_msg}")
                return ClaudeResponse(
                    task_id=task.id,
                    success=False,
                    output=None,
                    error=error_msg,
                    execution_time=execution_time
                )
                
        except Exception as e:
            execution_time = asyncio.get_event_loop().time() - start_time
            self.logger.exception(f"Error executing task {task.id}")
            return ClaudeResponse(
                task_id=task.id,
                success=False,
                output=None,
                error=str(e),
                execution_time=execution_time
            )
        finally:
            # Clean up
            self.active_processes.pop(task.id, None)
    
    async def stream_task(self, task: ClaudeTask) -> AsyncGenerator[str, None]:
        """
        Execute task with streaming output
        """
        command = self._build_command(task, streaming=True)
        
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=task.project_path
        )
        
        self.active_processes[task.id] = process
        
        try:
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                    
                decoded_line = line.decode().strip()
                if decoded_line:
                    yield decoded_line
                    
        except Exception as e:
            self.logger.exception(f"Error streaming task {task.id}")
            yield f"ERROR: {str(e)}"
        finally:
            self.active_processes.pop(task.id, None)
            if process.returncode is None:
                process.terminate()
    
    def _build_command(self, task: ClaudeTask, streaming: bool = False) -> list:
        """Build Claude Code SDK command"""
        command = ["claude", "-p", task.prompt]
        
        if task.output_format == "json":
            if streaming:
                command.extend(["--output-format", "stream-json"])
            else:
                command.extend(["--output-format", "json"])
        
        return command
    
    def _parse_output(self, output: str, format_type: str) -> Any:
        """Parse Claude Code SDK output"""
        if format_type == "json":
            try:
                return json.loads(output)
            except json.JSONDecodeError:
                return {"raw_output": output}
        return output
    
    async def cancel_task(self, task_id: str) -> bool:
        """Cancel a running task"""
        if task_id in self.active_processes:
            process = self.active_processes[task_id]
            process.terminate()
            await asyncio.sleep(1)
            if process.returncode is None:
                process.kill()
            return True
        return False
    
    async def get_active_tasks(self) -> Dict[str, Dict[str, Any]]:
        """Get information about active tasks"""
        active_tasks = {}
        for task_id, process in self.active_processes.items():
            active_tasks[task_id] = {
                "pid": process.pid,
                "returncode": process.returncode,
                "status": "running" if process.returncode is None else "completed"
            }
        return active_tasks
```

### 2. Task Delegation Layer

```python
# src/claude/task_delegator.py
import uuid
from typing import Dict, Any, List, Optional
from enum import Enum
from dataclasses import dataclass

class TaskType(Enum):
    CODE_GENERATION = "code_generation"
    CODE_REVIEW = "code_review"
    FILE_OPERATION = "file_operation"
    GIT_OPERATION = "git_operation"
    TEST_EXECUTION = "test_execution"
    DOCUMENTATION = "documentation"
    DEBUGGING = "debugging"

@dataclass
class TaskRequest:
    """High-level task request"""
    type: TaskType
    description: str
    parameters: Dict[str, Any]
    project_context: Optional[Dict[str, Any]] = None
    priority: int = 1
    dependencies: List[str] = None

class TaskDelegator:
    """
    High-level interface for delegating tasks to Claude Code SDK
    """
    
    def __init__(self, sdk_controller: ClaudeCodeSDKController):
        self.sdk_controller = sdk_controller
        self.task_templates = self._load_task_templates()
    
    async def delegate_task(self, request: TaskRequest) -> ClaudeResponse:
        """
        Delegate a high-level task to Claude Code SDK
        """
        # Generate unique task ID
        task_id = str(uuid.uuid4())
        
        # Build Claude task from request
        claude_task = self._build_claude_task(task_id, request)
        
        # Execute task
        response = await self.sdk_controller.execute_task(claude_task)
        
        # Post-process response
        return self._post_process_response(response, request)
    
    async def delegate_workflow(self, requests: List[TaskRequest]) -> List[ClaudeResponse]:
        """
        Delegate multiple related tasks
        """
        responses = []
        
        # Sort by priority and dependencies
        sorted_requests = self._sort_by_dependencies(requests)
        
        for request in sorted_requests:
            response = await self.delegate_task(request)
            responses.append(response)
            
            # If task failed and is critical, stop workflow
            if not response.success and request.priority == 0:
                break
        
        return responses
    
    def _build_claude_task(self, task_id: str, request: TaskRequest) -> ClaudeTask:
        """
        Convert TaskRequest to ClaudeTask
        """
        # Get template for task type
        template = self.task_templates.get(request.type, "")
        
        # Build prompt
        prompt = self._build_prompt(template, request)
        
        # Determine project path
        project_path = None
        if request.project_context:
            project_path = request.project_context.get("project_path")
        
        return ClaudeTask(
            id=task_id,
            prompt=prompt,
            project_path=project_path,
            context=request.project_context
        )
    
    def _build_prompt(self, template: str, request: TaskRequest) -> str:
        """
        Build prompt from template and request
        """
        prompt_parts = [
            f"Task Type: {request.type.value}",
            f"Description: {request.description}",
        ]
        
        # Add parameters
        if request.parameters:
            prompt_parts.append("Parameters:")
            for key, value in request.parameters.items():
                prompt_parts.append(f"  {key}: {value}")
        
        # Add context
        if request.project_context:
            prompt_parts.append("Context:")
            for key, value in request.project_context.items():
                if key != "project_path":
                    prompt_parts.append(f"  {key}: {value}")
        
        # Add template-specific instructions
        if template:
            prompt_parts.append("\nInstructions:")
            prompt_parts.append(template)
        
        return "\n".join(prompt_parts)
    
    def _load_task_templates(self) -> Dict[TaskType, str]:
        """
        Load task-specific prompt templates
        """
        return {
            TaskType.CODE_GENERATION: """
            Generate clean, well-documented code that follows best practices.
            Include error handling and type annotations where appropriate.
            Provide the code in the specified programming language.
            """,
            
            TaskType.CODE_REVIEW: """
            Review the provided code for:
            - Code quality and best practices
            - Security vulnerabilities
            - Performance issues
            - Maintainability concerns
            Provide specific suggestions for improvement.
            """,
            
            TaskType.FILE_OPERATION: """
            Perform the requested file operation safely.
            Verify file paths and permissions before proceeding.
            Provide confirmation of successful completion.
            """,
            
            TaskType.GIT_OPERATION: """
            Execute the git operation following best practices.
            Ensure the working directory is clean when appropriate.
            Provide clear commit messages and branch naming.
            """,
            
            TaskType.TEST_EXECUTION: """
            Run the specified tests and provide detailed results.
            Include test coverage information when available.
            Report any failures with clear error messages.
            """,
            
            TaskType.DOCUMENTATION: """
            Generate comprehensive documentation that is:
            - Clear and easy to understand
            - Well-structured with appropriate headings
            - Includes examples where helpful
            - Follows documentation best practices
            """,
            
            TaskType.DEBUGGING: """
            Analyze the problem systematically:
            - Identify the root cause
            - Propose multiple solutions if possible
            - Explain the reasoning behind recommendations
            - Provide step-by-step debugging process
            """
        }
    
    def _sort_by_dependencies(self, requests: List[TaskRequest]) -> List[TaskRequest]:
        """
        Sort tasks by dependencies and priority
        """
        # Simple dependency resolution - in production, use proper topological sort
        return sorted(requests, key=lambda x: (x.priority, len(x.dependencies or [])))
    
    def _post_process_response(self, response: ClaudeResponse, request: TaskRequest) -> ClaudeResponse:
        """
        Post-process Claude response based on task type
        """
        if response.success and request.type == TaskType.CODE_GENERATION:
            # Validate generated code
            response = self._validate_generated_code(response)
        
        return response
    
    def _validate_generated_code(self, response: ClaudeResponse) -> ClaudeResponse:
        """
        Validate generated code for basic syntax
        """
        # Add validation logic here
        return response
```

## MCP Protocol Integration

### 3. MCP Server Implementation

```python
# src/mcp/server.py
import asyncio
from typing import Dict, Any, List, Optional
from dataclasses import dataclass
import json

from .protocol import MCPProtocolHandler
from ..claude.task_delegator import TaskDelegator, TaskRequest, TaskType
from ..rag.context_manager import ContextManager

@dataclass
class MCPRequest:
    """MCP protocol request"""
    method: str
    params: Dict[str, Any]
    id: str

@dataclass
class MCPResponse:
    """MCP protocol response"""
    result: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None
    id: Optional[str] = None

class MCPServer:
    """
    MCP Server with Claude Code SDK integration
    """
    
    def __init__(self, task_delegator: TaskDelegator, context_manager: ContextManager):
        self.task_delegator = task_delegator
        self.context_manager = context_manager
        self.protocol_handler = MCPProtocolHandler()
        self.tools = self._register_tools()
    
    def _register_tools(self) -> Dict[str, Any]:
        """Register available MCP tools"""
        return {
            "code_generation": {
                "description": "Generate code using Claude Code SDK",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "language": {"type": "string"},
                        "description": {"type": "string"},
                        "requirements": {"type": "array", "items": {"type": "string"}},
                        "project_path": {"type": "string"}
                    },
                    "required": ["language", "description"]
                }
            },
            "code_review": {
                "description": "Review code using Claude Code SDK",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "file_path": {"type": "string"},
                        "focus_areas": {"type": "array", "items": {"type": "string"}},
                        "project_path": {"type": "string"}
                    },
                    "required": ["file_path"]
                }
            },
            "rag_query": {
                "description": "Query knowledge base using RAG",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string"},
                        "top_k": {"type": "integer", "default": 5},
                        "threshold": {"type": "number", "default": 0.8}
                    },
                    "required": ["query"]
                }
            },
            "context_update": {
                "description": "Update session context",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "session_id": {"type": "string"},
                        "context_data": {"type": "object"},
                        "operation": {"type": "string", "enum": ["add", "update", "remove"]}
                    },
                    "required": ["session_id", "context_data", "operation"]
                }
            }
        }
    
    async def handle_request(self, request: MCPRequest) -> MCPResponse:
        """
        Handle incoming MCP request
        """
        try:
            if request.method == "tools/list":
                return await self._handle_tools_list(request)
            elif request.method == "tools/call":
                return await self._handle_tool_call(request)
            elif request.method == "resources/list":
                return await self._handle_resources_list(request)
            elif request.method == "resources/read":
                return await self._handle_resource_read(request)
            else:
                return MCPResponse(
                    error={"code": -32601, "message": f"Method not found: {request.method}"},
                    id=request.id
                )
        
        except Exception as e:
            return MCPResponse(
                error={"code": -32603, "message": f"Internal error: {str(e)}"},
                id=request.id
            )
    
    async def _handle_tools_list(self, request: MCPRequest) -> MCPResponse:
        """Handle tools/list request"""
        tools_list = []
        for name, definition in self.tools.items():
            tools_list.append({
                "name": name,
                "description": definition["description"],
                "inputSchema": definition["parameters"]
            })
        
        return MCPResponse(
            result={"tools": tools_list},
            id=request.id
        )
    
    async def _handle_tool_call(self, request: MCPRequest) -> MCPResponse:
        """Handle tools/call request"""
        tool_name = request.params.get("name")
        arguments = request.params.get("arguments", {})
        
        if tool_name == "code_generation":
            return await self._handle_code_generation(arguments, request.id)
        elif tool_name == "code_review":
            return await self._handle_code_review(arguments, request.id)
        elif tool_name == "rag_query":
            return await self._handle_rag_query(arguments, request.id)
        elif tool_name == "context_update":
            return await self._handle_context_update(arguments, request.id)
        else:
            return MCPResponse(
                error={"code": -32602, "message": f"Unknown tool: {tool_name}"},
                id=request.id
            )
    
    async def _handle_code_generation(self, arguments: Dict[str, Any], request_id: str) -> MCPResponse:
        """Handle code generation tool call"""
        try:
            # Create task request
            task_request = TaskRequest(
                type=TaskType.CODE_GENERATION,
                description=arguments["description"],
                parameters={
                    "language": arguments["language"],
                    "requirements": arguments.get("requirements", [])
                },
                project_context={
                    "project_path": arguments.get("project_path")
                }
            )
            
            # Delegate to Claude Code SDK
            response = await self.task_delegator.delegate_task(task_request)
            
            if response.success:
                return MCPResponse(
                    result={
                        "content": [
                            {
                                "type": "text",
                                "text": json.dumps(response.output, indent=2)
                            }
                        ]
                    },
                    id=request_id
                )
            else:
                return MCPResponse(
                    error={
                        "code": -32000,
                        "message": f"Code generation failed: {response.error}"
                    },
                    id=request_id
                )
        
        except Exception as e:
            return MCPResponse(
                error={"code": -32603, "message": f"Error in code generation: {str(e)}"},
                id=request_id
            )
    
    async def _handle_code_review(self, arguments: Dict[str, Any], request_id: str) -> MCPResponse:
        """Handle code review tool call"""
        try:
            task_request = TaskRequest(
                type=TaskType.CODE_REVIEW,
                description=f"Review code in file: {arguments['file_path']}",
                parameters={
                    "file_path": arguments["file_path"],
                    "focus_areas": arguments.get("focus_areas", [])
                },
                project_context={
                    "project_path": arguments.get("project_path")
                }
            )
            
            response = await self.task_delegator.delegate_task(task_request)
            
            if response.success:
                return MCPResponse(
                    result={
                        "content": [
                            {
                                "type": "text",
                                "text": json.dumps(response.output, indent=2)
                            }
                        ]
                    },
                    id=request_id
                )
            else:
                return MCPResponse(
                    error={
                        "code": -32000,
                        "message": f"Code review failed: {response.error}"
                    },
                    id=request_id
                )
        
        except Exception as e:
            return MCPResponse(
                error={"code": -32603, "message": f"Error in code review: {str(e)}"},
                id=request_id
            )
    
    async def _handle_rag_query(self, arguments: Dict[str, Any], request_id: str) -> MCPResponse:
        """Handle RAG query tool call"""
        try:
            query = arguments["query"]
            top_k = arguments.get("top_k", 5)
            threshold = arguments.get("threshold", 0.8)
            
            # Use context manager for RAG query
            results = await self.context_manager.retrieve_knowledge(
                query=query,
                top_k=top_k,
                similarity_threshold=threshold
            )
            
            return MCPResponse(
                result={
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(results, indent=2)
                        }
                    ]
                },
                id=request_id
            )
        
        except Exception as e:
            return MCPResponse(
                error={"code": -32603, "message": f"Error in RAG query: {str(e)}"},
                id=request_id
            )
    
    async def _handle_context_update(self, arguments: Dict[str, Any], request_id: str) -> MCPResponse:
        """Handle context update tool call"""
        try:
            session_id = arguments["session_id"]
            context_data = arguments["context_data"]
            operation = arguments["operation"]
            
            if operation == "add":
                await self.context_manager.add_context(session_id, context_data)
            elif operation == "update":
                await self.context_manager.update_context(session_id, context_data)
            elif operation == "remove":
                await self.context_manager.remove_context(session_id, context_data)
            
            return MCPResponse(
                result={"status": "success", "operation": operation},
                id=request_id
            )
        
        except Exception as e:
            return MCPResponse(
                error={"code": -32603, "message": f"Error updating context: {str(e)}"},
                id=request_id
            )
    
    async def _handle_resources_list(self, request: MCPRequest) -> MCPResponse:
        """Handle resources/list request"""
        # Return available resources
        resources = await self.context_manager.list_resources()
        return MCPResponse(
            result={"resources": resources},
            id=request.id
        )
    
    async def _handle_resource_read(self, request: MCPRequest) -> MCPResponse:
        """Handle resources/read request"""
        uri = request.params.get("uri")
        content = await self.context_manager.read_resource(uri)
        
        return MCPResponse(
            result={
                "contents": [
                    {
                        "uri": uri,
                        "mimeType": "text/plain",
                        "text": content
                    }
                ]
            },
            id=request.id
        )
```

## RAG-Enhanced Context Management

### 4. Vector Store Integration

```python
# src/rag/vector_store.py
import asyncio
from typing import List, Dict, Any, Optional, Union
from abc import ABC, abstractmethod
import numpy as np

# Vector database implementations
try:
    import chromadb
    from chromadb.config import Settings
    CHROMADB_AVAILABLE = True
except ImportError:
    CHROMADB_AVAILABLE = False

try:
    from qdrant_client import QdrantClient
    from qdrant_client.http import models
    QDRANT_AVAILABLE = True
except ImportError:
    QDRANT_AVAILABLE = False

class VectorStoreInterface(ABC):
    """Abstract interface for vector stores"""
    
    @abstractmethod
    async def add_documents(self, documents: List[Dict[str, Any]]) -> bool:
        pass
    
    @abstractmethod
    async def search(self, query_vector: List[float], top_k: int = 5, 
                    filter_criteria: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        pass
    
    @abstractmethod
    async def delete_documents(self, document_ids: List[str]) -> bool:
        pass
    
    @abstractmethod
    async def update_document(self, document_id: str, document: Dict[str, Any]) -> bool:
        pass

class ChromaDBVectorStore(VectorStoreInterface):
    """ChromaDB implementation for local development"""
    
    def __init__(self, collection_name: str = "mcp_knowledge", persist_directory: str = "./chroma_db"):
        if not CHROMADB_AVAILABLE:
            raise ImportError("ChromaDB not installed. Install with: pip install chromadb")
        
        self.client = chromadb.PersistentClient(
            path=persist_directory,
            settings=Settings(anonymized_telemetry=False)
        )
        self.collection = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"}
        )
    
    async def add_documents(self, documents: List[Dict[str, Any]]) -> bool:
        """Add documents to ChromaDB"""
        try:
            ids = [doc["id"] for doc in documents]
            embeddings = [doc["embedding"] for doc in documents]
            texts = [doc["text"] for doc in documents]
            metadatas = [doc.get("metadata", {}) for doc in documents]
            
            self.collection.add(
                ids=ids,
                embeddings=embeddings,
                documents=texts,
                metadatas=metadatas
            )
            return True
        except Exception as e:
            print(f"Error adding documents to ChromaDB: {e}")
            return False
    
    async def search(self, query_vector: List[float], top_k: int = 5, 
                    filter_criteria: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Search in ChromaDB"""
        try:
            where_clause = filter_criteria if filter_criteria else None
            
            results = self.collection.query(
                query_embeddings=[query_vector],
                n_results=top_k,
                where=where_clause,
                include=["documents", "metadatas", "distances"]
            )
            
            # Format results
            formatted_results = []
            for i in range(len(results["ids"][0])):
                formatted_results.append({
                    "id": results["ids"][0][i],
                    "text": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "score": 1 - results["distances"][0][i]  # Convert distance to similarity
                })
            
            return formatted_results
        except Exception as e:
            print(f"Error searching ChromaDB: {e}")
            return []
    
    async def delete_documents(self, document_ids: List[str]) -> bool:
        """Delete documents from ChromaDB"""
        try:
            self.collection.delete(ids=document_ids)
            return True
        except Exception as e:
            print(f"Error deleting documents from ChromaDB: {e}")
            return False
    
    async def update_document(self, document_id: str, document: Dict[str, Any]) -> bool:
        """Update document in ChromaDB"""
        try:
            self.collection.update(
                ids=[document_id],
                embeddings=[document["embedding"]],
                documents=[document["text"]],
                metadatas=[document.get("metadata", {})]
            )
            return True
        except Exception as e:
            print(f"Error updating document in ChromaDB: {e}")
            return False

class QdrantVectorStore(VectorStoreInterface):
    """Qdrant implementation for production"""
    
    def __init__(self, host: str = "localhost", port: int = 6333, 
                 collection_name: str = "mcp_knowledge", vector_size: int = 1536):
        if not QDRANT_AVAILABLE:
            raise ImportError("Qdrant client not installed. Install with: pip install qdrant-client")
        
        self.client = QdrantClient(host=host, port=port)
        self.collection_name = collection_name
        self.vector_size = vector_size
        
        # Create collection if it doesn't exist
        try:
            self.client.get_collection(collection_name)
        except:
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=models.VectorParams(
                    size=vector_size,
                    distance=models.Distance.COSINE
                )
            )
    
    async def add_documents(self, documents: List[Dict[str, Any]]) -> bool:
        """Add documents to Qdrant"""
        try:
            points = []
            for doc in documents:
                points.append(
                    models.PointStruct(
                        id=doc["id"],
                        vector=doc["embedding"],
                        payload={
                            "text": doc["text"],
                            **doc.get("metadata", {})
                        }
                    )
                )
            
            self.client.upsert(
                collection_name=self.collection_name,
                points=points
            )
            return True
        except Exception as e:
            print(f"Error adding documents to Qdrant: {e}")
            return False
    
    async def search(self, query_vector: List[float], top_k: int = 5, 
                    filter_criteria: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Search in Qdrant"""
        try:
            filter_condition = None
            if filter_criteria:
                filter_condition = models.Filter(
                    must=[
                        models.FieldCondition(
                            key=key,
                            match=models.MatchValue(value=value)
                        ) for key, value in filter_criteria.items()
                    ]
                )
            
            search_result = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_vector,
                query_filter=filter_condition,
                limit=top_k,
                with_payload=True
            )
            
            # Format results
            formatted_results = []
            for point in search_result:
                formatted_results.append({
                    "id": str(point.id),
                    "text": point.payload.get("text", ""),
                    "metadata": {k: v for k, v in point.payload.items() if k != "text"},
                    "score": point.score
                })
            
            return formatted_results
        except Exception as e:
            print(f"Error searching Qdrant: {e}")
            return []
    
    async def delete_documents(self, document_ids: List[str]) -> bool:
        """Delete documents from Qdrant"""
        try:
            self.client.delete(
                collection_name=self.collection_name,
                points_selector=models.PointIdsList(
                    points=[doc_id for doc_id in document_ids]
                )
            )
            return True
        except Exception as e:
            print(f"Error deleting documents from Qdrant: {e}")
            return False
    
    async def update_document(self, document_id: str, document: Dict[str, Any]) -> bool:
        """Update document in Qdrant"""
        try:
            point = models.PointStruct(
                id=document_id,
                vector=document["embedding"],
                payload={
                    "text": document["text"],
                    **document.get("metadata", {})
                }
            )
            
            self.client.upsert(
                collection_name=self.collection_name,
                points=[point]
            )
            return True
        except Exception as e:
            print(f"Error updating document in Qdrant: {e}")
            return False

class VectorStoreFactory:
    """Factory for creating vector store instances"""
    
    @staticmethod
    def create_vector_store(store_type: str, **kwargs) -> VectorStoreInterface:
        """Create vector store instance"""
        if store_type.lower() == "chromadb":
            return ChromaDBVectorStore(**kwargs)
        elif store_type.lower() == "qdrant":
            return QdrantVectorStore(**kwargs)
        else:
            raise ValueError(f"Unsupported vector store type: {store_type}")
```

### 5. Context Manager with RAG

```python
# src/rag/context_manager.py
import asyncio
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
import json
import hashlib
from datetime import datetime, timedelta

from .vector_store import VectorStoreInterface, VectorStoreFactory
from .retrieval import KnowledgeRetriever

@dataclass
class SessionContext:
    """Session context with memory management"""
    session_id: str
    created_at: datetime = field(default_factory=datetime.now)
    last_updated: datetime = field(default_factory=datetime.now)
    short_term_memory: Dict[str, Any] = field(default_factory=dict)
    working_context: Dict[str, Any] = field(default_factory=dict)
    conversation_history: List[Dict[str, Any]] = field(default_factory=list)
    project_context: Optional[Dict[str, Any]] = None
    preferences: Dict[str, Any] = field(default_factory=dict)

@dataclass
class KnowledgeItem:
    """Knowledge base item"""
    id: str
    content: str
    metadata: Dict[str, Any]
    embedding: Optional[List[float]] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

class ContextManager:
    """
    Advanced context management with RAG integration
    """
    
    def __init__(self, vector_store: VectorStoreInterface, knowledge_retriever: KnowledgeRetriever):
        self.vector_store = vector_store
        self.knowledge_retriever = knowledge_retriever
        self.sessions: Dict[str, SessionContext] = {}
        self.context_cache: Dict[str, Any] = {}
        
        # Context management settings
        self.max_conversation_history = 50
        self.context_window_size = 128000  # tokens
        self.memory_retention_days = 30
        
    async def create_session(self, session_id: str, initial_context: Optional[Dict[str, Any]] = None) -> SessionContext:
        """Create new session with context"""
        session = SessionContext(
            session_id=session_id,
            project_context=initial_context
        )
        self.sessions[session_id] = session
        return session
    
    async def get_session(self, session_id: str) -> Optional[SessionContext]:
        """Get existing session"""
        return self.sessions.get(session_id)
    
    async def update_session_context(self, session_id: str, context_update: Dict[str, Any]) -> bool:
        """Update session context"""
        session = self.sessions.get(session_id)
        if not session:
            return False
        
        session.working_context.update(context_update)
        session.last_updated = datetime.now()
        
        # Cache invalidation
        cache_key = f"context_{session_id}"
        if cache_key in self.context_cache:
            del self.context_cache[cache_key]
        
        return True
    
    async def add_to_conversation_history(self, session_id: str, interaction: Dict[str, Any]) -> bool:
        """Add interaction to conversation history"""
        session = self.sessions.get(session_id)
        if not session:
            return False
        
        interaction["timestamp"] = datetime.now().isoformat()
        session.conversation_history.append(interaction)
        
        # Trim history if too long
        if len(session.conversation_history) > self.max_conversation_history:
            session.conversation_history = session.conversation_history[-self.max_conversation_history:]
        
        return True
    
    async def get_relevant_context(self, session_id: str, query: str, include_knowledge: bool = True) -> Dict[str, Any]:
        """
        Assemble relevant context for a query
        """
        # Check cache first
        cache_key = f"context_{session_id}_{hashlib.md5(query.encode()).hexdigest()}"
        if cache_key in self.context_cache:
            return self.context_cache[cache_key]
        
        session = self.sessions.get(session_id)
        if not session:
            return {}
        
        context = {
            "session_id": session_id,
            "timestamp": datetime.now().isoformat(),
            "working_context": session.working_context,
            "project_context": session.project_context,
            "preferences": session.preferences
        }
        
        # Add recent conversation history
        recent_history = session.conversation_history[-10:]  # Last 10 interactions
        context["conversation_history"] = recent_history
        
        # Add RAG-retrieved knowledge if requested
        if include_knowledge:
            knowledge_results = await self.retrieve_knowledge(
                query=query,
                session_id=session_id,
                top_k=5
            )
            context["retrieved_knowledge"] = knowledge_results
        
        # Add short-term memory relevant to query
        relevant_memory = await self._get_relevant_memory(session, query)
        context["relevant_memory"] = relevant_memory
        
        # Cache the result
        self.context_cache[cache_key] = context
        
        return context
    
    async def retrieve_knowledge(self, query: str, session_id: Optional[str] = None, 
                                top_k: int = 5, similarity_threshold: float = 0.8) -> List[Dict[str, Any]]:
        """
        Retrieve relevant knowledge using RAG
        """
        # Get query embedding
        query_embedding = await self.knowledge_retriever.get_embedding(query)
        
        # Prepare filter criteria based on session context
        filter_criteria = {}
        if session_id:
            session = self.sessions.get(session_id)
            if session and session.project_context:
                # Add project-specific filters
                if "project_path" in session.project_context:
                    filter_criteria["project"] = session.project_context["project_path"]
        
        # Search vector store
        results = await self.vector_store.search(
            query_vector=query_embedding,
            top_k=top_k,
            filter_criteria=filter_criteria
        )
        
        # Filter by similarity threshold
        filtered_results = [
            result for result in results 
            if result["score"] >= similarity_threshold
        ]
        
        # Enhance results with additional context
        enhanced_results = []
        for result in filtered_results:
            enhanced_result = {
                **result,
                "retrieval_query": query,
                "retrieval_timestamp": datetime.now().isoformat(),
                "relevance_score": result["score"]
            }
            enhanced_results.append(enhanced_result)
        
        return enhanced_results
    
    async def add_knowledge(self, content: str, metadata: Dict[str, Any]) -> str:
        """
        Add new knowledge to the knowledge base
        """
        # Generate unique ID
        knowledge_id = hashlib.sha256(f"{content}{datetime.now().isoformat()}".encode()).hexdigest()[:16]
        
        # Get embedding
        embedding = await self.knowledge_retriever.get_embedding(content)
        
        # Create knowledge item
        knowledge_item = KnowledgeItem(
            id=knowledge_id,
            content=content,
            metadata=metadata,
            embedding=embedding
        )
        
        # Add to vector store
        document = {
            "id": knowledge_item.id,
            "text": knowledge_item.content,
            "embedding": knowledge_item.embedding,
            "metadata": {
                **knowledge_item.metadata,
                "created_at": knowledge_item.created_at.isoformat(),
                "updated_at": knowledge_item.updated_at.isoformat()
            }
        }
        
        success = await self.vector_store.add_documents([document])
        
        if success:
            return knowledge_id
        else:
            raise Exception("Failed to add knowledge to vector store")
    
    async def update_knowledge(self, knowledge_id: str, content: str, metadata: Dict[str, Any]) -> bool:
        """
        Update existing knowledge
        """
        # Get new embedding
        embedding = await self.knowledge_retriever.get_embedding(content)
        
        # Update document
        document = {
            "id": knowledge_id,
            "text": content,
            "embedding": embedding,
            "metadata": {
                **metadata,
                "updated_at": datetime.now().isoformat()
            }
        }
        
        return await self.vector_store.update_document(knowledge_id, document)
    
    async def delete_knowledge(self, knowledge_ids: List[str]) -> bool:
        """
        Delete knowledge items
        """
        return await self.vector_store.delete_documents(knowledge_ids)
    
    async def _get_relevant_memory(self, session: SessionContext, query: str) -> Dict[str, Any]:
        """
        Get relevant items from short-term memory
        """
        # Simple keyword matching for now - could be enhanced with semantic search
        query_keywords = query.lower().split()
        relevant_memory = {}
        
        for key, value in session.short_term_memory.items():
            if any(keyword in str(value).lower() for keyword in query_keywords):
                relevant_memory[key] = value
        
        return relevant_memory
    
    async def cleanup_expired_sessions(self) -> int:
        """
        Clean up expired sessions
        """
        cutoff_time = datetime.now() - timedelta(days=self.memory_retention_days)
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if session.last_updated < cutoff_time:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            del self.sessions[session_id]
        
        return len(expired_sessions)
    
    async def get_session_statistics(self, session_id: str) -> Dict[str, Any]:
        """
        Get session statistics
        """
        session = self.sessions.get(session_id)
        if not session:
            return {}
        
        return {
            "session_id": session_id,
            "created_at": session.created_at.isoformat(),
            "last_updated": session.last_updated.isoformat(),
            "conversation_length": len(session.conversation_history),
            "context_size": len(str(session.working_context)),
            "memory_items": len(session.short_term_memory)
        }
    
    async def list_resources(self) -> List[Dict[str, Any]]:
        """List available resources for MCP"""
        resources = [
            {
                "uri": "context://sessions",
                "name": "Active Sessions",
                "description": "List of active session contexts",
                "mimeType": "application/json"
            },
            {
                "uri": "context://knowledge",
                "name": "Knowledge Base",
                "description": "Available knowledge items",
                "mimeType": "application/json"
            }
        ]
        return resources
    
    async def read_resource(self, uri: str) -> str:
        """Read resource content for MCP"""
        if uri == "context://sessions":
            session_list = []
            for session_id, session in self.sessions.items():
                session_list.append({
                    "session_id": session_id,
                    "created_at": session.created_at.isoformat(),
                    "last_updated": session.last_updated.isoformat(),
                    "conversation_length": len(session.conversation_history)
                })
            return json.dumps(session_list, indent=2)
        
        elif uri == "context://knowledge":
            # Return knowledge base summary
            return json.dumps({
                "knowledge_base": "Available via search",
                "search_endpoint": "Use rag_query tool to search knowledge"
            }, indent=2)
        
        else:
            return f"Resource not found: {uri}"
```

## Workflow Orchestration

### 6. Dify Integration

```python
# src/workflow/dify_integration.py
import asyncio
from typing import Dict, Any, List, Optional
import httpx
import json
from dataclasses import dataclass

@dataclass
class DifyWorkflowConfig:
    """Dify workflow configuration"""
    api_endpoint: str
    api_key: str
    workflow_id: str
    timeout: int = 300

@dataclass
class WorkflowExecution:
    """Workflow execution state"""
    execution_id: str
    workflow_id: str
    status: str
    inputs: Dict[str, Any]
    outputs: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None

class DifyWorkflowOrchestrator:
    """
    Dify workflow orchestration integration
    """
    
    def __init__(self, config: DifyWorkflowConfig):
        self.config = config
        self.client = httpx.AsyncClient(
            base_url=config.api_endpoint,
            headers={
                "Authorization": f"Bearer {config.api_key}",
                "Content-Type": "application/json"
            },
            timeout=config.timeout
        )
        self.active_executions: Dict[str, WorkflowExecution] = {}
    
    async def execute_workflow(self, inputs: Dict[str, Any], 
                              execution_id: Optional[str] = None) -> WorkflowExecution:
        """
        Execute Dify workflow
        """
        if not execution_id:
            execution_id = f"exec_{len(self.active_executions)}"
        
        execution = WorkflowExecution(
            execution_id=execution_id,
            workflow_id=self.config.workflow_id,
            status="running",
            inputs=inputs
        )
        
        self.active_executions[execution_id] = execution
        
        try:
            # Execute workflow via Dify API
            response = await self.client.post(
                f"/v1/workflows/{self.config.workflow_id}/run",
                json={
                    "inputs": inputs,
                    "response_mode": "blocking",  # or "streaming"
                    "user": execution_id
                }
            )
            
            if response.status_code == 200:
                result = response.json()
                execution.status = "completed"
                execution.outputs = result.get("data", {})
                execution.completed_at = result.get("finished_at")
            else:
                execution.status = "failed"
                execution.error = f"HTTP {response.status_code}: {response.text}"
        
        except Exception as e:
            execution.status = "failed"
            execution.error = str(e)
        
        return execution
    
    async def stream_workflow(self, inputs: Dict[str, Any]) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Execute workflow with streaming response
        """
        async with self.client.stream(
            "POST",
            f"/v1/workflows/{self.config.workflow_id}/run",
            json={
                "inputs": inputs,
                "response_mode": "streaming",
                "user": "stream_user"
            }
        ) as response:
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    try:
                        data = json.loads(line[6:])  # Remove "data: " prefix
                        yield data
                    except json.JSONDecodeError:
                        continue
    
    async def get_workflow_status(self, execution_id: str) -> Optional[WorkflowExecution]:
        """
        Get workflow execution status
        """
        return self.active_executions.get(execution_id)
    
    async def cancel_workflow(self, execution_id: str) -> bool:
        """
        Cancel running workflow
        """
        execution = self.active_executions.get(execution_id)
        if execution and execution.status == "running":
            # Dify doesn't provide direct cancellation API, so we mark as cancelled
            execution.status = "cancelled"
            return True
        return False
    
    async def list_workflows(self) -> List[Dict[str, Any]]:
        """
        List available workflows
        """
        try:
            response = await self.client.get("/v1/workflows")
            if response.status_code == 200:
                return response.json().get("data", [])
        except Exception as e:
            print(f"Error listing workflows: {e}")
        return []
    
    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()
```

### 7. Custom Workflow Engine

```python
# src/workflow/orchestrator.py
import asyncio
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum
import uuid
from datetime import datetime

class TaskStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

@dataclass
class WorkflowTask:
    """Individual workflow task"""
    id: str
    name: str
    task_type: str
    inputs: Dict[str, Any]
    outputs: Dict[str, Any] = field(default_factory=dict)
    status: TaskStatus = TaskStatus.PENDING
    dependencies: List[str] = field(default_factory=list)
    error: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

@dataclass
class Workflow:
    """Workflow definition"""
    id: str
    name: str
    tasks: List[WorkflowTask]
    status: TaskStatus = TaskStatus.PENDING
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

class WorkflowOrchestrator:
    """
    Custom workflow orchestration engine
    """
    
    def __init__(self, task_delegator, context_manager):
        self.task_delegator = task_delegator
        self.context_manager = context_manager
        self.active_workflows: Dict[str, Workflow] = {}
        self.task_handlers: Dict[str, Callable] = {}
        self._register_default_handlers()
    
    def _register_default_handlers(self):
        """Register default task handlers"""
        self.task_handlers.update({
            "claude_code": self._handle_claude_code_task,
            "rag_query": self._handle_rag_query_task,
            "context_update": self._handle_context_update_task,
            "parallel": self._handle_parallel_task,
            "conditional": self._handle_conditional_task,
            "loop": self._handle_loop_task
        })
    
    async def create_workflow(self, name: str, task_definitions: List[Dict[str, Any]]) -> str:
        """
        Create new workflow from task definitions
        """
        workflow_id = str(uuid.uuid4())
        
        tasks = []
        for task_def in task_definitions:
            task = WorkflowTask(
                id=task_def.get("id", str(uuid.uuid4())),
                name=task_def["name"],
                task_type=task_def["type"],
                inputs=task_def.get("inputs", {}),
                dependencies=task_def.get("dependencies", [])
            )
            tasks.append(task)
        
        workflow = Workflow(
            id=workflow_id,
            name=name,
            tasks=tasks
        )
        
        self.active_workflows[workflow_id] = workflow
        return workflow_id
    
    async def execute_workflow(self, workflow_id: str, 
                              global_inputs: Optional[Dict[str, Any]] = None) -> Workflow:
        """
        Execute workflow with dependency resolution
        """
        workflow = self.active_workflows.get(workflow_id)
        if not workflow:
            raise ValueError(f"Workflow {workflow_id} not found")
        
        workflow.status = TaskStatus.RUNNING
        workflow.started_at = datetime.now()
        
        try:
            # Build dependency graph
            dependency_graph = self._build_dependency_graph(workflow.tasks)
            
            # Execute tasks in dependency order
            completed_tasks = set()
            task_outputs = global_inputs or {}
            
            while len(completed_tasks) < len(workflow.tasks):
                # Find ready tasks (dependencies satisfied)
                ready_tasks = []
                for task in workflow.tasks:
                    if (task.id not in completed_tasks and 
                        task.status == TaskStatus.PENDING and
                        all(dep in completed_tasks for dep in task.dependencies)):
                        ready_tasks.append(task)
                
                if not ready_tasks:
                    # Check for failed tasks that block progress
                    failed_tasks = [t for t in workflow.tasks if t.status == TaskStatus.FAILED]
                    if failed_tasks:
                        workflow.status = TaskStatus.FAILED
                        break
                    else:
                        # Circular dependency or other issue
                        raise Exception("No ready tasks found - possible circular dependency")
                
                # Execute ready tasks in parallel
                await asyncio.gather(
                    *[self._execute_task(task, task_outputs) for task in ready_tasks],
                    return_exceptions=True
                )
                
                # Update completed tasks
                for task in ready_tasks:
                    if task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
                        completed_tasks.add(task.id)
                        if task.status == TaskStatus.COMPLETED:
                            task_outputs.update(task.outputs)
            
            # Determine final workflow status
            failed_tasks = [t for t in workflow.tasks if t.status == TaskStatus.FAILED]
            if failed_tasks:
                workflow.status = TaskStatus.FAILED
            else:
                workflow.status = TaskStatus.COMPLETED
            
            workflow.completed_at = datetime.now()
            
        except Exception as e:
            workflow.status = TaskStatus.FAILED
            workflow.completed_at = datetime.now()
            print(f"Workflow execution failed: {e}")
        
        return workflow
    
    async def _execute_task(self, task: WorkflowTask, global_context: Dict[str, Any]):
        """
        Execute individual task
        """
        task.status = TaskStatus.RUNNING
        task.started_at = datetime.now()
        
        try:
            # Get task handler
            handler = self.task_handlers.get(task.task_type)
            if not handler:
                raise ValueError(f"No handler for task type: {task.task_type}")
            
            # Prepare task inputs with global context
            task_inputs = {**global_context, **task.inputs}
            
            # Execute task
            result = await handler(task, task_inputs)
            
            # Update task with results
            task.outputs = result
            task.status = TaskStatus.COMPLETED
            task.completed_at = datetime.now()
            
        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error = str(e)
            task.completed_at = datetime.now()
            print(f"Task {task.id} failed: {e}")
    
    async def _handle_claude_code_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle Claude Code SDK task"""
        from ..claude.task_delegator import TaskRequest, TaskType
        
        task_request = TaskRequest(
            type=TaskType[inputs.get("claude_task_type", "CODE_GENERATION")],
            description=inputs["description"],
            parameters=inputs.get("parameters", {}),
            project_context=inputs.get("project_context")
        )
        
        response = await self.task_delegator.delegate_task(task_request)
        
        if response.success:
            return {"result": response.output, "success": True}
        else:
            raise Exception(f"Claude Code task failed: {response.error}")
    
    async def _handle_rag_query_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle RAG query task"""
        query = inputs["query"]
        session_id = inputs.get("session_id")
        top_k = inputs.get("top_k", 5)
        
        results = await self.context_manager.retrieve_knowledge(
            query=query,
            session_id=session_id,
            top_k=top_k
        )
        
        return {"knowledge_results": results, "success": True}
    
    async def _handle_context_update_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle context update task"""
        session_id = inputs["session_id"]
        context_data = inputs["context_data"]
        
        success = await self.context_manager.update_session_context(session_id, context_data)
        
        return {"success": success}
    
    async def _handle_parallel_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle parallel task execution"""
        subtasks = inputs["subtasks"]
        
        # Execute subtasks in parallel
        results = await asyncio.gather(
            *[self._execute_subtask(subtask, inputs) for subtask in subtasks],
            return_exceptions=True
        )
        
        return {"parallel_results": results, "success": True}
    
    async def _handle_conditional_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle conditional task execution"""
        condition = inputs["condition"]
        true_task = inputs.get("true_task")
        false_task = inputs.get("false_task")
        
        # Evaluate condition (simple evaluation for now)
        condition_result = eval(condition, {}, inputs)
        
        if condition_result and true_task:
            result = await self._execute_subtask(true_task, inputs)
        elif not condition_result and false_task:
            result = await self._execute_subtask(false_task, inputs)
        else:
            result = {"skipped": True}
        
        return {"conditional_result": result, "condition_met": condition_result, "success": True}
    
    async def _handle_loop_task(self, task: WorkflowTask, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Handle loop task execution"""
        loop_items = inputs["items"]
        loop_task = inputs["loop_task"]
        
        results = []
        for item in loop_items:
            loop_inputs = {**inputs, "current_item": item}
            result = await self._execute_subtask(loop_task, loop_inputs)
            results.append(result)
        
        return {"loop_results": results, "success": True}
    
    async def _execute_subtask(self, subtask_def: Dict[str, Any], inputs: Dict[str, Any]) -> Any:
        """Execute subtask"""
        task_type = subtask_def["type"]
        handler = self.task_handlers.get(task_type)
        
        if handler:
            # Create temporary task for execution
            temp_task = WorkflowTask(
                id=str(uuid.uuid4()),
                name=subtask_def.get("name", "subtask"),
                task_type=task_type,
                inputs=subtask_def.get("inputs", {})
            )
            return await handler(temp_task, inputs)
        else:
            raise ValueError(f"Unknown subtask type: {task_type}")
    
    def _build_dependency_graph(self, tasks: List[WorkflowTask]) -> Dict[str, List[str]]:
        """Build task dependency graph"""
        graph = {}
        for task in tasks:
            graph[task.id] = task.dependencies
        return graph
    
    async def get_workflow_status(self, workflow_id: str) -> Optional[Dict[str, Any]]:
        """Get workflow execution status"""
        workflow = self.active_workflows.get(workflow_id)
        if not workflow:
            return None
        
        return {
            "workflow_id": workflow.id,
            "name": workflow.name,
            "status": workflow.status.value,
            "created_at": workflow.created_at.isoformat(),
            "started_at": workflow.started_at.isoformat() if workflow.started_at else None,
            "completed_at": workflow.completed_at.isoformat() if workflow.completed_at else None,
            "tasks": [
                {
                    "id": task.id,
                    "name": task.name,
                    "type": task.task_type,
                    "status": task.status.value,
                    "error": task.error
                }
                for task in workflow.tasks
            ]
        }
    
    async def cancel_workflow(self, workflow_id: str) -> bool:
        """Cancel running workflow"""
        workflow = self.active_workflows.get(workflow_id)
        if workflow and workflow.status == TaskStatus.RUNNING:
            workflow.status = TaskStatus.CANCELLED
            # Cancel running tasks
            for task in workflow.tasks:
                if task.status == TaskStatus.RUNNING:
                    task.status = TaskStatus.CANCELLED
            return True
        return False
    
    def register_task_handler(self, task_type: str, handler: Callable):
        """Register custom task handler"""
        self.task_handlers[task_type] = handler
```

## Advanced Patterns

### 8. Application Main Entry Point

```python
# src/main.py
import asyncio
import logging
import yaml
from pathlib import Path

from mcp.server import MCPServer
from claude.sdk_controller import ClaudeCodeSDKController
from claude.task_delegator import TaskDelegator
from rag.vector_store import VectorStoreFactory
from rag.retrieval import KnowledgeRetriever
from rag.context_manager import ContextManager
from workflow.orchestrator import WorkflowOrchestrator
from workflow.dify_integration import DifyWorkflowOrchestrator, DifyWorkflowConfig

class MCPApplication:
    """
    Main MCP application with Claude Code SDK integration
    """
    
    def __init__(self, config_path: str = "config/app_config.yaml"):
        self.config = self._load_config(config_path)
        self.logger = self._setup_logging()
        
        # Initialize components
        self.sdk_controller = None
        self.task_delegator = None
        self.vector_store = None
        self.knowledge_retriever = None
        self.context_manager = None
        self.workflow_orchestrator = None
        self.dify_orchestrator = None
        self.mcp_server = None
    
    def _load_config(self, config_path: str) -> dict:
        """Load application configuration"""
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def _setup_logging(self) -> logging.Logger:
        """Setup application logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(__name__)
    
    async def initialize(self):
        """Initialize all application components"""
        try:
            # Initialize Claude Code SDK Controller
            self.sdk_controller = ClaudeCodeSDKController(
                max_concurrent_processes=self.config.get("claude_sdk", {}).get("max_processes", 5)
            )
            
            # Initialize Task Delegator
            self.task_delegator = TaskDelegator(self.sdk_controller)
            
            # Initialize Vector Store
            vector_config = self.config.get("vector_store", {})
            self.vector_store = VectorStoreFactory.create_vector_store(
                store_type=vector_config.get("type", "chromadb"),
                **vector_config.get("config", {})
            )
            
            # Initialize Knowledge Retriever
            self.knowledge_retriever = KnowledgeRetriever(
                embedding_model=self.config.get("embeddings", {}).get("model", "text-embedding-3-large")
            )
            
            # Initialize Context Manager
            self.context_manager = ContextManager(
                vector_store=self.vector_store,
                knowledge_retriever=self.knowledge_retriever
            )
            
            # Initialize Workflow Orchestrator
            self.workflow_orchestrator = WorkflowOrchestrator(
                task_delegator=self.task_delegator,
                context_manager=self.context_manager
            )
            
            # Initialize Dify Integration (if configured)
            dify_config = self.config.get("dify")
            if dify_config:
                self.dify_orchestrator = DifyWorkflowOrchestrator(
                    DifyWorkflowConfig(**dify_config)
                )
            
            # Initialize MCP Server
            self.mcp_server = MCPServer(
                task_delegator=self.task_delegator,
                context_manager=self.context_manager
            )
            
            self.logger.info("All components initialized successfully")
            
        except Exception as e:
            self.logger.error(f"Failed to initialize application: {e}")
            raise
    
    async def run(self):
        """Run the MCP application"""
        await self.initialize()
        
        # Start background tasks
        background_tasks = [
            asyncio.create_task(self._cleanup_expired_sessions()),
            asyncio.create_task(self._health_check_loop()),
        ]
        
        try:
            self.logger.info("MCP Application started")
            
            # Keep the application running
            while True:
                await asyncio.sleep(1)
                
        except KeyboardInterrupt:
            self.logger.info("Shutting down MCP Application")
        finally:
            # Cancel background tasks
            for task in background_tasks:
                task.cancel()
            
            # Cleanup
            await self.shutdown()
    
    async def _cleanup_expired_sessions(self):
        """Background task to cleanup expired sessions"""
        while True:
            try:
                await asyncio.sleep(3600)  # Run every hour
                if self.context_manager:
                    cleaned = await self.context_manager.cleanup_expired_sessions()
                    if cleaned > 0:
                        self.logger.info(f"Cleaned up {cleaned} expired sessions")
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Error in session cleanup: {e}")
    
    async def _health_check_loop(self):
        """Background task for health checks"""
        while True:
            try:
                await asyncio.sleep(300)  # Run every 5 minutes
                
                # Check component health
                health_status = await self.get_health_status()
                
                if not health_status["healthy"]:
                    self.logger.warning(f"Health check failed: {health_status}")
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Error in health check: {e}")
    
    async def get_health_status(self) -> dict:
        """Get application health status"""
        health = {
            "healthy": True,
            "components": {},
            "timestamp": asyncio.get_event_loop().time()
        }
        
        try:
            # Check SDK Controller
            if self.sdk_controller:
                active_tasks = await self.sdk_controller.get_active_tasks()
                health["components"]["sdk_controller"] = {
                    "status": "healthy",
                    "active_tasks": len(active_tasks)
                }
            
            # Check Vector Store (simple ping)
            # This would depend on the specific vector store implementation
            health["components"]["vector_store"] = {"status": "healthy"}
            
            # Check Context Manager
            if self.context_manager:
                health["components"]["context_manager"] = {
                    "status": "healthy",
                    "active_sessions": len(self.context_manager.sessions)
                }
            
        except Exception as e:
            health["healthy"] = False
            health["error"] = str(e)
        
        return health
    
    async def shutdown(self):
        """Graceful shutdown"""
        try:
            # Close Dify client
            if self.dify_orchestrator:
                await self.dify_orchestrator.close()
            
            # Cancel active SDK processes
            if self.sdk_controller:
                for task_id in list(self.sdk_controller.active_processes.keys()):
                    await self.sdk_controller.cancel_task(task_id)
            
            self.logger.info("Application shutdown complete")
            
        except Exception as e:
            self.logger.error(f"Error during shutdown: {e}")

async def main():
    """Main entry point"""
    app = MCPApplication()
    await app.run()

if __name__ == "__main__":
    asyncio.run(main())