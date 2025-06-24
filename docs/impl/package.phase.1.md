# Phase 1 Package Research - MCP Server Foundation

**Date**: June 23, 2025  
**Status**: ✅ COMPREHENSIVE RESEARCH - Phase 1 Foundation Only  
**Scope**: Basic MCP server with simple tool registry, local LLM, minimal storage  

## Package Selection Table

| Component | **Selected** | Alternatives Considered | Selection Rationale |
|-----------|-------------|------------------------|-------------------|
| **Core Framework** | `qicore-v4` | • Build everything from scratch<br/>• Compose separate packages | QICORE-V4 provides mathematically sound infrastructure with Result<T> + functional composition; alternatives require manual integration |
| **MCP Protocol** | `qicore-v4.ai.mcp` (wraps `mcp>=1.9.4`) | • **fastmcp** (alternative)<br/>• Custom JSON-RPC<br/>• Direct mcp usage | QICORE-V4 wrapper adds Result<T> + circuit breaker around proven official MCP SDK; direct usage lacks resilience |
| **Web Framework** | `qicore-v4.web` (wraps `fastapi>=0.115.13`) | • **starlette** (lower level)<br/>• **flask** (traditional)<br/>• Direct fastapi usage | QICORE-V4 wrapper integrates FastAPI with Result<T> + unified config; direct usage needs manual integration |
| **ASGI Server** | `qicore-v4.asgi` (wraps `uvicorn>=0.30.0`) | • **hypercorn** (HTTP/2)<br/>• **gunicorn+uvloop**<br/>• Direct uvicorn usage | QICORE-V4 wrapper configures Uvicorn for our stack; direct usage needs manual config management |
| **Data Validation** | `qicore-v4.core.config` (wraps `pydantic>=2.5.0`) | • **attrs+cattrs** (performance)<br/>• **marshmallow** (flexible)<br/>• Direct pydantic usage | QICORE-V4 wrapper provides Result<T> validation; direct Pydantic throws exceptions on validation errors |
| **LLM Client** | `qicore-v4.ai.llm` (wraps `ollama-python>=0.2.1`) | • **openai** (cloud GPT)<br/>• **anthropic** (cloud Claude)<br/>• Direct ollama usage | QICORE-V4 wrapper adds circuit breaker + Result<T> around Ollama client; direct usage lacks resilience patterns |
| **Session Storage** | `qicore-v4.core.cache` (wraps `redis>=5.0.1`) | • **memcached** (simpler)<br/>• **diskcache** (file-based)<br/>• Direct redis usage | QICORE-V4 wrapper provides Result<T> interface around Redis; direct usage throws exceptions on connection errors |
| **Database** | `qicore-v4.db` (wraps `aiosqlite>=0.19.0`) | • **asyncpg+postgresql** (powerful)<br/>• **databases** (abstraction)<br/>• Direct aiosqlite usage | QICORE-V4 wrapper provides Result<T> + unified interface; direct usage throws exceptions on SQL errors |
| **HTTP Client** | `qicore-v4.http` | • **httpx** (versatile)<br/>• **aiohttp** (async-only, faster)<br/>• **requests** (sync-only) | QICORE-V4 HTTP component provides circuit breaker + Result<T> error handling; external packages lack built-in resilience |
| **Configuration** | `qicore-v4.core.config` | • **python-dotenv** (simple)<br/>• **pydantic-settings** (structured)<br/>• **dynaconf** (feature-rich) | QICORE-V4 config supports multi-source merge with monoid semantics; external packages require manual composition |
| **Logging** | `qicore-v4.core.logger` | • **structlog** (structured)<br/>• **loguru** (simple async)<br/>• **standard logging** (built-in) | QICORE-V4 logger integrates with Result<T> + QiError patterns; external packages need Result wrapper adaptation |

## QICORE-V4 Integration Strategy

**QICORE-V4 provides comprehensive infrastructure** organized into specialized components that replace ALL external packages with superior functionality:

### Complete Component Organization in QICORE-V4

