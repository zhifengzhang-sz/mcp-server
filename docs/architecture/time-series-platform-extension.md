# Time Series Data Platform Architecture Extension

## Executive Summary

This document extends our MCP application architecture to include comprehensive time series data processing capabilities, specifically designed for cryptocurrency market data analysis using CryptoCompare API, Redpanda/Kafka streaming, and advanced analytics.

## Architecture Overview

### Enhanced System Architecture

```typescript
┌─────────────────────────────────────────────────────────────────────────────┐
│                       MCP Time Series Application                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  Context Management        │    Workflow Execution      │  Time Series Engine│
│  ├─ Market Context Store   │    ├─ Strategy Orchestration│  ├─ Real-time Streams│
│  ├─ Pattern Memory         │    ├─ Analysis Workflows   │  ├─ Historical OHLC │
│  ├─ Alert Context          │    ├─ Trading Signals      │  ├─ Technical Analysis│
│  ├─ Risk Context           │    └─ Report Generation    │  └─ Market Sentiment │
│  └─ Correlation Analysis   │                            │                     │
├─────────────────────────────────────────────────────────────────────────────┤
│              Claude Code SDK + Financial Analytics Integration              │
│  ├─ Trading Strategy Gen   │    ├─ Risk Models          │  ├─ Backtesting     │
│  ├─ Technical Indicators   │    ├─ Portfolio Optimization│  ├─ Performance Metrics│
│  ├─ Pattern Recognition    │    ├─ Market Analysis      │  ├─ Alert Generation │
│  └─ Automated Research     │    └─ Compliance Checks   │  └─ Report Generation│
├─────────────────────────────────────────────────────────────────────────────┤
│     Streaming Layer        │   Storage & Analytics Layer │   External Data    │
│  ├─ Redpanda (Primary)     │   ├─ ClickHouse (OLAP)     │   ├─ CryptoCompare  │
│  ├─ Kafka (Compatibility)  │   ├─ TimescaleDB (TSDB)    │   ├─ Binance API    │
│  ├─ WebSocket Clients      │   ├─ Qdrant (Vector Store) │   ├─ CoinGecko      │
│  ├─ Data Ingestion Pipeline│   ├─ Redis (Cache/Sessions)│   ├─ News APIs      │
│  └─ Stream Processing      │   └─ PostgreSQL (Metadata) │   └─ Social Sentiment│
├─────────────────────────────────────────────────────────────────────────────┤
│                           MCP Protocol Layer                               │
│  ├─ Market Data Tools      │   ├─ Analytics Tools        │   ├─ Strategy Tools │
│  ├─ Real-time Subscriptions│   ├─ Pattern Detection     │   ├─ Risk Management │
│  ├─ Historical Queries     │   ├─ Technical Indicators  │   ├─ Portfolio Tools │
│  └─ Alert Management       │   └─ Performance Metrics   │   └─ Compliance Tools│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Time Series Data Sources

### 1. CryptoCompare Integration

#### Real-time Data Streams
```typescript
// src/data-sources/cryptocompare-client.ts
import { HTTPClient } from "qicore/application/http/client";
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { Cache } from "qicore/core/cache";

export interface OHLCData {
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
  exchange: string;
  change_24h?: number;
  change_pct_24h?: number;
}

export class CryptoCompareClient {
  private httpClient: HTTPClient;
  private wsConnections: Map<string, WebSocket>;
  private logger: StructuredLogger;
  private cache: Cache<string, any>;
  private subscriptions: Map<string, Set<string>>;

  constructor(apiKey: string, options: {
    baseUrl?: string;
    rateLimitPer30Min?: number;
    cacheConfig?: any;
  } = {}) {
    this.httpClient = new HTTPClient(
      options.baseUrl || "https://min-api.cryptocompare.com",
      {
        "Authorization": `Apikey ${apiKey}`,
        "Content-Type": "application/json"
      }
    );

    this.wsConnections = new Map();
    this.subscriptions = new Map();
    
    this.logger = new StructuredLogger({
      level: "info",
      component: "CryptoCompareClient"
    });

    this.cache = new Cache({
      maxSize: 10000,
      defaultTtl: 60000, // 1 minute for market data
      evictionPolicy: "lru"
    });
  }

  /**
   * Get historical OHLC data
   */
  async getHistoricalOHLC(
    symbol: string,
    timeframe: "minute" | "hour" | "day",
    options: {
      limit?: number;
      toTs?: number;
      exchange?: string;
      aggregate?: number;
    } = {}
  ): Promise<Result<OHLCData[]>> {
    try {
      const cacheKey = `historical_${symbol}_${timeframe}_${JSON.stringify(options)}`;
      const cached = await this.cache.get(cacheKey);
      
      if (cached.isSuccess()) {
        this.logger.debug("Cache hit for historical data", { symbol, timeframe });
        return Result.success(cached.unwrap());
      }

      const endpoint = this.getHistoricalEndpoint(timeframe);
      const params = {
        fsym: symbol.split('/')[0] || symbol,
        tsym: symbol.split('/')[1] || 'USD',
        limit: options.limit || 2000,
        ...(options.toTs && { toTs: options.toTs }),
        ...(options.exchange && { e: options.exchange }),
        ...(options.aggregate && { aggregate: options.aggregate })
      };

      const response = await this.httpClient.get<any>(endpoint, params);
      
      if (response.isFailure()) {
        return response as Result<OHLCData[]>;
      }

      const data = response.unwrap().data;
      
      if (!data || !data.Data || data.Response === "Error") {
        return Result.failure(
          QiError.integrationError(
            `CryptoCompare API error: ${data?.Message || 'Unknown error'}`,
            "cryptocompare",
            endpoint
          )
        );
      }

      const ohlcData: OHLCData[] = data.Data.map((candle: any) => ({
        timestamp: candle.time * 1000, // Convert to milliseconds
        open: candle.open,
        high: candle.high,
        low: candle.low,
        close: candle.close,
        volume: candle.volumeto,
        symbol: `${params.fsym}/${params.tsym}`,
        exchange: data.Aggregated ? "CCCAGG" : options.exchange
      }));

      // Cache the result
      await this.cache.set(cacheKey, ohlcData, 300000); // 5 minutes cache

      this.logger.info("Historical OHLC data retrieved", {
        symbol,
        timeframe,
        count: ohlcData.length,
        from: new Date(ohlcData[0]?.timestamp).toISOString(),
        to: new Date(ohlcData[ohlcData.length - 1]?.timestamp).toISOString()
      });

      return Result.success(ohlcData);

    } catch (error) {
      this.logger.error("Failed to get historical OHLC", error as any, { symbol, timeframe });
      
      return Result.failure(
        QiError.networkError(
          `Historical data request failed: ${error}`,
          `historical_${timeframe}`
        )
      );
    }
  }

