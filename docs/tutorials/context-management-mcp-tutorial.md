# Context Management Tutorial: MCP Integration with Claude Code SDK

## Overview

This comprehensive tutorial explains how context information is stored, managed, and retrieved in our MCP application, and how Claude Code SDK accesses context through MCP protocol.

## Table of Contents

1. [Context Architecture Overview](#context-architecture-overview)
2. [Information Storage Strategy](#information-storage-strategy)
3. [Context Retrieval Mechanisms](#context-retrieval-mechanisms)
4. [MCP Protocol Integration](#mcp-protocol-integration)
5. [Claude Code SDK Context Access](#claude-code-sdk-context-access)
6. [Implementation Examples](#implementation-examples)
7. [Performance Optimization](#performance-optimization)
8. [Monitoring & Debugging](#monitoring--debugging)

## Context Architecture Overview

### Multi-Tier Context Management System

```typescript
// Context Management Architecture
interface ContextArchitecture {
  storage: {
    primary: VectorStore;      // Semantic context (Qdrant/ChromaDB)
    cache: Cache;              // Hot context (qicore-v4 Cache)
    session: SessionStore;     // Active sessions (Redis/Memory)
    persistent: PersistentStore; // Long-term memory (Database)
  };
  retrieval: {
    semantic: SemanticRetrieval;    // RAG-based context search
    temporal: TemporalRetrieval;    // Time-based context access
    hierarchical: HierarchicalRetrieval; // Nested context structures
  };
  protocols: {
    mcp: MCPContextHandler;     // MCP protocol interface
    claude: ClaudeSDKBridge;    // Claude Code SDK integration
  };
}
```

### Context Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Context Information Flow                     │
├─────────────────────────────────────────────────────────────────┤
│  Input Sources        │    Storage Layers      │   Access Points │
│  ├─ User Interactions │    ├─ Vector Store     │   ├─ MCP Tools   │
│  ├─ File Contents     │    ├─ Cache Layer      │   ├─ Claude SDK  │
│  ├─ Git History       │    ├─ Session Store    │   ├─ Web Interface│
│  ├─ Project Metadata  │    └─ Persistent DB    │   └─ API Clients │
│  └─ External APIs     │                        │                 │
├─────────────────────────────────────────────────────────────────┤
│                    Context Processing Pipeline                  │
│  Ingestion → Embedding → Storage → Indexing → Retrieval        │
└─────────────────────────────────────────────────────────────────┘
```

## Information Storage Strategy

### 1. Context Data Model

```typescript
// src/context/models.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { Cache } from "qicore/core/cache";

/**
 * Core context item with temporal and semantic metadata
 */
export interface ContextItem {
  id: string;
  content: string;
  type: ContextType;
  metadata: ContextMetadata;
  embedding?: number[];
  relationships: ContextRelationship[];
  created_at: Date;
  updated_at: Date;
  access_count: number;
  relevance_score?: number;
}

export enum ContextType {
  PROJECT_FILE = "project_file",
  CONVERSATION = "conversation", 
  CODE_SNIPPET = "code_snippet",
  DOCUMENTATION = "documentation",
  GIT_COMMIT = "git_commit",
  EXTERNAL_RESOURCE = "external_resource",
  USER_PREFERENCE = "user_preference",
  WORKFLOW_STATE = "workflow_state"
}

export interface ContextMetadata {
  source: string;
  project_path?: string;
  file_path?: string;
  language?: string;
  tags: string[];
  version?: string;
  author?: string;
  session_id?: string;
  importance: ImportanceLevel;
  sensitivity: SensitivityLevel;
  expiry?: Date;
}

export enum ImportanceLevel {
  CRITICAL = "critical",
  HIGH = "high", 
  MEDIUM = "medium",
  LOW = "low"
}

export enum SensitivityLevel {
  PUBLIC = "public",
  INTERNAL = "internal",
  CONFIDENTIAL = "confidential",
  SECRET = "secret"
}

export interface ContextRelationship {
  type: RelationType;
  target_id: string;
  strength: number; // 0.0 to 1.0
  metadata?: Record<string, any>;
}

export enum RelationType {
  DEPENDS_ON = "depends_on",
  REFERENCES = "references",
  SIMILAR_TO = "similar_to",
  FOLLOWS = "follows",
  CONTAINS = "contains",
  PART_OF = "part_of"
}
```

### 2. Vector Storage Implementation

```typescript
// src/context/vector-store.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { QiError } from "qicore/base/error";

export interface VectorStoreConfig {
  provider: "qdrant" | "chromadb";
  connection: {
    host: string;
    port: number;
    api_key?: string;
    collection_name: string;
  };
  embedding: {
    model: string;
    dimensions: number;
  };
}

export class ContextVectorStore {
  private logger: StructuredLogger;
  private config: VectorStoreConfig;
  private client: any; // Qdrant or ChromaDB client

  constructor(config: VectorStoreConfig) {
    this.config = config;
    this.logger = new StructuredLogger({
      level: "info",
      component: "ContextVectorStore"
    });
  }

  /**
   * Store context item with vector embedding
   */
  async storeContext(item: ContextItem): Promise<Result<string>> {
    try {
      // Generate embedding if not provided
      if (!item.embedding) {
        const embeddingResult = await this.generateEmbedding(item.content);
        if (embeddingResult.isFailure()) {
          return embeddingResult as Result<string>;
        }
        item.embedding = embeddingResult.unwrap();
      }

      // Prepare vector point
      const point = {
        id: item.id,
        vector: item.embedding,
        payload: {
          content: item.content,
          type: item.type,
          metadata: item.metadata,
          relationships: item.relationships,
          created_at: item.created_at.toISOString(),
          updated_at: item.updated_at.toISOString(),
          access_count: item.access_count
        }
      };

      // Store in vector database
      await this.client.upsert(this.config.connection.collection_name, [point]);

      this.logger.info("Context stored successfully", {
        context_id: item.id,
        type: item.type,
        content_length: item.content.length
      });

      return Result.success(item.id);

    } catch (error) {
      this.logger.error("Failed to store context", error as QiError, {
        context_id: item.id,
        type: item.type
      });

      return Result.failure(
        QiError.resourceError(
          `Context storage failed: ${error}`,
          "vector_store",
          item.id
        )
      );
    }
  }

  /**
   * Retrieve similar contexts using semantic search
   */
  async retrieveSimilar(
    query: string,
    options: {
      top_k?: number;
      similarity_threshold?: number;
      filters?: Record<string, any>;
      context_types?: ContextType[];
    } = {}
  ): Promise<Result<ContextItem[]>> {
    try {
      // Generate query embedding
      const queryEmbedding = await this.generateEmbedding(query);
      if (queryEmbedding.isFailure()) {
        return queryEmbedding as Result<ContextItem[]>;
      }

      // Build search filters
      const filters = this.buildFilters(options.filters, options.context_types);

      // Perform vector search
      const searchResults = await this.client.search(
        this.config.connection.collection_name,
        {
          vector: queryEmbedding.unwrap(),
          limit: options.top_k || 10,
          filter: filters,
          with_payload: true,
          score_threshold: options.similarity_threshold || 0.7
        }
      );

      // Convert results to ContextItems
      const contexts = searchResults.map((result: any) => ({
        id: result.id,
        content: result.payload.content,
        type: result.payload.type,
        metadata: result.payload.metadata,
        relationships: result.payload.relationships || [],
        created_at: new Date(result.payload.created_at),
        updated_at: new Date(result.payload.updated_at),
        access_count: result.payload.access_count,
        relevance_score: result.score
      }));

      this.logger.info("Context retrieval successful", {
        query_length: query.length,
        results_count: contexts.length,
        top_score: contexts[0]?.relevance_score
      });

      return Result.success(contexts);

    } catch (error) {
      this.logger.error("Context retrieval failed", error as QiError, {
        query_length: query.length,
        options
      });

      return Result.failure(
        QiError.resourceError(
          `Context retrieval failed: ${error}`,
          "vector_store",
          "search"
        )
      );
    }
  }

  /**
   * Update context and regenerate embedding if content changed
   */
  async updateContext(id: string, updates: Partial<ContextItem>): Promise<Result<void>> {
    try {
      // Get existing context
      const existing = await this.getContextById(id);
      if (existing.isFailure()) {
        return existing as Result<void>;
      }

      const context = existing.unwrap();
      
      // Apply updates
      const updatedContext = {
        ...context,
        ...updates,
        updated_at: new Date()
      };

      // Regenerate embedding if content changed
      if (updates.content && updates.content !== context.content) {
        const embeddingResult = await this.generateEmbedding(updates.content);
        if (embeddingResult.isFailure()) {
          return embeddingResult as Result<void>;
        }
        updatedContext.embedding = embeddingResult.unwrap();
      }

      // Store updated context
      const storeResult = await this.storeContext(updatedContext);
      return storeResult.map(() => undefined);

    } catch (error) {
      this.logger.error("Context update failed", error as QiError, { context_id: id });
      
      return Result.failure(
        QiError.resourceError(
          `Context update failed: ${error}`,
          "vector_store",
          id
        )
      );
    }
  }

  /**
   * Delete context by ID
   */
  async deleteContext(id: string): Promise<Result<void>> {
    try {
      await this.client.delete(this.config.connection.collection_name, [id]);
      
      this.logger.info("Context deleted successfully", { context_id: id });
      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Context deletion failed", error as QiError, { context_id: id });
      
      return Result.failure(
        QiError.resourceError(
          `Context deletion failed: ${error}`,
          "vector_store", 
          id
        )
      );
    }
  }

  /**
   * Get context by ID
   */
  async getContextById(id: string): Promise<Result<ContextItem>> {
    try {
      const result = await this.client.retrieve(
        this.config.connection.collection_name,
        [id],
        { with_payload: true }
      );

      if (!result || result.length === 0) {
        return Result.failure(
          QiError.resourceError(
            "Context not found",
            "vector_store",
            id
          )
        );
      }

      const point = result[0];
      const context: ContextItem = {
        id: point.id,
        content: point.payload.content,
        type: point.payload.type,
        metadata: point.payload.metadata,
        relationships: point.payload.relationships || [],
        created_at: new Date(point.payload.created_at),
        updated_at: new Date(point.payload.updated_at), 
        access_count: point.payload.access_count,
        embedding: point.vector
      };

      return Result.success(context);

    } catch (error) {
      this.logger.error("Context retrieval by ID failed", error as QiError, { context_id: id });
      
      return Result.failure(
        QiError.resourceError(
          `Context retrieval failed: ${error}`,
          "vector_store",
          id
        )
      );
    }
  }

  /**
   * Generate embedding for text content
   */
  private async generateEmbedding(content: string): Promise<Result<number[]>> {
    try {
      // Implementation depends on embedding provider (OpenAI, local model, etc.)
      const response = await fetch("http://embedding-service/embed", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          text: content,
          model: this.config.embedding.model 
        })
      });

      if (!response.ok) {
        throw new Error(`Embedding service error: ${response.statusText}`);
      }

      const data = await response.json();
      return Result.success(data.embedding);

    } catch (error) {
      return Result.failure(
        QiError.integrationError(
          `Embedding generation failed: ${error}`,
          "embedding_service",
          "generate"
        )
      );
    }
  }

  /**
   * Build search filters for vector query
   */
  private buildFilters(
    customFilters?: Record<string, any>,
    contextTypes?: ContextType[]
  ): any {
    const filters: any = {};

    if (contextTypes && contextTypes.length > 0) {
      filters.type = { $in: contextTypes };
    }

    if (customFilters) {
      Object.assign(filters, customFilters);
    }

    return filters;
  }
}
```

### 3. Cache Layer Implementation

```typescript
// src/context/cache-manager.ts
import { Cache, CacheManager } from "qicore/core/cache";
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";

export class ContextCacheManager {
  private hotCache: Cache<string, ContextItem>;
  private sessionCache: Cache<string, SessionContext>;
  private queryCache: Cache<string, ContextItem[]>;
  private logger: StructuredLogger;

  constructor() {
    this.hotCache = CacheManager.getCache<string, ContextItem>("hot_context", {
      maxSize: 1000,
      defaultTtl: 300000, // 5 minutes
      evictionPolicy: "lru"
    });

    this.sessionCache = CacheManager.getCache<string, SessionContext>("session_context", {
      maxSize: 500,
      defaultTtl: 1800000, // 30 minutes
      evictionPolicy: "lru"
    });

    this.queryCache = CacheManager.getCache<string, ContextItem[]>("query_cache", {
      maxSize: 200,
      defaultTtl: 600000, // 10 minutes
      evictionPolicy: "lru"
    });

    this.logger = new StructuredLogger({
      level: "info",
      component: "ContextCacheManager"
    });
  }

  /**
   * Cache context item for quick access
   */
  async cacheContext(context: ContextItem): Promise<Result<void>> {
    const result = await this.hotCache.set(context.id, context);
    
    if (result.isSuccess()) {
      this.logger.debug("Context cached", {
        context_id: context.id,
        type: context.type
      });
    }

    return result;
  }

  /**
   * Get context from cache
   */
  async getCachedContext(id: string): Promise<Result<ContextItem>> {
    const result = await this.hotCache.get(id);
    
    if (result.isSuccess()) {
      this.logger.debug("Context cache hit", { context_id: id });
    } else {
      this.logger.debug("Context cache miss", { context_id: id });
    }

    return result;
  }

  /**
   * Cache session context
   */
  async cacheSession(sessionId: string, context: SessionContext): Promise<Result<void>> {
    const result = await this.sessionCache.set(sessionId, context);
    
    if (result.isSuccess()) {
      this.logger.debug("Session cached", {
        session_id: sessionId,
        context_items: Object.keys(context.activeContext).length
      });
    }

    return result;
  }

  /**
   * Get session from cache
   */
  async getCachedSession(sessionId: string): Promise<Result<SessionContext>> {
    return await this.sessionCache.get(sessionId);
  }

  /**
   * Cache query results for repeated searches
   */
  async cacheQueryResults(queryHash: string, results: ContextItem[]): Promise<Result<void>> {
    return await this.queryCache.set(queryHash, results);
  }

  /**
   * Get cached query results
   */
  async getCachedQueryResults(queryHash: string): Promise<Result<ContextItem[]>> {
    return await this.queryCache.get(queryHash);
  }

  /**
   * Invalidate related cache entries when context changes
   */
  async invalidateContext(contextId: string): Promise<Result<void>> {
    try {
      // Remove from hot cache
      await this.hotCache.delete(contextId);

      // Invalidate related query cache entries
      // This would require more sophisticated tracking in a real implementation
      await this.queryCache.clear();

      this.logger.info("Context cache invalidated", { context_id: contextId });
      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Cache invalidation failed", error as any, { context_id: contextId });
      return Result.failure(
        QiError.resourceError(
          `Cache invalidation failed: ${error}`,
          "cache",
          contextId
        )
      );
    }
  }

  /**
   * Get cache statistics
   */
  getCacheStats(): Record<string, any> {
    return {
      hot_context: this.hotCache.getStats(),
      session_context: this.sessionCache.getStats(),
      query_cache: this.queryCache.getStats()
    };
  }
}

export interface SessionContext {
  sessionId: string;
  userId?: string;
  projectPath?: string;
  activeContext: Record<string, ContextItem>;
  conversationHistory: ConversationTurn[];
  preferences: UserPreferences;
  workingMemory: Record<string, any>;
  created_at: Date;
  last_accessed: Date;
}

export interface ConversationTurn {
  id: string;
  timestamp: Date;
  type: "user" | "assistant" | "system";
  content: string;
  metadata?: Record<string, any>;
}

export interface UserPreferences {
  language: string;
  codeStyle?: Record<string, any>;
  contextualDepth: "minimal" | "moderate" | "comprehensive";
  privacyLevel: "open" | "restricted" | "private";
}
```

## Context Retrieval Mechanisms

### 1. Semantic Retrieval Engine

```typescript
// src/context/retrieval-engine.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { QiError } from "qicore/base/error";

export class ContextRetrievalEngine {
  private vectorStore: ContextVectorStore;
  private cacheManager: ContextCacheManager;
  private logger: StructuredLogger;

  constructor(vectorStore: ContextVectorStore, cacheManager: ContextCacheManager) {
    this.vectorStore = vectorStore;
    this.cacheManager = cacheManager;
    this.logger = new StructuredLogger({
      level: "info",
      component: "ContextRetrievalEngine"
    });
  }

  /**
   * Multi-stage context retrieval with caching and fallbacks
   */
  async retrieveRelevantContext(
    query: string,
    sessionId: string,
    options: {
      maxResults?: number;
      includeTypes?: ContextType[];
      timeRange?: { start: Date; end: Date };
      projectScope?: string;
      importance?: ImportanceLevel[];
    } = {}
  ): Promise<Result<RetrievalResult>> {
    const startTime = Date.now();
    
    try {
      // 1. Check query cache first
      const queryHash = this.hashQuery(query, options);
      const cachedResult = await this.cacheManager.getCachedQueryResults(queryHash);
      
      if (cachedResult.isSuccess()) {
        this.logger.info("Context retrieval from cache", {
          query_hash: queryHash,
          results_count: cachedResult.unwrap().length,
          duration: Date.now() - startTime
        });

        return Result.success({
          contexts: cachedResult.unwrap(),
          source: "cache",
          totalResults: cachedResult.unwrap().length,
          retrievalTime: Date.now() - startTime
        });
      }

      // 2. Get session context for personalization
      const sessionContext = await this.cacheManager.getCachedSession(sessionId);
      
      // 3. Build enhanced query with session context
      const enhancedQuery = this.buildEnhancedQuery(
        query, 
        sessionContext.isSuccess() ? sessionContext.unwrap() : undefined
      );

      // 4. Perform semantic search
      const searchResult = await this.vectorStore.retrieveSimilar(enhancedQuery, {
        top_k: options.maxResults || 10,
        context_types: options.includeTypes,
        filters: this.buildTimeAndProjectFilters(options),
        similarity_threshold: 0.7
      });

      if (searchResult.isFailure()) {
        return searchResult as Result<RetrievalResult>;
      }

      let contexts = searchResult.unwrap();

      // 5. Apply post-processing filters
      contexts = this.applyPostProcessingFilters(contexts, options);

      // 6. Rank by relevance and importance
      contexts = this.rankContexts(contexts, query, sessionContext.unwrapOr(undefined));

      // 7. Cache results for future queries
      await this.cacheManager.cacheQueryResults(queryHash, contexts);

      const result: RetrievalResult = {
        contexts,
        source: "vector_search",
        totalResults: contexts.length,
        retrievalTime: Date.now() - startTime
      };

      this.logger.info("Context retrieval completed", {
        query_length: query.length,
        results_count: contexts.length,
        duration: result.retrievalTime,
        top_score: contexts[0]?.relevance_score
      });

      return Result.success(result);

    } catch (error) {
      this.logger.error("Context retrieval failed", error as QiError, {
        query_length: query.length,
        session_id: sessionId,
        options
      });

      return Result.failure(
        QiError.resourceError(
          `Context retrieval failed: ${error}`,
          "retrieval_engine",
          "retrieve"
        )
      );
    }
  }

  /**
   * Retrieve context for specific entity (file, function, etc.)
   */
  async retrieveEntityContext(
    entityId: string,
    entityType: ContextType,
    depth: number = 2
  ): Promise<Result<ContextItem[]>> {
    try {
      // Get the main entity
      const entityResult = await this.vectorStore.getContextById(entityId);
      if (entityResult.isFailure()) {
        return entityResult as Result<ContextItem[]>;
      }

      const entity = entityResult.unwrap();
      const contexts = [entity];
      
      // Traverse relationships up to specified depth
      await this.traverseRelationships(entity, contexts, depth, new Set([entityId]));

      this.logger.info("Entity context retrieved", {
        entity_id: entityId,
        entity_type: entityType,
        depth,
        total_contexts: contexts.length
      });

      return Result.success(contexts);

    } catch (error) {
      this.logger.error("Entity context retrieval failed", error as QiError, {
        entity_id: entityId,
        entity_type: entityType,
        depth
      });

      return Result.failure(
        QiError.resourceError(
          `Entity context retrieval failed: ${error}`,
          "retrieval_engine",
          entityId
        )
      );
    }
  }

  /**
   * Build enhanced query using session context
   */
  private buildEnhancedQuery(query: string, session?: SessionContext): string {
    if (!session) return query;

    const enhancements = [];

    // Add project context
    if (session.projectPath) {
      enhancements.push(`project:${session.projectPath}`);
    }

    // Add recent conversation context
    const recentTurns = session.conversationHistory
      .slice(-3)
      .map(turn => turn.content.substring(0, 100))
      .join(" ");
    
    if (recentTurns) {
      enhancements.push(`recent_context:${recentTurns}`);
    }

    // Add user preferences
    if (session.preferences.language) {
      enhancements.push(`language:${session.preferences.language}`);
    }

    return [query, ...enhancements].join(" ");
  }

  /**
   * Apply post-processing filters
   */
  private applyPostProcessingFilters(
    contexts: ContextItem[],
    options: any
  ): ContextItem[] {
    let filtered = contexts;

    // Time range filter
    if (options.timeRange) {
      filtered = filtered.filter(context => 
        context.created_at >= options.timeRange.start &&
        context.created_at <= options.timeRange.end
      );
    }

    // Importance filter
    if (options.importance) {
      filtered = filtered.filter(context =>
        options.importance.includes(context.metadata.importance)
      );
    }

    // Project scope filter
    if (options.projectScope) {
      filtered = filtered.filter(context =>
        context.metadata.project_path?.startsWith(options.projectScope)
      );
    }

    return filtered;
  }

  /**
   * Rank contexts by relevance and importance
   */
  private rankContexts(
    contexts: ContextItem[],
    query: string,
    session?: SessionContext
  ): ContextItem[] {
    return contexts.sort((a, b) => {
      // Base score from semantic similarity
      const scoreA = a.relevance_score || 0;
      const scoreB = b.relevance_score || 0;

      // Boost score based on importance
      const importanceBoost = {
        [ImportanceLevel.CRITICAL]: 0.3,
        [ImportanceLevel.HIGH]: 0.2,
        [ImportanceLevel.MEDIUM]: 0.1,
        [ImportanceLevel.LOW]: 0.0
      };

      const finalScoreA = scoreA + importanceBoost[a.metadata.importance];
      const finalScoreB = scoreB + importanceBoost[b.metadata.importance];

      // Recent access boost
      const recentBoost = 0.1;
      const daysSinceAccessA = (Date.now() - a.updated_at.getTime()) / (1000 * 60 * 60 * 24);
      const daysSinceAccessB = (Date.now() - b.updated_at.getTime()) / (1000 * 60 * 60 * 24);

      const boostedScoreA = daysSinceAccessA < 1 ? finalScoreA + recentBoost : finalScoreA;
      const boostedScoreB = daysSinceAccessB < 1 ? finalScoreB + recentBoost : finalScoreB;

      return boostedScoreB - boostedScoreA;
    });
  }

  /**
   * Traverse relationship graph
   */
  private async traverseRelationships(
    context: ContextItem,
    accumulated: ContextItem[],
    remainingDepth: number,
    visited: Set<string>
  ): Promise<void> {
    if (remainingDepth <= 0) return;

    for (const relationship of context.relationships) {
      if (visited.has(relationship.target_id)) continue;

      const relatedResult = await this.vectorStore.getContextById(relationship.target_id);
      if (relatedResult.isSuccess()) {
        const related = relatedResult.unwrap();
        accumulated.push(related);
        visited.add(relationship.target_id);

        await this.traverseRelationships(related, accumulated, remainingDepth - 1, visited);
      }
    }
  }

  /**
   * Build filters for time and project scope
   */
  private buildTimeAndProjectFilters(options: any): Record<string, any> {
    const filters: Record<string, any> = {};

    if (options.timeRange) {
      filters.created_at = {
        $gte: options.timeRange.start.toISOString(),
        $lte: options.timeRange.end.toISOString()
      };
    }

    if (options.projectScope) {
      filters["metadata.project_path"] = {
        $prefix: options.projectScope
      };
    }

    return filters;
  }

  /**
   * Generate query hash for caching
   */
  private hashQuery(query: string, options: any): string {
    const input = JSON.stringify({ query, options });
    // Simple hash implementation - use crypto in production
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString(36);
  }
}

export interface RetrievalResult {
  contexts: ContextItem[];
  source: "cache" | "vector_search" | "hybrid";
  totalResults: number;
  retrievalTime: number;
}
```

## MCP Protocol Integration

### 1. MCP Context Tools

```typescript
// src/mcp/context-tools.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";

export class MCPContextTools {
  private retrievalEngine: ContextRetrievalEngine;
  private vectorStore: ContextVectorStore;
  private cacheManager: ContextCacheManager;
  private logger: StructuredLogger;

  constructor(
    retrievalEngine: ContextRetrievalEngine,
    vectorStore: ContextVectorStore,
    cacheManager: ContextCacheManager
  ) {
    this.retrievalEngine = retrievalEngine;
    this.vectorStore = vectorStore;
    this.cacheManager = cacheManager;
    this.logger = new StructuredLogger({
      level: "info",
      component: "MCPContextTools"
    });
  }

  /**
   * Register MCP tools for context management
   */
  getToolDefinitions(): Record<string, any> {
    return {
      "context_search": {
        description: "Search for relevant context using semantic similarity",
        parameters: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query for finding relevant context"
            },
            session_id: {
              type: "string", 
              description: "Session ID for personalized context"
            },
            max_results: {
              type: "integer",
              description: "Maximum number of results to return",
              default: 10
            },
            context_types: {
              type: "array",
              items: { type: "string" },
              description: "Filter by specific context types"
            },
            project_scope: {
              type: "string",
              description: "Limit search to specific project path"
            }
          },
          required: ["query"]
        }
      },

      "context_store": {
        description: "Store new context information",
        parameters: {
          type: "object",
          properties: {
            content: {
              type: "string",
              description: "Content to store as context"
            },
            type: {
              type: "string",
              enum: ["project_file", "conversation", "code_snippet", "documentation", "git_commit", "external_resource"],
              description: "Type of context being stored"
            },
            metadata: {
              type: "object",
              description: "Additional metadata for the context"
            },
            session_id: {
              type: "string",
              description: "Session ID for attribution"
            }
          },
          required: ["content", "type"]
        }
      },

      "context_update": {
        description: "Update existing context information",
        parameters: {
          type: "object",
          properties: {
            context_id: {
              type: "string",
              description: "ID of context to update"
            },
            updates: {
              type: "object",
              description: "Fields to update"
            }
          },
          required: ["context_id", "updates"]
        }
      },

      "session_context": {
        description: "Get comprehensive context for a session",
        parameters: {
          type: "object",
          properties: {
            session_id: {
              type: "string",
              description: "Session ID to get context for"
            },
            include_history: {
              type: "boolean",
              description: "Include conversation history",
              default: true
            },
            include_project: {
              type: "boolean", 
              description: "Include project-related context",
              default: true
            }
          },
          required: ["session_id"]
        }
      },

      "context_relationships": {
        description: "Get related contexts through relationship graph",
        parameters: {
          type: "object",
          properties: {
            context_id: {
              type: "string",
              description: "Starting context ID"
            },
            relationship_types: {
              type: "array",
              items: { type: "string" },
              description: "Types of relationships to follow"
            },
            max_depth: {
              type: "integer",
              description: "Maximum relationship depth to traverse",
              default: 2
            }
          },
          required: ["context_id"]
        }
      }
    };
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName: string, parameters: any): Promise<Result<any>> {
    try {
      switch (toolName) {
        case "context_search":
          return await this.handleContextSearch(parameters);
        
        case "context_store":
          return await this.handleContextStore(parameters);
        
        case "context_update":
          return await this.handleContextUpdate(parameters);
        
        case "session_context":
          return await this.handleSessionContext(parameters);
        
        case "context_relationships":
          return await this.handleContextRelationships(parameters);
        
        default:
          return Result.failure(
            QiError.configurationError(
              `Unknown tool: ${toolName}`,
              "mcp_tools",
              "tool_name"
            )
          );
      }
    } catch (error) {
      this.logger.error("MCP tool call failed", error as QiError, {
        tool_name: toolName,
        parameters
      });

      return Result.failure(
        QiError.integrationError(
          `Tool execution failed: ${error}`,
          "mcp_tools",
          toolName
        )
      );
    }
  }

  /**
   * Handle context search tool
   */
  private async handleContextSearch(params: any): Promise<Result<any>> {
    const retrievalResult = await this.retrievalEngine.retrieveRelevantContext(
      params.query,
      params.session_id || "default",
      {
        maxResults: params.max_results,
        includeTypes: params.context_types,
        projectScope: params.project_scope
      }
    );

    if (retrievalResult.isFailure()) {
      return retrievalResult;
    }

    const result = retrievalResult.unwrap();
    
    return Result.success({
      contexts: result.contexts.map(context => ({
        id: context.id,
        content: context.content.substring(0, 500), // Truncate for MCP response
        type: context.type,
        relevance_score: context.relevance_score,
        metadata: {
          source: context.metadata.source,
          project_path: context.metadata.project_path,
          importance: context.metadata.importance,
          created_at: context.created_at
        }
      })),
      total_results: result.totalResults,
      retrieval_time: result.retrievalTime,
      source: result.source
    });
  }

  /**
   * Handle context storage tool
   */
  private async handleContextStore(params: any): Promise<Result<any>> {
    const contextItem: ContextItem = {
      id: this.generateContextId(),
      content: params.content,
      type: params.type as ContextType,
      metadata: {
        source: "mcp_tool",
        importance: ImportanceLevel.MEDIUM,
        sensitivity: SensitivityLevel.INTERNAL,
        tags: [],
        ...params.metadata
      },
      relationships: [],
      created_at: new Date(),
      updated_at: new Date(),
      access_count: 0
    };

    const storeResult = await this.vectorStore.storeContext(contextItem);
    
    if (storeResult.isSuccess()) {
      // Also cache for quick access
      await this.cacheManager.cacheContext(contextItem);
      
      return Result.success({
        context_id: contextItem.id,
        status: "stored",
        type: contextItem.type
      });
    }

    return storeResult;
  }

  /**
   * Handle context update tool  
   */
  private async handleContextUpdate(params: any): Promise<Result<any>> {
    const updateResult = await this.vectorStore.updateContext(
      params.context_id,
      params.updates
    );

    if (updateResult.isSuccess()) {
      // Invalidate cache
      await this.cacheManager.invalidateContext(params.context_id);
      
      return Result.success({
        context_id: params.context_id,
        status: "updated"
      });
    }

    return updateResult;
  }

  /**
   * Handle session context tool
   */
  private async handleSessionContext(params: any): Promise<Result<any>> {
    const sessionResult = await this.cacheManager.getCachedSession(params.session_id);
    
    if (sessionResult.isFailure()) {
      return Result.success({
        session_id: params.session_id,
        status: "not_found",
        active_contexts: [],
        conversation_history: []
      });
    }

    const session = sessionResult.unwrap();
    
    const response: any = {
      session_id: params.session_id,
      status: "found",
      created_at: session.created_at,
      last_accessed: session.last_accessed
    };

    if (params.include_history) {
      response.conversation_history = session.conversationHistory.slice(-10); // Last 10 turns
    }

    if (params.include_project) {
      response.project_context = {
        project_path: session.projectPath,
        active_contexts: Object.keys(session.activeContext).length,
        working_memory: Object.keys(session.workingMemory).length
      };
    }

    return Result.success(response);
  }

  /**
   * Handle context relationships tool
   */
  private async handleContextRelationships(params: any): Promise<Result<any>> {
    const relationshipResult = await this.retrievalEngine.retrieveEntityContext(
      params.context_id,
      ContextType.PROJECT_FILE, // This would be determined dynamically
      params.max_depth || 2
    );

    if (relationshipResult.isFailure()) {
      return relationshipResult;
    }

    const contexts = relationshipResult.unwrap();
    
    return Result.success({
      root_context_id: params.context_id,
      related_contexts: contexts.map(context => ({
        id: context.id,
        type: context.type,
        content_preview: context.content.substring(0, 200),
        relationships: context.relationships,
        metadata: {
          source: context.metadata.source,
          importance: context.metadata.importance
        }
      })),
      total_related: contexts.length,
      max_depth_reached: params.max_depth || 2
    });
  }

  /**
   * Generate unique context ID
   */
  private generateContextId(): string {
    return `ctx_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }
}
```

## Claude Code SDK Context Access

### 1. MCP Bridge for Claude SDK

```typescript
// src/mcp/claude-sdk-bridge.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { HTTPClient } from "qicore/application/http/client";

export class ClaudeSDKContextBridge {
  private mcpContextTools: MCPContextTools;
  private httpClient: HTTPClient;
  private logger: StructuredLogger;

  constructor(mcpContextTools: MCPContextTools, httpClient: HTTPClient) {
    this.mcpContextTools = mcpContextTools;
    this.httpClient = httpClient;
    this.logger = new StructuredLogger({
      level: "info",
      component: "ClaudeSDKContextBridge"
    });
  }

  /**
   * Provide context to Claude Code SDK via MCP protocol
   */
  async provideContextToSDK(
    sessionId: string,
    taskContext: TaskContext,
    sdkRequest: SDKRequest
  ): Promise<Result<EnrichedSDKRequest>> {
    try {
      // 1. Gather relevant context based on task
      const contextResult = await this.gatherTaskContext(sessionId, taskContext);
      if (contextResult.isFailure()) {
        return contextResult as Result<EnrichedSDKRequest>;
      }

      const gatheredContext = contextResult.unwrap();

      // 2. Build MCP resources for SDK
      const mcpResources = await this.buildMCPResources(gatheredContext);

      // 3. Enrich SDK request with context
      const enrichedRequest: EnrichedSDKRequest = {
        ...sdkRequest,
        mcp_context: {
          session_id: sessionId,
          available_tools: this.mcpContextTools.getToolDefinitions(),
          context_resources: mcpResources,
          project_scope: taskContext.projectPath,
          working_memory: gatheredContext.workingMemory
        },
        enhanced_prompt: this.buildEnhancedPrompt(
          sdkRequest.prompt,
          gatheredContext
        )
      };

      this.logger.info("Context provided to Claude SDK", {
        session_id: sessionId,
        task_type: taskContext.type,
        context_items: gatheredContext.contexts.length,
        resource_count: mcpResources.length
      });

      return Result.success(enrichedRequest);

    } catch (error) {
      this.logger.error("Failed to provide context to SDK", error as any, {
        session_id: sessionId,
        task_type: taskContext.type
      });

      return Result.failure(
        QiError.integrationError(
          `Context provision failed: ${error}`,
          "claude_sdk_bridge",
          "provide_context"
        )
      );
    }
  }

  /**
   * Handle context requests from Claude SDK
   */
  async handleSDKContextRequest(
    sessionId: string,
    mcpCall: MCPCall
  ): Promise<Result<MCPResponse>> {
    try {
      // Delegate to MCP context tools
      const toolResult = await this.mcpContextTools.handleToolCall(
        mcpCall.tool_name,
        mcpCall.parameters
      );

      if (toolResult.isFailure()) {
        return Result.success({
          id: mcpCall.id,
          error: {
            code: -32603,
            message: toolResult.error().message
          }
        });
      }

      return Result.success({
        id: mcpCall.id,
        result: {
          content: [
            {
              type: "text",
              text: JSON.stringify(toolResult.unwrap(), null, 2)
            }
          ]
        }
      });

    } catch (error) {
      this.logger.error("SDK context request failed", error as any, {
        session_id: sessionId,
        tool_name: mcpCall.tool_name
      });

      return Result.success({
        id: mcpCall.id,
        error: {
          code: -32603,
          message: `Internal error: ${error}`
        }
      });
    }
  }

  /**
   * Update context based on SDK feedback
   */
  async updateContextFromSDK(
    sessionId: string,
    sdkFeedback: SDKFeedback
  ): Promise<Result<void>> {
    try {
      // Store SDK-generated content as context
      if (sdkFeedback.generated_content) {
        await this.mcpContextTools.handleToolCall("context_store", {
          content: sdkFeedback.generated_content,
          type: "code_snippet",
          metadata: {
            source: "claude_sdk",
            task_id: sdkFeedback.task_id,
            session_id: sessionId,
            generated_at: new Date().toISOString()
          },
          session_id: sessionId
        });
      }

      // Update working memory with SDK insights
      if (sdkFeedback.insights) {
        await this.updateWorkingMemory(sessionId, sdkFeedback.insights);
      }

      this.logger.info("Context updated from SDK feedback", {
        session_id: sessionId,
        task_id: sdkFeedback.task_id,
        has_content: !!sdkFeedback.generated_content,
        has_insights: !!sdkFeedback.insights
      });

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to update context from SDK", error as any, {
        session_id: sessionId,
        task_id: sdkFeedback.task_id
      });

      return Result.failure(
        QiError.integrationError(
          `Context update failed: ${error}`,
          "claude_sdk_bridge",
          "update_context"
        )
      );
    }
  }

  /**
   * Gather relevant context for a task
   */
  private async gatherTaskContext(
    sessionId: string,
    taskContext: TaskContext
  ): Promise<Result<GatheredContext>> {
    const contexts: ContextItem[] = [];
    let workingMemory: Record<string, any> = {};

    // Get session context
    const sessionResult = await this.mcpContextTools.handleToolCall("session_context", {
      session_id: sessionId,
      include_history: true,
      include_project: true
    });

    if (sessionResult.isSuccess()) {
      workingMemory.session = sessionResult.unwrap();
    }

    // Search for task-relevant context
    const searchResult = await this.mcpContextTools.handleToolCall("context_search", {
      query: taskContext.description,
      session_id: sessionId,
      max_results: 15,
      project_scope: taskContext.projectPath,
      context_types: this.getRelevantContextTypes(taskContext.type)
    });

    if (searchResult.isSuccess()) {
      contexts.push(...searchResult.unwrap().contexts);
    }

    // Get file-specific context if working with files
    if (taskContext.filePath) {
      const fileContextResult = await this.getFileContext(taskContext.filePath);
      if (fileContextResult.isSuccess()) {
        contexts.push(...fileContextResult.unwrap());
      }
    }

    return Result.success({
      contexts,
      workingMemory,
      sessionId
    });
  }

  /**
   * Build MCP resources for SDK consumption
   */
  private async buildMCPResources(context: GatheredContext): Promise<MCPResource[]> {
    const resources: MCPResource[] = [];

    // Add context items as resources
    for (const item of context.contexts) {
      resources.push({
        uri: `context://item/${item.id}`,
        name: `Context: ${item.type}`,
        description: item.content.substring(0, 100) + "...",
        mimeType: "application/json"
      });
    }

    // Add session resource
    resources.push({
      uri: `context://session/${context.sessionId}`,
      name: "Session Context", 
      description: "Current session state and working memory",
      mimeType: "application/json"
    });

    // Add project resource if available
    if (context.workingMemory.session?.project_context) {
      resources.push({
        uri: `context://project/${context.workingMemory.session.project_context.project_path}`,
        name: "Project Context",
        description: "Project structure and metadata",
        mimeType: "application/json"
      });
    }

    return resources;
  }

  /**
   * Build enhanced prompt with context
   */
  private buildEnhancedPrompt(originalPrompt: string, context: GatheredContext): string {
    const promptParts = [originalPrompt];

    // Add context section
    if (context.contexts.length > 0) {
      promptParts.push("\n## Available Context:");
      
      context.contexts.slice(0, 5).forEach((item, index) => {
        promptParts.push(
          `### Context ${index + 1}: ${item.type}\n` +
          `Source: ${item.metadata.source}\n` +
          `Content: ${item.content.substring(0, 300)}...\n`
        );
      });
    }

    // Add working memory
    if (Object.keys(context.workingMemory).length > 0) {
      promptParts.push("\n## Working Memory:");
      promptParts.push(JSON.stringify(context.workingMemory, null, 2));
    }

    // Add MCP tool access information
    promptParts.push(
      "\n## Available Tools:",
      "You have access to MCP context tools for:",
      "- Searching for additional context: context_search",
      "- Storing new context: context_store", 
      "- Updating existing context: context_update",
      "- Exploring relationships: context_relationships"
    );

    return promptParts.join("\n");
  }

  /**
   * Get relevant context types for task type
   */
  private getRelevantContextTypes(taskType: string): ContextType[] {
    const typeMapping: Record<string, ContextType[]> = {
      "code_generation": [ContextType.PROJECT_FILE, ContextType.CODE_SNIPPET, ContextType.DOCUMENTATION],
      "code_review": [ContextType.PROJECT_FILE, ContextType.CODE_SNIPPET, ContextType.GIT_COMMIT],
      "debugging": [ContextType.PROJECT_FILE, ContextType.CODE_SNIPPET, ContextType.CONVERSATION],
      "documentation": [ContextType.PROJECT_FILE, ContextType.DOCUMENTATION, ContextType.CODE_SNIPPET],
      "refactoring": [ContextType.PROJECT_FILE, ContextType.CODE_SNIPPET, ContextType.GIT_COMMIT]
    };

    return typeMapping[taskType] || [
      ContextType.PROJECT_FILE,
      ContextType.CODE_SNIPPET,
      ContextType.CONVERSATION
    ];
  }

  /**
   * Get file-specific context
   */
  private async getFileContext(filePath: string): Promise<Result<ContextItem[]>> {
    // Implementation would search for context related to specific file
    return Result.success([]);
  }

  /**
   * Update working memory with new insights
   */
  private async updateWorkingMemory(
    sessionId: string,
    insights: Record<string, any>
  ): Promise<void> {
    // Implementation would update session working memory
  }
}

