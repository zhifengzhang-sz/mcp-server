#!/usr/bin/env bun

/**
 * QiCore Crypto Data Platform - Main Entry Point
 * 
 * This orchestrates the entire data platform:
 * - Initializes database connections
 * - Starts data streaming services
 * - Launches AI agents for market analysis
 * - Provides unified management and monitoring
 */

import { loadConfig, validateConfig } from './config/index.js';
import { initializeDatabases, DatabaseManager } from './database/index.js';
import { CryptoDataStreamer } from './streaming/crypto-streamer.js';
import { MarketMonitoringAgent } from './agents/market-monitoring-agent.js';

class QiCoreCryptoDataPlatform {
  private config = loadConfig();
  private dbManager?: DatabaseManager;
  private streamer?: CryptoDataStreamer;
  private agents: MarketMonitoringAgent[] = [];
  private isRunning = false;
  private logger = console;

  /**
   * Initialize and start the entire platform
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      this.logger.warn('Platform is already running');
      return;
    }

    try {
      this.logger.info('🚀 Starting QiCore Crypto Data Platform...');
      this.logger.info('=====================================');
      
      // Validate configuration
      const validation = validateConfig(this.config);
      if (!validation.valid) {
        this.logger.error('❌ Configuration validation failed:');
        validation.errors.forEach(error => this.logger.error(`  - ${error}`));
        throw new Error('Invalid configuration');
      }
      
      this.logger.info('✅ Configuration validated');
      this.logger.info(`📊 Environment: ${this.config.environment}`);
      this.logger.info(`🤖 Agents configured: ${this.config.agents.length}`);
      this.logger.info(`📡 Data sources: ${this.config.dataSources.length}`);
      
      // Initialize database connections
      await this.initializeDatabases();
      
      // Start data streaming
      await this.startDataStreaming();
      
      // Start AI agents
      await this.startAgents();
      
      this.isRunning = true;
      this.logger.info('🎉 QiCore Crypto Data Platform is running!');
      this.logger.info('=====================================');
      this.printStatus();
      
    } catch (error) {
      this.logger.error('❌ Failed to start platform:', error);
      await this.stop();
      throw error;
    }
  }

  /**
   * Stop the platform gracefully
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    this.logger.info('🛑 Stopping QiCore Crypto Data Platform...');
    
    // Stop agents
    await Promise.all(this.agents.map(agent => agent.stop()));
    this.agents = [];
    
    // Stop data streaming
    if (this.streamer) {
      await this.streamer.stop();
    }
    
    // Close database connections would happen here
    // (Pool connections will close automatically)
    
    this.isRunning = false;
    this.logger.info('✅ QiCore Crypto Data Platform stopped');
  }

  /**
   * Initialize database connections
   */
  private async initializeDatabases(): Promise<void> {
    this.logger.info('🗄️  Initializing databases...');
    
    try {
      const connections = await initializeDatabases(this.config.streaming);
      this.dbManager = new DatabaseManager(connections);
      
      this.logger.info('✅ Database connections established');
      this.logger.info(`   📊 TimescaleDB: ${this.config.streaming.databases.timescaledb.host}:${this.config.streaming.databases.timescaledb.port}`);
      this.logger.info(`   📈 ClickHouse: ${this.config.streaming.databases.clickhouse.host}:${this.config.streaming.databases.clickhouse.port}`);
      
    } catch (error) {
      this.logger.error('❌ Database initialization failed:', error);
      throw error;
    }
  }

  /**
   * Start data streaming services
   */
  private async startDataStreaming(): Promise<void> {
    this.logger.info('📡 Starting data streaming...');
    
    try {
      this.streamer = new CryptoDataStreamer(this.config.streaming);
      await this.streamer.start();
      
      this.logger.info('✅ Data streaming started');
      this.logger.info(`   🔴 Redpanda: ${this.config.streaming.redpanda.brokers.join(', ')}`);
      this.logger.info(`   📊 Topics: ${Object.values(this.config.streaming.redpanda.topics).join(', ')}`);
      
    } catch (error) {
      this.logger.error('❌ Data streaming failed to start:', error);
      throw error;
    }
  }

