/**
 * Configuration Management for QiCore Crypto Data Platform
 */

import type { PlatformConfig } from '../types/index.js';

/**
 * Default configuration for development environment
 */
export const defaultConfig: PlatformConfig = {
  environment: 'development',
  
  agents: [
    {
      id: 'market-monitor-1',
      type: 'market_monitor',
      modelConfig: {
        provider: 'ollama',
        model: process.env.AI_MODEL || 'qwen3:0.6b',
        baseURL: process.env.AI_BASE_URL || 'http://localhost:11434'
      },
      enabled: true,
      updateInterval: 5000 // 5 seconds
    },
    {
      id: 'technical-analysis-1', 
      type: 'technical_analysis',
      modelConfig: {
        provider: 'ollama',
        model: process.env.AI_MODEL || 'qwen3:0.6b',
        baseURL: process.env.AI_BASE_URL || 'http://localhost:11434'
      },
      enabled: true,
      updateInterval: 30000 // 30 seconds
    }
  ],

  streaming: {
    redpanda: {
      brokers: ['localhost:9092'],
      topics: {
        marketData: 'crypto.market.data',
        signals: 'crypto.signals',
        analysis: 'crypto.analysis'
      }
    },
    databases: {
      timescaledb: {
        host: 'localhost',
        port: 5432,
        database: 'cryptodb',
        username: 'postgres',
        password: 'password'
      },
      clickhouse: {
        host: 'localhost',
        port: 8123,
        database: 'crypto_analytics',
        username: 'default',
        password: ''
      }
    }
  },

  dataSources: [
    {
      name: 'cryptocompare',
      type: 'rest',
      url: 'https://min-api.cryptocompare.com/data',
      apiKey: process.env.CRYPTOCOMPARE_API_KEY,
      symbols: ['BTC', 'ETH', 'ADA', 'DOT', 'SOL'],
      enabled: true
    },
    {
      name: 'cryptocompare-ws',
      type: 'websocket', 
      url: 'wss://streamer.cryptocompare.com/v2',
      apiKey: process.env.CRYPTOCOMPARE_API_KEY,
      symbols: ['BTC', 'ETH', 'ADA', 'DOT', 'SOL'],
      enabled: true
    }
  ],

  logging: {
    level: 'info',
    outputs: ['console', 'file']
  }
};

/**
 * Load configuration from environment variables and defaults
 */
export function loadConfig(): PlatformConfig {
  const config = { ...defaultConfig };
  
  // Override with environment variables
  if (process.env.NODE_ENV) {
    config.environment = process.env.NODE_ENV as any;
  }
  
  if (process.env.LOG_LEVEL) {
    config.logging.level = process.env.LOG_LEVEL as any;
  }
  
  // Database overrides
  if (process.env.TIMESCALE_HOST) {
    config.streaming.databases.timescaledb.host = process.env.TIMESCALE_HOST;
  }
  
  if (process.env.CLICKHOUSE_HOST) {
    config.streaming.databases.clickhouse.host = process.env.CLICKHOUSE_HOST;
  }
  
  return config;
}

/**
 * Validate configuration
 */
export function validateConfig(config: PlatformConfig): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  // Validate agents
  if (config.agents.length === 0) {
    errors.push('At least one agent must be configured');
  }
  
  // Validate data sources
  if (config.dataSources.length === 0) {
    errors.push('At least one data source must be configured');
  }
  
  // Check for required API keys
  const cryptoCompareSource = config.dataSources.find(ds => ds.name === 'cryptocompare');
  if (cryptoCompareSource && cryptoCompareSource.enabled && !cryptoCompareSource.apiKey) {
    errors.push('CryptoCompare API key is required when CryptoCompare data source is enabled');
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}