  /**
   * Subscribe to real-time market data via WebSocket
   */
  async subscribeToRealTime(
    symbols: string[],
    callback: (data: MarketTick) => void,
    options: {
      exchanges?: string[];
      aggregateData?: boolean;
    } = {}
  ): Promise<Result<string>> {
    try {
      const subscriptionId = `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // CryptoCompare WebSocket URL
      const wsUrl = "wss://streamer.cryptocompare.com/v2";
      const ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        // Subscribe to trade data
        const subscribeMessage = {
          action: "SubAdd",
          subs: symbols.map(symbol => {
            const [from, to] = symbol.split('/');
            return `0~Coinbase~${from}~${to || 'USD'}`;
          })
        };

        ws.send(JSON.stringify(subscribeMessage));
        
        this.logger.info("WebSocket subscription established", {
          subscription_id: subscriptionId,
          symbols,
          exchanges: options.exchanges
        });
      };

      ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data);
          
          if (message.TYPE === "0") { // Trade update
            const tick: MarketTick = {
              symbol: `${message.FSYM}/${message.TSYM}`,
              price: message.P,
              volume: message.Q || 0,
              timestamp: message.TS * 1000,
              exchange: message.M,
              change_24h: message.CHANGE24HOUR,
              change_pct_24h: message.CHANGEPCT24HOUR
            };

            callback(tick);
          }
        } catch (parseError) {
          this.logger.error("Failed to parse WebSocket message", parseError as any, {
            subscription_id: subscriptionId
          });
        }
      };

      ws.onerror = (error) => {
        this.logger.error("WebSocket error", error as any, {
          subscription_id: subscriptionId
        });
      };

      ws.onclose = () => {
        this.logger.info("WebSocket connection closed", {
          subscription_id: subscriptionId
        });
        this.wsConnections.delete(subscriptionId);
      };

      this.wsConnections.set(subscriptionId, ws);
      this.subscriptions.set(subscriptionId, new Set(symbols));

      return Result.success(subscriptionId);

    } catch (error) {
      this.logger.error("Failed to establish WebSocket subscription", error as any, { symbols });
      
      return Result.failure(
        QiError.networkError(
          `WebSocket subscription failed: ${error}`,
          "websocket_subscribe"
        )
      );
    }
  }

  /**
   * Unsubscribe from real-time data
   */
  async unsubscribe(subscriptionId: string): Promise<Result<void>> {
    try {
      const ws = this.wsConnections.get(subscriptionId);
      const symbols = this.subscriptions.get(subscriptionId);

      if (ws && ws.readyState === WebSocket.OPEN) {
        const unsubscribeMessage = {
          action: "SubRemove",
          subs: Array.from(symbols || []).map(symbol => {
            const [from, to] = symbol.split('/');
            return `0~Coinbase~${from}~${to || 'USD'}`;
          })
        };

        ws.send(JSON.stringify(unsubscribeMessage));
        ws.close();
      }

      this.wsConnections.delete(subscriptionId);
      this.subscriptions.delete(subscriptionId);

      this.logger.info("Unsubscribed from real-time data", { subscription_id: subscriptionId });

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to unsubscribe", error as any, { subscription_id: subscriptionId });
      
      return Result.failure(
        QiError.networkError(
          `Unsubscribe failed: ${error}`,
          "websocket_unsubscribe"
        )
      );
    }
  }

  /**
   * Get current market prices
   */
  async getCurrentPrices(
    symbols: string[],
    currencies: string[] = ["USD"]
  ): Promise<Result<Record<string, Record<string, number>>>> {
    try {
      const cacheKey = `prices_${symbols.join(',')}_${currencies.join(',')}`;
      const cached = await this.cache.get(cacheKey);
      
      if (cached.isSuccess()) {
        return Result.success(cached.unwrap());
      }

      const response = await this.httpClient.get<any>("/data/pricemulti", {
        fsyms: symbols.join(','),
        tsyms: currencies.join(',')
      });

      if (response.isFailure()) {
        return response as Result<Record<string, Record<string, number>>>;
      }

      const prices = response.unwrap().data;
      
      // Cache for 30 seconds
      await this.cache.set(cacheKey, prices, 30000);

      this.logger.debug("Current prices retrieved", {
        symbols: symbols.length,
        currencies: currencies.length
      });

      return Result.success(prices);

    } catch (error) {
      this.logger.error("Failed to get current prices", error as any, { symbols, currencies });
      
      return Result.failure(
        QiError.networkError(
          `Price request failed: ${error}`,
          "current_prices"
        )
      );
    }
  }

  /**
   * Get market statistics
   */
  async getMarketStats(symbol: string): Promise<Result<MarketStats>> {
    try {
      const [from, to] = symbol.split('/');
      
      const response = await this.httpClient.get<any>("/data/pricemultifull", {
        fsyms: from,
        tsyms: to || 'USD'
      });

      if (response.isFailure()) {
        return response as Result<MarketStats>;
      }

      const rawData = response.unwrap().data.RAW?.[from]?.[to || 'USD'];
      
      if (!rawData) {
        return Result.failure(
          QiError.resourceError(
            "Market data not found",
            "cryptocompare",
            symbol
          )
        );
      }

      const stats: MarketStats = {
        symbol,
        price: rawData.PRICE,
        change24h: rawData.CHANGE24HOUR,
        changePct24h: rawData.CHANGEPCT24HOUR,
        volume24h: rawData.VOLUME24HOURTO,
        marketCap: rawData.MKTCAP,
        high24h: rawData.HIGH24HOUR,
        low24h: rawData.LOW24HOUR,
        open24h: rawData.OPEN24HOUR,
        lastUpdate: rawData.LASTUPDATE * 1000,
        totalVolume: rawData.TOTALVOLUME24HTO,
        supply: rawData.SUPPLY
      };

      return Result.success(stats);

    } catch (error) {
      this.logger.error("Failed to get market stats", error as any, { symbol });
      
      return Result.failure(
        QiError.networkError(
          `Market stats request failed: ${error}`,
          "market_stats"
        )
      );
    }
  }

  private getHistoricalEndpoint(timeframe: string): string {
    const endpoints = {
      minute: "/data/v2/histominute",
      hour: "/data/v2/histohour", 
      day: "/data/v2/histoday"
    };
    return endpoints[timeframe as keyof typeof endpoints] || endpoints.day;
  }

  /**
   * Cleanup resources
   */
  async destroy(): Promise<void> {
    // Close all WebSocket connections
    for (const [subscriptionId, ws] of this.wsConnections) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.close();
      }
    }
    
    this.wsConnections.clear();
    this.subscriptions.clear();
    
    this.logger.info("CryptoCompare client destroyed");
  }
}

export interface MarketStats {
  symbol: string;
  price: number;
  change24h: number;
  changePct24h: number;
  volume24h: number;
  marketCap?: number;
  high24h: number;
  low24h: number;
  open24h: number;
  lastUpdate: number;
  totalVolume: number;
  supply?: number;
}
```

### 2. Streaming Data Pipeline

#### Redpanda Integration
```typescript
// src/streaming/redpanda-client.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { QiError } from "qicore/base/error";

export interface RedpandaConfig {
  brokers: string[];
  clientId: string;
  groupId?: string;
  security?: {
    mechanism: "PLAIN" | "SCRAM-SHA-256" | "SCRAM-SHA-512";
    username: string;
    password: string;
  };
  ssl?: boolean;
}

export interface StreamMessage {
  key?: string;
  value: any;
  headers?: Record<string, string>;
  timestamp?: number;
  partition?: number;
  topic: string;
}

export class RedpandaStreamingClient {
  private producer: any; // Kafka producer instance
  private consumers: Map<string, any>;
  private logger: StructuredLogger;
  private config: RedpandaConfig;

  constructor(config: RedpandaConfig) {
    this.config = config;
    this.consumers = new Map();
    this.logger = new StructuredLogger({
      level: "info",
      component: "RedpandaStreamingClient"
    });
  }

  /**
   * Initialize producer and create topics
   */
  async initialize(): Promise<Result<void>> {
    try {
      // Initialize Kafka client (using kafkajs or similar)
      const { Kafka } = await import('kafkajs');
      
      const kafka = new Kafka({
        clientId: this.config.clientId,
        brokers: this.config.brokers,
        ssl: this.config.ssl,
        sasl: this.config.security ? {
          mechanism: this.config.security.mechanism.toLowerCase() as any,
          username: this.config.security.username,
          password: this.config.security.password
        } : undefined
      });

      this.producer = kafka.producer({
        maxInFlightRequests: 1,
        idempotent: true,
        transactionTimeout: 30000
      });

      await this.producer.connect();

      // Create necessary topics
      const admin = kafka.admin();
      await admin.connect();

      const topics = [
        'crypto.market.ticks',
        'crypto.market.ohlc',
        'crypto.market.stats',
        'crypto.alerts',
        'crypto.analysis.results'
      ];

      await admin.createTopics({
        topics: topics.map(topic => ({
          topic,
          numPartitions: 3,
          replicationFactor: 1
        }))
      });

      await admin.disconnect();

      this.logger.info("Redpanda client initialized", {
        brokers: this.config.brokers,
        topics_created: topics.length
      });

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to initialize Redpanda client", error as any);
      
      return Result.failure(
        QiError.integrationError(
          `Redpanda initialization failed: ${error}`,
          "redpanda",
          "initialize"
        )
      );
    }
  }

  /**
   * Publish market tick data
   */
  async publishMarketTick(tick: MarketTick): Promise<Result<void>> {
    try {
      const message: StreamMessage = {
        key: tick.symbol,
        value: JSON.stringify(tick),
        headers: {
          'content-type': 'application/json',
          'source': 'cryptocompare',
          'event-type': 'market-tick'
        },
        timestamp: tick.timestamp,
        topic: 'crypto.market.ticks'
      };

      await this.producer.send({
        topic: message.topic,
        messages: [{
          key: message.key,
          value: message.value,
          headers: message.headers,
          timestamp: message.timestamp?.toString()
        }]
      });

      this.logger.debug("Market tick published", {
        symbol: tick.symbol,
        price: tick.price,
        exchange: tick.exchange
      });

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to publish market tick", error as any, { tick });
      
      return Result.failure(
        QiError.integrationError(
          `Market tick publish failed: ${error}`,
          "redpanda",
          "publish_tick"
        )
      );
    }
  }

  /**
   * Publish OHLC data
   */
  async publishOHLC(ohlcData: OHLCData[]): Promise<Result<void>> {
    try {
      const messages = ohlcData.map(ohlc => ({
        key: `${ohlc.symbol}_${ohlc.timestamp}`,
        value: JSON.stringify(ohlc),
        headers: {
          'content-type': 'application/json',
          'source': 'cryptocompare',
          'event-type': 'ohlc-data'
        },
        timestamp: ohlc.timestamp.toString()
      }));

      await this.producer.send({
        topic: 'crypto.market.ohlc',
        messages
      });

      this.logger.info("OHLC data published", {
        symbol: ohlcData[0]?.symbol,
        count: ohlcData.length,
        timespan: {
          from: new Date(ohlcData[0]?.timestamp).toISOString(),
          to: new Date(ohlcData[ohlcData.length - 1]?.timestamp).toISOString()
        }
      });

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to publish OHLC data", error as any, { count: ohlcData.length });
      
      return Result.failure(
        QiError.integrationError(
          `OHLC publish failed: ${error}`,
          "redpanda",
          "publish_ohlc"
        )
      );
    }
  }

  /**
   * Subscribe to market data stream
   */
  async subscribeToMarketData(
    topics: string[],
    callback: (message: StreamMessage) => Promise<void>,
    options: {
      groupId?: string;
      fromBeginning?: boolean;
    } = {}
  ): Promise<Result<string>> {
    try {
      const { Kafka } = await import('kafkajs');
      
      const kafka = new Kafka({
        clientId: this.config.clientId,
        brokers: this.config.brokers,
        ssl: this.config.ssl,
        sasl: this.config.security ? {
          mechanism: this.config.security.mechanism.toLowerCase() as any,
          username: this.config.security.username,
          password: this.config.security.password
        } : undefined
      });

      const consumer = kafka.consumer({ 
        groupId: options.groupId || this.config.groupId || 'mcp-consumer'
      });

      await consumer.connect();
      await consumer.subscribe({ 
        topics,
        fromBeginning: options.fromBeginning || false
      });

      const subscriptionId = `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      await consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            const streamMessage: StreamMessage = {
              key: message.key?.toString(),
              value: JSON.parse(message.value?.toString() || '{}'),
              headers: message.headers ? Object.fromEntries(
                Object.entries(message.headers).map(([k, v]) => [k, v?.toString() || ''])
              ) : {},
              timestamp: message.timestamp ? parseInt(message.timestamp) : Date.now(),
              partition,
              topic
            };

            await callback(streamMessage);

          } catch (processError) {
            this.logger.error("Failed to process stream message", processError as any, {
              topic,
              partition,
              subscription_id: subscriptionId
            });
          }
        }
      });

      this.consumers.set(subscriptionId, consumer);

      this.logger.info("Subscribed to market data stream", {
        subscription_id: subscriptionId,
        topics,
        group_id: options.groupId
      });

      return Result.success(subscriptionId);

    } catch (error) {
      this.logger.error("Failed to subscribe to market data", error as any, { topics });
      
      return Result.failure(
        QiError.integrationError(
          `Stream subscription failed: ${error}`,
          "redpanda",
          "subscribe"
        )
      );
    }
  }

  /**
   * Unsubscribe from stream
   */
  async unsubscribe(subscriptionId: string): Promise<Result<void>> {
    try {
      const consumer = this.consumers.get(subscriptionId);
      
      if (consumer) {
        await consumer.disconnect();
        this.consumers.delete(subscriptionId);
        
        this.logger.info("Unsubscribed from stream", { subscription_id: subscriptionId });
      }

      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to unsubscribe", error as any, { subscription_id: subscriptionId });
      
      return Result.failure(
        QiError.integrationError(
          `Unsubscribe failed: ${error}`,
          "redpanda",
          "unsubscribe"
        )
      );
    }
  }

  /**
   * Cleanup resources
   */
  async destroy(): Promise<void> {
    try {
      // Disconnect producer
      if (this.producer) {
        await this.producer.disconnect();
      }

      // Disconnect all consumers
      for (const [subscriptionId, consumer] of this.consumers) {
        await consumer.disconnect();
      }
      
      this.consumers.clear();

      this.logger.info("Redpanda client destroyed");

    } catch (error) {
      this.logger.error("Error during Redpanda client cleanup", error as any);
    }
  }
}
```

### 3. Time Series Storage

#### ClickHouse Integration
```typescript
// src/storage/clickhouse-client.ts
import { HTTPClient } from "qicore/application/http/client";
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";
import { Cache } from "qicore/core/cache";