// Supporting interfaces
export interface TaskContext {
  type: string;
  description: string;
  projectPath?: string;
  filePath?: string;
  language?: string;
}

export interface SDKRequest {
  prompt: string;
  options?: Record<string, any>;
}

export interface EnrichedSDKRequest extends SDKRequest {
  mcp_context: {
    session_id: string;
    available_tools: Record<string, any>;
    context_resources: MCPResource[];
    project_scope?: string;
    working_memory: Record<string, any>;
  };
  enhanced_prompt: string;
}

export interface MCPCall {
  id: string;
  tool_name: string;
  parameters: any;
}

export interface MCPResponse {
  id: string;
  result?: any;
  error?: {
    code: number;
    message: string;
  };
}

export interface SDKFeedback {
  task_id: string;
  generated_content?: string;
  insights?: Record<string, any>;
  performance_metrics?: Record<string, any>;
}

export interface GatheredContext {
  contexts: ContextItem[];
  workingMemory: Record<string, any>;
  sessionId: string;
}

export interface MCPResource {
  uri: string;
  name: string;
  description: string;
  mimeType: string;
}
```

## Implementation Examples

### 1. Complete Context Manager Usage

```typescript
// src/examples/context-usage-example.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";

export class ContextManagerExample {
  private contextManager: CompleteContextManager;
  private logger: StructuredLogger;

