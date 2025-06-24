# Context Assembly Implementation Design

> Python Implementation: Context Gathering and Optimization  
> Design Phase: Implementation Architecture  
> Layer: Processing - Context Assembly  
> File Structure: `mcp_server/processing/context/`

## Overview

This document specifies the Python implementation strategy for the Context Assembly system, including package integration, custom algorithms, and wrapper design for multi-source context optimization.

**Core Requirement**: Assemble relevant context from multiple sources within 500ms while optimizing for LLM context window constraints.

## Architecture Overview

```
Context Assembly Layer
├── ContextAssembler (Main Orchestrator)
├── SourceManager (Source Registry & Priority)
├── ContextOptimizer (Size & Relevance Optimization)
├── CacheManager (Context Caching Strategy)
└── Sources/
    ├── ConversationSource
    ├── WorkspaceSource  
    ├── SemanticSource
    └── DocumentSource
```

## Package Integration Strategy

### Vector Search: ChromaDB Integration
```python
# Implementation Design - Not actual code
# mcp_server/processing/context/adapters/vector_adapter.py

class VectorSearchAdapter:
    """Async wrapper for ChromaDB with connection pooling"""
    
    # Initialization Strategy
    - Lazy connection to ChromaDB
    - Thread pool for blocking operations (5 threads max)
    - Connection health monitoring with recovery
    - Collection management with auto-creation
    
    # Core Methods
    async def search_similar(query: str, limit: int) -> List[Document]:
        - Convert query to embeddings (sentence-transformers)
        - Execute ChromaDB search in thread pool
        - Apply relevance filtering (similarity > 0.7)
        - Return structured Document objects
    
    async def add_documents(documents: List[Document]) -> None:
        - Batch embeddings generation (max 50 docs)
        - Upsert to ChromaDB collection
        - Update search index asynchronously
        - Handle deduplication by content hash
    
    # Error Handling
    - ChromaDB connection failures -> fallback to text search
    - Embedding model errors -> use cached embeddings
    - Timeout handling (max 200ms per search)
```

### Embeddings: Sentence Transformers Integration
```python
# Implementation Design
# mcp_server/processing/context/adapters/embedding_adapter.py

class EmbeddingModelManager:
    """Model lifecycle and performance optimization"""
    
    # Model Selection Strategy
    - Primary: "all-MiniLM-L6-v2" (fast, good quality)
    - Fallback: "all-mpnet-base-v2" (better quality, slower)
    - Model warming at startup (background task)
    - GPU detection and optimization
    
    # Batch Processing
    async def encode_batch(texts: List[str]) -> List[np.ndarray]:
        - Optimal batch size: 32 texts
        - Thread pool execution (CPU-bound)
        - Memory management (clear cache after batches)
        - Progress tracking for large batches
    
    # Caching Strategy
    - LRU cache for frequent queries (max 1000 embeddings)
    - Persistent cache in Redis with TTL (24 hours)
    - Cache key: SHA-256 hash of normalized text
```

## Custom Implementation Requirements

### 1. Context Source Registry
```python
# Implementation Design - Architecture
# mcp_server/processing/context/sources/registry.py

class ContextSourceRegistry:
    """Dynamic source registration and priority management"""
    
    # Source Registration
    - Priority-based source ordering (1-100)
    - Dynamic source enable/disable
    - Source health monitoring
    - Timeout configuration per source
    
    # Source Types
    ConversationSource (Priority: 90):
        - Recent conversation turns (last 20)
        - User preference tracking
        - Context relevance scoring
        
    WorkspaceSource (Priority: 80):
        - Open files and recent edits
        - Git status and changes
        - Project structure context
        
    SemanticSource (Priority: 70):
        - Vector similarity search
        - Document semantic matching
        - Code similarity detection
        
    DocumentSource (Priority: 60):
        - README files and documentation
        - Configuration files
        - Project metadata
    
    # Parallel Source Execution
    async def gather_context(request: ContextRequest) -> ContextBundle:
        - Execute all sources concurrently
        - Apply per-source timeouts (100-300ms)
        - Aggregate results with priority weighting
        - Handle partial failures gracefully
```

