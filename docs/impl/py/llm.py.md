# LLM Implementation

> **LLM Interface with Provider Pattern and Plugin Pipeline**  
> **Design Source**: [Container Design](../design/container.phase.1.md), [Class Design](../design/classes.phase.1.md)  
> **Implementation**: Python 3.12+ with Functional Pipeline Patterns  
> **Purpose**: Modular LLM integration with plugin-extensible processing pipelines

## Overview

This document implements the LLM interface system that provides modular LLM integration with provider patterns and plugin-extensible processing pipelines. The implementation follows functional programming principles with pipeline composition and plugin extension points.

## LLM Interface Architecture

### Provider Interface and Implementation

```python
from typing import Dict, List, Optional, Any, Callable, Union
from dataclasses import dataclass, field
from abc import ABC, abstractmethod
import asyncio
from models import Context, MCPRequest, MCPResponse

class LLMProvider(ABC):
    """
    Abstract base class for LLM providers.
    
    Defines the interface for different LLM backends (Ollama, OpenAI, etc.)
    """
    
    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Provider identifier."""
        pass
    
    @property
    @abstractmethod
    def supported_models(self) -> List[str]:
        """List of models supported by this provider."""
        pass
    
    @abstractmethod
    async def submit_prompt(self, prompt: str, context: Context, model: str) -> str:
        """
        Submit prompt to LLM and return response.
        
        Args:
            prompt: Prompt text to submit
            context: Context for the request
            model: Model name to use
            
        Returns:
            LLM response text
        """
        pass
    
    @abstractmethod
    async def load_model(self, model_name: str) -> bool:
        """
        Load model if needed.
        
        Args:
            model_name: Name of model to load
            
        Returns:
            True if model loaded successfully
        """
        pass
    
    @abstractmethod
    async def get_capabilities(self) -> Dict[str, Any]:
        """Get provider capabilities and status."""
        pass

class OllamaProvider(LLMProvider):
    """Ollama LLM provider implementation."""
    
    def __init__(self, base_url: str = "http://localhost:11434"):
        self.base_url = base_url
        self.loaded_models: set = set()
    
    @property
    def provider_name(self) -> str:
        return "ollama"
    
    @property
    def supported_models(self) -> List[str]:
        return [
            "llama3.1:8b",
            "llama3.1:70b", 
            "qwen3:8b",
            "codestral:22b"
        ]
    
    async def submit_prompt(self, prompt: str, context: Context, model: str) -> str:
        """Submit prompt to Ollama."""
        try:
            # TODO: Implement actual Ollama API call
            response = f"Ollama response for model {model}: {prompt[:100]}..."
            return response
        except Exception as e:
            raise RuntimeError(f"Ollama submission failed: {str(e)}")
    
    async def load_model(self, model_name: str) -> bool:
        """Load model in Ollama."""
        try:
            if model_name in self.loaded_models:
                return True
            
            # TODO: Implement actual model loading
            # This would call Ollama's pull/load API
            
            self.loaded_models.add(model_name)
            return True
            
        except Exception as e:
            print(f"Failed to load model {model_name}: {e}")
            return False
    
    async def get_capabilities(self) -> Dict[str, Any]:
        """Get Ollama capabilities."""
        return {
            "provider": self.provider_name,
            "base_url": self.base_url,
            "loaded_models": list(self.loaded_models),
            "supported_models": self.supported_models,
            "features": ["streaming", "function_calling", "embeddings"]
        }
```

### Pipeline Processing Components

