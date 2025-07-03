# QiCore Crypto Data Platform - Project Knowledge

## Project Overview

This is the **QiCore Crypto Data Platform** - a foundation for agentized cryptocurrency data processing built on:
- **Model Context Protocol (MCP)** for standardized tool interfaces
- **Real AI agents** using QiAgent library (not just prompt generation)
- **Streaming data pipelines** (Redpanda/Kafka + TimescaleDB + ClickHouse)
- **Multi-agent coordination** for financial analysis

## Current Status: Ready to Build

### ✅ Completed Foundation Work
1. **QiAgent Library Upgrade**: Agent now uses real AI execution (tested with Ollama qwen3:0.6b/14b)
2. **Model-Agnostic Design**: Switch between Ollama/Claude/OpenAI via environment variables
3. **MCP Integration**: Memory + Filesystem servers working
4. **Architecture Proposal**: Comprehensive design in `docs/proposal.md`

### 🎯 Current Objective
Build the **Minimal Viable Data Pipeline**: CryptoCompare → Redpanda → TimescaleDB

## Architecture Overview

### Core Components
```
┌─────────────────────────────────────────────────────────────┐
│                     Data Platform                          │
├─────────────────┬───────────────────┬─────────────────────┤
│   Data Sources  │   Stream Engine   │    Storage Layer    │
│                 │                   │                     │
│ • CryptoCompare │ • Redpanda/Kafka  │ • TimescaleDB       │
│ • TwelveData    │ • Event Streaming │ • ClickHouse        │
│ • WebSocket     │ • Real-time       │ • Time-series       │
└─────────────────┴───────────────────┴─────────────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Agent Layer                             │
├─────────────────┬───────────────────┬─────────────────────┤
│ Market Monitor  │ Technical Analysis│   Risk Assessment   │
│                 │                   │                     │
│ • Price feeds   │ • Pattern detect  │ • Position sizing   │
│ • Volume data   │ • Indicator calc  │ • Risk metrics      │
│ • Order books   │ • Signal gen      │ • Portfolio mgmt    │
└─────────────────┴───────────────────┴─────────────────────┘
```

### Technology Stack

#### **AI & Agent Framework**
- **QiAgent**: Real AI execution (not prompt generation)
- **Ollama**: Local inference (qwen3:0.6b, qwen3:8b, qwen3:14b available)
- **Model Switching**: Environment variables (AI_PROVIDER, AI_MODEL)
- **MCP Integration**: Memory + Filesystem servers

#### **Data Pipeline**
- **Streaming**: Redpanda (Kafka-compatible)
- **Time-series DB**: TimescaleDB (for real-time queries)
- **Analytics DB**: ClickHouse (for historical analysis)
- **Data Sources**: CryptoCompare API, WebSocket feeds

#### **Infrastructure**
- **Runtime**: Bun (TypeScript/JavaScript)
- **Containerization**: Docker Compose
- **Development**: Local Ollama + GPU acceleration

## Project Structure

```
/home/zzhang/dev/qi/github/mcp-server/
├── dp/                          # 🎯 CURRENT PROJECT
│   ├── docs/                    # Architecture documentation
│   │   └── proposal.md          # Comprehensive platform design
│   ├── PROJECT_KNOWLEDGE.md     # This file
│   └── [TO BE BUILT]            # Data platform implementation
│
├── qicore-v4/typescript/agent/  # ✅ COMPLETED FOUNDATION
│   ├── app/                     # Upgraded agent application
│   │   ├── src/agents/ollama.ts # Model-agnostic AI agent
│   │   ├── test-*.ts           # Working AI integration tests
│   │   └── AGENT_UPGRADE_SUMMARY.md
│   └── lib/                     # QiAgent library (workspace dependency)
│
└── docs/                        # Original documentation
```

## Key Technical Achievements