### 2. Context Optimization Engine
```python
# Implementation Design
# mcp_server/processing/context/optimization/optimizer.py

class ContextOptimizer:
    """Smart context pruning and relevance optimization"""
    
    # Size Optimization Strategy
    - Target context window: 8192 tokens (configurable)
    - Reserve space: 2048 tokens for response
    - Working limit: 6000 tokens for context
    - Token counting: tiktoken library (GPT tokenizer)
    
    # Relevance Scoring Algorithm
    def calculate_relevance(item: ContextItem, query: str) -> float:
        Factors:
        - Semantic similarity (40% weight)
        - Recency (30% weight) 
        - Source priority (20% weight)
        - User interaction history (10% weight)
        
        Formula: weighted_sum(factors) * decay_function(age)
    
    # Pruning Strategy
    1. Sort items by relevance score (descending)
    2. Include high-priority items (score > 0.8)
    3. Fill remaining space with next-best items
    4. Ensure minimum diversity (at least 2 source types)
    5. Apply smart truncation (preserve sentence boundaries)
    
    # Content Deduplication
    - Content similarity detection (fuzzy matching)
    - Exact duplicate removal (hash-based)
    - Near-duplicate consolidation (merge similar items)
```

### 3. Context Caching Strategy
```python
# Implementation Design
# mcp_server/processing/context/caching/context_cache.py

class ContextCacheManager:
    """Multi-level caching for context assembly performance"""
    
    # Cache Levels
    Level 1 - Memory Cache:
        - Recent contexts (LRU, max 100 items)
        - Embedding cache (common queries)
        - Source result cache (5-minute TTL)
        
    Level 2 - Redis Cache:
        - Assembled contexts (1-hour TTL)
        - Document embeddings (24-hour TTL)
        - User preference cache (persistent)
    
    # Cache Key Strategy
    context_key = hash(query + workspace_state + user_id + timestamp_hour)
    source_key = hash(source_type + parameters + timestamp_minute)
    embedding_key = hash(normalized_text + model_version)
    
    # Cache Invalidation
    - Workspace changes -> invalidate workspace source cache
    - New conversation turns -> invalidate conversation cache
    - Time-based expiration with jitter
    - Manual cache warming for common patterns
    
    # Performance Targets
    - Cache hit ratio: > 60% for repeated queries
    - Cache lookup time: < 10ms
    - Cache memory usage: < 500MB
```

## File Structure Implementation

### Core Modules
```
mcp_server/processing/context/
├── __init__.py                      # Public API exports
├── assembler.py                     # Main ContextAssembler class
├── models.py                        # Context data structures
├── exceptions.py                    # Context-specific exceptions
├── config.py                        # Context system configuration
│
├── sources/                         # Context source implementations
│   ├── __init__.py
│   ├── base.py                      # AbstractContextSource
│   ├── registry.py                  # SourceRegistry
│   ├── conversation.py              # ConversationSource
│   ├── workspace.py                 # WorkspaceSource
│   ├── semantic.py                  # SemanticSource
│   └── document.py                  # DocumentSource
│
├── optimization/                    # Context optimization
│   ├── __init__.py
│   ├── optimizer.py                 # ContextOptimizer
│   ├── scorer.py                    # RelevanceScorer
│   ├── pruner.py                    # ContextPruner
│   └── tokenizer.py                 # TokenCounter wrapper
│
├── caching/                         # Caching layer
│   ├── __init__.py
│   ├── context_cache.py             # ContextCacheManager
│   ├── embedding_cache.py           # EmbeddingCache
│   └── source_cache.py              # SourceResultCache
│
├── adapters/                        # External package adapters
│   ├── __init__.py
│   ├── vector_adapter.py            # ChromaDB adapter
│   ├── embedding_adapter.py         # SentenceTransformer adapter
│   └── tokenizer_adapter.py         # tiktoken adapter
│
└── utils/                           # Context utilities
    ├── __init__.py
    ├── text_utils.py                # Text processing utilities
    ├── similarity.py                # Similarity calculations
    └── validation.py                # Context validation
```