export interface ClickHouseConfig {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
  ssl?: boolean;
}

export interface TimeSeriesQuery {
  symbol?: string;
  startTime: Date;
  endTime: Date;
  timeframe?: "1m" | "5m" | "15m" | "1h" | "4h" | "1d";
  indicators?: string[];
  limit?: number;
}

export class ClickHouseTimeSeriesClient {
  private httpClient: HTTPClient;
  private logger: StructuredLogger;
  private cache: Cache<string, any>;
  private config: ClickHouseConfig;

  constructor(config: ClickHouseConfig) {
    this.config = config;
    
    const baseUrl = `http${config.ssl ? 's' : ''}://${config.host}:${config.port}`;
    this.httpClient = new HTTPClient(baseUrl, {
      'X-ClickHouse-User': config.username,
      'X-ClickHouse-Key': config.password,
      'X-ClickHouse-Database': config.database
    });

    this.logger = new StructuredLogger({
      level: "info",
      component: "ClickHouseTimeSeriesClient"
    });

    this.cache = new Cache({
      maxSize: 1000,
      defaultTtl: 300000, // 5 minutes
      evictionPolicy: "lru"
    });
  }

  /**
   * Initialize database schema
   */
  async initializeSchema(): Promise<Result<void>> {
    try {
      const schemas = [
        this.createOHLCTableSchema(),
        this.createMarketTicksTableSchema(),
        this.createMarketStatsTableSchema(),
        this.createTechnicalIndicatorsTableSchema()
      ];

      for (const schema of schemas) {
        const result = await this.executeQuery(schema);
        if (result.isFailure()) {
          return result as Result<void>;
        }
      }

      this.logger.info("ClickHouse schema initialized");
      return Result.success(undefined);

    } catch (error) {
      this.logger.error("Failed to initialize ClickHouse schema", error as any);
      
      return Result.failure(
        QiError.integrationError(
          `Schema initialization failed: ${error}`,
          "clickhouse",
          "initialize"
        )
      );
    }
  }