### 1. Real AI Execution Working ✅
```typescript
// Before: Just prompt generation
const prompt = await promptManager.createPrompt(data);
return `[MOCK ANALYSIS]: ${prompt}`;

// After: Real AI execution
const result = await generateText({
  model: ollama("qwen3:0.6b"),
  prompt: "Analyze this cryptocurrency pattern...",
  temperature: 0.1,
  maxTokens: 500,
});
return result.text; // Actual AI output
```

### 2. Model-Agnostic Configuration ✅
```bash
# Switch models without source changes
export AI_PROVIDER=ollama
export AI_MODEL=qwen3:14b
export AI_BASE_URL=http://localhost:11434

# Or use Claude
export AI_PROVIDER=anthropic
export AI_MODEL=claude-3-haiku-20240307
export AI_API_KEY=your_key_here
```

### 3. MCP Integration ✅
- Memory server: Knowledge graph for analysis results
- Filesystem server: File operations and data storage
- Tool standardization: Consistent interfaces across agents

## Development Environment

### Prerequisites
- **Ollama**: 11 models available locally (qwen3:0.6b to qwen3:32b)
- **GPU**: RTX 5070 Ti (16GB VRAM) - 2 models can run simultaneously
- **Runtime**: Bun v1.2.18+ for TypeScript execution
- **MCP Servers**: Memory + Filesystem servers auto-start

### Current Working Commands
```bash
# Test AI integration
cd /home/zzhang/dev/qi/github/mcp-server/qicore-v4/typescript/agent/app/src
bun test-ai-integration.ts

# Test model switching
AI_MODEL=qwen3:14b bun test-model-switching.ts

# Run mathematical verification (uses configured model)
bun mcp-verification-agent.ts
```

## Next Steps for Data Platform

### Phase 1: Foundation Setup
1. **Project Initialization**
   - Initialize Bun/TypeScript project
   - Set up Docker Compose for services
   - Configure development environment

2. **Core Services**
   - Redpanda container (Kafka-compatible streaming)
   - TimescaleDB container (time-series database)
   - ClickHouse container (analytics database)

3. **Data Pipeline MVP**
   - CryptoCompare API integration
   - WebSocket data streaming
   - Basic data ingestion

### Phase 2: Agent Integration
1. **Market Monitoring Agent**
   - Real-time price feeds
   - Volume and liquidity monitoring
   - Event detection

2. **Technical Analysis Agent**
   - Pattern recognition using AI
   - Indicator calculations
   - Signal generation

3. **Multi-Agent Coordination**
   - Agent communication protocols
   - Shared state management
   - Decision coordination

### Phase 3: Production Features
1. **Risk Management**
   - Position sizing algorithms
   - Risk metrics calculation
   - Portfolio optimization

2. **Backtesting Framework**
   - Historical data analysis
   - Strategy validation
   - Performance metrics

3. **Monitoring & Observability**
   - Agent performance tracking
   - System health monitoring
   - Alert systems

## Important Notes

### Agent Library Status
- ✅ **Working**: Real AI execution with QiAgent + Ollama
- ✅ **Working**: Model switching via environment variables
- ✅ **Working**: MCP integration (memory + filesystem)
- ✅ **Tested**: Mathematical analysis workflow

### GPU & Performance
- **Current Setup**: RTX 5070 Ti (16GB VRAM)
- **Model Usage**: Can run 2 models simultaneously (qwen3:14b + qwen3:0.6b)
- **Utilization**: 10-30% GPU usage is normal for single-request inference
- **Memory**: ~15GB VRAM used with both models loaded

### Development Workflow
1. **Start here**: `/home/zzhang/dev/qi/github/mcp-server/dp/`
2. **Reference docs**: `docs/proposal.md` for architecture details
3. **Foundation code**: Use agent patterns from `../qicore-v4/typescript/agent/`
4. **AI integration**: Import from `@qicore/agent-lib` workspace

## Ready to Build! 🚀

The foundation is solid:
- Real AI agents working
- MCP infrastructure ready
- Architecture designed
- Development environment configured

Let's build the crypto data platform that showcases the power of MCP + AI agents!