# Storage Layer Specification

**References**: [Package Strategy](package.phase.1.md)  
**Package Selection**: qicore-v4.core.cache, qicore-v4.db (per package.phase.1.md)  
**Purpose**: Multi-layered storage with caching and persistence

## Requirements

### Package Strategy Compliance
- **MUST use**: qicore-v4.core.cache (wraps redis>=5.0.1)
- **MUST use**: qicore-v4.db (wraps aiosqlite>=0.19.0)  
- **MUST NOT use**: Direct redis-py or aiosqlite imports
- **MUST implement**: Result<T> patterns for all storage operations

### Storage Components
1. **Cache Manager**: Redis-based caching with TTL
2. **Persistence Manager**: SQLite storage for conversations/sessions
3. **Index Manager**: Document search and indexing
4. **Migration Manager**: Database schema management

### Caching Requirements
- **Memory Cache**: LRU cache for hot data (100 items max)
- **Redis Cache**: Distributed cache with TTL (contexts: 1hr, embeddings: 24hr)
- **Cache Keys**: Deterministic hashing of operation + parameters
- **Invalidation**: Event-based cache invalidation on workspace changes

### Persistence Requirements  
- **Conversations**: Store user conversations with message history
- **Sessions**: Persist session state and metadata
- **Documents**: Index document metadata and search vectors
- **Migrations**: Schema versioning and migration support

### Performance Targets
- **Cache Access**: <10ms for cache hits
- **Database Queries**: <100ms for conversation retrieval
- **Batch Operations**: Support bulk insert/update operations
- **Connection Pooling**: Redis (10 connections), SQLite (5 connections)

### Error Handling
- **Cache Failures**: Graceful degradation, continue without cache
- **Database Errors**: Return Result<Error> with recovery suggestions  
- **Connection Issues**: Automatic reconnection with exponential backoff
- **Data Corruption**: Validation and repair procedures

## Implementation Notes

Storage layer should:
- Use qicore-v4 wrappers exclusively (per package.phase.1.md)
- Implement all operations as Result<T> returning functions
- Support both sync and async operations via qicore-v4 patterns
- Provide metrics and health monitoring
- Handle graceful degradation when external services unavailable 