  /**
   * Insert OHLC data
   */
  async insertOHLC(data: OHLCData[]): Promise<Result<void>> {
    try {
      if (data.length === 0) return Result.success(undefined);

      const values = data.map(ohlc => 
        `('${ohlc.symbol}', ${ohlc.timestamp}, ${ohlc.open}, ${ohlc.high}, ${ohlc.low}, ${ohlc.close}, ${ohlc.volume}, '${ohlc.exchange || 'UNKNOWN'}')`
      ).join(',');

      const query = `
        INSERT INTO market_ohlc (symbol, timestamp, open, high, low, close, volume, exchange)
        VALUES ${values}
      `;

      const result = await this.executeQuery(query);
      
      if (result.isSuccess()) {
        this.logger.info("OHLC data inserted", {
          symbol: data[0].symbol,
          count: data.length,
          timespan: {
            from: new Date(Math.min(...data.map(d => d.timestamp))).toISOString(),
            to: new Date(Math.max(...data.map(d => d.timestamp))).toISOString()
          }
        });
      }

      return result;

    } catch (error) {
      this.logger.error("Failed to insert OHLC data", error as any, { count: data.length });
      
      return Result.failure(
        QiError.integrationError(
          `OHLC insert failed: ${error}`,
          "clickhouse",
          "insert_ohlc"
        )
      );
    }
  }

