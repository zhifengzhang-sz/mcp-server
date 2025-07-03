# AI Code Generation Consistency Study - Documentation

## Overview
This directory contains documentation for the AI Code Generation Consistency Study platform - a TypeScript/Bun application that measures consistency in AI code generation across different models, focusing on Haskell code generation.

## Documentation Structure

```
docs/
├── readme.md              # This file - documentation index
├── contracts/             # Component interface contracts  
│   ├── qiprompt.comp.md   # QiPrompt component contracts
│   └── qiagent.comp.md    # QiAgent component contracts
└── guides/                # User and developer guides
    └── claude.sdk.md      # Claude Code SDK integration guide
```

## Architecture Summary

The platform follows a clean module-based architecture with **proper dependency flow** - modules are self-contained and app depends on modules, never the reverse.

### **Reusable Modules** (`src/modules/`)
- **`qicore/`** - Core QiCore v4 functionality (Result, Error, Logger, Configuration)
- **`qiagent/`** - AI model integration and code generation
- **`qiprompt/`** - Prompt management and instruction handling
- **`types.ts`** - **Core AI types** (AIModel, GenerationRequest, InstructionSet, QualityMetrics)

### **Application Layer** (`src/app/`)
- **`analysis/`** - Statistical analysis and consistency measurement
- **`config/`** - Study configuration management
- **`database/`** - Data persistence and storage
- **`evaluation/`** - Code quality evaluation and scoring
- **`generators/`** - Test case and benchmark generation
- **`runners/`** - Study execution runners
- **`types/`** - **Study-specific types** (StudyConfig, StudyResult, GenerationResult, StudyStatistics)

## ✅ **Dependency Architecture Fixed**

**Correct Flow:**
```
app/types/ → modules/types.ts → modules/qicore/
     ↑              ↑                ↑
   app/analysis   modules/qiagent   modules/qiprompt
```

**Key Principles:**
- ✅ **Modules are self-contained** - no app dependencies
- ✅ **App uses modules** - imports from modules/types.ts
- ✅ **Core AI types** in modules (AIModel, GenerationRequest, etc.)
- ✅ **Study-specific types** in app (StudyConfig, StudyResult, etc.)

## Implementation Notes

- **Package-based approach**: Uses proven libraries (winston, zod, fp-ts, axios)
- **Functional programming**: QiCore Result types, fp-ts Either for error handling
- **Type safety**: Full TypeScript with Zod validation schemas
- **Testing**: Comprehensive unit and integration tests

## Key Components

### QiCore Foundation (Module)
- `Result<T>` type for functional error handling
- Structured error system with QiError
- Configuration management with environment variables
- Structured logging with winston

### QiAgent (Module)
- OpenAI API integration
- Local model support (Ollama)
- Anthropic Claude integration
- Consistent response formatting

### QiPrompt (Module)
- Instruction template system
- Prompt validation and optimization
- Context management for code generation

For specific component details, see the contracts documentation in `/contracts/`. 