  constructor() {
    // Initialize complete context management system
    this.contextManager = new CompleteContextManager({
      vectorStore: {
        provider: "qdrant",
        connection: {
          host: "localhost",
          port: 6333,
          collection_name: "mcp_context"
        },
        embedding: {
          model: "text-embedding-3-large",
          dimensions: 1536
        }
      },
      cache: {
        maxSize: 1000,
        defaultTtl: 300000
      }
    });

    this.logger = new StructuredLogger({
      level: "info",
      component: "ContextManagerExample"
    });
  }

  /**
   * Example: Store project file as context
   */
  async storeProjectFile(filePath: string, content: string): Promise<Result<string>> {
    const contextItem: ContextItem = {
      id: `file_${Date.now()}`,
      content,
      type: ContextType.PROJECT_FILE,
      metadata: {
        source: "file_system",
        file_path: filePath,
        language: this.detectLanguage(filePath),
        importance: ImportanceLevel.HIGH,
        sensitivity: SensitivityLevel.INTERNAL,
        tags: ["source_code", "project_file"]
      },
      relationships: [],
      created_at: new Date(),
      updated_at: new Date(),
      access_count: 0
    };

    return await this.contextManager.storeContext(contextItem);
  }

  /**
   * Example: Search for relevant context before code generation
   */
  async getCodeGenerationContext(
    request: string,
    sessionId: string,
    projectPath: string
  ): Promise<Result<RetrievalResult>> {
    return await this.contextManager.retrieveRelevantContext(
      request,
      sessionId,
      {
        maxResults: 8,
        includeTypes: [
          ContextType.PROJECT_FILE,
          ContextType.CODE_SNIPPET,
          ContextType.DOCUMENTATION
        ],
        projectScope: projectPath,
        importance: [ImportanceLevel.HIGH, ImportanceLevel.CRITICAL]
      }
    );
  }

