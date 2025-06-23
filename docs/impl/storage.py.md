# Storage Layer Implementation Design

> Python Implementation: Caching, Persistence, and Indexing  
> Design Phase: Implementation Architecture  
> Layer: Data - Storage Management  
> File Structure: `mcp_server/storage/`

## Overview

This document specifies the Python implementation strategy for the Storage Layer, including Redis caching, SQLite persistence, document indexing, and package integration strategies.

**Core Requirement**: Provide fast, reliable storage with sub-10ms cache access and robust data persistence.

## Architecture Overview

```
Storage Layer
├── CacheManager (Redis Integration)
├── PersistenceManager (SQLite Integration)  
├── IndexManager (Document Search)
├── MigrationManager (Schema Management)
└── BackupManager (Data Protection)
```

## Package Integration Strategy

### Redis Caching: redis-py Integration
```python
# Implementation Design
# mcp_server/storage/cache/redis_adapter.py

class RedisAdapter:
    """Async Redis wrapper with connection pooling"""
    
    # Connection Configuration
    - Connection pool: 10 connections max
    - Health check interval: 30 seconds
    - Reconnection strategy: exponential backoff
    - Timeout: 100ms for cache operations
    
    # Cache Operations
    async def get_cached_context(self, key: str) -> Optional[ContextBundle]:
        """Get cached context with deserialization"""
        - Retrieve from Redis with key prefix
        - Deserialize using msgpack (faster than JSON)
        - Handle cache misses gracefully
        - Track cache hit/miss metrics
    
    async def set_cached_context(self, key: str, context: ContextBundle, ttl: int = 3600):
        """Cache context with TTL"""
        - Serialize with msgpack compression
        - Set with expiration time
        - Handle Redis connection failures
        - Log cache size metrics
    
    # Batch Operations
    async def mget_embeddings(self, keys: List[str]) -> Dict[str, np.ndarray]:
        """Batch retrieve embeddings"""
        - Pipeline multiple GET operations
        - Deserialize numpy arrays
        - Return partial results on failures
```

### SQLite Persistence: aiosqlite Integration
```python
# Implementation Design  
# mcp_server/storage/persistence/sqlite_adapter.py

class SQLiteAdapter:
    """Async SQLite wrapper with connection pooling"""
    
    # Connection Management
    - Connection pool: 5 connections
    - WAL mode for better concurrency
    - Foreign key enforcement enabled
    - Auto-vacuum for maintenance
    
    # Core Operations
    async def save_conversation(self, conversation: Conversation):
        """Save conversation with transaction"""
        - Begin transaction
        - Insert conversation record
        - Insert message records in batch
        - Commit or rollback on error
        - Handle unique constraint violations
    
    async def get_conversation_history(self, user_id: str, limit: int = 50) -> List[Conversation]:
        """Retrieve conversation history"""
        - Query with proper indexing
        - Limit results and paginate
        - Join with message data
        - Return structured objects
    
    # Migration Support
    async def apply_migrations(self):
        """Apply database schema migrations"""
        - Check current schema version
        - Apply migrations incrementally
        - Handle migration failures
        - Update schema version
```

## Custom Implementation Requirements

### 1. Document Indexing System
```python
# Implementation Design
# mcp_server/storage/indexing/document_indexer.py

class DocumentIndexer:
    """Custom document indexing with full-text search"""
    
    # Index Structure
    - JSON metadata files per document
    - Full-text search with trigram indexing
    - Semantic search integration
    - Incremental updates
    
    # Indexing Operations
    async def index_document(self, doc: Document):
        """Index document with metadata extraction"""
        
        # Extract metadata
        metadata = {
            'path': doc.path,
            'size': doc.size,
            'modified': doc.modified_at,
            'type': doc.file_type,
            'checksum': doc.content_hash
        }
        
        # Full-text indexing
        text_content = await self._extract_text(doc)
        tokens = self._tokenize_text(text_content)
        
        # Store index entry
        index_entry = {
            'metadata': metadata,
            'tokens': tokens,
            'embeddings': await self._generate_embeddings(text_content)
        }
        
        await self._store_index_entry(doc.path, index_entry)
    
    # Search Operations
    async def search_documents(self, query: str, limit: int = 10) -> List[Document]:
        """Multi-modal document search"""
        
        # Text search
        text_results = await self._text_search(query, limit)
        
        # Semantic search
        semantic_results = await self._semantic_search(query, limit)
        
        # Combine and rank results
        combined_results = self._merge_search_results(text_results, semantic_results)
        
        return combined_results[:limit]
```

