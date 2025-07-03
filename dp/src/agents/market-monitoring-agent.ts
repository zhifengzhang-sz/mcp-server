#!/usr/bin/env bun

/**
 * Market Monitoring Agent - Real-time market analysis with QiAgent
 * 
 * This agent:
 * - Monitors real-time market data from Kafka streams
 * - Uses QiAgent for AI-powered market analysis
 * - Generates trading signals and insights
 * - Publishes results back to Kafka topics
 * - Stores analysis in databases
 */

import { Kafka, Consumer, Producer } from 'kafkajs';
import { generateText } from '@qicore/agent-lib';
import { ollama } from 'ollama-ai-provider';
import type { 
  OHLCVData, 
  MarketTick, 
  AgentSignal, 
  MarketAnalysis, 
  TechnicalIndicator,
  AgentConfig 
} from '../types/index.js';
import { DatabaseManager } from '../database/index.js';
import { loadConfig } from '../config/index.js';

export class MarketMonitoringAgent {
  private kafka: Kafka;
  private consumer: Consumer;
  private producer: Producer;
  private model: any;
  private config: AgentConfig;
  private dbManager: DatabaseManager;
  private isRunning = false;
  private marketData: Map<string, OHLCVData[]> = new Map();
  private logger: Console;

  constructor(config: AgentConfig, dbManager: DatabaseManager) {
    this.config = config;
    this.dbManager = dbManager;
    this.logger = console;
    
    // Initialize AI model
    this.model = ollama(config.modelConfig.model, {
      baseURL: config.modelConfig.baseURL || 'http://localhost:11434'
    });
    
    // Initialize Kafka
    const streamingConfig = loadConfig().streaming;
    this.kafka = new Kafka({
      clientId: `qicore-market-agent-${config.id}`,
      brokers: streamingConfig.redpanda.brokers,
    });
    
    this.consumer = this.kafka.consumer({ 
      groupId: `market-monitoring-${config.id}` 
    });
    
    this.producer = this.kafka.producer();
    
    this.logger.info(`🤖 Market Monitoring Agent initialized: ${config.id}`);
    this.logger.info(`🧠 Using AI model: ${config.modelConfig.provider}:${config.modelConfig.model}`);
  }

  /**
   * Start the market monitoring agent
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('Agent is already running');
      return;
    }

    try {
      this.logger.info(`🚀 Starting Market Monitoring Agent: ${this.config.id}`);
      
      // Connect to Kafka
      await this.consumer.connect();
      await this.producer.connect();
      
      // Subscribe to market data topic
      const streamingConfig = loadConfig().streaming;
      await this.consumer.subscribe({ 
        topic: streamingConfig.redpanda.topics.marketData,
        fromBeginning: false 
      });
      
      // Start consuming messages
      await this.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          await this.handleMarketData(message);
        },
      });
      
      // Start periodic analysis
      this.startPeriodicAnalysis();
      
      this.isRunning = true;
      this.logger.info(`✅ Market Monitoring Agent is running: ${this.config.id}`);
      
    } catch (error) {
      this.logger.error('❌ Failed to start market monitoring agent:', error);
      throw error;
    }
  }

  /**
   * Stop the agent gracefully
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    this.logger.info(`🛑 Stopping Market Monitoring Agent: ${this.config.id}`);
    
    await this.consumer.disconnect();
    await this.producer.disconnect();
    
    this.isRunning = false;
    this.logger.info(`✅ Market Monitoring Agent stopped: ${this.config.id}`);
  }

  /**
   * Handle incoming market data messages
   */
  private async handleMarketData(message: any): Promise<void> {
    try {
      const data = JSON.parse(message.value?.toString() || '{}');
      
      // Handle OHLCV data
      if (data.open !== undefined && data.close !== undefined) {
        const ohlcv: OHLCVData = data;
        await this.processOHLCVData(ohlcv);
      }
      
      // Handle market ticks
      if (data.price !== undefined && data.side !== undefined) {
        const tick: MarketTick = data;
        await this.processMarketTick(tick);
      }
      
    } catch (error) {
      this.logger.error('Error handling market data:', error);
    }
  }

