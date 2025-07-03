#!/usr/bin/env bun

/**
 * Crypto Data Streamer - Real-time data ingestion from CryptoCompare
 * 
 * This module handles:
 * - WebSocket connections to CryptoCompare
 * - REST API polling for historical data
 * - Data publishing to Redpanda/Kafka topics
 * - Error handling and reconnection logic
 */

import { Kafka, Producer } from 'kafkajs';
import WebSocket from 'ws';
import type { OHLCVData, MarketTick, StreamingConfig } from '../types/index.js';
import { loadConfig } from '../config/index.js';

export class CryptoDataStreamer {
  private kafka: Kafka;
  private producer: Producer;
  private config: StreamingConfig;
  private websockets: Map<string, WebSocket> = new Map();
  private isRunning = false;
  private logger: Console;

  constructor(config?: StreamingConfig) {
    this.config = config || loadConfig().streaming;
    this.logger = console;
    
    // Initialize Kafka client
    this.kafka = new Kafka({
      clientId: 'qicore-crypto-streamer',
      brokers: this.config.redpanda.brokers,
      retry: {
        initialRetryTime: 100,
        retries: 8,
      },
    });
    
    this.producer = this.kafka.producer({
      maxInFlightRequests: 1,
      idempotent: false,
      transactionTimeout: 30000,
    });
  }

  /**
   * Start the crypto data streaming
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('Streamer is already running');
      return;
    }

    try {
      this.logger.info('🚀 Starting Crypto Data Streamer...');
      
      // Connect to Kafka
      await this.producer.connect();
      this.logger.info('✅ Connected to Redpanda/Kafka');
      
      // Create topics if they don't exist
      await this.createTopics();
      
      // Start WebSocket connections
      await this.startWebSocketConnections();
      
      // Start REST API polling
      this.startRestPolling();
      
      this.isRunning = true;
      this.logger.info('🎉 Crypto Data Streamer is running!');
      
    } catch (error) {
      this.logger.error('❌ Failed to start streamer:', error);
      throw error;
    }
  }

  /**
   * Stop the streamer gracefully
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    this.logger.info('🛑 Stopping Crypto Data Streamer...');
    
    // Close WebSocket connections
    for (const [symbol, ws] of this.websockets) {
      ws.close();
      this.logger.info(`Closed WebSocket for ${symbol}`);
    }
    this.websockets.clear();
    
    // Disconnect from Kafka
    await this.producer.disconnect();
    
    this.isRunning = false;
    this.logger.info('✅ Crypto Data Streamer stopped');
  }

  /**
   * Create Kafka topics if they don't exist
   */
  private async createTopics(): Promise<void> {
    const admin = this.kafka.admin();
    await admin.connect();
    
    try {
      const topics = [
        {
          topic: this.config.redpanda.topics.marketData,
          numPartitions: 3,
          replicationFactor: 1,
          configEntries: [
            { name: 'retention.ms', value: '604800000' }, // 7 days
            { name: 'compression.type', value: 'snappy' },
          ],
        },
        {
          topic: this.config.redpanda.topics.signals,
          numPartitions: 2,
          replicationFactor: 1,
          configEntries: [
            { name: 'retention.ms', value: '2592000000' }, // 30 days
          ],
        },
        {
          topic: this.config.redpanda.topics.analysis,
          numPartitions: 2,
          replicationFactor: 1,
          configEntries: [
            { name: 'retention.ms', value: '7776000000' }, // 90 days
          ],
        },
      ];

      await admin.createTopics({
        topics,
        waitForLeaders: true,
      });
      
      this.logger.info('✅ Kafka topics created/verified');
    } catch (error) {
      // Topics might already exist, which is fine
      this.logger.info('Topics already exist or creation failed (likely already exist)');
    } finally {
      await admin.disconnect();
    }
  }

  /**
   * Start WebSocket connections for real-time data
   */
  private async startWebSocketConnections(): Promise<void> {
    const symbols = ['BTC', 'ETH', 'ADA', 'DOT', 'SOL'];
    const apiKey = process.env.CRYPTOCOMPARE_API_KEY;
    
    if (!apiKey) {
      this.logger.warn('⚠️  No CryptoCompare API key found, WebSocket connections will be limited');
    }

    for (const symbol of symbols) {
      await this.createWebSocketConnection(symbol, apiKey);
    }
  }

  /**
   * Create WebSocket connection for a specific symbol
   */
  private async createWebSocketConnection(symbol: string, apiKey?: string): Promise<void> {
    const wsUrl = 'wss://streamer.cryptocompare.com/v2';
    const ws = new WebSocket(wsUrl);
    
    ws.on('open', () => {
      this.logger.info(`📡 WebSocket connected for ${symbol}`);
      
      // Subscribe to trades and ticker data
      const subscribeMsg = {
        action: 'SubAdd',
        subs: [
          `5~CCCAGG~${symbol}~USD`, // Trade data
          `2~Binance~${symbol}~USD`, // Ticker data
        ],
      };
      
      if (apiKey) {
        (subscribeMsg as any).api_key = apiKey;
      }
      
      ws.send(JSON.stringify(subscribeMsg));
    });

    ws.on('message', (data: Buffer) => {
      try {
        const message = JSON.parse(data.toString());
        this.handleWebSocketMessage(symbol, message);
      } catch (error) {
        this.logger.error(`Error parsing WebSocket message for ${symbol}:`, error);
      }
    });

    ws.on('error', (error) => {
      this.logger.error(`WebSocket error for ${symbol}:`, error);
      this.reconnectWebSocket(symbol, apiKey);
    });

    ws.on('close', () => {
      this.logger.warn(`WebSocket closed for ${symbol}, reconnecting...`);
      this.reconnectWebSocket(symbol, apiKey);
    });

    this.websockets.set(symbol, ws);
  }

