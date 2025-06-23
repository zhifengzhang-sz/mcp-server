# Ollama GPU Optimization Guide

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Nix Integration Strategy](#nix-integration-strategy)
4. [GPU Configuration](#gpu-configuration)
5. [Performance Optimization](#performance-optimization)
6. [Model Management](#model-management)
7. [Monitoring and Debugging](#monitoring-and-debugging)
8. [Integration with MCP Server](#integration-with-mcp-server)
9. [Troubleshooting](#troubleshooting)

## Overview

Our Ollama integration uses a **hybrid approach**: system-installed Ollama binary with Nix-managed environment and custom GPU optimization wrapper. This provides the best balance of performance, maintainability, and reproducibility.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   OLLAMA INTEGRATION ARCHITECTURE           │
├─────────────────────────────────────────────────────────────┤
│  Nix Development Environment                                │
│  ├── Custom Ollama Wrapper Script                          │
│  ├── GPU Detection & Configuration                         │
│  ├── Performance Optimization                              │
│  └── China Mirror Support                                  │
├─────────────────────────────────────────────────────────────┤
│  System Installation                                       │
│  ├── Ollama Binary (/usr/local/bin/ollama)                │
│  ├── CUDA Runtime (12.9)                                  │
│  ├── NVIDIA Drivers                                       │
│  └── GPU Libraries                                        │
├─────────────────────────────────────────────────────────────┤
│  Hardware Optimization                                     │
│  ├── RTX 5070 Ti (16GB VRAM)                             │
│  ├── Maximum VRAM Utilization                            │
│  ├── Parallel Request Processing                          │
│  └── Flash Attention Acceleration                         │
└─────────────────────────────────────────────────────────────┘
```

### Why This Approach?

**Benefits of System Installation + Nix Wrapper:**
- **Performance**: Native system installation with direct GPU access
- **Reliability**: Proven installation method with official support
- **Flexibility**: Nix wrapper adds optimizations without breaking core functionality
- **Reproducibility**: Environment variables and configuration managed by Nix
- **China Support**: Mirror configuration for model downloads

## System Requirements

### Hardware Requirements
- **GPU**: NVIDIA RTX series (RTX 4060 or better recommended)
- **VRAM**: 8GB minimum, 16GB+ recommended for larger models
- **RAM**: 16GB minimum, 32GB+ recommended
- **Storage**: 50GB+ for model storage

### Software Requirements
- **Linux**: Ubuntu 20.04+ or similar
- **NVIDIA Drivers**: 535+ (latest recommended)
- **CUDA**: 12.0+ (12.9 in our configuration)
- **Ollama**: Latest version (installed system-wide)

### Installation Verification
```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA
nvcc --version

# Check Ollama installation
which ollama
ollama --version
```

## Nix Integration Strategy

### 1. Custom Ollama Wrapper

Our `flake.nix` creates a custom Ollama wrapper that:
- Detects system Ollama installation
- Configures GPU optimization automatically
- Sets up China mirrors when needed
- Provides performance monitoring

```nix
# Create Ollama wrapper that uses system installation
ollama-gpu = pkgs.writeScriptBin "ollama" ''
  #!/usr/bin/env bash
  
  # Check if system Ollama is installed
  if ! command -v /usr/local/bin/ollama >/dev/null 2>&1 && ! command -v /usr/bin/ollama >/dev/null 2>&1; then
    echo "❌ System Ollama not found. Installing..."
    echo "Run: curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
  fi
  
  # Find system Ollama
  SYSTEM_OLLAMA=""
  if [ -x "/usr/local/bin/ollama" ]; then
    SYSTEM_OLLAMA="/usr/local/bin/ollama"
  elif [ -x "/usr/bin/ollama" ]; then
    SYSTEM_OLLAMA="/usr/bin/ollama"
  fi
  
  # ... GPU configuration and optimization ...
  
  # Use system Ollama binary
  exec "$SYSTEM_OLLAMA" "$@"
'';
```

### 2. Development Environment Integration

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    # GPU-enabled Ollama wrapper
    ollama-gpu
    
    # System monitoring tools
    nvidia-ml-py
    
    # Other packages...
  ];
  
  shellHook = ''
    # GPU detection and reporting
    if nvidia-smi &>/dev/null 2>&1; then
      GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)
      GPU_MEM=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits)
      echo "🎮 GPU: $GPU_NAME"
      echo "💾 VRAM: $GPU_MEM"
    fi
  '';
};
```

## GPU Configuration

### RTX 5070 Ti Optimization

Our configuration is specifically optimized for the RTX 5070 Ti with 16GB VRAM:

```bash
# MAXIMIZE GPU Performance for RTX 5070 Ti (16GB VRAM)
export OLLAMA_GPU_OVERHEAD=0              # Use all available VRAM
export OLLAMA_NUM_PARALLEL=4              # Multiple parallel requests
export OLLAMA_MAX_LOADED_MODELS=2         # Keep multiple models in VRAM
export OLLAMA_FLASH_ATTENTION=true        # Enable flash attention for speed
export OLLAMA_KV_CACHE_TYPE="f16"         # Full precision KV cache
export OLLAMA_NUM_GPU=1                   # Use your single GPU
export OLLAMA_SCHED_SPREAD=false          # Don't spread across GPUs

# CUDA optimizations
export CUDA_VISIBLE_DEVICES=0
export NVIDIA_VISIBLE_DEVICES=0
export CUDA_LAUNCH_BLOCKING=0             # Async CUDA operations

# Memory optimizations for 16GB VRAM
export OLLAMA_MAX_QUEUE=64                # Higher request queue
export OLLAMA_LOAD_TIMEOUT="10m"          # Allow time for large models
```

### CUDA Library Paths

```bash
# Use your system's CUDA libraries
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/lib/wsl/lib:/usr/local/cuda-12.9/lib64:$LD_LIBRARY_PATH"
export CUDA_PATH="/usr/local/cuda-12.9"
export CUDA_ROOT="/usr/local/cuda-12.9"
```

### Configuration for Different GPUs

#### RTX 4060 (8GB VRAM)
```bash
export OLLAMA_GPU_OVERHEAD=1024           # Reserve 1GB for system
export OLLAMA_NUM_PARALLEL=2              # Fewer parallel requests
export OLLAMA_MAX_LOADED_MODELS=1         # One model at a time
export OLLAMA_KV_CACHE_TYPE="f16"         # Full precision
```

#### RTX 4070 (12GB VRAM) 
```bash
export OLLAMA_GPU_OVERHEAD=512            # Reserve 512MB
export OLLAMA_NUM_PARALLEL=3              # Moderate parallelism
export OLLAMA_MAX_LOADED_MODELS=2         # Two models
export OLLAMA_KV_CACHE_TYPE="f16"         # Full precision
```

#### RTX 4090 (24GB VRAM)
```bash
export OLLAMA_GPU_OVERHEAD=0              # Use all VRAM
export OLLAMA_NUM_PARALLEL=6              # High parallelism
export OLLAMA_MAX_LOADED_MODELS=3         # Multiple models
export OLLAMA_KV_CACHE_TYPE="f16"         # Full precision
```

## Performance Optimization

### Model Selection for RTX 5070 Ti

#### Recommended Models by Use Case

**Fast Response (< 1s):**
```bash
ollama pull qwen2.5:1.5b                  # 1.5B parameters, very fast
ollama pull llama3.2:3b                   # 3B parameters, good balance
ollama pull phi3.5:3.8b                   # 3.8B parameters, efficient
```

**Balanced Performance (1-3s):**
```bash
ollama pull qwen2.5:7b                    # 7B parameters, good quality
ollama pull llama3.1:8b                   # 8B parameters, versatile
ollama pull mistral:7b                    # 7B parameters, instruction-tuned
```

**High Quality (3-8s):**
```bash
ollama pull qwen2.5:14b                   # 14B parameters, high quality
ollama pull llama3.1:70b-q4_0             # 70B quantized, excellent quality
```

**Specialized Models:**
```bash
# Code generation
ollama pull codellama:7b-code
ollama pull deepseek-coder:6.7b

# Embeddings (for ChromaDB)
ollama pull nomic-embed-text
ollama pull mxbai-embed-large
```

### Memory Management Strategies

#### 1. **Dynamic Model Loading**
```python
# models/dynamic_loader.py
class DynamicModelLoader:
    def __init__(self, ollama_client):
        self.client = ollama_client
        self.loaded_models = set()
        self.max_loaded = 2  # Based on OLLAMA_MAX_LOADED_MODELS
    
    def ensure_model_loaded(self, model_name: str):
        """Ensure model is loaded, unloading others if necessary."""
        if model_name in self.loaded_models:
            return
        
        # Check if we need to unload models
        if len(self.loaded_models) >= self.max_loaded:
            # Unload least recently used model
            oldest_model = self.loaded_models.pop()
            self._unload_model(oldest_model)
        
        # Load new model
        self._load_model(model_name)
        self.loaded_models.add(model_name)
    
    def _load_model(self, model_name: str):
        """Load model into VRAM."""
        try:
            # Trigger model loading with a simple query
            self.client.generate(model=model_name, prompt="Hello", stream=False)
        except Exception as e:
            print(f"Failed to load model {model_name}: {e}")
    
    def _unload_model(self, model_name: str):
        """Unload model from VRAM."""
        # Ollama automatically manages this, but we track it
        print(f"Unloading model: {model_name}")
```

#### 2. **Request Queuing and Batching**
```python
# performance/request_manager.py
import asyncio
from collections import deque
from typing import Dict, List

class RequestManager:
    def __init__(self, max_queue_size: int = 64):
        self.queue = deque()
        self.max_queue_size = max_queue_size
        self.processing = False
    
    async def add_request(self, model: str, prompt: str, **kwargs) -> str:
        """Add request to queue and wait for response."""
        if len(self.queue) >= self.max_queue_size:
            raise Exception("Request queue full")
        
        # Create request with future for response
        future = asyncio.Future()
        request = {
            "model": model,
            "prompt": prompt,
            "kwargs": kwargs,
            "future": future
        }
        
        self.queue.append(request)
        
        # Start processing if not already running
        if not self.processing:
            asyncio.create_task(self._process_queue())
        
        return await future
    
    async def _process_queue(self):
        """Process requests in queue."""
        self.processing = True
        
        while self.queue:
            request = self.queue.popleft()
            
            try:
                # Process request
                response = await self._process_single_request(request)
                request["future"].set_result(response)
            except Exception as e:
                request["future"].set_exception(e)
        
        self.processing = False
    
    async def _process_single_request(self, request: Dict) -> str:
        """Process a single request."""
        # Implementation depends on your Ollama client
        pass
```

### Performance Monitoring

#### 1. **GPU Utilization Monitoring**
```python
# monitoring/gpu_monitor.py
import nvidia_ml_py3 as nvml
import time
from dataclasses import dataclass
from typing import List

@dataclass
class GPUStats:
    gpu_id: int
    name: str
    memory_used: int  # MB
    memory_total: int  # MB
    memory_percent: float
    gpu_utilization: int  # Percentage
    temperature: int  # Celsius

class GPUMonitor:
    def __init__(self):
        nvml.nvmlInit()
        self.device_count = nvml.nvmlDeviceGetCount()
    
    def get_gpu_stats(self) -> List[GPUStats]:
        """Get current GPU statistics."""
        stats = []
        
        for i in range(self.device_count):
            handle = nvml.nvmlDeviceGetHandleByIndex(i)
            
            # Memory info
            memory_info = nvml.nvmlDeviceGetMemoryInfo(handle)
            memory_used = memory_info.used // (1024 * 1024)  # Convert to MB
            memory_total = memory_info.total // (1024 * 1024)
            memory_percent = (memory_info.used / memory_info.total) * 100
            
            # GPU utilization
            utilization = nvml.nvmlDeviceGetUtilizationRates(handle)
            
            # Temperature
            temp = nvml.nvmlDeviceGetTemperature(handle, nvml.NVML_TEMPERATURE_GPU)
            
            # Device name
            name = nvml.nvmlDeviceGetName(handle).decode('utf-8')
            
            stats.append(GPUStats(
                gpu_id=i,
                name=name,
                memory_used=memory_used,
                memory_total=memory_total,
                memory_percent=memory_percent,
                gpu_utilization=utilization.gpu,
                temperature=temp
            ))
        
        return stats
    
    def monitor_continuous(self, interval: int = 5):
        """Continuously monitor GPU usage."""
        try:
            while True:
                stats = self.get_gpu_stats()
                for stat in stats:
                    print(f"GPU {stat.gpu_id} ({stat.name}): "
                          f"Memory: {stat.memory_used}/{stat.memory_total}MB ({stat.memory_percent:.1f}%), "
                          f"Utilization: {stat.gpu_utilization}%, "
                          f"Temp: {stat.temperature}°C")
                
                time.sleep(interval)
        except KeyboardInterrupt:
            print("Monitoring stopped")
```

#### 2. **Ollama Performance Metrics**
```python
# monitoring/ollama_monitor.py
import time
import psutil
from typing import Dict, List
from dataclasses import dataclass

@dataclass
class OllamaMetrics:
    timestamp: float
    model_name: str
    prompt_length: int
    response_length: int
    processing_time: float
    tokens_per_second: float
    memory_usage: float  # MB

class OllamaMonitor:
    def __init__(self):
        self.metrics_history: List[OllamaMetrics] = []
    
    def time_request(self, model: str, prompt: str, response: str, start_time: float, end_time: float):
        """Record metrics for a request."""
        processing_time = end_time - start_time
        
        # Estimate tokens (rough approximation)
        response_tokens = len(response.split())
        tokens_per_second = response_tokens / processing_time if processing_time > 0 else 0
        
        # Memory usage
        process = psutil.Process()
        memory_usage = process.memory_info().rss / (1024 * 1024)  # MB
        
        metrics = OllamaMetrics(
            timestamp=start_time,
            model_name=model,
            prompt_length=len(prompt),
            response_length=len(response),
            processing_time=processing_time,
            tokens_per_second=tokens_per_second,
            memory_usage=memory_usage
        )
        
        self.metrics_history.append(metrics)
    
    def get_performance_summary(self, model: str = None) -> Dict:
        """Get performance summary for model or all models."""
        if model:
            metrics = [m for m in self.metrics_history if m.model_name == model]
        else:
            metrics = self.metrics_history
        
        if not metrics:
            return {}
        
        return {
            "total_requests": len(metrics),
            "avg_processing_time": sum(m.processing_time for m in metrics) / len(metrics),
            "avg_tokens_per_second": sum(m.tokens_per_second for m in metrics) / len(metrics),
            "min_processing_time": min(m.processing_time for m in metrics),
            "max_processing_time": max(m.processing_time for m in metrics),
            "avg_memory_usage": sum(m.memory_usage for m in metrics) / len(metrics)
        }
```

## Model Management

### Recommended Model Setup

```bash
# Essential models for MCP server
ollama pull llama3.2:3b                   # Primary chat model (fast)
ollama pull qwen2.5:7b                    # Secondary chat model (balanced)
ollama pull nomic-embed-text              # Embedding model for ChromaDB
ollama pull codellama:7b-code             # Code generation

# Optional specialized models
ollama pull mistral:7b                    # Alternative chat model
ollama pull llama3.1:8b                   # Higher quality chat
```

### Model Storage and Organization

```bash
# Model storage structure
~/.ollama/
├── models/
│   ├── manifests/
│   │   └── registry.ollama.ai/
│   └── blobs/
│       ├── sha256-abc123...              # Model weights
│       └── sha256-def456...
└── logs/
    └── server.log
```

### Model Management Scripts

```python
# scripts/model_manager.py
import subprocess
import json
from typing import List, Dict

class ModelManager:
    def __init__(self):
        self.ollama_cmd = "ollama"
    
    def list_models(self) -> List[Dict]:
        """List all installed models."""
        try:
            result = subprocess.run([self.ollama_cmd, "list"], 
                                  capture_output=True, text=True, check=True)
            
            models = []
            lines = result.stdout.strip().split('\n')[1:]  # Skip header
            
            for line in lines:
                parts = line.split()
                if len(parts) >= 3:
                    models.append({
                        "name": parts[0],
                        "id": parts[1],
                        "size": parts[2],
                        "modified": " ".join(parts[3:]) if len(parts) > 3 else ""
                    })
            
            return models
        except subprocess.CalledProcessError:
            return []
    
    def pull_model(self, model_name: str) -> bool:
        """Download a model."""
        try:
            subprocess.run([self.ollama_cmd, "pull", model_name], check=True)
            return True
        except subprocess.CalledProcessError:
            return False
    
    def remove_model(self, model_name: str) -> bool:
        """Remove a model."""
        try:
            subprocess.run([self.ollama_cmd, "rm", model_name], check=True)
            return True
        except subprocess.CalledProcessError:
            return False
    
    def get_model_info(self, model_name: str) -> Dict:
        """Get detailed model information."""
        try:
            result = subprocess.run([self.ollama_cmd, "show", model_name], 
                                  capture_output=True, text=True, check=True)
            
            # Parse the output (format varies)
            info = {"raw_output": result.stdout}
            
            # Try to extract structured information
            lines = result.stdout.split('\n')
            for line in lines:
                if "Parameters" in line:
                    info["parameters"] = line.split()[-1]
                elif "Quantization" in line:
                    info["quantization"] = line.split()[-1]
            
            return info
        except subprocess.CalledProcessError:
            return {}
```

## Integration with MCP Server

### Ollama Client Integration

```python
# integrations/ollama_client.py
import httpx
import json
from typing import Dict, Optional, AsyncGenerator

class OllamaClient:
    def __init__(self, base_url: str = "http://localhost:11434"):
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=300.0)  # 5 minute timeout
    
    async def generate(
        self, 
        model: str, 
        prompt: str, 
        stream: bool = False,
        **kwargs
    ) -> Dict:
        """Generate text with Ollama model."""
        data = {
            "model": model,
            "prompt": prompt,
            "stream": stream,
            **kwargs
        }
        
        if stream:
            return self._generate_stream(data)
        else:
            response = await self.client.post(f"{self.base_url}/api/generate", json=data)
            response.raise_for_status()
            return response.json()
    
    async def _generate_stream(self, data: Dict) -> AsyncGenerator[Dict, None]:
        """Generate streaming response."""
        async with self.client.stream("POST", f"{self.base_url}/api/generate", json=data) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line:
                    yield json.loads(line)
    
    async def embeddings(self, model: str, prompt: str) -> List[float]:
        """Get embeddings for text."""
        data = {
            "model": model,
            "prompt": prompt
        }
        
        response = await self.client.post(f"{self.base_url}/api/embeddings", json=data)
        response.raise_for_status()
        return response.json()["embedding"]
    
    async def chat(
        self, 
        model: str, 
        messages: List[Dict],
        stream: bool = False,
        **kwargs
    ) -> Dict:
        """Chat with conversation context."""
        data = {
            "model": model,
            "messages": messages,
            "stream": stream,
            **kwargs
        }
        
        response = await self.client.post(f"{self.base_url}/api/chat", json=data)
        response.raise_for_status()
        return response.json()
```

### FastMCP Integration

```python
# mcp_server/ollama_tools.py
from fastmcp import FastMCP
from .integrations.ollama_client import OllamaClient

class OllamaTools:
    def __init__(self, mcp_server: FastMCP):
        self.mcp = mcp_server
        self.ollama = OllamaClient()
        self._register_tools()
    
    def _register_tools(self):
        """Register Ollama tools with MCP server."""
        
        @self.mcp.tool()
        async def generate_text(
            model: str = "llama3.2:3b",
            prompt: str = "",
            max_tokens: int = 1000,
            temperature: float = 0.7
        ) -> str:
            """Generate text using Ollama model."""
            
            response = await self.ollama.generate(
                model=model,
                prompt=prompt,
                options={
                    "num_predict": max_tokens,
                    "temperature": temperature
                }
            )
            
            return response["response"]
        
        @self.mcp.tool()
        async def get_embeddings(
            text: str,
            model: str = "nomic-embed-text"
        ) -> List[float]:
            """Get text embeddings using Ollama."""
            
            return await self.ollama.embeddings(model=model, prompt=text)
        
        @self.mcp.tool()
        async def chat_with_context(
            messages: List[Dict],
            model: str = "llama3.2:3b",
            temperature: float = 0.7
        ) -> str:
            """Chat with conversation context."""
            
            response = await self.ollama.chat(
                model=model,
                messages=messages,
                options={"temperature": temperature}
            )
            
            return response["message"]["content"]
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Ollama Not Starting
```bash
# Check if Ollama service is running
systemctl status ollama

# Start Ollama service
sudo systemctl start ollama

# Enable auto-start
sudo systemctl enable ollama

# Manual start (for debugging)
ollama serve
```

#### 2. GPU Not Detected
```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA installation
nvcc --version

# Check Ollama GPU support
ollama run llama3.2:3b "Hello" --verbose
```

#### 3. Model Download Issues
```bash
# Check network connectivity
curl -I https://ollama.com

# Manual model download
ollama pull llama3.2:3b --verbose

# Check storage space
df -h ~/.ollama/
```

#### 4. Performance Issues
```python
# Debug performance
import time

start_time = time.time()
response = ollama.generate(model="llama3.2:3b", prompt="Hello world")
end_time = time.time()

print(f"Generation took {end_time - start_time:.2f} seconds")
print(f"Response length: {len(response['response'])} characters")

# Check GPU utilization during generation
# Run `nvidia-smi` in another terminal
```

### Performance Optimization Checklist

- [ ] ✅ System Ollama installed and running
- [ ] ✅ NVIDIA drivers updated (535+)
- [ ] ✅ CUDA 12.9 installed
- [ ] ✅ GPU environment variables set
- [ ] ✅ Models pre-downloaded
- [ ] ✅ Memory limits configured for GPU
- [ ] ✅ Request queuing implemented
- [ ] ✅ Performance monitoring active

### Debug Commands

```bash
# Test Ollama installation
ollama --version
ollama list

# Test GPU access
nvidia-smi
nvidia-smi -l 1  # Continuous monitoring

# Test model generation
time ollama run llama3.2:3b "Write a short poem"

# Check Ollama logs
journalctl -u ollama -f

# Monitor system resources
htop
iotop
```

This guide provides comprehensive coverage of Ollama integration and optimization for maximum performance with the RTX 5070 Ti GPU while maintaining reproducibility through Nix.