  /**
   * Process OHLCV data and update internal state
   */
  private async processOHLCVData(ohlcv: OHLCVData): Promise<void> {
    const symbol = ohlcv.symbol;
    
    // Update market data cache
    if (!this.marketData.has(symbol)) {
      this.marketData.set(symbol, []);
    }
    
    const symbolData = this.marketData.get(symbol)!;
    symbolData.push(ohlcv);
    
    // Keep only last 100 data points for analysis
    if (symbolData.length > 100) {
      symbolData.shift();
    }
    
    this.logger.debug(`📊 Updated market data for ${symbol}: $${ohlcv.close}`);
  }

  /**
   * Process real-time market ticks
   */
  private async processMarketTick(tick: MarketTick): Promise<void> {
    // For now, just log significant price movements
    const threshold = 0.01; // 1% price change
    
    const symbolData = this.marketData.get(tick.symbol);
    if (symbolData && symbolData.length > 0) {
      const lastPrice = symbolData[symbolData.length - 1].close;
      const priceChange = Math.abs(tick.price - lastPrice) / lastPrice;
      
      if (priceChange > threshold) {
        this.logger.info(`📈 Significant price movement in ${tick.symbol}: ${(priceChange * 100).toFixed(2)}%`);
        
        // Trigger immediate analysis for significant movements
        await this.analyzeSymbol(tick.symbol);
      }
    }
  }

  /**
   * Start periodic market analysis
   */
  private startPeriodicAnalysis(): void {
    setInterval(async () => {
      if (!this.isRunning) return;
      
      // Analyze each symbol we have data for
      for (const symbol of this.marketData.keys()) {
        try {
          await this.analyzeSymbol(symbol);
        } catch (error) {
          this.logger.error(`Error analyzing ${symbol}:`, error);
        }
      }
    }, this.config.updateInterval);
    
    this.logger.info(`⏰ Started periodic analysis every ${this.config.updateInterval}ms`);
  }

  /**
   * Analyze a specific symbol using AI
   */
  private async analyzeSymbol(symbol: string): Promise<void> {
    const symbolData = this.marketData.get(symbol);
    if (!symbolData || symbolData.length < 10) {
      return; // Need at least 10 data points for meaningful analysis
    }

    try {
      this.logger.info(`🔍 Analyzing ${symbol} with AI...`);
      const startTime = Date.now();
      
      // Calculate technical indicators
      const indicators = this.calculateTechnicalIndicators(symbolData);
      
      // Prepare market context for AI analysis
      const latest = symbolData[symbolData.length - 1];
      const previous = symbolData[symbolData.length - 2];
      const priceChange = ((latest.close - previous.close) / previous.close) * 100;
      
      const marketContext = this.buildMarketContext(symbol, symbolData, indicators);
      
      // Generate AI analysis
      const aiAnalysis = await this.generateAIAnalysis(symbol, marketContext);
      const duration = Date.now() - startTime;
      
      // Determine trend and generate signals
      const trend = this.determineTrend(symbolData);
      const signal = this.generateTradingSignal(symbol, indicators, aiAnalysis, trend);
      
      // Create market analysis object
      const analysis: MarketAnalysis = {
        symbol,
        timestamp: Date.now(),
        indicators,
        trend,
        pattern: this.detectPattern(symbolData),
        aiAnalysis,
        agentId: this.config.id,
      };
      
      // Store analysis and publish signal
      await Promise.all([
        this.dbManager.insertAnalysis(analysis),
        signal ? this.publishSignal(signal) : Promise.resolve(),
        this.publishAnalysis(analysis),
      ]);
      
      this.logger.info(`✅ AI analysis completed for ${symbol} in ${duration}ms`);
      this.logger.info(`📊 Trend: ${trend}, Pattern: ${analysis.pattern || 'none'}`);
      
    } catch (error) {
      this.logger.error(`💥 AI analysis failed for ${symbol}:`, error);
    }
  }