### 2. Cache Strategy Implementation
```python
# Implementation Design
# mcp_server/storage/cache/cache_strategy.py

class CacheStrategy:
    """Multi-level caching with intelligent eviction"""
    
    # Cache Levels
    Level 1 - Memory (LRU, 100 items):
        - Recent contexts and embeddings
        - Hot-path data (user preferences)
        - Session-specific data
        
    Level 2 - Redis (TTL-based):
        - Assembled contexts (1 hour TTL)
        - Document embeddings (24 hour TTL)
        - Search results (30 minute TTL)
        
    Level 3 - SQLite (Persistent):
        - Conversation history
        - User preferences
        - Document metadata
    
    # Cache Key Strategy
    def generate_cache_key(self, operation: str, params: Dict) -> str:
        """Generate deterministic cache keys"""
        
        # Normalize parameters
        normalized = self._normalize_params(params)
        
        # Create stable hash
        content = f"{operation}:{json.dumps(normalized, sort_keys=True)}"
        return hashlib.sha256(content.encode()).hexdigest()[:16]
    
    # Invalidation Strategy
    async def invalidate_cache(self, event: CacheInvalidationEvent):
        """Smart cache invalidation based on events"""
        
        if event.type == "workspace_change":
            await self._invalidate_workspace_cache(event.workspace_path)
        
        elif event.type == "conversation_update":
            await self._invalidate_conversation_cache(event.user_id)
        
        elif event.type == "document_change":
            await self._invalidate_document_cache(event.document_path)
```

## File Structure Implementation

```
mcp_server/storage/
├── __init__.py                      # Public API exports
├── manager.py                       # StorageManager main class
├── models.py                        # Storage data models
├── exceptions.py                    # Storage-specific exceptions
├── config.py                        # Storage configuration
│
├── cache/                           # Caching layer
│   ├── __init__.py
│   ├── redis_adapter.py             # Redis integration
│   ├── memory_cache.py              # In-memory LRU cache
│   ├── cache_strategy.py            # Multi-level caching
│   └── serialization.py             # Cache serialization
│
├── persistence/                     # Persistent storage
│   ├── __init__.py
│   ├── sqlite_adapter.py            # SQLite integration
│   ├── repositories.py              # Repository pattern
│   ├── migrations.py                # Schema migrations
│   └── backup.py                    # Backup management
│
├── indexing/                        # Document indexing
│   ├── __init__.py
│   ├── document_indexer.py          # Document indexing
│   ├── text_search.py               # Full-text search
│   ├── semantic_search.py           # Vector search integration
│   └── index_maintenance.py         # Index cleanup
│
└── monitoring/                      # Storage monitoring
    ├── __init__.py
    ├── metrics.py                   # Storage metrics
    ├── health_check.py              # Health monitoring
    └── performance.py               # Performance tracking
```

## Data Models

```python
# Implementation Design
# mcp_server/storage/models.py

@dataclass
class CacheEntry:
    """Generic cache entry with metadata"""
    key: str
    value: Any
    created_at: datetime
    accessed_at: datetime
    ttl: Optional[int] = None
    size_bytes: int = 0
    hit_count: int = 0

@dataclass
class ConversationRecord:
    """Conversation persistence model"""
    id: str
    user_id: str
    session_id: str
    created_at: datetime
    updated_at: datetime
    messages: List[MessageRecord]
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass
class DocumentIndex:
    """Document index entry"""
    path: str
    content_hash: str
    indexed_at: datetime
    file_size: int
    file_type: str
    tokens: List[str]
    embeddings: Optional[np.ndarray] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
```

## Performance Optimization

### Connection Pooling Strategy
```python
# Implementation Design
class ConnectionPoolManager:
    """Optimized connection pooling for all storage backends"""
    
    # Redis Pool Configuration
    redis_pool = {
        'max_connections': 10,
        'retry_on_timeout': True,
        'health_check_interval': 30,
        'socket_timeout': 0.1,
        'socket_connect_timeout': 0.5
    }
    
    # SQLite Pool Configuration  
    sqlite_pool = {
        'max_connections': 5,
        'timeout': 30.0,
        'check_same_thread': False,
        'isolation_level': None  # Autocommit mode
    }
    
    async def get_redis_connection(self) -> Redis:
        """Get Redis connection from pool"""
        return await self.redis_pool.get_connection()
    
    async def get_sqlite_connection(self) -> aiosqlite.Connection:
        """Get SQLite connection from pool"""
        return await self.sqlite_pool.get_connection()
```

## Error Handling and Resilience

```python
# Implementation Design
class StorageErrorHandler:
    """Comprehensive storage error handling"""
    
    # Error Recovery Strategies
    async def handle_redis_failure(self, operation: str, error: Exception):
        """Handle Redis connection failures"""
        
        # Log error with context
        logger.error(f"Redis operation failed: {operation}", exc_info=error)
        
        # Attempt reconnection
        if isinstance(error, ConnectionError):
            await self._attempt_redis_reconnection()
        
        # Fallback to memory cache
        return await self._fallback_to_memory_cache(operation)
    
    async def handle_sqlite_failure(self, operation: str, error: Exception):
        """Handle SQLite operation failures"""
        
        # Database corruption handling
        if "database disk image is malformed" in str(error):
            await self._handle_database_corruption()
        
        # Lock timeout handling
        elif "database is locked" in str(error):
            await self._handle_database_lock()
        
        # Retry with exponential backoff
        return await self._retry_sqlite_operation(operation)
```

---

**Implementation Status**: Design complete, ready for storage adapter development  
**Next Steps**:
1. Implement Redis async adapter with connection pooling
2. Create SQLite persistence layer with migrations
3. Build document indexing system
4. Develop multi-level cache strategy

**Dependencies**: redis-py, aiosqlite, msgpack, numpy 