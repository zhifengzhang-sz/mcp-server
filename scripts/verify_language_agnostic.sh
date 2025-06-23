#!/bin/bash
# File: scripts/verify_language_agnostic.sh
# Purpose: Verify design documents contain no language-specific syntax

echo "🔍 Checking for language-specific syntax violations..."
violations=0
violation_details=""

# Check for TypeScript/JavaScript syntax
echo "Checking for TypeScript/JavaScript syntax..."
if results=$(grep -r "interface\s\+\w\+\s*{" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found TypeScript interface syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}TypeScript interfaces; "
fi

if results=$(grep -r "=>\s*\w\+" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found arrow function syntax:"
    echo "$results"  
    violations=$((violations + 1))
    violation_details="${violation_details}Arrow functions; "
fi

if results=$(grep -r "function\s*(" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found function declaration syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Function declarations; "
fi

# Check for Python syntax  
echo "Checking for Python syntax..."
if results=$(grep -r "def\s\+\w\+.*:" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found Python function syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Python functions; "
fi

if results=$(grep -r "class\s\+\w\+.*:" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found Python class syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Python classes; "
fi

# Check for Haskell syntax
echo "Checking for Haskell syntax..."
if results=$(grep -r "::\s*\w\+" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found Haskell type annotation syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Haskell type annotations; "
fi

if results=$(grep -r "\w\+\s*<-\s*\w\+" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found Haskell bind syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Haskell bind operators; "
fi

# Check for generic code syntax
echo "Checking for generic code syntax..."
if results=$(grep -r "<\w\+>" docs/design/ docs/objective/ 2>/dev/null); then
    echo "❌ Found generic type syntax:"
    echo "$results"
    violations=$((violations + 1))
    violation_details="${violation_details}Generic types; "
fi

# Results
echo ""
echo "=== LANGUAGE-AGNOSTIC VERIFICATION RESULTS ==="
if [ $violations -eq 0 ]; then
    echo "✅ Language-agnostic verification PASSED"
    echo "✅ All design documents use mathematical notation only"
    exit 0
else
    echo "❌ Language-agnostic verification FAILED"
    echo "❌ Found $violations violation type(s): $violation_details"
    echo ""
    echo "🔧 Fix Required:"
    echo "   - Replace language-specific syntax with mathematical notation"
    echo "   - Use '→' instead of '=>'"
    echo "   - Use operation contracts instead of function/class definitions"
    echo "   - Use type specifications instead of language-specific types"
    exit 1
fi 