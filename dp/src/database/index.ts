/**
 * Database Connection Utilities
 * 
 * This module provides connections and utilities for:
 * - TimescaleDB (time-series data)
 * - ClickHouse (analytics)
 * - Redis (caching)
 */

import { Pool } from 'pg';
import { createClient } from '@clickhouse/client';
import type { StreamingConfig, OHLCVData, MarketAnalysis, AgentSignal } from '../types/index.js';

export interface DatabaseConnections {
  timescaledb: Pool;
  clickhouse: ReturnType<typeof createClient>;
}

/**
 * Initialize database connections
 */
export async function initializeDatabases(config: StreamingConfig): Promise<DatabaseConnections> {
  console.log('🔌 Initializing database connections...');
  
  // TimescaleDB connection
  const timescaledb = new Pool({
    host: config.databases.timescaledb.host,
    port: config.databases.timescaledb.port,
    database: config.databases.timescaledb.database,
    user: config.databases.timescaledb.username,
    password: config.databases.timescaledb.password,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  // Test TimescaleDB connection
  try {
    const client = await timescaledb.connect();
    await client.query('SELECT NOW()');
    client.release();
    console.log('✅ TimescaleDB connected');
  } catch (error) {
    console.error('❌ TimescaleDB connection failed:', error);
    throw error;
  }

  // ClickHouse connection
  const clickhouse = createClient({
    host: `http://${config.databases.clickhouse.host}:${config.databases.clickhouse.port}`,
    database: config.databases.clickhouse.database,
    username: config.databases.clickhouse.username,
    password: config.databases.clickhouse.password,
    clickhouse_settings: {
      async_insert: 1,
      wait_for_async_insert: 0,
    },
  });

  // Test ClickHouse connection
  try {
    await clickhouse.ping();
    console.log('✅ ClickHouse connected');
  } catch (error) {
    console.error('❌ ClickHouse connection failed:', error);
    throw error;
  }

  return { timescaledb, clickhouse };
}

/**
 * TimescaleDB Operations
 */
export class TimescaleDBOperations {
  constructor(private pool: Pool) {}

  /**
   * Insert OHLCV data
   */
  async insertOHLCV(data: OHLCVData): Promise<void> {
    const query = `
      INSERT INTO market_data.ohlcv (time, symbol, exchange, open, high, low, close, volume)
      VALUES (to_timestamp($1::bigint / 1000), $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (time, symbol, exchange) DO UPDATE SET
        open = EXCLUDED.open,
        high = EXCLUDED.high,
        low = EXCLUDED.low,
        close = EXCLUDED.close,
        volume = EXCLUDED.volume
    `;
    
    const values = [
      data.timestamp,
      data.symbol,
      data.exchange || 'unknown',
      data.open,
      data.high,
      data.low,
      data.close,
      data.volume,
    ];

    await this.pool.query(query, values);
  }

  /**
   * Insert agent signal
   */
  async insertSignal(signal: AgentSignal): Promise<void> {
    const query = `
      INSERT INTO agent_data.signals (time, agent_id, signal_type, symbol, strength, confidence, reasoning, metadata)
      VALUES (to_timestamp($1::bigint / 1000), $2, $3, $4, $5, $6, $7, $8)
    `;
    
    const values = [
      signal.timestamp,
      signal.agentId,
      signal.type,
      signal.symbol,
      signal.strength,
      signal.confidence,
      signal.reasoning,
      JSON.stringify(signal.metadata || {}),
    ];

    await this.pool.query(query, values);
  }

  /**
   * Insert market analysis
   */
  async insertAnalysis(analysis: MarketAnalysis): Promise<void> {
    const query = `
      INSERT INTO analysis.market_analysis (time, symbol, agent_id, trend, pattern, indicators, ai_analysis)
      VALUES (to_timestamp($1::bigint / 1000), $2, $3, $4, $5, $6, $7)
    `;
    
    const values = [
      analysis.timestamp,
      analysis.symbol,
      analysis.agentId,
      analysis.trend,
      analysis.pattern || null,
      JSON.stringify(analysis.indicators),
      analysis.aiAnalysis,
    ];

    await this.pool.query(query, values);
  }

  /**
   * Get latest OHLCV data for symbol
   */
  async getLatestOHLCV(symbol: string, limit = 100): Promise<OHLCVData[]> {
    const query = `
      SELECT 
        EXTRACT(epoch FROM time) * 1000 as timestamp,
        symbol,
        exchange,
        open,
        high,
        low,
        close,
        volume
      FROM market_data.ohlcv 
      WHERE symbol = $1 
      ORDER BY time DESC 
      LIMIT $2
    `;
    
    const result = await this.pool.query(query, [symbol, limit]);
    
    return result.rows.map(row => ({
      timestamp: parseInt(row.timestamp),
      symbol: row.symbol,
      exchange: row.exchange,
      open: parseFloat(row.open),
      high: parseFloat(row.high),
      low: parseFloat(row.low),
      close: parseFloat(row.close),
      volume: parseFloat(row.volume),
    }));
  }

  /**
   * Get recent signals for symbol
   */
  async getRecentSignals(symbol: string, hours = 24): Promise<AgentSignal[]> {
    const query = `
      SELECT 
        agent_id,
        signal_type,
        symbol,
        strength,
        confidence,
        reasoning,
        metadata,
        EXTRACT(epoch FROM time) * 1000 as timestamp
      FROM agent_data.signals 
      WHERE symbol = $1 
        AND time >= NOW() - INTERVAL '${hours} hours'
      ORDER BY time DESC
    `;
    
    const result = await this.pool.query(query, [symbol]);
    
    return result.rows.map(row => ({
      agentId: row.agent_id,
      type: row.signal_type,
      symbol: row.symbol,
      strength: parseFloat(row.strength),
      confidence: parseFloat(row.confidence),
      reasoning: row.reasoning,
      metadata: row.metadata,
      timestamp: parseInt(row.timestamp),
    }));
  }
}

/**
 * ClickHouse Operations
 */
export class ClickHouseOperations {
  constructor(private client: ReturnType<typeof createClient>) {}

  /**
   * Insert OHLCV data for analytics
   */
  async insertOHLCVAnalytics(data: OHLCVData): Promise<void> {
    await this.client.insert({
      table: 'ohlcv_historical',
      values: [
        {
          timestamp: new Date(data.timestamp),
          symbol: data.symbol,
          exchange: data.exchange || 'unknown',
          open: data.open,
          high: data.high,
          low: data.low,
          close: data.close,
          volume: data.volume,
        },
      ],
      format: 'JSONEachRow',
    });
  }

  /**
   * Insert market analysis for analytics
   */
  async insertAnalysisAnalytics(analysis: MarketAnalysis): Promise<void> {
    await this.client.insert({
      table: 'market_analysis_historical',
      values: [
        {
          timestamp: new Date(analysis.timestamp),
          symbol: analysis.symbol,
          agent_id: analysis.agentId,
          trend: analysis.trend,
          pattern: analysis.pattern || '',
          indicators: JSON.stringify(analysis.indicators),
          ai_analysis: analysis.aiAnalysis,
          signal_strength: 0, // Can be derived from analysis
          confidence: 0, // Can be derived from analysis
        },
      ],
      format: 'JSONEachRow',
    });
  }

  /**
   * Get symbol volatility analysis
   */
  async getSymbolVolatility(symbol: string, hours = 24): Promise<any[]> {
    const query = `
      SELECT 
        hour,
        symbol,
        avg_price,
        price_volatility,
        period_high,
        period_low,
        total_volume,
        volatility_ratio
      FROM symbol_volatility
      WHERE symbol = {symbol: String}
        AND hour >= now() - INTERVAL {hours: UInt32} HOUR
      ORDER BY hour DESC
    `;
    
    const result = await this.client.query({
      query,
      query_params: { symbol, hours },
      format: 'JSONEachRow',
    });
    
    return await result.json();
  }

  /**
   * Get agent performance metrics
   */
  async getAgentPerformance(agentId: string, hours = 24): Promise<any[]> {
    const query = `
      SELECT 
        hour,
        agent_id,
        avg_accuracy,
        avg_response_time_ms,
        total_signals,
        correct_predictions,
        success_rate
      FROM agent_performance_summary
      WHERE agent_id = {agent_id: String}
        AND hour >= now() - INTERVAL {hours: UInt32} HOUR
      ORDER BY hour DESC
    `;
    
    const result = await this.client.query({
      query,
      query_params: { agent_id: agentId, hours },
      format: 'JSONEachRow',
    });
    
    return await result.json();
  }

  /**
   * Get daily OHLCV summary
   */
  async getDailyOHLCV(symbol: string, days = 30): Promise<any[]> {
    const query = `
      SELECT 
        day,
        symbol,
        exchange,
        open,
        high,
        low,
        close,
        volume,
        tick_count
      FROM ohlcv_daily
      WHERE symbol = {symbol: String}
        AND day >= today() - {days: UInt32}
      ORDER BY day DESC
    `;
    
    const result = await this.client.query({
      query,
      query_params: { symbol, days },
      format: 'JSONEachRow',
    });
    
    return await result.json();
  }
}

/**
 * Database manager that combines both databases
 */
export class DatabaseManager {
  public timescale: TimescaleDBOperations;
  public clickhouse: ClickHouseOperations;
  
  constructor(connections: DatabaseConnections) {
    this.timescale = new TimescaleDBOperations(connections.timescaledb);
    this.clickhouse = new ClickHouseOperations(connections.clickhouse);
  }

  /**
   * Insert data to both databases
   */
  async insertOHLCV(data: OHLCVData): Promise<void> {
    await Promise.all([
      this.timescale.insertOHLCV(data),
      this.clickhouse.insertOHLCVAnalytics(data),
    ]);
  }

  /**
   * Insert analysis to both databases
   */
  async insertAnalysis(analysis: MarketAnalysis): Promise<void> {
    await Promise.all([
      this.timescale.insertAnalysis(analysis),
      this.clickhouse.insertAnalysisAnalytics(analysis),
    ]);
  }

  /**
   * Insert signal to TimescaleDB only (real-time focus)
   */
  async insertSignal(signal: AgentSignal): Promise<void> {
    await this.timescale.insertSignal(signal);
  }
}