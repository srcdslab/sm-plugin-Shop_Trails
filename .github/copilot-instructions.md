# Copilot Instructions for Shop_Trails SourceMod Plugin

## Repository Overview
This repository contains a SourceMod plugin that adds trail effects to the Shop system for Source engine games. The plugin allows players to purchase and equip various trail effects that follow them in-game, integrating with multiple shop systems and other plugins.

**Key Information:**
- **Language**: SourcePawn
- **Plugin Type**: Shop module/addon  
- **Current Version**: 2.2.3
- **SourceMod Version**: 1.12+ (builds with 1.11.0-git6917)
- **Dependencies**: Shop-Core, MultiColors, optional ZombieReloaded/ZRiot/ToggleEffects

## Project Structure

```
/addons/sourcemod/
├── scripting/
│   └── Shop_Trails.sp          # Main plugin source (504 lines)
└── configs/shop/
    ├── trails.txt              # Trail definitions and prices
    └── trails_dlist.txt        # Download list for materials
/materials/sprites/             # Trail material files
/.github/workflows/ci.yml       # GitHub Actions CI/CD
/sourceknight.yaml             # Build configuration
```

## Build System & Development Environment

### Build Tool: SourceKnight
This project uses **sourceknight** (modern SourceMod build system) with Docker:

```bash
# Install sourceknight (if not available)
pip install sourceknight

# Build the plugin
sourceknight build

# Output location: .sourceknight/package/
```

### Dependencies Management
Dependencies are automatically managed through `sourceknight.yaml`:
- **sourcemod**: Core SourceMod framework (v1.11.0-git6917)
- **multicolors**: Chat color library
- **shop**: Shop-Core system (required)
- **zombiereloaded**: Optional ZR integration  
- **toggleeffects**: Optional special effects integration

### CI/CD Pipeline
- **Trigger**: Push, PR, manual dispatch
- **Build**: Ubuntu 24.04 with sourceknight action
- **Package**: Includes configs and materials
- **Release**: Auto-release on master/main, tagged releases

## Code Architecture & Patterns

### Plugin Structure
```sourcepawn
// Standard SourceMod plugin structure
#pragma semicolon 1
#pragma newdecls required

// Core includes + dependencies
#include <sourcemod>
#include <shop>
#include <multicolors>

// Optional plugin integrations
#tryinclude <zombiereloaded>
#tryinclude <ToggleEffects>
```

### Key Components
1. **Client Preferences**: Uses cookies for trail visibility settings
2. **Shop Integration**: Implements shop category "trails"
3. **Material Management**: Precaches and downloads trail materials
4. **Effect Rendering**: Creates and manages trail entities
5. **Multi-plugin Support**: Optional integration with ZR/ZRiot/ToggleEffects

### Global Variables Pattern
```sourcepawn
Handle g_hCookie;                    // Client preferences
bool g_bShouldSee[MAXPLAYERS + 1];   // Visibility per client
int g_SpriteModel[MAXPLAYERS + 1];   // Trail model per client
ItemId selected_id[MAXPLAYERS+1];    // Selected trail per client
```

## Configuration Files

### trails.txt Format
```
"Trails" {
    "trail_name" {
        "price"        "1000"
        "material"     "materials/sprites/trails/blue.vmt"
        "color"        "255 255 255"
        "startwidth"   "25"
        "endwidth"     "15"
        "name"         "Display Name"
        "sell_price"   "250"
        "duration"     "0"
        "lifetime"     "2.000000"
        "position"     "0.0 0.0 10.0"
    }
}
```

### trails_dlist.txt
Simple text file listing materials for download:
```
materials/sprites/trails/blue.vmt
materials/sprites/trails/blue.vtf
```

## Coding Standards & Best Practices

### SourcePawn Style Guide
- **Indentation**: Tabs (4 spaces)
- **Variables**: camelCase for local, PascalCase for functions
- **Globals**: Prefix with "g_" 
- **Pragmas**: Always use `#pragma semicolon 1` and `#pragma newdecls required`
- **Comments**: Minimal, descriptive function documentation only

### Handle Management
```sourcepawn
// CORRECT: Direct delete, no null check needed
delete hKvTrails;

// CORRECT: For StringMap/ArrayList - delete and recreate
delete g_trailMap;
g_trailMap = new StringMap();

// AVOID: .Clear() creates memory leaks
// g_trailMap.Clear(); // DON'T USE
```

### Shop Integration Pattern
```sourcepawn
public void Shop_Started() {
    // Register shop category
    Shop_RegisterCategory(CATEGORY, CategorySelected, CategoryDisplay);
}

bool CategorySelected(int client, CategoryId category, ItemId item) {
    // Handle item selection
}

void CategoryDisplay(int client, CategoryId category, char[] buffer, int maxlength) {
    // Display category info
}
```

### Client State Management
```sourcepawn
public void OnClientDisconnect(int client) {
    // Save preferences
    SetCookieBool(client, g_hCookie, g_bShouldSee[client]);
    
    // Reset state
    g_bShouldSee[client] = true;
    KillTrail(client);
}
```

## Testing & Validation

### Manual Testing Checklist
1. **Build Verification**: `sourceknight build` succeeds
2. **Plugin Loading**: No errors in SourceMod logs
3. **Shop Integration**: Trail category appears in shop menu
4. **Trail Effects**: Trails render correctly in-game
5. **Preferences**: Visibility toggle works
6. **Multi-plugin**: ZR/ZRiot compatibility (if applicable)

### Common Issues
- **Missing Materials**: Ensure trails_dlist.txt includes all required files
- **Handle Leaks**: Use `delete` instead of `.Clear()` for collections
- **Shop Dependency**: Plugin requires Shop-Core to be loaded first
- **Late Loading**: Plugin handles late loading via `g_bLate` flag

## Development Workflow

### Making Changes
1. **Edit Source**: Modify `Shop_Trails.sp`
2. **Update Config**: Add new trails to `trails.txt` if needed
3. **Add Materials**: Update `trails_dlist.txt` for new materials
4. **Build**: `sourceknight build`
5. **Test**: Deploy to test server
6. **Commit**: Use semantic versioning in commits

### Adding New Trails
1. Add material files to `/materials/sprites/trails/`
2. Add trail definition to `configs/shop/trails.txt`
3. Add material paths to `configs/shop/trails_dlist.txt`
4. No code changes needed for basic trails

### Plugin Integration
```sourcepawn
// Optional plugin detection
#tryinclude <pluginname>

// Check availability
public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "pluginname")) {
        // Enable integration
    }
}
```

## Performance Considerations
- **Timer Usage**: Minimize timers, use events where possible
- **String Operations**: Cache results, avoid repeated operations
- **Loop Optimization**: Use early breaks and efficient algorithms
- **Memory Management**: Proper handle cleanup prevents leaks
- **Server Tick**: Consider impact on server performance

## Version Control
- **Versioning**: Update version in plugin info block
- **Releases**: Tags trigger automated releases
- **Branches**: Use feature branches for new development
- **CI**: All PRs run through automated build verification

## Troubleshooting

### Common Build Issues
- **Missing Dependencies**: Check `sourceknight.yaml` dependencies
- **Include Errors**: Verify include files are available
- **Syntax Errors**: Use SourceMod compiler error messages

### Runtime Issues
- **Plugin Fails to Load**: Check SourceMod error logs
- **Shop Integration**: Verify Shop-Core is loaded and running
- **Material Issues**: Check server console for missing materials
- **Client Crashes**: Review trail rendering parameters

---

**Note**: This plugin is part of the srcdslab ecosystem. Follow repository conventions and maintain compatibility with other shop modules.