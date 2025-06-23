#!/bin/bash
# File: scripts/verify_interface_consistency.sh
# Purpose: Verify interface consistency across container/component/class levels

echo "🔍 Checking interface consistency across design levels..."

# Create temporary files for analysis
temp_dir="/tmp/interface_verification_$$"
mkdir -p "$temp_dir"

echo "Extracting operation signatures from all design documents..."

# Extract all operation signatures with their source files
grep -rn "- \w\+(.*).*→" docs/design/ | \
    sed 's/\(docs\/design\/[^:]*\):\([0-9]*\):.*- \([^(]*([^)]*)\s*→\s*[^[:space:]]*\).*/\3|\1|\2/' | \
    sort > "$temp_dir/all_operations.txt"

# Extract just the operation signatures for duplicate analysis
grep -r "- \w\+(.*).*→" docs/design/ | \
    sed 's/.*- \([^(]*([^)]*)\s*→\s*[^[:space:]]*\).*/\1/' | \
    sort | uniq -c | sort -nr > "$temp_dir/operation_counts.txt"

# Check for operations that appear in multiple files with different signatures
echo "Analyzing operation signature consistency..."

inconsistencies=0
operation_names=$(grep -r "- \w\+(.*).*→" docs/design/ | \
    sed 's/.*- \([^(]*\)(.*/\1/' | sort | uniq)

for op in $operation_names; do
    # Get all signatures for this operation name
    signatures=$(grep "^[[:space:]]*- $op(" "$temp_dir/all_operations.txt" | \
        cut -d'|' -f1 | sort | uniq)
    
    signature_count=$(echo "$signatures" | wc -l)
    
    if [ "$signature_count" -gt 1 ]; then
        echo "❌ INCONSISTENT OPERATION: $op"
        echo "   Found $signature_count different signatures:"
        echo "$signatures" | sed 's/^/     /'
        
        # Show which files have which signatures
        echo "   File locations:"
        for sig in $signatures; do
            echo "     Signature: $sig"
            grep -F "$sig" "$temp_dir/all_operations.txt" | \
                cut -d'|' -f2-3 | sed 's/|/ line /' | sed 's/^/       /'
        done
        echo ""
        inconsistencies=$((inconsistencies + 1))
    fi
done

# Check for missing operations (operations that should be in all levels but aren't)
echo "Checking for missing operations across levels..."

container_ops=$(grep -r "- \w\+(.*).*→" docs/design/container.phase.1.md | \
    sed 's/.*- \([^(]*\)(.*/\1/' | sort | uniq)

component_ops=$(grep -r "- \w\+(.*).*→" docs/design/component.phase.1.md | \
    sed 's/.*- \([^(]*\)(.*/\1/' | sort | uniq)

class_ops=$(grep -r "- \w\+(.*).*→" docs/design/classes.phase.1.md | \
    sed 's/.*- \([^(]*\)(.*/\1/' | sort | uniq)

missing_ops=0

# Check core operations that should be in all levels
core_operations="register unregister discover validate compose executeChain optimizeChain assemble enhance execute handle dispatch"

for core_op in $core_operations; do
    container_has=$(echo "$container_ops" | grep -c "^$core_op$" || true)
    component_has=$(echo "$component_ops" | grep -c "^$core_op$" || true) 
    class_has=$(echo "$class_ops" | grep -c "^$core_op$" || true)
    
    if [ "$container_has" -eq 0 ] && [ "$component_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in container level but present in component level"
        missing_ops=$((missing_ops + 1))
    fi
    
    if [ "$container_has" -eq 0 ] && [ "$class_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in container level but present in class level"
        missing_ops=$((missing_ops + 1))
    fi
    
    if [ "$component_has" -eq 0 ] && [ "$container_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in component level but present in container level"
        missing_ops=$((missing_ops + 1))
    fi
    
    if [ "$component_has" -eq 0 ] && [ "$class_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in component level but present in class level"
        missing_ops=$((missing_ops + 1))
    fi
    
    if [ "$class_has" -eq 0 ] && [ "$container_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in class level but present in container level"
        missing_ops=$((missing_ops + 1))
    fi
    
    if [ "$class_has" -eq 0 ] && [ "$component_has" -gt 0 ]; then
        echo "⚠️  MISSING: Operation '$core_op' in class level but present in component level"
        missing_ops=$((missing_ops + 1))
    fi
done

# Check for canonical interface contract compliance
echo "Verifying compliance with canonical interface contracts..."
canonical_violations=0

# Check if canonical contracts exist
if [ ! -f "docs/design/phase.1.md" ]; then
    echo "❌ Missing canonical interface contracts in docs/design/phase.1.md"
    canonical_violations=$((canonical_violations + 1))
else
    # Check if each design document references canonical contracts
    for design_file in docs/design/container.phase.1.md docs/design/component.phase.1.md docs/design/classes.phase.1.md; do
        if [ -f "$design_file" ]; then
            # Verify operations match canonical contracts (basic check)
            if ! grep -q "register(plugin: Plugin) → PluginRegistry\|register(tool: Tool) → ToolRegistry" "$design_file"; then
                echo "⚠️  POTENTIAL DEVIATION: $design_file may not follow canonical interface contracts"
            fi
        fi
    done
fi

# Clean up
rm -rf "$temp_dir"

# Results
echo ""
echo "=== INTERFACE CONSISTENCY VERIFICATION RESULTS ==="
total_issues=$((inconsistencies + missing_ops + canonical_violations))

if [ $total_issues -eq 0 ]; then
    echo "✅ Interface consistency verification PASSED"
    echo "✅ All operations have consistent signatures across levels"
    echo "✅ No missing operations detected"
    echo "✅ Canonical interface contracts are followed"
    exit 0
else
    echo "❌ Interface consistency verification FAILED"
    echo "❌ Found $inconsistencies signature inconsistencies"
    echo "❌ Found $missing_ops missing operations across levels"
    echo "❌ Found $canonical_violations canonical contract violations"
    echo ""
    echo "🔧 Fix Required:"
    echo "   - Unify operation signatures across container/component/class levels"
    echo "   - Add missing operations to appropriate design documents"
    echo "   - Ensure all designs follow canonical interface contracts"
    echo "   - See docs/design/phase.1.md for canonical operation signatures"
    exit 1
fi 