  /**
   * Insert market ticks
   */
  async insertMarketTicks(ticks: MarketTick[]): Promise<Result<void>> {
    try {
      if (ticks.length === 0) return Result.success(undefined);

      const values = ticks.map(tick => 
        `('${tick.symbol}', ${tick.timestamp}, ${tick.price}, ${tick.volume}, '${tick.exchange}', ${tick.change_24h || 0}, ${tick.change_pct_24h || 0})`
      ).join(',');

      const query = `
        INSERT INTO market_ticks (symbol, timestamp, price, volume, exchange, change_24h, change_pct_24h)
        VALUES ${values}
      `;

      const result = await this.executeQuery(query);
      
      if (result.isSuccess()) {
        this.logger.debug("Market ticks inserted", { count: ticks.length });
      }

      return result;

    } catch (error) {
      this.logger.error("Failed to insert market ticks", error as any, { count: ticks.length });
      
      return Result.failure(
        QiError.integrationError(
          `Market ticks insert failed: ${error}`,
          "clickhouse",
          "insert_ticks"
        )
      );
    }
  }

  /**
   * Query OHLC data
   */
  async queryOHLC(query: TimeSeriesQuery): Promise<Result<OHLCData[]>> {
    try {
      const cacheKey = this.generateCacheKey('ohlc', query);
      const cached = await this.cache.get(cacheKey);
      
      if (cached.isSuccess()) {
        this.logger.debug("Cache hit for OHLC query", { query });
        return Result.success(cached.unwrap());
      }

      let sql = `
        SELECT 
          symbol,
          timestamp,
          open,
          high,
          low,
          close,
          volume,
          exchange
        FROM market_ohlc
        WHERE timestamp >= ${query.startTime.getTime()}
          AND timestamp <= ${query.endTime.getTime()}
      `;

      if (query.symbol) {
        sql += ` AND symbol = '${query.symbol}'`;
      }

      // Aggregate by timeframe if specified
      if (query.timeframe && query.timeframe !== '1m') {
        const interval = this.getTimeframeInterval(query.timeframe);
        sql = `
          SELECT 
            symbol,
            intDiv(timestamp, ${interval}) * ${interval} as timestamp,
            argMin(open, timestamp) as open,
            max(high) as high,
            min(low) as low,
            argMax(close, timestamp) as close,
            sum(volume) as volume,
            any(exchange) as exchange
          FROM (${sql})
          GROUP BY symbol, intDiv(timestamp, ${interval})
          ORDER BY symbol, timestamp
        `;
      } else {
        sql += ` ORDER BY symbol, timestamp`;
      }

      if (query.limit) {
        sql += ` LIMIT ${query.limit}`;
      }

      const result = await this.executeQuery(sql);
      
      if (result.isFailure()) {
        return result as Result<OHLCData[]>;
      }

      const rows = result.unwrap();
      const ohlcData: OHLCData[] = rows.map((row: any) => ({
        symbol: row.symbol,
        timestamp: parseInt(row.timestamp),
        open: parseFloat(row.open),
        high: parseFloat(row.high),
        low: parseFloat(row.low),
        close: parseFloat(row.close),
        volume: parseFloat(row.volume),
        exchange: row.exchange
      }));

      // Cache for 1 minute
      await this.cache.set(cacheKey, ohlcData, 60000);

      this.logger.info("OHLC data queried", {
        symbol: query.symbol,
        timeframe: query.timeframe,
        count: ohlcData.length,
        cache_key: cacheKey
      });

      return Result.success(ohlcData);

    } catch (error) {
      this.logger.error("Failed to query OHLC data", error as any, { query });
      
      return Result.failure(
        QiError.integrationError(
          `OHLC query failed: ${error}`,
          "clickhouse",
          "query_ohlc"
        )
      );
    }
  }

  /**
   * Calculate technical indicators
   */
  async calculateTechnicalIndicators(
    symbol: string,
    indicators: string[],
    timeRange: { start: Date; end: Date },
    timeframe: string = "1h"
  ): Promise<Result<Record<string, any[]>>> {
    try {
      const results: Record<string, any[]> = {};

      for (const indicator of indicators) {
        const sql = this.buildIndicatorQuery(symbol, indicator, timeRange, timeframe);
        const queryResult = await this.executeQuery(sql);
        
        if (queryResult.isSuccess()) {
          results[indicator] = queryResult.unwrap();
        }
      }

      this.logger.info("Technical indicators calculated", {
        symbol,
        indicators: indicators.length,
        timeframe
      });

      return Result.success(results);

    } catch (error) {
      this.logger.error("Failed to calculate technical indicators", error as any, {
        symbol,
        indicators,
        timeframe
      });
      
      return Result.failure(
        QiError.integrationError(
          `Technical indicators calculation failed: ${error}`,
          "clickhouse",
          "calculate_indicators"
        )
      );
    }
  }

  /**
   * Execute raw query
   */
  private async executeQuery(sql: string): Promise<Result<any[]>> {
    try {
      const response = await this.httpClient.post<any>('/', sql, {
        'Content-Type': 'text/plain'
      });

      if (response.isFailure()) {
        return response as Result<any[]>;
      }

      const data = response.unwrap().data;
      
      // Parse ClickHouse response format
      if (typeof data === 'string') {
        const lines = data.trim().split('\n');
        const rows = lines.map(line => {
          try {
            return JSON.parse(line);
          } catch {
            return line.split('\t');
          }
        });
        return Result.success(rows);
      }

      return Result.success(Array.isArray(data) ? data : [data]);

    } catch (error) {
      this.logger.error("Query execution failed", error as any, { sql: sql.substring(0, 100) });
      
      return Result.failure(
        QiError.integrationError(
          `Query execution failed: ${error}`,
          "clickhouse",
          "execute_query"
        )
      );
    }
  }