| Component Category | QICORE-V4 Module | Replaces External Packages | Key Advantages |
|-------------------|------------------|----------------------------|----------------|
| **🔧 Core Infrastructure** | `qicore-v4.core` | `python-dotenv`, `pydantic-settings`, `structlog`, `redis` | Unified config+logging+cache with Result<T> integration |
| **🌐 Web & Networking** | `qicore-v4.web`, `qicore-v4.asgi`, `qicore-v4.http` | `fastapi`, `uvicorn`, `httpx` | Integrated web stack with circuit breakers + Result<T> |
| **🤖 AI Components** | `qicore-v4.ai.mcp`, `qicore-v4.ai.llm` | `mcp`, `ollama-python`, `openai` | Unified AI interface with resilience patterns |
| **💾 Data Layer** | `qicore-v4.db` | `aiosqlite`, `asyncpg`, `databases` | Unified DB interface supporting SQLite + PostgreSQL |
| **⚡ Foundation** | `qicore-v4.base` | Manual try/catch patterns | Type-safe Result<T> + QiError with composition |

### Proposed Component Structure

```
qicore-v4/
├── core/                    # Infrastructure services
│   ├── config.py           # Multi-source configuration with validation
│   ├── logger.py           # Structured logging with Result<T> integration  
│   └── cache.py            # Memory + persistent caching with TTL/LRU
├── web/                     # Web framework
│   ├── server.py           # Web framework (FastAPI alternative)
│   └── middleware.py       # CORS, auth, logging middleware
├── asgi/                    # ASGI server  
│   └── server.py           # ASGI server (Uvicorn alternative)
├── http/                    # HTTP client
│   ├── client.py           # HTTP client with circuit breaker
│   └── circuit_breaker.py  # Circuit breaker implementation
├── ai/                      # AI/LLM components
│   ├── mcp.py              # MCP protocol wrapper with Result<T>
│   └── llm.py              # Unified LLM client (Ollama, OpenAI, etc.)
├── db/                      # Database layer
│   ├── sqlite.py           # SQLite adapter with Result<T>
│   ├── postgresql.py       # PostgreSQL adapter with Result<T>
│   └── interface.py        # Unified DB interface
└── base/                    # Foundation types
    ├── result.py           # Result<T> type with composition
    └── error.py            # QiError with context chaining
```

### Implementation Benefits

✅ **100% Result<T> Integration**: No exceptions, all operations return `Result<T>`  
✅ **Built-in Resilience**: Circuit breakers, retries, timeouts throughout  
✅ **Functional Composition**: Chain operations with `map()`, `flatMap()`, `orElse()`  
✅ **Mathematical Correctness**: Category theory ensures consistent behavior  
✅ **Unified Configuration**: Single config system for all components  
✅ **Zero External Dependencies**: Complete self-contained infrastructure  

### Package Selection Impact

**Architecture**: QICORE-V4 provides contracts and Result<T> wrappers around proven underlying packages

**Before QICORE-V4**: 11 external packages with exception-based error handling  
**After QICORE-V4**: **QICORE-V4 contracts + same underlying packages + Result<T> integration**

**Implementation Strategy** - QICORE-V4 Wrappers Around Proven Packages:
- ✅ `qicore-v4.ai.mcp` → **wraps** `mcp>=1.9.4` with Result<T> interface
- ✅ `qicore-v4.web` → **wraps** `fastapi>=0.115.13` with Result<T> + config integration  
- ✅ `qicore-v4.asgi` → **wraps** `uvicorn>=0.30.0` with unified config
- ✅ `qicore-v4.core.config` → **wraps** `pydantic>=2.5.0` + `python-dotenv>=1.0.0` with Result<T>
- ✅ `qicore-v4.ai.llm` → **wraps** `ollama-python>=0.2.1` with circuit breaker + Result<T>
- ✅ `qicore-v4.core.cache` → **wraps** `redis>=5.0.1` with Result<T> interface
- ✅ `qicore-v4.db` → **wraps** `aiosqlite>=0.19.0` with Result<T> interface
- ✅ `qicore-v4.http` → **wraps** `httpx>=0.28.1` with circuit breaker + Result<T>
- ✅ `qicore-v4.core.logger` → **wraps** `structlog>=23.2.0` with Result<T> integration

### Next Steps for QICORE-V4 Implementation