  /**
   * Start AI agents
   */
  private async startAgents(): Promise<void> {
    if (!this.dbManager) {
      throw new Error('Database manager not initialized');
    }

    this.logger.info('🤖 Starting AI agents...');
    
    const enabledAgents = this.config.agents.filter(agent => agent.enabled);
    
    for (const agentConfig of enabledAgents) {
      try {
        let agent: MarketMonitoringAgent;
        
        switch (agentConfig.type) {
          case 'market_monitor':
            agent = new MarketMonitoringAgent(agentConfig, this.dbManager);
            break;
          
          case 'technical_analysis':
            // Would create TechnicalAnalysisAgent here
            this.logger.warn(`Agent type '${agentConfig.type}' not yet implemented, skipping`);
            continue;
            
          case 'risk_management':
            // Would create RiskManagementAgent here
            this.logger.warn(`Agent type '${agentConfig.type}' not yet implemented, skipping`);
            continue;
            
          default:
            this.logger.warn(`Unknown agent type: ${agentConfig.type}, skipping`);
            continue;
        }
        
        await agent.start();
        this.agents.push(agent);
        
        const stats = agent.getStats();
        this.logger.info(`   ✅ ${agentConfig.type}: ${agentConfig.id} (${stats.model})`);
        
      } catch (error) {
        this.logger.error(`❌ Failed to start agent ${agentConfig.id}:`, error);
        // Continue with other agents rather than failing entirely
      }
    }
    
    this.logger.info(`✅ ${this.agents.length}/${enabledAgents.length} agents started successfully`);
  }

  /**
   * Print current platform status
   */
  private printStatus(): void {
    this.logger.info('\n📊 Platform Status:');
    this.logger.info('==================');
    this.logger.info(`🔄 Running: ${this.isRunning ? 'Yes' : 'No'}`);
    this.logger.info(`🗄️  Databases: ${this.dbManager ? 'Connected' : 'Not connected'}`);
    this.logger.info(`📡 Streaming: ${this.streamer ? 'Active' : 'Inactive'}`);
    this.logger.info(`🤖 Agents: ${this.agents.length} running`);
    
    if (this.agents.length > 0) {
      this.logger.info('\nAgent Details:');
      this.agents.forEach(agent => {
        const stats = agent.getStats();
        this.logger.info(`   ${stats.agentId}: ${stats.symbolsTracked} symbols, ${stats.dataPointsTracked} data points`);
      });
    }
    
    this.logger.info('\n🌐 Monitoring URLs:');
    this.logger.info(`   Redpanda Console: http://localhost:8080`);
    this.logger.info(`   ClickHouse: http://localhost:8123`);
    this.logger.info(`   TimescaleDB: localhost:5432`);
    this.logger.info('');
  }

  /**
   * Get platform statistics
   */
  getStats() {
    return {
      isRunning: this.isRunning,
      environment: this.config.environment,
      agents: this.agents.map(agent => agent.getStats()),
      streaming: {
        active: !!this.streamer,
        brokers: this.config.streaming.redpanda.brokers,
        topics: this.config.streaming.redpanda.topics,
      },
      databases: {
        connected: !!this.dbManager,
        timescaledb: `${this.config.streaming.databases.timescaledb.host}:${this.config.streaming.databases.timescaledb.port}`,
        clickhouse: `${this.config.streaming.databases.clickhouse.host}:${this.config.streaming.databases.clickhouse.port}`,
      },
    };
  }

  /**
   * Health check for monitoring
   */
  async healthCheck(): Promise<{ status: 'healthy' | 'unhealthy'; details: any }> {
    try {
      const issues: string[] = [];
      
      if (!this.isRunning) {
        issues.push('Platform is not running');
      }
      
      if (!this.dbManager) {
        issues.push('Database connections not established');
      }
      
      if (!this.streamer) {
        issues.push('Data streaming not active');
      }
      
      if (this.agents.length === 0) {
        issues.push('No agents are running');
      }
      
      return {
        status: issues.length === 0 ? 'healthy' : 'unhealthy',
        details: {
          timestamp: new Date().toISOString(),
          issues: issues.length > 0 ? issues : undefined,
          stats: this.getStats(),
        },
      };
      
    } catch (error) {
      return {
        status: 'unhealthy',
        details: {
          timestamp: new Date().toISOString(),
          error: error instanceof Error ? error.message : 'Unknown error',
        },
      };
    }
  }
}

// CLI execution
if (import.meta.main) {
  const platform = new QiCoreCryptoDataPlatform();
  
  // Graceful shutdown handlers
  process.on('SIGINT', async () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    await platform.stop();
    process.exit(0);
  });
  
  process.on('SIGTERM', async () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
    await platform.stop();
    process.exit(0);
  });
  
  // Unhandled error handlers
  process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
  });
  
  process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    process.exit(1);
  });
  
  // Start the platform
  platform.start().catch((error) => {
    console.error('Failed to start QiCore Crypto Data Platform:', error);
    process.exit(1);
  });
}