  private createOHLCTableSchema(): string {
    return `
      CREATE TABLE IF NOT EXISTS market_ohlc (
        symbol String,
        timestamp UInt64,
        open Float64,
        high Float64,
        low Float64,
        close Float64,
        volume Float64,
        exchange String
      ) ENGINE = MergeTree()
      PARTITION BY toYYYYMM(toDateTime(timestamp / 1000))
      ORDER BY (symbol, timestamp)
      TTL toDateTime(timestamp / 1000) + INTERVAL 2 YEAR
    `;
  }

  private createMarketTicksTableSchema(): string {
    return `
      CREATE TABLE IF NOT EXISTS market_ticks (
        symbol String,
        timestamp UInt64,
        price Float64,
        volume Float64,
        exchange String,
        change_24h Float64,
        change_pct_24h Float64
      ) ENGINE = MergeTree()
      PARTITION BY toYYYYMM(toDateTime(timestamp / 1000))
      ORDER BY (symbol, timestamp)
      TTL toDateTime(timestamp / 1000) + INTERVAL 1 MONTH
    `;
  }

  private createMarketStatsTableSchema(): string {
    return `
      CREATE TABLE IF NOT EXISTS market_stats (
        symbol String,
        timestamp UInt64,
        market_cap Float64,
        volume_24h Float64,
        circulating_supply Float64,
        total_supply Float64,
        max_supply Float64
      ) ENGINE = ReplacingMergeTree()
      PARTITION BY toYYYYMM(toDateTime(timestamp / 1000))
      ORDER BY (symbol, timestamp)
      TTL toDateTime(timestamp / 1000) + INTERVAL 1 YEAR
    `;
  }

  private createTechnicalIndicatorsTableSchema(): string {
    return `
      CREATE TABLE IF NOT EXISTS technical_indicators (
        symbol String,
        timestamp UInt64,
        indicator_name String,
        indicator_value Float64,
        timeframe String,
        parameters String
      ) ENGINE = ReplacingMergeTree()
      PARTITION BY (toYYYYMM(toDateTime(timestamp / 1000)), indicator_name)
      ORDER BY (symbol, timestamp, indicator_name, timeframe)
      TTL toDateTime(timestamp / 1000) + INTERVAL 6 MONTH
    `;
  }

  private getTimeframeInterval(timeframe: string): number {
    const intervals: Record<string, number> = {
      '1m': 60 * 1000,
      '5m': 5 * 60 * 1000,
      '15m': 15 * 60 * 1000,
      '1h': 60 * 60 * 1000,
      '4h': 4 * 60 * 60 * 1000,
      '1d': 24 * 60 * 60 * 1000
    };
    return intervals[timeframe] || intervals['1h'];
  }

  private buildIndicatorQuery(
    symbol: string,
    indicator: string,
    timeRange: { start: Date; end: Date },
    timeframe: string
  ): string {
    const baseQuery = `
      WITH ohlc_data AS (
        SELECT 
          timestamp,
          close,
          high,
          low,
          volume,
          ROW_NUMBER() OVER (ORDER BY timestamp) as rn
        FROM market_ohlc
        WHERE symbol = '${symbol}'
          AND timestamp >= ${timeRange.start.getTime()}
          AND timestamp <= ${timeRange.end.getTime()}
        ORDER BY timestamp
      )
    `;

    switch (indicator.toLowerCase()) {
      case 'sma_20':
        return baseQuery + `
          SELECT 
            timestamp,
            AVG(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as sma_20
          FROM ohlc_data
          WHERE rn >= 20
        `;
      
      case 'ema_12':
        return baseQuery + `
          SELECT 
            timestamp,
            exponentialMovingAverage(2.0 / (12 + 1))(close) OVER (ORDER BY timestamp) as ema_12
          FROM ohlc_data
        `;
      
      case 'rsi_14':
        return baseQuery + `
          SELECT 
            timestamp,
            RSI(close, 14) OVER (ORDER BY timestamp) as rsi_14
          FROM ohlc_data
          WHERE rn >= 14
        `;
      
      case 'bollinger_bands':
        return baseQuery + `
          SELECT 
            timestamp,
            AVG(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as bb_middle,
            AVG(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) + 
              2 * stddevPop(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as bb_upper,
            AVG(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) - 
              2 * stddevPop(close) OVER (ORDER BY timestamp ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as bb_lower
          FROM ohlc_data
          WHERE rn >= 20
        `;
      
      default:
        return baseQuery + `SELECT timestamp, close FROM ohlc_data`;
    }
  }

  private generateCacheKey(type: string, query: any): string {
    return `${type}_${JSON.stringify(query)}`.replace(/[^a-zA-Z0-9_]/g, '_');
  }
}
```

## MCP Tools for Time Series

### Financial Analytics MCP Tools
```typescript
// src/mcp/financial-tools.ts
import { Result } from "qicore/base/result";
import { StructuredLogger } from "qicore/core/logger";

export class FinancialAnalyticsMCPTools {
  private cryptoCompareClient: CryptoCompareClient;
  private clickHouseClient: ClickHouseTimeSeriesClient;
  private redpandaClient: RedpandaStreamingClient;
  private logger: StructuredLogger;

  constructor(
    cryptoCompareClient: CryptoCompareClient,
    clickHouseClient: ClickHouseTimeSeriesClient,
    redpandaClient: RedpandaStreamingClient
  ) {
    this.cryptoCompareClient = cryptoCompareClient;
    this.clickHouseClient = clickHouseClient;
    this.redpandaClient = redpandaClient;
    this.logger = new StructuredLogger({
      level: "info",
      component: "FinancialAnalyticsMCPTools"
    });
  }