  /**
   * Example: Handle Claude SDK context request
   */
  async handleClaudeSDKRequest(
    sessionId: string,
    taskDescription: string,
    projectPath: string
  ): Promise<Result<EnrichedSDKRequest>> {
    const taskContext: TaskContext = {
      type: "code_generation",
      description: taskDescription,
      projectPath
    };

    const sdkRequest: SDKRequest = {
      prompt: taskDescription,
      options: {
        output_format: "json",
        project_path: projectPath
      }
    };

    return await this.contextManager.provideContextToSDK(
      sessionId,
      taskContext,
      sdkRequest
    );
  }

  /**
   * Example: Update context based on user interaction
   */
  async updateFromUserInteraction(
    sessionId: string,
    userMessage: string,
    assistantResponse: string
  ): Promise<Result<void>> {
    // Store conversation turn
    const conversationContext: ContextItem = {
      id: `conv_${Date.now()}`,
      content: `User: ${userMessage}\nAssistant: ${assistantResponse}`,
      type: ContextType.CONVERSATION,
      metadata: {
        source: "user_interaction",
        session_id: sessionId,
        importance: ImportanceLevel.MEDIUM,
        sensitivity: SensitivityLevel.INTERNAL,
        tags: ["conversation", "interaction"]
      },
      relationships: [],
      created_at: new Date(),
      updated_at: new Date(),
      access_count: 0
    };

    return await this.contextManager.storeContext(conversationContext);
  }