```python
class ContextPreprocessor(ABC):
    """Interface for context preprocessing plugins."""
    
    @property
    @abstractmethod
    def preprocessor_name(self) -> str:
        """Preprocessor identifier."""
        pass
    
    @abstractmethod
    async def preprocess_context(self, context: Context) -> Context:
        """
        Preprocess context before LLM submission.
        
        Args:
            context: Original context
            
        Returns:
            Enhanced context
        """
        pass

class ResponsePostprocessor(ABC):
    """Interface for response postprocessing plugins."""
    
    @property
    @abstractmethod
    def postprocessor_name(self) -> str:
        """Postprocessor identifier."""
        pass
    
    @abstractmethod
    async def postprocess_response(self, response: str, context: Context) -> str:
        """
        Postprocess LLM response.
        
        Args:
            response: Original LLM response
            context: Request context
            
        Returns:
            Enhanced response
        """
        pass

# Core preprocessors for Phase 1
class TokenOptimizationPreprocessor(ContextPreprocessor):
    """Preprocessor for token count optimization."""
    
    @property
    def preprocessor_name(self) -> str:
        return "token_optimization"
    
    async def preprocess_context(self, context: Context) -> Context:
        """Optimize context for token limits."""
        # TODO: Implement token counting and optimization
        # This would truncate or summarize context to fit model limits
        
        optimized_context = context.with_metadata({
            "optimized_for_tokens": True,
            "original_token_count": context.token_count,
            "optimization_applied": "token_limit"
        })
        
        return optimized_context

class SecurityPreprocessor(ContextPreprocessor):
    """Preprocessor for security and content filtering."""
    
    @property
    def preprocessor_name(self) -> str:
        return "security_filter"
    
    async def preprocess_context(self, context: Context) -> Context:
        """Apply security filtering to context."""
        # TODO: Implement security filtering
        # This would remove sensitive information, apply content filters
        
        secured_context = context.with_metadata({
            "security_filtered": True,
            "filter_applied": "content_security",
            "sensitive_data_removed": False
        })
        
        return secured_context

# Core postprocessors for Phase 1
class ResponseFormattingPostprocessor(ResponsePostprocessor):
    """Postprocessor for response formatting."""
    
    @property
    def postprocessor_name(self) -> str:
        return "response_formatting"
    
    async def postprocess_response(self, response: str, context: Context) -> str:
        """Format LLM response for consistency."""
        # TODO: Implement response formatting
        # This would apply markdown formatting, structure responses
        
        formatted_response = f"**Enhanced Response:**\n\n{response}\n\n---\n*Processed by {self.postprocessor_name}*"
        return formatted_response

class ErrorHandlingPostprocessor(ResponsePostprocessor):
    """Postprocessor for error handling and recovery."""
    
    @property
    def postprocessor_name(self) -> str:
        return "error_handling"
    
    async def postprocess_response(self, response: str, context: Context) -> str:
        """Handle errors in LLM responses."""
        # TODO: Implement error detection and handling
        # This would detect errors, provide fallback responses
        
        if "error" in response.lower() or len(response.strip()) == 0:
            return "I encountered an issue processing your request. Please try rephrasing your question."
        
        return response
```

### LLM Pipeline Implementation

