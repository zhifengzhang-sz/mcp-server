#!/bin/bash
# File: scripts/verify_cross_references.sh
# Purpose: Verify cross-reference integrity and type consistency

echo "🔍 Checking cross-reference integrity and type consistency..."

broken_refs=0
type_inconsistencies=0
reference_issues=0

# Check for broken internal document references
echo "Checking internal document references..."
while IFS= read -r line; do
    # Extract file and reference from grep output
    file=$(echo "$line" | cut -d':' -f1)
    ref_path=$(echo "$line" | sed 's/.*\](docs\/\([^)]*\)).*/docs\/\1/')
    
    if [ ! -f "$ref_path" ]; then
        echo "❌ BROKEN REFERENCE in $file:"
        echo "   References: $ref_path (file not found)"
        broken_refs=$((broken_refs + 1))
    fi
done < <(grep -rn "\[.*\](docs/[^)]*)" docs/design/ docs/objective/ 2>/dev/null | grep -v "\.git")

# Check for broken section references within files
echo "Checking internal section references..."
while IFS= read -r line; do
    file=$(echo "$line" | cut -d':' -f1)
    reference=$(echo "$line" | sed 's/.*\](#\([^)]*\)).*/\1/')
    
    # Check if the referenced section exists in the same file
    if ! grep -q "^#.*$reference\|^##.*$reference\|^###.*$reference" "$file" 2>/dev/null; then
        echo "❌ BROKEN SECTION REFERENCE in $file:"
        echo "   References: #$reference (section not found)"
        reference_issues=$((reference_issues + 1))
    fi
done < <(grep -rn "\[.*\](#[^)]*)" docs/design/ docs/objective/ 2>/dev/null)

# Check type name consistency across documents
echo "Checking type name consistency..."

# Extract all type names from operation signatures and type definitions
all_types=$(grep -r "→\s*\w\+\|\w\+:" docs/design/ docs/objective/ 2>/dev/null | \
    sed 's/.*→\s*\([A-Z][A-Za-z]*\).*/\1/; s/.*\([A-Z][A-Za-z]*\):.*/\1/' | \
    grep "^[A-Z]" | sort | uniq)

# Common types that should be consistent
critical_types="Plugin PluginRegistry PluginId DiscoveryCriteria ValidationResult CompositePlugin Context ContextAdapter Tool ToolRegistry ToolAdapter ToolParameters ToolResult SessionEvent EventResult Session SessionState"

for type_name in $critical_types; do
    # Find all variations of this type name
    variations=$(grep -r "$type_name" docs/design/ docs/objective/ 2>/dev/null | \
        grep -o "[A-Za-z]*$type_name[A-Za-z]*\|$type_name[A-Za-z]*\|[A-Za-z]*$type_name" | \
        sort | uniq | grep -v "^$type_name$")
    
    if [ -n "$variations" ]; then
        echo "⚠️  TYPE VARIATION for $type_name:"
        echo "$variations" | sed 's/^/     /'
        type_inconsistencies=$((type_inconsistencies + 1))
    fi
done

# Check for missing type definitions
echo "Checking for missing type definitions..."
missing_types=0

# Types that should be defined somewhere
required_types="Plugin PluginRegistry PluginId DiscoveryCriteria ValidationResult CompositePlugin Context ContextAdapter Tool ToolRegistry ToolAdapter ToolParameters ToolResult SessionEvent EventResult"

for req_type in $required_types; do
    # Check if type is defined (look for type definition patterns)
    if ! grep -r "$req_type.*=\|$req_type.*Specification\|$req_type.*Definition\|$req_type.*Contract" docs/design/ >/dev/null 2>&1; then
        echo "⚠️  MISSING TYPE DEFINITION: $req_type"
        missing_types=$((missing_types + 1))
    fi
done

# Check phase reference consistency
echo "Checking phase reference consistency..."
phase_errors=0

# Find all phase references
phase_refs=$(grep -r "Phase [1-4]\|phase [1-4]\|phase\.[1-4]" docs/design/ docs/objective/ 2>/dev/null | \
    grep -o "Phase [1-4]\|phase [1-4]\|phase\.[1-4]" | sort | uniq -c)

if [ -n "$phase_refs" ]; then
    echo "Phase references found:"
    echo "$phase_refs" | sed 's/^/   /'
    
    # Check for invalid phase numbers (>4)
    if grep -r "Phase [5-9]\|phase [5-9]\|phase\.[5-9]" docs/design/ docs/objective/ >/dev/null 2>&1; then
        echo "❌ INVALID PHASE NUMBERS: Found references to phases > 4"
        phase_errors=$((phase_errors + 1))
    fi
else
    echo "✅ Phase references look consistent"
fi

# Check for circular dependencies
echo "Checking for circular dependencies..."
circular_deps=0

# Simple check for circular references between design documents
design_files="container.phase.1 component.phase.1 classes.phase.1 context.phase.1 flow.phase.1"

for file1 in $design_files; do
    for file2 in $design_files; do
        if [ "$file1" != "$file2" ]; then
            # Check if file1 references file2 AND file2 references file1
            if grep -q "$file2" "docs/design/$file1.md" 2>/dev/null && \
               grep -q "$file1" "docs/design/$file2.md" 2>/dev/null; then
                echo "⚠️  POTENTIAL CIRCULAR DEPENDENCY: $file1 ↔ $file2"
                circular_deps=$((circular_deps + 1))
            fi
        fi
    done
done

# Check interface dependency consistency
echo "Checking interface dependency mapping..."
interface_mapping_errors=0

# Check if all levels (container/component/class) are properly referenced
for level in container component classes; do
    if [ -f "docs/design/$level.phase.1.md" ]; then
        # Check if this level references the canonical interfaces
        if ! grep -q "Unified Interface Contracts\|canonical.*interface\|phase\.1\.md" "docs/design/$level.phase.1.md" 2>/dev/null; then
            echo "⚠️  MISSING CANONICAL REFERENCE: $level.phase.1.md should reference canonical interfaces"
            interface_mapping_errors=$((interface_mapping_errors + 1))
        fi
    fi
done

# Summary of findings
echo ""
echo "=== CROSS-REFERENCE VERIFICATION RESULTS ==="

total_issues=$((broken_refs + type_inconsistencies + reference_issues + missing_types + phase_errors + circular_deps + interface_mapping_errors))

echo "📊 Summary:"
echo "   - Broken file references: $broken_refs"
echo "   - Broken section references: $reference_issues"  
echo "   - Type inconsistencies: $type_inconsistencies"
echo "   - Missing type definitions: $missing_types"
echo "   - Phase reference errors: $phase_errors"
echo "   - Circular dependencies: $circular_deps"
echo "   - Interface mapping errors: $interface_mapping_errors"

if [ $total_issues -eq 0 ]; then
    echo ""
    echo "✅ Cross-reference verification PASSED"
    echo "✅ All internal references are valid"
    echo "✅ Type names are consistent across documents"
    echo "✅ Phase references are valid"
    echo "✅ No circular dependencies detected"
    echo "✅ Interface mappings are complete"
    exit 0
else
    echo ""
    echo "❌ Cross-reference verification FAILED"
    echo "❌ Found $total_issues total issues across all categories"
    echo ""
    echo "🔧 Fix Required:"
    echo "   - Fix broken file and section references"
    echo "   - Standardize type names across all documents"
    echo "   - Add missing type definitions"
    echo "   - Ensure phase references are valid (1-4 only)"
    echo "   - Resolve circular dependencies"
    echo "   - Add canonical interface references"
    exit 1
fi 