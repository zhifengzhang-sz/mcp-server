#!/bin/bash

# Comprehensive commit for documentation alignment and methodology breakthrough

echo "🚀 Committing Development Methodology Documentation & Package Research..."
echo "📝 Excluding: docs/impl/ (work-in-progress implementation details)"
echo "🔗 Handling: qicore-v4 submodule separately"
echo ""

# First, commit changes in qicore-v4 submodule
echo "📦 Step 1: Committing qicore-v4 submodule changes..."
cd qicore-v4

# Check if there are changes in qicore-v4
if [[ -n $(git status --porcelain) ]]; then
    echo "✅ Found changes in qicore-v4, committing..."
    git add -A
    git commit -m "feat: Complete QICORE-V4 Methodology with Package Research Integration

Added missing Stage 3 in QICORE-V4 methodology that bridges objective contracts 
to language-specific implementation through systematic package research.

🎯 METHODOLOGY COMPLETION:
- NEW: Stage 3 Package Research Methodology (guides/package-research-methodology.md)
- Enhanced: 4-stage complete process (guides/guide.md)
- Added: Language-specific implementation with package research integration
- Complete: Theoretical → Practical transformation methodology

📊 KEY INSIGHT:
- Bridge gap between mathematical contracts and actual implementation
- Systematic package research → wrapper design methodology
- Production-ready transformation from objectives to working code

Files Added/Modified:
- guides/package-research-methodology.md (NEW: Stage 3 methodology)

- guides/guide.md (Enhanced: 4-stage complete process)

STATUS: QICORE-V4 methodology complete, ready for practical use"
    
    echo "✅ qicore-v4 changes committed successfully!"
else
    echo "ℹ️  No changes in qicore-v4 submodule"
fi

# Return to main repository
cd ..

echo ""
echo "📦 Step 2: Committing main repository changes..."

# Stage ALL changes
git add .

# Now selectively unstage only the docs/impl directory
git restore --staged docs/impl/

# Check what will be committed (should see all our changes except docs/impl)
git status

# Check specifically what files are staged
git diff --cached --name-only

# Commit all the staged changes
git commit -m "feat: Documentation alignment and VS Code submodule setup

- Updated package references: FastMCP → Official MCP SDK, Click → typer  
- Added dependencies: typer>=0.12.0, jinja2>=3.1.2 to pyproject.toml
- Fixed VS Code git submodule integration (.vscode/*)
- Updated all setup guides for git submodule workflow
- Added comprehensive package research documentation
- Updated qicore-v4 submodule reference

EXCLUDED: docs/impl/ (work-in-progress)
STATUS: Ready for Phase 1 implementation"

echo "✅ Main repository commit completed successfully!"
echo ""
echo "📋 Summary of changes committed:"
echo "- qicore-v4 submodule: Package research methodology completed"
echo "- Main repository: 18+ documentation files updated and aligned"
echo "- Development methodology documented for systematic approach"
echo "- VS Code git submodule integration fixed"
echo "- Complete package research validation"
echo "- Ready for Phase 1 implementation"
echo ""
echo "🚫 Excluded from main repository commit:"
echo "- docs/impl/ (work-in-progress implementation details)"
echo ""
echo "🎯 Next step: Actually implement Phase 1 MCP Server (the real work!)" 