**Contracts to Add** in `qicore-v4/docs/sources/nl/`:
1. **Web Framework Contract** - FastAPI wrapper with Result<T> 
2. **ASGI Server Contract** - Uvicorn wrapper with config integration
3. **AI/MCP Contract** - MCP + LLM client wrappers 
4. **Database Contract** - aiosqlite wrapper with Result<T>

**Implementation Strategy**: 
- Keep proven underlying packages (they work well)
- Add QICORE-V4 wrapper layer for Result<T> consistency
- Extend contracts in `qicore-v4/docs/sources/nl/` for missing components
- Implement wrappers following category theory patterns

## Development Dependencies

| Tool | Package | Version | Purpose |
|------|---------|---------|---------|
| **Testing** | `pytest` | 7.4.0+ | Test framework |
| **Async Testing** | `pytest-asyncio` | 0.21.0+ | Async test support |
| **Type Checking** | `mypy` | 1.6.0+ | Static type analysis |
| **Code Quality** | `ruff` | 0.1.6+ | Linting and formatting |

## Executive Summary

**Research focused on 10 core packages** for Phase 1 MCP server foundation. Prioritized simplicity, battle-tested reliability, and minimal complexity over advanced patterns.

**Philosophy**: Start simple, build solid foundation, defer complexity to later phases.

---

## 1. MCP Protocol Implementation

### 🎯 **PRIMARY: mcp (Official Python SDK)**
- **Package**: `mcp>=1.9.4`
- **Maturity**: Official SDK from Anthropic, actively maintained
- **Purpose**: Core MCP protocol implementation
- **Integration**: Native protocol handling, client/server support

**Benefits**:
- Official protocol compliance guaranteed
- Handles MCP message validation automatically
- Built-in support for tools, resources, prompts
- Active development with latest protocol features

**Trade-offs**:
- Relatively new package (assess stability)
- API may evolve with protocol updates
- Documentation may be limited

**Integration Strategy**:
```python
from mcp.server import Server
from mcp.tools import Tool

app = Server("mcp-server-foundation")

@app.tool()
def list_files(path: str) -> str:
    # Tool implementation
    pass
```

### 🔄 **FALLBACK: Custom JSON-RPC**
- **Packages**: `fastapi + websockets + jsonrpc`
- **Trade-off**: More work, but full control over implementation
- **Use Case**: If official SDK proves unstable or insufficient

---

## 2. Web Framework & Server

### 🎯 **PRIMARY: FastAPI + Uvicorn**
- **Packages**: `fastapi>=0.115.13`, `uvicorn>=0.30.0`
- **Maturity**: FastAPI widely adopted, Uvicorn standard ASGI server
- **Purpose**: HTTP server for MCP protocol, async support

**FastAPI Benefits**:
- Automatic OpenAPI documentation
- Built-in request validation with Pydantic
- Excellent async/await support
- WebSocket support for MCP streaming
- Large ecosystem, extensive documentation

**Uvicorn Benefits**:
- Production-ready ASGI server
- High performance (uvloop integration)
- Graceful shutdown, signal handling
- Simple deployment configuration

**Integration Strategy**:
```python
from fastapi import FastAPI
from fastapi.websockets import WebSocket

app = FastAPI(title="MCP Server Phase 1")

@app.websocket("/mcp")
async def mcp_endpoint(websocket: WebSocket):
    # MCP protocol handling
    pass
```

### 🔄 **ALTERNATIVES**:
- **Starlette**: Lower level, more control
- **Flask + gevent**: Traditional, but less async-native
- **Raw ASGI**: Maximum performance, maximum complexity

**Decision**: FastAPI strikes best balance of features, performance, and simplicity.

---

## 3. LLM Integration

### 🎯 **PRIMARY: ollama-python**
- **Package**: `ollama-python>=0.2.1`
- **Maturity**: Active development, focused on local models
- **Purpose**: Client for local Ollama instance

**Benefits**:
- Simple, clean API for model interaction
- Streaming response support
- Model management integration
- Local deployment (privacy, no API keys)

**Example Integration**:
```python
import ollama

async def generate_response(prompt: str) -> str:
    response = await ollama.chat(
        model='llama2',
        messages=[{'role': 'user', 'content': prompt}]
    )
    return response['message']['content']
```