  /**
   * Example: Get comprehensive session context
   */
  async getSessionSummary(sessionId: string): Promise<Result<SessionSummary>> {
    try {
      // Get session context
      const sessionResult = await this.contextManager.getSessionContext(sessionId);
      if (sessionResult.isFailure()) {
        return sessionResult as Result<SessionSummary>;
      }

      const session = sessionResult.unwrap();

      // Get recent activity
      const recentContexts = await this.contextManager.retrieveRecentActivity(
        sessionId,
        { hours: 24 }
      );

      // Get project context if available
      let projectSummary = null;
      if (session.projectPath) {
        const projectResult = await this.contextManager.getProjectSummary(session.projectPath);
        if (projectResult.isSuccess()) {
          projectSummary = projectResult.unwrap();
        }
      }

      const summary: SessionSummary = {
        sessionId,
        userId: session.userId,
        projectPath: session.projectPath,
        createdAt: session.created_at,
        lastAccessed: session.last_accessed,
        conversationTurns: session.conversationHistory.length,
        activeContexts: Object.keys(session.activeContext).length,
        recentActivity: recentContexts.unwrapOr([]),
        projectSummary,
        cacheStats: this.contextManager.getCacheStats()
      };

      return Result.success(summary);

    } catch (error) {
      return Result.failure(
        QiError.resourceError(
          `Session summary failed: ${error}`,
          "context_manager",
          sessionId
        )
      );
    }
  }

