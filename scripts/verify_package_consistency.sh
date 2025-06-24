#!/bin/bash

# Package Strategy Consistency Verification
# Verifies all impl files follow package.phase.1.md strategy

set -e

echo "🔍 PACKAGE STRATEGY CONSISTENCY VERIFICATION"
echo "=============================================="
echo ""

MASTER_FILE="docs/impl/package.phase.1.md"
IMPL_DIR="docs/impl"
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📋 VERIFICATION LOGIC:"
echo "- MASTER: $MASTER_FILE defines qicore-v4 wrapper strategy"
echo "- ALL other impl files must follow this strategy"
echo "- NO direct package imports where qicore-v4 wrappers exist"
echo ""

# Check 1: Master file exists and defines qicore-v4 strategy
echo "✅ Check 1: Master Strategy File"
if [ ! -f "$MASTER_FILE" ]; then
    echo -e "${RED}❌ CRITICAL: $MASTER_FILE not found${NC}"
    exit 1
fi

QICORE_DEFS=$(grep -c "qicore-v4\." "$MASTER_FILE" || echo "0")
if [ "$QICORE_DEFS" -lt 5 ]; then
    echo -e "${RED}❌ $MASTER_FILE has insufficient qicore-v4 definitions ($QICORE_DEFS found)${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ $MASTER_FILE defines qicore-v4 strategy ($QICORE_DEFS definitions)${NC}"
fi

echo ""

# Check 2: No direct package imports (except in master file)
echo "✅ Check 2: Direct Package Import Violations"
DIRECT_IMPORTS=$(grep -r "from redis\|import pydantic\|from fastapi\|import typer\|from structlog\|import aiosqlite" "$IMPL_DIR" --exclude="$(basename $MASTER_FILE)" --exclude="LOGICAL_STRUCTURE.md" | grep -v "qicore" || echo "")

if [ -n "$DIRECT_IMPORTS" ]; then
    echo -e "${RED}❌ FOUND DIRECT PACKAGE IMPORTS (should use qicore-v4 wrappers):${NC}"
    echo "$DIRECT_IMPORTS"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ No direct package imports found${NC}"
fi

echo ""

# Check 3: Reference to master strategy
echo "✅ Check 3: References to Master Strategy"
MISSING_REFS=""
for file in "$IMPL_DIR"/*.py.md; do
    if [ "$(basename "$file")" = "$(basename "$MASTER_FILE")" ]; then
        continue
    fi
    
    if ! grep -q "package.phase.1.md\|package selection\|package strategy" "$file"; then
        MISSING_REFS="$MISSING_REFS\n$(basename "$file")"
    fi
done

if [ -n "$MISSING_REFS" ]; then
    echo -e "${RED}❌ FILES MISSING REFERENCE TO MASTER STRATEGY:${NC}"
    echo -e "$MISSING_REFS"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ All component files reference master strategy${NC}"
fi

echo ""

# Check 4: qicore-v4 usage in component files
echo "✅ Check 4: qicore-v4 Usage in Component Files"
QICORE_USAGE=$(grep -r "qicore.v4\|qicore_v4" "$IMPL_DIR" --exclude="$(basename $MASTER_FILE)" --exclude="LOGICAL_STRUCTURE.md" | wc -l)

if [ "$QICORE_USAGE" -lt 10 ]; then
    echo -e "${YELLOW}⚠️  Limited qicore-v4 usage found ($QICORE_USAGE instances)${NC}"
    echo "This might indicate files aren't fully updated to use qicore-v4 wrappers"
else
    echo -e "${GREEN}✅ Good qicore-v4 usage found ($QICORE_USAGE instances)${NC}"
fi

echo ""

# Check 5: File relationship structure
echo "✅ Check 5: Implementation File Structure"
REQUIRED_FILES=(
    "impl.strategy.md"
    "README.md"
    "config.py.md"
    "storage.py.md"
    "interface.py.md"
    "context.py.md"
    "orchestration.py.md"
)

MISSING_FILES=""
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$IMPL_DIR/$file" ]; then
        MISSING_FILES="$MISSING_FILES\n$file"
    fi
done

if [ -n "$MISSING_FILES" ]; then
    echo -e "${RED}❌ MISSING REQUIRED FILES:${NC}"
    echo -e "$MISSING_FILES"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ All required implementation files present${NC}"
fi

echo ""
echo "=============================================="

# Summary
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}🎉 VERIFICATION PASSED: All files follow package strategy${NC}"
    exit 0
else
    echo -e "${RED}❌ VERIFICATION FAILED: $ERRORS consistency issues found${NC}"
    echo ""
    echo "💡 REMEDIATION REQUIRED:"
    echo "1. Update all component files to use qicore-v4 imports"
    echo "2. Remove direct package imports (fastapi → qicore-v4.web, etc.)"
    echo "3. Add references to package.phase.1.md in all component files"
    echo "4. Ensure all files follow the master package strategy"
    echo ""
    echo "📖 See: docs/impl/LOGICAL_STRUCTURE.md for details"
    exit 1
fi 