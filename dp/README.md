# QiCore Crypto Data Platform

A **real-time cryptocurrency data platform** powered by **AI agents** and built on the **Model Context Protocol (MCP)**. This platform demonstrates the power of combining streaming data, time-series databases, and AI-driven analysis for financial markets.

## 🎯 Key Features

- **Real AI Execution**: Uses QiAgent library with local Ollama or cloud APIs (not just prompt generation)
- **Model-Agnostic**: Switch between Ollama, Claude, OpenAI via environment variables
- **Streaming Data Pipeline**: CryptoCompare → Redpanda/Kafka → TimescaleDB + ClickHouse
- **Multi-Agent System**: Market monitoring, technical analysis, risk management agents
- **MCP Integration**: Standardized tool interfaces for AI agent coordination
- **Production Ready**: Docker Compose setup with monitoring and observability

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Data Sources                           │
├─────────────────┬───────────────────┬─────────────────────┤
│ CryptoCompare   │   TwelveData      │    WebSocket        │
│ • REST API      │   • Forex data    │    • Real-time      │
│ • WebSocket     │   • Crypto data   │    • Price feeds    │
│ • OHLCV data    │   • Stock data    │    • Order books    │
└─────────────────┴───────────────────┴─────────────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   Stream Processing                        │
├─────────────────┬───────────────────┬─────────────────────┤
│    Redpanda     │      Kafka        │     Real-time       │
│ • Event streams │ • Topic routing   │ • Data validation   │
│ • Partitioning  │ • Schema registry │ • Transformation    │
│ • Replication   │ • Consumer groups │ • Enrichment        │
└─────────────────┴───────────────────┴─────────────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage Layer                           │
├─────────────────┬───────────────────┬─────────────────────┤
│   TimescaleDB   │    ClickHouse     │       Redis         │
│ • Time-series   │ • Analytics       │ • Caching           │
│ • Real-time     │ • Aggregations    │ • Session state     │
│ • ACID          │ • Historical      │ • Rate limiting     │
└─────────────────┴───────────────────┴─────────────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                     AI Agent Layer                        │
├─────────────────┬───────────────────┬─────────────────────┤
│ Market Monitor  │ Technical Analysis│   Risk Assessment   │
│ • Price feeds   │ • Pattern detect  │ • Position sizing   │
│ • Volume data   │ • Indicator calc  │ • Risk metrics      │
│ • Alerts        │ • Signal gen      │ • Portfolio mgmt    │
└─────────────────┴───────────────────┴─────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Bun**: v1.2.0+ (JavaScript/TypeScript runtime)
- **Docker**: v20.0+ (for services)
- **Ollama**: Local AI models (optional, can use cloud APIs)
- **Git**: For cloning the repository

### 1. Clone and Setup

```bash
git clone <repository>
cd dp

# Install dependencies
bun install

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
vim .env
```

### 2. Start Infrastructure Services

```bash
# Start all services (Redpanda, TimescaleDB, ClickHouse, Redis)
bun run docker:up

# Wait for services to be healthy (check with)
docker compose ps
```

### 3. Configure AI Model

**Option A: Local Ollama (Recommended for development)**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a lightweight model
ollama pull qwen3:0.6b

# Set environment
export AI_PROVIDER=ollama
export AI_MODEL=qwen3:0.6b
```

**Option B: Cloud APIs**
```bash
# For Anthropic Claude
export AI_PROVIDER=anthropic
export AI_MODEL=claude-3-haiku-20240307
export AI_API_KEY=your_anthropic_key

# For OpenAI
export AI_PROVIDER=openai
export AI_MODEL=gpt-4o-mini
export AI_API_KEY=your_openai_key
```

### 4. Start the Platform

```bash
# Start the complete platform
bun run dev

