/**
 * Core Types for QiCore Crypto Data Platform
 */

// Market Data Types
export interface OHLCVData {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  symbol: string;
  exchange?: string;
}

export interface MarketTick {
  symbol: string;
  price: number;
  volume: number;
  timestamp: number;
  side: 'buy' | 'sell';
}

export interface OrderBookLevel {
  price: number;
  quantity: number;
}

export interface OrderBook {
  symbol: string;
  timestamp: number;
  bids: OrderBookLevel[];
  asks: OrderBookLevel[];
}

// Agent Types
export interface AgentConfig {
  id: string;
  type: 'market_monitor' | 'technical_analysis' | 'risk_management' | 'execution';
  modelConfig: {
    provider: 'ollama' | 'anthropic' | 'openai';
    model: string;
    baseURL?: string;
    apiKey?: string;
  };
  enabled: boolean;
  updateInterval: number; // milliseconds
}

export interface AgentSignal {
  agentId: string;
  type: 'buy' | 'sell' | 'hold' | 'alert';
  symbol: string;
  strength: number; // 0-1
  reasoning: string;
  timestamp: number;
  confidence: number; // 0-1
  metadata?: Record<string, any>;
}

// Data Pipeline Types
export interface StreamingConfig {
  redpanda: {
    brokers: string[];
    topics: {
      marketData: string;
      signals: string;
      analysis: string;
    };
  };
  databases: {
    timescaledb: {
      host: string;
      port: number;
      database: string;
      username: string;
      password: string;
    };
    clickhouse: {
      host: string;
      port: number;
      database: string;
      username: string;
      password: string;
    };
  };
}

export interface DataSource {
  name: string;
  type: 'rest' | 'websocket';
  url: string;
  apiKey?: string;
  symbols: string[];
  enabled: boolean;
}

// Analysis Types
export interface TechnicalIndicator {
  name: string;
  value: number;
  signal: 'bullish' | 'bearish' | 'neutral';
  timestamp: number;
}

export interface MarketAnalysis {
  symbol: string;
  timestamp: number;
  indicators: TechnicalIndicator[];
  pattern?: string;
  trend: 'up' | 'down' | 'sideways';
  aiAnalysis: string;
  agentId: string;
}

// Configuration Types
export interface PlatformConfig {
  agents: AgentConfig[];
  streaming: StreamingConfig;
  dataSources: DataSource[];
  environment: 'development' | 'staging' | 'production';
  logging: {
    level: 'debug' | 'info' | 'warn' | 'error';
    outputs: ('console' | 'file' | 'database')[];
  };
}