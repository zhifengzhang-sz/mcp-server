# VS Code Git Submodule Setup Guide

## Why Submodule Files Don't Show Git Colors in VS Code

### The Issue
When working with git submodules in VS Code, you may notice that:
- Files in the `qicore-v4` submodule don't show git status colors (modified, added, etc.)
- Only the main repository files show proper git status indication
- The submodule appears as a single "modified" entry in the main repo's git status

### Why This Happens
1. **Separate Git Repositories**: Submodules are independent git repositories
2. **VS Code Git Integration**: Primarily tracks the main repository's git status
3. **Nested Repository Limitation**: VS Code doesn't automatically show nested git status by default

## Solutions

### Option 1: Multi-Root Workspace (Recommended)

**Step 1**: Use the provided workspace configuration
```bash
# Open the workspace file in VS Code
code .vscode/mcp-server.code-workspace
```

**Step 2**: VS Code will show both repositories
- "MCP Server (Main)" - Main repository
- "QICORE-V4 (Submodule)" - Submodule repository

**Benefits**:
- ✅ Git colors work for both repositories
- ✅ Separate git panels for each repository
- ✅ Independent commit/push/pull for each
- ✅ Full git integration for both projects

### Option 2: Open Submodule Separately

**In VS Code**:
1. File → Open Folder
2. Navigate to `qicore-v4` directory
3. Open as separate workspace

**Benefits**:
- ✅ Full git integration for submodule
- ✅ All git colors and status work normally
- ❌ Need to switch between workspaces

### Option 3: Enhanced Git Settings

The `.vscode/settings.json` file has been configured with:
```json
{
    "git.detectSubmodules": true,
    "git.fetchOnPull": true,
    "git.autofetch": true,
    "git.openRepositoryInParentFolders": "always"
}
```

**Benefits**:
- ✅ Better submodule detection
- ✅ Automatic fetching
- ❌ Still limited individual file color indication

## Working with Submodule Changes

### Committing Submodule Changes

**Step 1**: Commit changes in the submodule
```bash
cd qicore-v4
git add .
git commit -m "Update QICORE-V4 contracts and guides"
git push origin main
```

**Step 2**: Update the main repository to reference the new submodule commit
```bash
cd ..  # Back to main repository
git add qicore-v4
git commit -m "Update qicore-v4 submodule to latest version"
git push origin main
```

### Checking Submodule Status

**From main repository**:
```bash
git submodule status
git diff --submodule
```

**From within submodule**:
```bash
cd qicore-v4
git status
git log --oneline -5
```

## VS Code Git Panel Behavior

### What You'll See

**Main Repository Git Panel**:
- Shows `qicore-v4` as a single modified file when submodule has changes
- Individual files in submodule won't show colors in main workspace

**Submodule Git Panel** (in multi-root workspace):
- Shows all individual file changes with proper colors
- Full git integration (staging, committing, pushing)
- Branch management and history

### Best Practices

1. **Use Multi-Root Workspace**: Best overall experience
2. **Commit Submodule First**: Always commit/push submodule changes before updating main repo
3. **Update Main Repo**: After submodule changes, update main repository reference
4. **Check Both Statuses**: Monitor git status in both repositories

## Troubleshooting

### Issue: Submodule Shows as Modified But No Changes Visible
```bash
cd qicore-v4
git status  # Check actual submodule status
```

### Issue: Submodule Not Updating
```bash
git submodule update --remote --merge
```

### Issue: VS Code Not Detecting Submodule
1. Reload VS Code window (Ctrl+Shift+P → "Developer: Reload Window")
2. Check `.vscode/settings.json` has `"git.detectSubmodules": true`
3. Use multi-root workspace configuration

## Recommended Workflow

1. **Open Multi-Root Workspace**: Use `.vscode/mcp-server.code-workspace`
2. **Work on Submodule**: Make changes in QICORE-V4 files
3. **Commit Submodule**: Use the QICORE-V4 git panel to commit/push
4. **Update Main Repo**: Use the main repository git panel to update submodule reference
5. **Push Main Repo**: Commit and push the submodule reference update

This workflow ensures proper git tracking and VS Code integration for both the main project and the QICORE-V4 submodule.

## Quick Reference

| Action | Command | Location |
|--------|---------|----------|
| Open multi-root workspace | `code .vscode/mcp-server.code-workspace` | Project root |
| Check submodule status | `git submodule status` | Main repo |
| Update submodule | `git submodule update --remote` | Main repo |
| Commit submodule changes | `git add . && git commit -m "..."` | Inside qicore-v4/ |
| Update main repo reference | `git add qicore-v4 && git commit -m "..."` | Main repo |

**Result**: Full git integration with proper file colors and status indication for both repositories! 