```python
@dataclass(frozen=True)
class LLMPipeline:
    """
    Immutable LLM processing pipeline with functional composition.
    
    Combines provider, preprocessors, and postprocessors for complete LLM processing.
    """
    provider: LLMProvider
    preprocessors: Tuple[ContextPreprocessor, ...] = field(default_factory=tuple)
    postprocessors: Tuple[ResponsePostprocessor, ...] = field(default_factory=tuple)
    default_model: str = "llama3.1:8b"
    pipeline_metadata: Dict[str, Any] = field(default_factory=dict)
    
    def with_preprocessor(self, preprocessor: ContextPreprocessor) -> 'LLMPipeline':
        """Add preprocessor to pipeline immutably."""
        new_preprocessors = self.preprocessors + (preprocessor,)
        return LLMPipeline(
            provider=self.provider,
            preprocessors=new_preprocessors,
            postprocessors=self.postprocessors,
            default_model=self.default_model,
            pipeline_metadata=self.pipeline_metadata
        )
    
    def with_postprocessor(self, postprocessor: ResponsePostprocessor) -> 'LLMPipeline':
        """Add postprocessor to pipeline immutably."""
        new_postprocessors = self.postprocessors + (postprocessor,)
        return LLMPipeline(
            provider=self.provider,
            preprocessors=self.preprocessors,
            postprocessors=new_postprocessors,
            default_model=self.default_model,
            pipeline_metadata=self.pipeline_metadata
        )
    
    def with_model(self, model: str) -> 'LLMPipeline':
        """Set default model immutably."""
        return LLMPipeline(
            provider=self.provider,
            preprocessors=self.preprocessors,
            postprocessors=self.postprocessors,
            default_model=model,
            pipeline_metadata=self.pipeline_metadata
        )
    
    def with_metadata(self, metadata: Dict[str, Any]) -> 'LLMPipeline':
        """Add pipeline metadata immutably."""
        new_metadata = {**self.pipeline_metadata, **metadata}
        return LLMPipeline(
            provider=self.provider,
            preprocessors=self.preprocessors,
            postprocessors=self.postprocessors,
            default_model=self.default_model,
            pipeline_metadata=new_metadata
        )

class LLMPipelineExecutor:
    """
    Pipeline execution engine with functional composition.
    
    Executes LLM pipelines through preprocessor and postprocessor chains.
    """
    
    def __init__(self, pipeline: LLMPipeline):
        self.pipeline = pipeline
    
    async def execute(self, prompt: str, context: Context, model: Optional[str] = None) -> str:
        """
        Execute complete LLM pipeline.
        
        Args:
            prompt: Prompt to submit
            context: Request context
            model: Optional model override
            
        Returns:
            Processed LLM response
        """
        try:
            # Step 1: Apply preprocessing chain
            processed_context = await self._apply_preprocessors(context)
            
            # Step 2: Submit to LLM provider
            model_to_use = model or self.pipeline.default_model
            await self.pipeline.provider.load_model(model_to_use)
            
            llm_response = await self.pipeline.provider.submit_prompt(
                prompt, processed_context, model_to_use
            )
            
            # Step 3: Apply postprocessing chain
            final_response = await self._apply_postprocessors(llm_response, processed_context)
            
            return final_response
            
        except Exception as e:
            return f"LLM pipeline execution failed: {str(e)}"
    
    async def _apply_preprocessors(self, context: Context) -> Context:
        """
        Apply preprocessor chain using functional composition.
        
        Functional pattern: fold(preprocessor.preprocess, context, preprocessors)
        """
        async def apply_preprocessor(current_context: Context, preprocessor: ContextPreprocessor) -> Context:
            try:
                return await preprocessor.preprocess_context(current_context)
            except Exception as e:
                # Log error but continue with current context
                print(f"Preprocessor {preprocessor.preprocessor_name} failed: {e}")
                return current_context
        
        # Functional composition
        result_context = context
        for preprocessor in self.pipeline.preprocessors:
            result_context = await apply_preprocessor(result_context, preprocessor)
        
        return result_context
    
    async def _apply_postprocessors(self, response: str, context: Context) -> str:
        """
        Apply postprocessor chain using functional composition.
        
        Functional pattern: fold(postprocessor.postprocess, response, postprocessors)
        """
        async def apply_postprocessor(current_response: str, postprocessor: ResponsePostprocessor) -> str:
            try:
                return await postprocessor.postprocess_response(current_response, context)
            except Exception as e:
                # Log error but continue with current response
                print(f"Postprocessor {postprocessor.postprocessor_name} failed: {e}")
                return current_response
        
        # Functional composition
        result_response = response
        for postprocessor in self.pipeline.postprocessors:
            result_response = await apply_postprocessor(result_response, postprocessor)
        
        return result_response
```

### LLM Interface Manager

