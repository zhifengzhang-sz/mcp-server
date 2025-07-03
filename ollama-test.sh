#!/bin/bash

echo "Testing Ollama functionality..."

# Check if Ollama is running
echo "=== Available Models ==="
ollama list

echo -e "\n=== Test Code Generation ==="
ollama run qwen2.5-coder:14b "Create a simple TypeScript Result type with map and flatMap operations. Keep it concise."

echo -e "\n=== Test Mathematical Code ==="
ollama run deepseek-coder-v2:16b "Generate a Haskell Functor instance for a Result type. Include property tests." 