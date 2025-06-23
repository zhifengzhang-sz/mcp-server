#!/bin/bash
# File: scripts/verify_all.sh
# Purpose: Run comprehensive documentation verification suite

echo "🚀 COMPREHENSIVE DOCUMENTATION VERIFICATION"
echo "=============================================="
echo "Date: $(date)"
echo "Checking: docs/design/*.md and docs/objective/*.md"
echo ""

# Initialize counters
total_checks=0
passed_checks=0
failed_checks=0

# Verification results storage
verification_results=""

# Function to run a verification script and capture results
run_verification() {
    local script_name="$1"
    local script_path="scripts/$script_name"
    local description="$2"
    
    echo "🔍 Running: $description"
    echo "Script: $script_path"
    echo "----------------------------------------"
    
    if [ -f "$script_path" ] && [ -x "$script_path" ]; then
        if "$script_path"; then
            echo "✅ PASSED: $description"
            passed_checks=$((passed_checks + 1))
            verification_results="${verification_results}✅ $description\n"
        else
            echo "❌ FAILED: $description"
            failed_checks=$((failed_checks + 1))
            verification_results="${verification_results}❌ $description\n"
        fi
    else
        echo "⚠️  SKIPPED: $script_path not found or not executable"
        verification_results="${verification_results}⚠️  SKIPPED: $description (script not found)\n"
    fi
    
    total_checks=$((total_checks + 1))
    echo ""
}

# Make sure all scripts are executable
chmod +x scripts/*.sh 2>/dev/null

echo "📋 VERIFICATION SUITE EXECUTION"
echo "================================="

# 1. Language-Agnostic Verification
run_verification "verify_language_agnostic.sh" "Language-Agnostic Requirements"

# 2. Interface Consistency Verification  
run_verification "verify_interface_consistency.sh" "Interface Consistency"

# 3. Cross-Reference Verification
run_verification "verify_cross_references.sh" "Cross-Reference Integrity"

# Manual checks that require human verification
echo "📝 MANUAL VERIFICATION CHECKLIST"
echo "=================================="
echo "The following items require manual verification:"
echo ""

echo "🎯 INTERFACE DEFINITION CLARITY:"
echo "   □ All operations have complete signatures"
echo "   □ All custom types are clearly defined"
echo "   □ Operation semantics are unambiguous"
echo "   □ Error conditions are specified"
echo ""

echo "🏗️ ARCHITECTURAL COHERENCE:"
echo "   □ Functional programming patterns are consistent"
echo "   □ Immutability is preserved throughout"
echo "   □ Plugin extensibility is consistent across levels"
echo "   □ Phase separation is clear and well-defined"
echo ""

echo "📚 DOCUMENTATION COMPLETENESS:"
echo "   □ All design levels (Container/Component/Class) are complete"
echo "   □ All functional areas (Plugin/Context/Tool/Session) are documented"
echo "   □ Extension points for Phases 2-4 are documented"
echo "   □ No missing interface definitions"
echo ""

# Summary Report
echo "==============================================="
echo "🎯 COMPREHENSIVE VERIFICATION SUMMARY"
echo "==============================================="
echo ""

echo "📊 AUTOMATED VERIFICATION RESULTS:"
echo "Total automated checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $failed_checks"
echo ""

if [ $failed_checks -eq 0 ]; then
    echo "🎉 ALL AUTOMATED VERIFICATIONS PASSED!"
    echo ""
    echo "✅ Documentation Quality Status: IMPLEMENTATION-READY"
    echo "✅ Language-Agnostic: All design documents use mathematical notation"
    echo "✅ Interface Consistency: Unified contracts across all levels"
    echo "✅ Cross-References: All internal links and types are consistent"
else
    echo "⚠️  VERIFICATION ISSUES FOUND"
    echo ""
    echo "❌ Documentation Quality Status: NEEDS FIXES"
    echo "Failed verifications:"
    echo -e "$verification_results" | grep "❌"
fi

echo ""
echo "📋 DETAILED RESULTS:"
echo -e "$verification_results"

echo ""
echo "🔧 NEXT STEPS:"
if [ $failed_checks -eq 0 ]; then
    echo "✅ Automated verification complete - proceed with manual checklist"
    echo "✅ Review architectural coherence and documentation completeness"
    echo "✅ Ready to proceed to implementation phase"
else
    echo "❌ Fix automated verification failures first"
    echo "❌ Re-run individual verification scripts to see detailed issues"
    echo "❌ Complete manual checklist after automated fixes"
fi

echo ""
echo "📖 REFERENCE:"
echo "   - Verification Framework: docs/impl/documentation_verification_checklist.md"
echo "   - Individual Scripts: scripts/verify_*.sh"
echo "   - Canonical Interfaces: docs/design/phase.1.md"

echo ""
echo "==============================================="
echo "Verification completed at: $(date)"
echo "==============================================="

# Exit with appropriate code
if [ $failed_checks -eq 0 ]; then
    exit 0
else
    exit 1
fi 