### Data Models
```python
# Implementation Design
# mcp_server/processing/context/models.py

@dataclass
class ContextRequest:
    """Input specification for context assembly"""
    query: str
    user_id: str
    workspace_path: Optional[str]
    session_id: str
    max_tokens: int = 6000
    source_preferences: Dict[str, float] = field(default_factory=dict)
    include_sources: List[str] = field(default_factory=list)
    exclude_sources: List[str] = field(default_factory=list)

@dataclass  
class ContextItem:
    """Individual piece of context with metadata"""
    content: str
    source_type: str
    source_id: str
    relevance_score: float
    created_at: datetime
    metadata: Dict[str, Any] = field(default_factory=dict)
    token_count: Optional[int] = None

@dataclass
class ContextBundle:
    """Complete assembled context package"""
    items: List[ContextItem]
    total_tokens: int
    assembly_time_ms: int
    cache_hit_ratio: float
    source_summary: Dict[str, int]  # source_type -> item_count
    truncated: bool = False
    
class SourceResult:
    """Result from individual context source"""
    source_type: str
    items: List[ContextItem]
    execution_time_ms: int
    success: bool
    error: Optional[str] = None
```

## Wrapper Implementation Strategy

### ChromaDB Async Wrapper
```python
# Implementation Design Pattern
class ChromaDBWrapper:
    """Thread-safe async wrapper for ChromaDB"""
    
    def __init__(self):
        self._client: Optional[chromadb.Client] = None
        self._executor = ThreadPoolExecutor(max_workers=5)
        self._collections: Dict[str, chromadb.Collection] = {}
        self._health_check_interval = 30  # seconds
    
    async def __aenter__(self):
        await self._ensure_connection()
        return self
        
    async def _ensure_connection(self):
        """Lazy connection with health monitoring"""
        if not self._client:
            # Initialize in thread pool (blocking operation)
            self._client = await asyncio.get_event_loop().run_in_executor(
                self._executor, self._create_client
            )
    
    async def search_similar(self, collection: str, query_embedding: List[float], 
                           n_results: int = 10) -> List[Dict]:
        """Async similarity search with error handling"""
        try:
            collection_obj = await self._get_collection(collection)
            result = await asyncio.get_event_loop().run_in_executor(
                self._executor,
                lambda: collection_obj.query(
                    query_embeddings=[query_embedding],
                    n_results=n_results
                )
            )
            return self._format_results(result)
        except Exception as e:
            logger.error(f"ChromaDB search failed: {e}")
            return []  # Graceful degradation
```

## Performance Optimization Strategy

### Concurrent Execution Design
```python
# Implementation Pattern
class ContextAssembler:
    """Main orchestrator with performance optimization"""
    
    async def assemble_context(self, request: ContextRequest) -> ContextBundle:
        """Optimized context assembly with concurrency"""
        
        # Phase 1: Parallel source execution (200ms budget)
        start_time = time.time()
        
        source_tasks = []
        for source in self._source_registry.get_enabled_sources():
            task = asyncio.create_task(
                self._execute_source_with_timeout(source, request, timeout=300)
            )
            source_tasks.append(task)
        
        # Wait for all sources or timeout
        source_results = await asyncio.gather(*source_tasks, return_exceptions=True)
        
        # Phase 2: Result aggregation and optimization (100ms budget)
        valid_results = [r for r in source_results if isinstance(r, SourceResult) and r.success]
        all_items = []
        for result in valid_results:
            all_items.extend(result.items)
        
        # Phase 3: Context optimization (200ms budget)
        optimized_context = await self._optimizer.optimize_context(all_items, request)
        
        # Phase 4: Caching and metrics
        assembly_time = int((time.time() - start_time) * 1000)
        await self._cache_manager.cache_context(request, optimized_context)
        
        return ContextBundle(
            items=optimized_context.items,
            total_tokens=optimized_context.token_count,
            assembly_time_ms=assembly_time,
            cache_hit_ratio=self._calculate_cache_hit_ratio(),
            source_summary=self._build_source_summary(valid_results),
            truncated=optimized_context.truncated
        )
```

### Memory Management
```python
# Implementation Strategy
class ResourceManager:
    """Memory and resource optimization"""
    
    # Memory Constraints
    MAX_CONTEXT_ITEMS = 1000  # Hard limit
    MAX_EMBEDDING_CACHE_SIZE = 500_000  # ~500MB embeddings
    MAX_MEMORY_CACHE_ITEMS = 100
    
    # Cleanup Strategy
    async def periodic_cleanup(self):
        """Background task for resource cleanup"""
        while True:
            await asyncio.sleep(300)  # Every 5 minutes
            
            # Clear old embedding cache
            await self._embedding_cache.cleanup_expired()
            
            # Garbage collect context items
            gc.collect()
            
            # Monitor memory usage
            memory_usage = psutil.Process().memory_info().rss / 1024 / 1024
            if memory_usage > 1000:  # 1GB threshold
                await self._emergency_cleanup()
```