  private detectLanguage(filePath: string): string {
    const ext = filePath.split('.').pop()?.toLowerCase();
    const languageMap: Record<string, string> = {
      'ts': 'typescript',
      'js': 'javascript', 
      'py': 'python',
      'go': 'go',
      'rs': 'rust',
      'java': 'java',
      'cpp': 'cpp',
      'c': 'c'
    };
    return languageMap[ext || ''] || 'unknown';
  }
}

interface SessionSummary {
  sessionId: string;
  userId?: string;
  projectPath?: string;
  createdAt: Date;
  lastAccessed: Date;
  conversationTurns: number;
  activeContexts: number;
  recentActivity: ContextItem[];
  projectSummary?: any;
  cacheStats: Record<string, any>;
}

// Complete context manager that combines all components
class CompleteContextManager {
  private vectorStore: ContextVectorStore;
  private cacheManager: ContextCacheManager;
  private retrievalEngine: ContextRetrievalEngine;
  private mcpContextTools: MCPContextTools;
  private claudeSDKBridge: ClaudeSDKContextBridge;

  constructor(config: any) {
    // Initialize all components
    this.vectorStore = new ContextVectorStore(config.vectorStore);
    this.cacheManager = new ContextCacheManager();
    this.retrievalEngine = new ContextRetrievalEngine(this.vectorStore, this.cacheManager);
    this.mcpContextTools = new MCPContextTools(
      this.retrievalEngine,
      this.vectorStore,
      this.cacheManager
    );
    
    const httpClient = new HTTPClient();
    this.claudeSDKBridge = new ClaudeSDKContextBridge(this.mcpContextTools, httpClient);
  }