# Or start individual components
bun run data:stream    # Data streaming only
bun run agent:market   # Market monitoring agent only
```

## 📊 Monitoring & Observability

Access the management interfaces:

- **Redpanda Console**: http://localhost:8080 - Kafka topic management
- **ClickHouse**: http://localhost:8123 - Analytics queries  
- **TimescaleDB**: localhost:5432 - Time-series data
- **Platform Health**: http://localhost:3000/health (when API is added)

## 🤖 AI Agents

### Market Monitoring Agent

- **Purpose**: Real-time market analysis and signal generation
- **Data Sources**: OHLCV data, market ticks, order book data
- **AI Analysis**: Pattern recognition, trend analysis, sentiment analysis
- **Output**: Trading signals, market insights, alerts

**Key Features:**
- RSI, SMA, and volume indicators
- Pattern detection (ascending/descending triangles)
- Real-time signal generation
- Configurable analysis intervals

### Technical Analysis Agent (Coming Soon)

- **Purpose**: Advanced technical analysis and forecasting
- **Features**: Multi-timeframe analysis, advanced indicators, backtesting

### Risk Management Agent (Coming Soon)

- **Purpose**: Portfolio risk assessment and position sizing
- **Features**: VaR calculation, correlation analysis, exposure monitoring

## 🔧 Configuration

### Environment Variables

```bash
# AI Configuration
AI_PROVIDER=ollama          # ollama | anthropic | openai
AI_MODEL=qwen3:0.6b        # Model name
AI_BASE_URL=http://localhost:11434  # For Ollama

# Data Sources  
CRYPTOCOMPARE_API_KEY=your_key_here  # Optional but recommended

# Databases
TIMESCALE_HOST=localhost
CLICKHOUSE_HOST=localhost

# Streaming
REDPANDA_BROKERS=localhost:19092
```

### Agent Configuration

Edit `src/config/index.ts` to modify agent behavior:

```typescript
agents: [
  {
    id: 'market-monitor-1',
    type: 'market_monitor',
    modelConfig: {
      provider: 'ollama',
      model: 'qwen3:0.6b'
    },
    enabled: true,
    updateInterval: 5000  // 5 seconds
  }
]
```

## 📈 Data Flow

1. **Data Ingestion**: CryptoCompare API → WebSocket streams
2. **Stream Processing**: Redpanda topics with partitioning by symbol
3. **Real-time Storage**: TimescaleDB with automatic partitioning
4. **Analytics Storage**: ClickHouse with compression and indexing
5. **AI Analysis**: Agents consume streams and generate insights
6. **Signal Publishing**: Results published back to Kafka topics

## 🧪 Testing

```bash
# Run tests
bun test

# Test specific components
bun run test:integration    # Integration tests
bun run test:agents        # Agent tests
bun run test:streaming     # Streaming tests

# Manual testing
bun run agent:market       # Test market agent
bun run data:stream        # Test data streaming
```

## 🔍 Debugging

```bash
# Enable debug logging
export LOG_LEVEL=debug

# Run with mock data (no real API calls)
export MOCK_MODE=true

# Simulate market data
export SIMULATE_DATA=true
```

## 📋 Available Scripts

```bash
# Development
bun run dev                 # Start complete platform
bun run start              # Production start

# Infrastructure
bun run docker:up          # Start all services
bun run docker:down        # Stop all services
bun run docker:logs        # View service logs

# Components
bun run data:stream        # Start data streaming
bun run agent:market       # Start market monitoring agent
bun run pipeline:start     # Start data pipeline

# Utilities
bun run typecheck          # TypeScript checking
bun test                   # Run tests
```

## 🎯 Next Steps

1. **Add More Agents**: Technical analysis, risk management, execution agents
2. **Web Dashboard**: Real-time monitoring and control interface
3. **API Endpoints**: REST API for external integrations
4. **Backtesting**: Historical strategy validation
5. **Paper Trading**: Live trading simulation
6. **Multi-Exchange**: Support for multiple crypto exchanges

## 🤝 Contributing

This platform demonstrates the power of MCP + AI agents for financial data processing. Key areas for contribution:

- Additional data sources and exchanges
- More sophisticated AI analysis strategies  
- Performance optimizations
- Additional agent types
- Integration with trading platforms

## 📄 License

MIT License - see LICENSE file for details

---

**Built with QiAgent + MCP + Real AI Execution** 🚀