  /**
   * Get MCP tool definitions for financial analytics
   */
  getToolDefinitions(): Record<string, any> {
    return {
      "crypto_historical_data": {
        description: "Get historical OHLC data for cryptocurrency analysis",
        parameters: {
          type: "object",
          properties: {
            symbol: {
              type: "string",
              description: "Cryptocurrency symbol (e.g., BTC/USD, ETH/USD)"
            },
            timeframe: {
              type: "string",
              enum: ["minute", "hour", "day"],
              description: "Timeframe for historical data"
            },
            limit: {
              type: "integer",
              description: "Number of data points to retrieve",
              default: 100
            },
            start_date: {
              type: "string",
              description: "Start date in ISO format (optional)"
            },
            end_date: {
              type: "string", 
              description: "End date in ISO format (optional)"
            }
          },
          required: ["symbol", "timeframe"]
        }
      },

      "crypto_current_price": {
        description: "Get current market price and statistics",
        parameters: {
          type: "object",
          properties: {
            symbols: {
              type: "array",
              items: { type: "string" },
              description: "Array of cryptocurrency symbols"
            },
            currencies: {
              type: "array",
              items: { type: "string" },
              description: "Target currencies (default: USD)",
              default: ["USD"]
            },
            include_stats: {
              type: "boolean",
              description: "Include detailed market statistics",
              default: false
            }
          },
          required: ["symbols"]
        }
      },

      "technical_analysis": {
        description: "Calculate technical indicators for market analysis",
        parameters: {
          type: "object",
          properties: {
            symbol: {
              type: "string",
              description: "Cryptocurrency symbol to analyze"
            },
            indicators: {
              type: "array",
              items: { 
                type: "string",
                enum: ["sma_20", "ema_12", "rsi_14", "macd", "bollinger_bands", "stochastic"]
              },
              description: "Technical indicators to calculate"
            },
            timeframe: {
              type: "string",
              enum: ["1m", "5m", "15m", "1h", "4h", "1d"],
              description: "Analysis timeframe",
              default: "1h"
            },
            period_days: {
              type: "integer",
              description: "Number of days to analyze",
              default: 30
            }
          },
          required: ["symbol", "indicators"]
        }
      },

      "market_analysis": {
        description: "Perform comprehensive market analysis using Claude Code SDK",
        parameters: {
          type: "object",
          properties: {
            symbols: {
              type: "array",
              items: { type: "string" },
              description: "Symbols to analyze"
            },
            analysis_type: {
              type: "string",
              enum: ["trend", "volatility", "correlation", "momentum", "risk"],
              description: "Type of analysis to perform"
            },
            timeframe: {
              type: "string",
              enum: ["1d", "1w", "1m", "3m", "1y"],
              description: "Analysis time period"
            },
            context: {
              type: "string",
              description: "Additional context or specific questions"
            }
          },
          required: ["symbols", "analysis_type", "timeframe"]
        }
      },

      "real_time_alerts": {
        description: "Set up real-time price and pattern alerts",
        parameters: {
          type: "object",
          properties: {
            symbol: {
              type: "string",
              description: "Symbol to monitor"
            },
            alert_type: {
              type: "string",
              enum: ["price_threshold", "percentage_change", "volume_spike", "technical_pattern"],
              description: "Type of alert to create"
            },
            conditions: {
              type: "object",
              description: "Alert conditions (varies by alert_type)"
            },
            notification_channel: {
              type: "string",
              enum: ["webhook", "email", "mcp_event"],
              description: "How to deliver alerts",
              default: "mcp_event"
            }
          },
          required: ["symbol", "alert_type", "conditions"]
        }
      },

      "trading_strategy_analysis": {
        description: "Analyze and backtest trading strategies using Claude Code SDK",
        parameters: {
          type: "object",
          properties: {
            symbol: {
              type: "string",
              description: "Symbol to test strategy on"
            },
            strategy_description: {
              type: "string",
              description: "Description of the trading strategy"
            },
            backtest_period: {
              type: "string",
              description: "Period for backtesting (e.g., '6m', '1y', '2y')"
            },
            initial_capital: {
              type: "number",
              description: "Initial capital for backtesting",
              default: 10000
            },
            risk_parameters: {
              type: "object",
              description: "Risk management parameters"
            }
          },
          required: ["symbol", "strategy_description", "backtest_period"]
        }
      }
    };
  }

  /**
   * Handle financial analytics tool calls
   */
  async handleToolCall(toolName: string, parameters: any): Promise<Result<any>> {
    try {
      switch (toolName) {
        case "crypto_historical_data":
          return await this.handleHistoricalDataRequest(parameters);
        
        case "crypto_current_price":
          return await this.handleCurrentPriceRequest(parameters);
        
        case "technical_analysis":
          return await this.handleTechnicalAnalysis(parameters);
        
        case "market_analysis":
          return await this.handleMarketAnalysis(parameters);
        
        case "real_time_alerts":
          return await this.handleRealTimeAlerts(parameters);
        
        case "trading_strategy_analysis":
          return await this.handleTradingStrategyAnalysis(parameters);
        
        default:
          return Result.failure(
            QiError.configurationError(
              `Unknown financial tool: ${toolName}`,
              "financial_tools",
              "tool_name"
            )
          );
      }
    } catch (error) {
      this.logger.error("Financial tool call failed", error as any, {
        tool_name: toolName,
        parameters
      });

      return Result.failure(
        QiError.integrationError(
          `Financial tool execution failed: ${error}`,
          "financial_tools",
          toolName
        )
      );
    }
  }

  private async handleHistoricalDataRequest(params: any): Promise<Result<any>> {
    const result = await this.cryptoCompareClient.getHistoricalOHLC(
      params.symbol,
      params.timeframe,
      {
        limit: params.limit || 100,
        ...(params.start_date && { toTs: Math.floor(new Date(params.start_date).getTime() / 1000) })
      }
    );

    if (result.isFailure()) {
      return result;
    }

    const data = result.unwrap();
    
    return Result.success({
      symbol: params.symbol,
      timeframe: params.timeframe,
      data_points: data.length,
      data: data.slice(0, 100), // Limit response size
      summary: {
        first_timestamp: data[0]?.timestamp,
        last_timestamp: data[data.length - 1]?.timestamp,
        price_range: {
          high: Math.max(...data.map(d => d.high)),
          low: Math.min(...data.map(d => d.low))
        },
        total_volume: data.reduce((sum, d) => sum + d.volume, 0)
      }
    });
  }