  /**
   * Generate AI analysis using QiAgent
   */
  private async generateAIAnalysis(symbol: string, marketContext: string): Promise<string> {
    const result = await generateText({
      model: this.model,
      prompt: `Analyze this cryptocurrency market data for ${symbol}:

${marketContext}

Please provide a comprehensive market analysis including:
1. Current market sentiment (bullish/bearish/neutral)
2. Key technical levels (support/resistance)
3. Volume analysis and liquidity assessment
4. Short-term price prediction (next 1-4 hours)
5. Risk factors and potential catalysts
6. Trading recommendation with reasoning

Keep the analysis concise but actionable for algorithmic trading decisions.`,
      temperature: 0.1,
      maxTokens: 400,
    });

    return result.text;
  }

  /**
   * Build market context string for AI analysis
   */
  private buildMarketContext(symbol: string, data: OHLCVData[], indicators: TechnicalIndicator[]): string {
    const latest = data[data.length - 1];
    const previous = data[data.length - 2];
    const priceChange = ((latest.close - previous.close) / previous.close) * 100;
    
    // Calculate recent price statistics
    const recent20 = data.slice(-20);
    const avgVolume = recent20.reduce((sum, d) => sum + d.volume, 0) / recent20.length;
    const highestPrice = Math.max(...recent20.map(d => d.high));
    const lowestPrice = Math.min(...recent20.map(d => d.low));
    
    return `Market Data Summary for ${symbol}:

Current Price: $${latest.close.toFixed(2)}
Price Change: ${priceChange.toFixed(2)}% from previous period
Volume: ${latest.volume.toFixed(2)} (Avg: ${avgVolume.toFixed(2)})
Trading Range (20 periods): $${lowestPrice.toFixed(2)} - $${highestPrice.toFixed(2)}

Technical Indicators:
${indicators.map(ind => `- ${ind.name}: ${ind.value.toFixed(4)} (${ind.signal})`).join('\n')}

Recent Price Action:
${data.slice(-5).map((d, i) => `${i+1}. O:${d.open.toFixed(2)} H:${d.high.toFixed(2)} L:${d.low.toFixed(2)} C:${d.close.toFixed(2)} V:${d.volume.toFixed(0)}`).join('\n')}`;
  }

  /**
   * Calculate technical indicators
   */
  private calculateTechnicalIndicators(data: OHLCVData[]): TechnicalIndicator[] {
    const indicators: TechnicalIndicator[] = [];
    
    if (data.length < 14) return indicators;
    
    // Simple Moving Average (SMA)
    const sma20 = this.calculateSMA(data.map(d => d.close), 20);
    if (sma20 !== null) {
      const latest = data[data.length - 1].close;
      indicators.push({
        name: 'SMA_20',
        value: sma20,
        signal: latest > sma20 ? 'bullish' : 'bearish',
        timestamp: Date.now(),
      });
    }
    
    // Relative Strength Index (RSI)
    const rsi = this.calculateRSI(data.map(d => d.close), 14);
    if (rsi !== null) {
      indicators.push({
        name: 'RSI_14',
        value: rsi,
        signal: rsi > 70 ? 'bearish' : rsi < 30 ? 'bullish' : 'neutral',
        timestamp: Date.now(),
      });
    }
    
    // Volume analysis
    const avgVolume = data.slice(-20).reduce((sum, d) => sum + d.volume, 0) / 20;
    const currentVolume = data[data.length - 1].volume;
    const volumeRatio = currentVolume / avgVolume;
    
    indicators.push({
      name: 'Volume_Ratio',
      value: volumeRatio,
      signal: volumeRatio > 1.5 ? 'bullish' : volumeRatio < 0.5 ? 'bearish' : 'neutral',
      timestamp: Date.now(),
    });
    
    return indicators;
  }

  /**
   * Calculate Simple Moving Average
   */
  private calculateSMA(prices: number[], period: number): number | null {
    if (prices.length < period) return null;
    
    const slice = prices.slice(-period);
    return slice.reduce((sum, price) => sum + price, 0) / period;
  }