**Trade-offs**:
- Requires local Ollama installation
- Limited to Ollama-supported models
- May need fallback for different providers

### 🔄 **FALLBACKS**:
- **openai**: For cloud models (API key required)
- **httpx**: Direct HTTP client for any provider
- **litellm**: Multi-provider client (added complexity)

**Decision**: ollama-python for local-first approach, with provider pattern for extensibility.

---

## 4. Data Validation & Serialization

### 🎯 **PRIMARY: Pydantic**
- **Package**: `pydantic>=2.5.0`
- **Maturity**: Industry standard, version 2.x stable
- **Purpose**: Request/response validation, configuration management

**Benefits**:
- Runtime type validation
- JSON schema generation
- Error message generation
- FastAPI integration
- Configuration management

**Example Usage**:
```python
from pydantic import BaseModel, Field

class ToolRequest(BaseModel):
    name: str = Field(..., description="Tool name")
    arguments: dict = Field(default_factory=dict)
    
class ToolResponse(BaseModel):
    result: str
    success: bool
```

**Trade-offs**:
- Runtime overhead for validation
- Learning curve for advanced features

### 🔄 **ALTERNATIVES**:
- **dataclasses**: Lighter weight, no validation
- **marshmallow**: More flexible, more complex
- **cattrs**: Good performance, less ecosystem

**Decision**: Pydantic v2 for proven reliability and FastAPI integration.

---

## 5. Storage Solutions

### 🎯 **SESSION CACHE: Redis**
- **Package**: `redis>=5.0.1`
- **Maturity**: Battle-tested, widely deployed
- **Purpose**: Session state, conversation history, temporary cache

**Benefits**:
- High performance in-memory storage
- TTL support for automatic cleanup
- Pub/sub for future extensibility
- Simple key-value operations

**Basic Usage**:
```python
import redis.asyncio as redis

redis_client = redis.Redis(host='localhost', port=6379)

async def cache_session(session_id: str, data: dict):
    await redis_client.setex(f"session:{session_id}", 3600, json.dumps(data))
```

### 🎯 **PERSISTENT STORAGE: aiosqlite**
- **Package**: `aiosqlite>=0.19.0`
- **Maturity**: Official async wrapper for sqlite3
- **Purpose**: Tool results, logs, configuration persistence

**Benefits**:
- No external dependencies (file-based)
- ACID transactions
- Full SQL capabilities
- Simple backup/restore

**Basic Usage**:
```python
import aiosqlite

async def store_tool_result(tool_name: str, result: str):
    async with aiosqlite.connect("mcp_server.db") as db:
        await db.execute(
            "INSERT INTO tool_results (tool, result, timestamp) VALUES (?, ?, ?)",
            (tool_name, result, datetime.utcnow())
        )
        await db.commit()
```

### 🔄 **ALTERNATIVES**:
- **In-memory only**: Simpler, but data loss on restart
- **PostgreSQL**: Overkill for Phase 1, added operational complexity
- **JSON files**: Simple but no concurrent access, no queries

**Decision**: Redis + SQLite combination provides simplicity with performance.

---

## 6. HTTP Client & Tool Integration

### 🎯 **PRIMARY: httpx**
- **Package**: `httpx>=0.28.1`
- **Maturity**: Modern HTTP client, actively developed
- **Purpose**: Tool operations requiring HTTP requests

**Benefits**:
- Async/await native
- HTTP/2 support
- Connection pooling
- Timeout handling
- Similar API to requests but async

**Usage Example**:
```python
import httpx

async def fetch_url_content(url: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=10.0)
        response.raise_for_status()
        return response.text
```

### 🔄 **ALTERNATIVES**:
- **aiohttp**: More complex, client + server
- **requests + asyncio**: Sync client in async context (not ideal)

**Decision**: httpx for async-native HTTP operations.

---

## 7. Configuration Management

### 🎯 **PRIMARY: python-dotenv**
- **Package**: `python-dotenv>=1.0.0`
- **Maturity**: Standard for Python configuration
- **Purpose**: Environment-based configuration

**Benefits**:
- Simple .env file support
- Environment variable precedence
- Development vs production configs
- No complex configuration management