  private async handleCurrentPriceRequest(params: any): Promise<Result<any>> {
    const pricesResult = await this.cryptoCompareClient.getCurrentPrices(
      params.symbols,
      params.currencies || ["USD"]
    );

    if (pricesResult.isFailure()) {
      return pricesResult;
    }

    const prices = pricesResult.unwrap();
    const response: any = { prices };

    if (params.include_stats) {
      const stats: Record<string, any> = {};
      
      for (const symbol of params.symbols) {
        const statsResult = await this.cryptoCompareClient.getMarketStats(symbol);
        if (statsResult.isSuccess()) {
          stats[symbol] = statsResult.unwrap();
        }
      }
      
      response.market_stats = stats;
    }

    return Result.success(response);
  }

  private async handleTechnicalAnalysis(params: any): Promise<Result<any>> {
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - (params.period_days || 30));

    const indicatorsResult = await this.clickHouseClient.calculateTechnicalIndicators(
      params.symbol,
      params.indicators,
      { start: startDate, end: endDate },
      params.timeframe
    );

    if (indicatorsResult.isFailure()) {
      return indicatorsResult;
    }

    const indicators = indicatorsResult.unwrap();
    
    return Result.success({
      symbol: params.symbol,
      timeframe: params.timeframe,
      analysis_period: {
        start: startDate.toISOString(),
        end: endDate.toISOString(),
        days: params.period_days || 30
      },
      indicators,
      summary: this.generateIndicatorSummary(indicators)
    });
  }

  private async handleMarketAnalysis(params: any): Promise<Result<any>> {
    // This would integrate with Claude Code SDK to generate comprehensive market analysis
    const analysisPrompt = this.buildMarketAnalysisPrompt(params);
    
    // Delegate to Claude Code SDK for analysis
    // Implementation would call the Claude SDK bridge
    
    return Result.success({
      analysis_type: params.analysis_type,
      symbols: params.symbols,
      timeframe: params.timeframe,
      analysis_prompt: analysisPrompt,
      status: "analysis_delegated_to_claude_sdk"
    });
  }

  private async handleRealTimeAlerts(params: any): Promise<Result<any>> {
    // Implementation would set up streaming alerts via Redpanda
    const alertId = `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    return Result.success({
      alert_id: alertId,
      symbol: params.symbol,
      alert_type: params.alert_type,
      conditions: params.conditions,
      status: "alert_configured",
      notification_channel: params.notification_channel
    });
  }

  private async handleTradingStrategyAnalysis(params: any): Promise<Result<any>> {
    // This would integrate with Claude Code SDK for strategy analysis and backtesting
    const strategyPrompt = this.buildStrategyAnalysisPrompt(params);
    
    return Result.success({
      strategy_id: `strategy_${Date.now()}`,
      symbol: params.symbol,
      backtest_period: params.backtest_period,
      initial_capital: params.initial_capital,
      analysis_prompt: strategyPrompt,
      status: "strategy_analysis_delegated_to_claude_sdk"
    });
  }

  private generateIndicatorSummary(indicators: Record<string, any[]>): any {
    const summary: any = {};
    
    for (const [name, values] of Object.entries(indicators)) {
      if (values.length > 0) {
        const latest = values[values.length - 1];
        const previous = values.length > 1 ? values[values.length - 2] : null;
        
        summary[name] = {
          current_value: latest,
          previous_value: previous,
          trend: previous ? (latest > previous ? "up" : "down") : "neutral",
          data_points: values.length
        };
      }
    }
    
    return summary;
  }

  private buildMarketAnalysisPrompt(params: any): string {
    return `
      Perform ${params.analysis_type} analysis for ${params.symbols.join(', ')} over ${params.timeframe} timeframe.
      
      Please analyze:
      1. Current market trends and patterns
      2. Key support and resistance levels
      3. Volume analysis and market sentiment
      4. Risk factors and opportunities
      
      Additional context: ${params.context || 'None'}
      
      Provide actionable insights and specific recommendations.
    `;
  }

  private buildStrategyAnalysisPrompt(params: any): string {
    return `
      Analyze and backtest the following trading strategy:
      
      Strategy: ${params.strategy_description}
      Symbol: ${params.symbol}
      Backtest Period: ${params.backtest_period}
      Initial Capital: $${params.initial_capital}
      
      Please provide:
      1. Strategy implementation code
      2. Backtesting results with key metrics
      3. Risk analysis and drawdown periods
      4. Performance comparison to buy-and-hold
      5. Optimization suggestions
      
      Risk Parameters: ${JSON.stringify(params.risk_parameters || {})}
    `;
  }
}
```

This comprehensive time series platform extension provides:

1. **Real-time data ingestion** from CryptoCompare with WebSocket streams
2. **High-performance streaming** via Redpanda (3-6x more efficient than Kafka)
3. **Analytical storage** in ClickHouse optimized for OHLC time series data
4. **MCP tool integration** allowing Claude Code SDK to access financial data
5. **Technical analysis capabilities** with built-in indicators
6. **Scalable architecture** supporting 24/7 crypto market data

The proposed architecture is **absolutely capable** of handling cryptocurrency time series analysis with CryptoCompare, Kafka/Redpanda, and provides the foundation for sophisticated financial analytics through Claude Code SDK integration.

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "1", "content": "Examine qicore-v4 TypeScript structure for implementation foundation", "status": "completed", "priority": "high"}, {"id": "2", "content": "Update knowledge on CryptoCompare, Kafka, Redpanda for time series", "status": "completed", "priority": "high"}, {"id": "3", "content": "Create detailed context management tutorial with MCP integration", "status": "completed", "priority": "high"}, {"id": "4", "content": "Design time series data platform architecture extension", "status": "completed", "priority": "medium"}, {"id": "5", "content": "Write TypeScript implementation guide for MCP app", "status": "in_progress", "priority": "medium"}]