  /**
   * Calculate Relative Strength Index
   */
  private calculateRSI(prices: number[], period: number = 14): number | null {
    if (prices.length < period + 1) return null;
    
    let gains = 0;
    let losses = 0;
    
    // Calculate initial average gain and loss
    for (let i = 1; i <= period; i++) {
      const change = prices[i] - prices[i - 1];
      if (change > 0) {
        gains += change;
      } else {
        losses += Math.abs(change);
      }
    }
    
    let avgGain = gains / period;
    let avgLoss = losses / period;
    
    // Calculate RSI for remaining periods
    for (let i = period + 1; i < prices.length; i++) {
      const change = prices[i] - prices[i - 1];
      const gain = change > 0 ? change : 0;
      const loss = change < 0 ? Math.abs(change) : 0;
      
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
    }
    
    if (avgLoss === 0) return 100;
    
    const rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  /**
   * Determine price trend
   */
  private determineTrend(data: OHLCVData[]): 'up' | 'down' | 'sideways' {
    if (data.length < 5) return 'sideways';
    
    const recent = data.slice(-5);
    const prices = recent.map(d => d.close);
    
    const firstPrice = prices[0];
    const lastPrice = prices[prices.length - 1];
    const change = (lastPrice - firstPrice) / firstPrice;
    
    if (change > 0.01) return 'up';      // >1% increase
    if (change < -0.01) return 'down';   // >1% decrease
    return 'sideways';
  }

  /**
   * Detect chart patterns (simple implementation)
   */
  private detectPattern(data: OHLCVData[]): string | undefined {
    if (data.length < 10) return undefined;
    
    const recent = data.slice(-10);
    const highs = recent.map(d => d.high);
    const lows = recent.map(d => d.low);
    
    // Simple pattern detection
    const isAscending = this.isAscendingTriangle(highs, lows);
    const isDescending = this.isDescendingTriangle(highs, lows);
    
    if (isAscending) return 'ascending_triangle';
    if (isDescending) return 'descending_triangle';
    
    return undefined;
  }

  /**
   * Check for ascending triangle pattern
   */
  private isAscendingTriangle(highs: number[], lows: number[]): boolean {
    // Simplified: check if lows are generally increasing while highs are relatively flat
    const lowsSlope = this.calculateSlope(lows);
    const highsSlope = this.calculateSlope(highs);
    
    return lowsSlope > 0.001 && Math.abs(highsSlope) < 0.0005;
  }

  /**
   * Check for descending triangle pattern
   */
  private isDescendingTriangle(highs: number[], lows: number[]): boolean {
    // Simplified: check if highs are generally decreasing while lows are relatively flat
    const lowsSlope = this.calculateSlope(lows);
    const highsSlope = this.calculateSlope(highs);
    
    return highsSlope < -0.001 && Math.abs(lowsSlope) < 0.0005;
  }

  /**
   * Calculate slope of price series
   */
  private calculateSlope(prices: number[]): number {
    if (prices.length < 2) return 0;
    
    const n = prices.length;
    const sumX = (n * (n - 1)) / 2;
    const sumY = prices.reduce((sum, price) => sum + price, 0);
    const sumXY = prices.reduce((sum, price, i) => sum + (i * price), 0);
    const sumX2 = (n * (n - 1) * (2 * n - 1)) / 6;
    
    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }

  /**
   * Generate trading signal based on analysis
   */
  private generateTradingSignal(
    symbol: string,
    indicators: TechnicalIndicator[],
    aiAnalysis: string,
    trend: 'up' | 'down' | 'sideways'
  ): AgentSignal | null {
    // Simple signal generation logic
    const rsiIndicator = indicators.find(ind => ind.name === 'RSI_14');
    const smaIndicator = indicators.find(ind => ind.name === 'SMA_20');
    const volumeIndicator = indicators.find(ind => ind.name === 'Volume_Ratio');
    
    let signalType: 'buy' | 'sell' | 'hold' | 'alert' = 'hold';
    let strength = 0.5;
    let confidence = 0.5;
    let reasoning = 'No clear signal detected';
    
    // RSI-based signals
    if (rsiIndicator) {
      if (rsiIndicator.value < 30 && trend !== 'down') {
        signalType = 'buy';
        strength = 0.7;
        confidence = 0.8;
        reasoning = `RSI oversold (${rsiIndicator.value.toFixed(1)}) with ${trend} trend`;
      } else if (rsiIndicator.value > 70 && trend !== 'up') {
        signalType = 'sell';
        strength = 0.7;
        confidence = 0.8;
        reasoning = `RSI overbought (${rsiIndicator.value.toFixed(1)}) with ${trend} trend`;
      }
    }
    
    // Volume confirmation
    if (volumeIndicator && volumeIndicator.value > 1.5) {
      confidence *= 1.2; // Increase confidence with high volume
      reasoning += `, high volume confirmation (${volumeIndicator.value.toFixed(1)}x avg)`;
    }
    
    // Only generate signals with sufficient strength
    if (strength < 0.6) {
      return null;
    }
    
    return {
      agentId: this.config.id,
      type: signalType,
      symbol,
      strength: Math.min(strength, 1.0),
      confidence: Math.min(confidence, 1.0),
      reasoning,
      timestamp: Date.now(),
      metadata: {
        indicators: indicators.map(ind => ({ name: ind.name, value: ind.value, signal: ind.signal })),
        trend,
        aiAnalysis: aiAnalysis.substring(0, 500), // Truncate for metadata
      },
    };
  }

  /**
   * Publish trading signal to Kafka
   */
  private async publishSignal(signal: AgentSignal): Promise<void> {
    try {
      const streamingConfig = loadConfig().streaming;
      
      await this.producer.send({
        topic: streamingConfig.redpanda.topics.signals,
        messages: [
          {
            key: signal.agentId,
            value: JSON.stringify(signal),
            timestamp: signal.timestamp.toString(),
          },
        ],
      });
      
      // Also store in database
      await this.dbManager.insertSignal(signal);
      
      this.logger.info(`📡 Published ${signal.type} signal for ${signal.symbol} (strength: ${signal.strength.toFixed(2)})`);
      
    } catch (error) {
      this.logger.error('Failed to publish signal:', error);
    }
  }

  /**
   * Publish market analysis to Kafka
   */
  private async publishAnalysis(analysis: MarketAnalysis): Promise<void> {
    try {
      const streamingConfig = loadConfig().streaming;
      
      await this.producer.send({
        topic: streamingConfig.redpanda.topics.analysis,
        messages: [
          {
            key: analysis.symbol,
            value: JSON.stringify(analysis),
            timestamp: analysis.timestamp.toString(),
          },
        ],
      });
      
      this.logger.debug(`📊 Published analysis for ${analysis.symbol}`);
      
    } catch (error) {
      this.logger.error('Failed to publish analysis:', error);
    }
  }

  /**
   * Get agent statistics
   */
  getStats() {
    return {
      agentId: this.config.id,
      type: this.config.type,
      model: `${this.config.modelConfig.provider}:${this.config.modelConfig.model}`,
      isRunning: this.isRunning,
      symbolsTracked: this.marketData.size,
      dataPointsTracked: Array.from(this.marketData.values()).reduce((sum, data) => sum + data.length, 0),
      updateInterval: this.config.updateInterval,
    };
  }
}

// CLI execution
if (import.meta.main) {
  const config = loadConfig();
  
  // Find market monitoring agent config
  const agentConfig = config.agents.find(a => a.type === 'market_monitor');
  if (!agentConfig) {
    console.error('❌ No market monitoring agent configuration found');
    process.exit(1);
  }
  
  // Initialize database connections (this would normally be done in main app)
  console.log('Note: This demo runs without database connections');
  console.log('In production, use the main application entry point');
  
  // For demo purposes, create a mock database manager
  const mockDbManager = {
    insertAnalysis: async () => console.log('📊 Analysis stored (mock)'),
    insertSignal: async () => console.log('📡 Signal stored (mock)'),
  } as any;
  
  const agent = new MarketMonitoringAgent(agentConfig, mockDbManager);
  
  // Graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    await agent.stop();
    process.exit(0);
  });
  
  // Start the agent
  agent.start().catch((error) => {
    console.error('Failed to start market monitoring agent:', error);
    process.exit(1);
  });
}