```python
class LLMInterface:
    """
    High-level LLM interface with pipeline management.
    
    Coordinates LLM providers, pipeline composition, and execution.
    """
    
    def __init__(self, default_provider: Optional[LLMProvider] = None):
        self.providers: Dict[str, LLMProvider] = {}
        self.pipelines: Dict[str, LLMPipeline] = {}
        self.default_provider = default_provider or OllamaProvider()
        
        # Register default provider
        self.register_provider(self.default_provider)
        
        # Create default pipeline
        self._create_default_pipeline()
    
    def register_provider(self, provider: LLMProvider) -> None:
        """Register LLM provider."""
        self.providers[provider.provider_name] = provider
    
    def _create_default_pipeline(self) -> None:
        """Create default pipeline with core processors."""
        pipeline = LLMPipeline(provider=self.default_provider)
        
        # Add default preprocessors
        pipeline = pipeline.with_preprocessor(TokenOptimizationPreprocessor())
        pipeline = pipeline.with_preprocessor(SecurityPreprocessor())
        
        # Add default postprocessors
        pipeline = pipeline.with_postprocessor(ResponseFormattingPostprocessor())
        pipeline = pipeline.with_postprocessor(ErrorHandlingPostprocessor())
        
        self.pipelines["default"] = pipeline
    
    def create_pipeline(self, pipeline_name: str, provider_name: str, model: str) -> LLMPipeline:
        """
        Create custom pipeline.
        
        Args:
            pipeline_name: Name for the pipeline
            provider_name: Provider to use
            model: Default model for pipeline
            
        Returns:
            Created pipeline
        """
        provider = self.providers.get(provider_name)
        if not provider:
            raise ValueError(f"Provider {provider_name} not found")
        
        pipeline = LLMPipeline(provider=provider, default_model=model)
        self.pipelines[pipeline_name] = pipeline
        
        return pipeline
    
    def add_preprocessor_to_pipeline(self, pipeline_name: str, preprocessor: ContextPreprocessor) -> None:
        """Add preprocessor to existing pipeline."""
        if pipeline_name not in self.pipelines:
            raise ValueError(f"Pipeline {pipeline_name} not found")
        
        current_pipeline = self.pipelines[pipeline_name]
        updated_pipeline = current_pipeline.with_preprocessor(preprocessor)
        self.pipelines[pipeline_name] = updated_pipeline
    
    def add_postprocessor_to_pipeline(self, pipeline_name: str, postprocessor: ResponsePostprocessor) -> None:
        """Add postprocessor to existing pipeline."""
        if pipeline_name not in self.pipelines:
            raise ValueError(f"Pipeline {pipeline_name} not found")
        
        current_pipeline = self.pipelines[pipeline_name]
        updated_pipeline = current_pipeline.with_postprocessor(postprocessor)
        self.pipelines[pipeline_name] = updated_pipeline
    
    async def submit_request(self, 
                           prompt: str, 
                           context: Context, 
                           pipeline_name: str = "default",
                           model: Optional[str] = None) -> str:
        """
        Submit request through specified pipeline.
        
        Args:
            prompt: Prompt to submit
            context: Request context
            pipeline_name: Pipeline to use
            model: Optional model override
            
        Returns:
            Processed LLM response
        """
        pipeline = self.pipelines.get(pipeline_name)
        if not pipeline:
            raise ValueError(f"Pipeline {pipeline_name} not found")
        
        executor = LLMPipelineExecutor(pipeline)
        return await executor.execute(prompt, context, model)
    
    async def get_provider_status(self, provider_name: str) -> Optional[Dict[str, Any]]:
        """Get provider capabilities and status."""
        provider = self.providers.get(provider_name)
        if provider:
            return await provider.get_capabilities()
        return None
    
    def get_available_models(self, provider_name: str) -> List[str]:
        """Get available models for provider."""
        provider = self.providers.get(provider_name)
        if provider:
            return provider.supported_models
        return []
    
    def get_pipeline_info(self, pipeline_name: str) -> Optional[Dict[str, Any]]:
        """Get pipeline configuration information."""
        pipeline = self.pipelines.get(pipeline_name)
        if not pipeline:
            return None
        
        return {
            "pipeline_name": pipeline_name,
            "provider": pipeline.provider.provider_name,
            "default_model": pipeline.default_model,
            "preprocessors": [p.preprocessor_name for p in pipeline.preprocessors],
            "postprocessors": [p.postprocessor_name for p in pipeline.postprocessors],
            "metadata": pipeline.pipeline_metadata
        }
```

## Integration with Plugin System

The LLM system integrates with the plugin system through:

1. **Preprocessors as Plugins**: Context preprocessors implement the plugin interface
2. **Postprocessors as Plugins**: Response postprocessors implement the plugin interface
3. **Pipeline Registration**: Plugins can register processors for specific LLM workflows
4. **Provider Extensions**: New LLM providers can be registered as plugins

## Usage Example

```python
# Initialize LLM interface
llm_interface = LLMInterface()

# Create custom pipeline for code analysis
code_pipeline = llm_interface.create_pipeline(
    pipeline_name="code_analysis",
    provider_name="ollama", 
    model="codestral:22b"
)

# Add specialized preprocessors
class CodeContextPreprocessor(ContextPreprocessor):
    @property
    def preprocessor_name(self) -> str:
        return "code_context"
    
    async def preprocess_context(self, context: Context) -> Context:
        # Add code-specific context enhancement
        return context

llm_interface.add_preprocessor_to_pipeline("code_analysis", CodeContextPreprocessor())

# Submit request through pipeline
from models import Context
context = Context(session_id="session-123")
response = await llm_interface.submit_request(
    prompt="Analyze this Python function for potential bugs",
    context=context,
    pipeline_name="code_analysis"
)
```

## Future Phase Extensions

This LLM system provides extension points for future phases:

- **Phase 2 RAG**: Semantic context preprocessors for knowledge base integration
- **Phase 3 sAgents**: Agent-specific preprocessors and postprocessors for multi-agent coordination
- **Phase 4 Autonomy**: Self-improving processors that optimize based on usage patterns

All extensions use the same pipeline pattern without modifying core LLM implementation. 