**Example Usage**:
```python
from dotenv import load_dotenv
import os

load_dotenv()

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
```

### 🔄 **ALTERNATIVES**:
- **Pydantic Settings**: More complex, better validation
- **configparser**: INI files, more traditional
- **dynaconf**: Feature-rich, overkill for Phase 1

**Decision**: python-dotenv for simplicity.

---

## 8. Logging & Observability

### 🎯 **PRIMARY: structlog**
- **Package**: `structlog>=23.2.0`
- **Maturity**: Standard for structured logging in Python
- **Purpose**: Structured logging for debugging and monitoring

**Benefits**:
- Structured JSON output
- Context preservation across async calls
- Performance (lazy formatting)
- Extensive ecosystem integration

**Example Setup**:
```python
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()
```

### 🔄 **ALTERNATIVES**:
- **Standard logging**: Built-in, but unstructured
- **loguru**: Simpler API, less structured
- **Rich logging**: Good for development, less for production

**Decision**: structlog for production-ready structured logging.

---

## 9. Development & Quality Tools

### 🎯 **TESTING: pytest**
- **Package**: `pytest>=7.4.0`
- **Maturity**: Python testing standard
- **Purpose**: Unit and integration testing

### 🎯 **TYPE CHECKING: mypy**
- **Package**: `mypy>=1.6.0`
- **Maturity**: Python static typing standard
- **Purpose**: Static type analysis

### 🎯 **CODE QUALITY: ruff**
- **Package**: `ruff>=0.1.6`
- **Maturity**: Fast, modern linting and formatting
- **Purpose**: Code quality enforcement

---

## Final Package Selection

### **Core Runtime Dependencies**
```toml
[tool.poetry.dependencies]
python = "^3.11"
mcp = "^1.9.4"                    # Official MCP SDK
fastapi = "^0.115.13"             # Web framework
uvicorn = "^0.30.0"               # ASGI server
pydantic = "^2.5.0"               # Data validation
ollama-python = "^0.2.1"          # LLM client
redis = "^5.0.1"                  # Session cache
aiosqlite = "^0.19.0"             # Persistent storage
httpx = "^0.28.1"                 # HTTP client
python-dotenv = "^1.0.0"          # Configuration
structlog = "^23.2.0"             # Structured logging
```

### **Development Dependencies**
```toml
[tool.poetry.group.dev.dependencies]
pytest = "^7.4.0"                 # Testing framework
pytest-asyncio = "^0.21.0"        # Async test support
mypy = "^1.6.0"                   # Type checking
ruff = "^0.1.6"                   # Linting and formatting
```

---

## Integration Architecture

### **Simple Component Mapping**
```
MCP Protocol     → mcp + fastapi
Tool Registry    → Python dict + pydantic validation
Session State    → redis (temporary) + aiosqlite (persistent)
LLM Integration  → ollama-python
Tool Operations  → httpx for HTTP, native Python for file/system
Configuration    → python-dotenv + pydantic settings
Logging         → structlog
```

### **Deployment Configuration**
```bash
# Development
uvicorn main:app --reload --port 8000

# Production
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

---

## Risk Assessment & Mitigation

### **Low Risk** ✅
- **FastAPI, Pydantic, Redis, SQLite**: Battle-tested, mature
- **httpx, structlog, pytest**: Widely adopted, stable APIs

### **Medium Risk** ⚠️
- **mcp**: Official but new, monitor for API changes
- **ollama-python**: Local dependency, ensure fallback options

### **Mitigation Strategies**
1. **MCP SDK**: Implement adapter pattern for easy switching
2. **LLM Client**: Provider interface for multiple backends
3. **Storage**: Simple interfaces for easy backend swapping
4. **Monitoring**: Structured logging for debugging issues

---

## Phase 1 Success Criteria

**Package selection complete when**:
1. ✅ All packages support async/await patterns
2. ✅ No complex dependencies or extensive configuration
3. ✅ Clear upgrade path for Phase 2 extensions
4. ✅ Production deployment is straightforward
5. ✅ Development iteration is fast and reliable

**Next Step**: Begin implementation with core MCP server and basic tool registry. 