  async storeContext(item: ContextItem): Promise<Result<string>> {
    return await this.vectorStore.storeContext(item);
  }

  async retrieveRelevantContext(
    query: string,
    sessionId: string,
    options: any = {}
  ): Promise<Result<RetrievalResult>> {
    return await this.retrievalEngine.retrieveRelevantContext(query, sessionId, options);
  }

  async provideContextToSDK(
    sessionId: string,
    taskContext: TaskContext,
    sdkRequest: SDKRequest
  ): Promise<Result<EnrichedSDKRequest>> {
    return await this.claudeSDKBridge.provideContextToSDK(sessionId, taskContext, sdkRequest);
  }

  async getSessionContext(sessionId: string): Promise<Result<SessionContext>> {
    return await this.cacheManager.getCachedSession(sessionId);
  }

  async retrieveRecentActivity(sessionId: string, timeRange: any): Promise<Result<ContextItem[]>> {
    // Implementation for recent activity retrieval
    return Result.success([]);
  }

  async getProjectSummary(projectPath: string): Promise<Result<any>> {
    // Implementation for project summary
    return Result.success({});
  }

  getCacheStats(): Record<string, any> {
    return this.cacheManager.getCacheStats();
  }
}
```

This comprehensive tutorial provides a complete understanding of how context management works in our MCP application architecture, how Claude Code SDK accesses context through MCP protocol, and includes practical implementation examples using qicore-v4 TypeScript foundation.

The key points are:

1. **Multi-tier storage** with vector database, cache, and session management
2. **Semantic retrieval** using embeddings and RAG techniques  
3. **MCP protocol integration** that allows Claude SDK to access context through standard tools
4. **Real-time context updates** and relationship tracking
5. **Performance optimization** through caching and efficient retrieval

Claude Code SDK accesses context by making MCP tool calls to our context management system, which provides relevant information based on the current task and session state.