  /**
   * Handle incoming WebSocket messages
   */
  private async handleWebSocketMessage(symbol: string, message: any): Promise<void> {
    try {
      if (message.TYPE === '5') { // Trade data
        const tick: MarketTick = {
          symbol: message.FSYM,
          price: message.P,
          volume: message.Q,
          timestamp: message.TS * 1000, // Convert to milliseconds
          side: message.F === '1' ? 'buy' : 'sell',
        };
        
        await this.publishMarketTick(tick);
      }
      
      if (message.TYPE === '2') { // Ticker data
        // Handle ticker updates here if needed
        this.logger.debug(`Ticker update for ${symbol}:`, message);
      }
    } catch (error) {
      this.logger.error(`Error handling WebSocket message for ${symbol}:`, error);
    }
  }

  /**
   * Reconnect WebSocket with exponential backoff
   */
  private async reconnectWebSocket(symbol: string, apiKey?: string): Promise<void> {
    const ws = this.websockets.get(symbol);
    if (ws) {
      ws.terminate();
      this.websockets.delete(symbol);
    }

    // Wait before reconnecting (exponential backoff could be added here)
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    if (this.isRunning) {
      await this.createWebSocketConnection(symbol, apiKey);
    }
  }

  /**
   * Start REST API polling for OHLCV data
   */
  private startRestPolling(): void {
    const pollInterval = 60000; // 1 minute
    const symbols = ['BTC', 'ETH', 'ADA', 'DOT', 'SOL'];
    
    setInterval(async () => {
      if (!this.isRunning) return;
      
      for (const symbol of symbols) {
        try {
          await this.fetchAndPublishOHLCV(symbol);
        } catch (error) {
          this.logger.error(`Error fetching OHLCV for ${symbol}:`, error);
        }
      }
    }, pollInterval);
    
    this.logger.info('📊 Started REST API polling for OHLCV data');
  }

  /**
   * Fetch OHLCV data from CryptoCompare REST API
   */
  private async fetchAndPublishOHLCV(symbol: string): Promise<void> {
    const apiKey = process.env.CRYPTOCOMPARE_API_KEY;
    const baseUrl = 'https://min-api.cryptocompare.com/data/v2/histominute';
    
    const params = new URLSearchParams({
      fsym: symbol,
      tsym: 'USD',
      limit: '1', // Get latest minute
      aggregate: '1',
    });
    
    if (apiKey) {
      params.append('api_key', apiKey);
    }
    
    const url = `${baseUrl}?${params}`;
    
    try {
      const response = await fetch(url);
      const data = await response.json();
      
      if (data.Response === 'Success' && data.Data?.Data?.length > 0) {
        const latest = data.Data.Data[data.Data.Data.length - 1];
        
        const ohlcv: OHLCVData = {
          timestamp: latest.time * 1000, // Convert to milliseconds
          symbol,
          exchange: 'CCCAGG',
          open: latest.open,
          high: latest.high,
          low: latest.low,
          close: latest.close,
          volume: latest.volumeto, // Volume in USD
        };
        
        await this.publishOHLCV(ohlcv);
      }
    } catch (error) {
      this.logger.error(`Failed to fetch OHLCV for ${symbol}:`, error);
    }
  }

  /**
   * Publish OHLCV data to Kafka
   */
  private async publishOHLCV(ohlcv: OHLCVData): Promise<void> {
    try {
      await this.producer.send({
        topic: this.config.redpanda.topics.marketData,
        messages: [
          {
            key: ohlcv.symbol,
            value: JSON.stringify(ohlcv),
            partition: this.getPartitionForSymbol(ohlcv.symbol),
            timestamp: ohlcv.timestamp.toString(),
          },
        ],
      });
      
      this.logger.debug(`📈 Published OHLCV for ${ohlcv.symbol}`);
    } catch (error) {
      this.logger.error('Failed to publish OHLCV:', error);
    }
  }

  /**
   * Publish market tick to Kafka
   */
  private async publishMarketTick(tick: MarketTick): Promise<void> {
    try {
      await this.producer.send({
        topic: this.config.redpanda.topics.marketData,
        messages: [
          {
            key: `${tick.symbol}_tick`,
            value: JSON.stringify(tick),
            partition: this.getPartitionForSymbol(tick.symbol),
            timestamp: tick.timestamp.toString(),
          },
        ],
      });
      
      this.logger.debug(`🎯 Published tick for ${tick.symbol}: $${tick.price}`);
    } catch (error) {
      this.logger.error('Failed to publish market tick:', error);
    }
  }

  /**
   * Get partition number for symbol (simple hash-based partitioning)
   */
  private getPartitionForSymbol(symbol: string): number {
    let hash = 0;
    for (let i = 0; i < symbol.length; i++) {
      const char = symbol.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash) % 3; // Assuming 3 partitions
  }
}

// CLI execution
if (import.meta.main) {
  const streamer = new CryptoDataStreamer();
  
  // Graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    await streamer.stop();
    process.exit(0);
  });
  
  process.on('SIGTERM', async () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
    await streamer.stop();
    process.exit(0);
  });
  
  // Start the streamer
  streamer.start().catch((error) => {
    console.error('Failed to start crypto streamer:', error);
    process.exit(1);
  });
}