## Error Handling and Resilience

### Failure Modes and Recovery
```python
# Implementation Strategy
class ErrorHandler:
    """Comprehensive error handling for context assembly"""
    
    # Source Failure Handling
    - Individual source timeouts -> continue with other sources
    - ChromaDB connection failure -> fallback to text search
    - Embedding model failure -> use cached embeddings or simpler matching
    - Redis cache failure -> continue without caching
    
    # Degraded Mode Operations
    - No vector search -> text-based relevance scoring
    - No embeddings -> keyword matching with TF-IDF
    - No cache -> direct source execution (slower)
    - Partial source failures -> warn user, continue with available data
    
    # Circuit Breaker Pattern
    async def execute_with_circuit_breaker(self, source: ContextSource, 
                                         request: ContextRequest) -> SourceResult:
        circuit_breaker = self._circuit_breakers[source.name]
        
        if circuit_breaker.is_open:
            return SourceResult(
                source_type=source.name,
                items=[],
                execution_time_ms=0,
                success=False,
                error="Circuit breaker open"
            )
        
        try:
            result = await source.get_context(request)
            circuit_breaker.record_success()
            return result
        except Exception as e:
            circuit_breaker.record_failure()
            raise
```

## Testing Strategy

### Unit Test Design
```python
# Test Structure Design
tests/processing/context/
├── test_assembler.py               # Main orchestrator tests
├── test_sources/
│   ├── test_conversation_source.py
│   ├── test_workspace_source.py
│   └── test_semantic_source.py
├── test_optimization/
│   ├── test_optimizer.py
│   ├── test_scorer.py
│   └── test_pruner.py
├── test_caching/
│   └── test_context_cache.py
└── test_adapters/
    ├── test_vector_adapter.py
    └── test_embedding_adapter.py

# Mock Strategy
- Mock ChromaDB with in-memory collections
- Mock sentence-transformers with dummy embeddings
- Mock Redis with fakeredis
- Use pytest-asyncio for async test support
- Property-based testing for optimization algorithms
```

### Performance Test Design
```python
# Performance Test Requirements
class PerformanceTests:
    """Context assembly performance validation"""
    
    # Performance Targets
    - Context assembly time: < 500ms (p95)
    - Memory usage: < 500MB for 1000 context items
    - Cache hit ratio: > 60% for repeated queries
    - Concurrent request handling: 10 requests/second
    
    # Load Test Scenarios
    - Single user, multiple requests
    - Multiple users, concurrent requests  
    - Large workspace (10k+ files)
    - Memory pressure simulation
    - Network latency simulation (Redis/ChromaDB)
```

## Configuration and Deployment

### Configuration Structure
```python
# Implementation Design
# Context system configuration

class ContextConfig:
    """Context assembly configuration"""
    
    # Performance Settings
    max_context_tokens: int = 6000
    assembly_timeout_ms: int = 500
    source_timeout_ms: int = 300
    max_concurrent_sources: int = 5
    
    # Source Priorities (1-100)
    conversation_priority: int = 90
    workspace_priority: int = 80
    semantic_priority: int = 70
    document_priority: int = 60
    
    # Cache Settings
    memory_cache_size: int = 100
    redis_cache_ttl: int = 3600
    embedding_cache_ttl: int = 86400
    
    # Vector Search
    similarity_threshold: float = 0.7
    max_search_results: int = 50
    embedding_model: str = "all-MiniLM-L6-v2"
    
    # Optimization
    relevance_decay_factor: float = 0.95
    min_source_diversity: int = 2
    enable_deduplication: bool = True
```

---

**Implementation Status**: Design complete, ready for package wrapper development  
**Next Steps**:
1. Implement ChromaDB async wrapper
2. Create embedding model manager
3. Build source registry and base classes
4. Develop context optimization algorithms

**Dependencies**: ChromaDB, sentence-transformers, tiktoken, Redis 