# Copilot Instructions for ServerAdvertisements Plugin

## Repository Overview

This repository contains **ServerAdvertisements**, a SourcePawn plugin for SourceMod that provides a comprehensive server advertising/messaging system for Source engine game servers. The plugin allows server administrators to display timed messages to players in various formats (chat, HUD, center text, top menu) with support for multiple languages, map-specific messages, and player flag-based filtering.

## Technical Environment

- **Language**: SourcePawn (.sp files, .inc includes)
- **Platform**: SourceMod 1.11.0+ (Source engine games like CS:GO, CS2, TF2)
- **Build System**: SourceKnight (configured via `sourceknight.yaml`)
- **Compiler**: SourceMod compiler (spcomp) - handles compilation to .smx bytecode
- **CI/CD**: GitHub Actions workflow in `.github/workflows/ci.yml`

## Dependencies

The plugin requires these SourceMod extensions and libraries:
- **sourcemod** (1.11.0-git6906) - Core SourceMod framework
- **multicolors** - Color support for chat messages 
- **smlib** - SourceMod Library with utility functions
- **utilshelper** - Additional utility functions
- Standard includes: `geoip`, `clientprefs`, `sdktools`

Dependencies are automatically handled by SourceKnight during build.

## Project Structure

```
/scripting/
├── ServerAdvertisements.sp          # Main plugin file (395 lines)
└── include/
    ├── globals.inc                  # Global definitions and structs
    ├── client.inc                   # Client-related functions
    └── misc.inc                     # Miscellaneous utility functions

/configs/
└── ServerAdvertisements.cfg         # Plugin configuration file

sourceknight.yaml                    # Build configuration
.github/workflows/ci.yml            # GitHub Actions CI/CD
```

## Key Plugin Features

- **Multi-format messages**: Chat (T), HUD (H), Center Text (C), Top Menu (M)
- **Multi-language support**: Using language codes (EN, CZ, etc.)
- **Map filtering**: Messages for specific maps or map prefixes
- **Player flag filtering**: Admin flags and ignore flags
- **Welcome messages**: Displayed when players connect
- **Timed messages**: Configurable intervals and message groups
- **Text variables**: Dynamic text replacement (e.g., {PLAYERNAME}, {CURRENTMAP})
- **Color support**: Extensive color system via MultiColors

## Plugin Commands

### Admin Commands
- `!SAr` or `sm_SAr` - Reload messages from configuration file (requires ROOT flag)

### Client Commands  
- `!SAlang` or `sm_SAlang` - Change language preference for messages

### ConVars
- `sm_SA_enable` (default: 1) - Enable/Disable ServerAdvertisements plugin

## Code Style & Standards

This codebase follows these SourcePawn conventions:

### Naming Conventions
- **Global variables**: Prefix with `g_` (e.g., `g_cV_Enabled`, `g_hSACustomLanguage`)
- **Function names**: PascalCase (e.g., `OnPluginStart`, `Command_SAr`)
- **Local variables**: camelCase (e.g., `sConfigPath`, `clientLang`)
- **Constants**: ALL_CAPS with underscores (e.g., `PLUGIN_NAME`, `TAG_SIZE`)

### Code Structure
- Always use `#pragma semicolon 1` and `#pragma newdecls required`
- Indentation: 4 spaces (using tabs in IDE)
- Use descriptive variable and function names
- Remove trailing whitespace
- Follow event-based programming model

### Memory Management
- Use `StringMap`/`ArrayList` instead of arrays where appropriate
- Use `delete` for cleanup without null checks (SourcePawn handles null safety)
- Never use `.Clear()` on StringMap/ArrayList - use `delete` and recreate
- Properly handle memory allocation/deallocation

### Best Practices
- Implement error handling for all API calls
- Use translation files for user-facing messages
- Avoid hardcoded values - use configuration files
- Use methodmaps for native functions
- All SQL queries must be asynchronous (if applicable)
- Use transactions in SQL when needed

## Building and Testing

### Local Development Build
```bash
# SourceKnight handles all dependencies and compilation
# The build system uses Docker and is configured via sourceknight.yaml
# If you have SourceKnight installed locally:
sourceknight build

# Alternative: Use the same build process as GitHub Actions
# This uses the maxime1907/action-sourceknight Docker action
docker run --rm -v $(pwd):/workspace sourceknight/build
```

### GitHub Actions Build
The repository uses GitHub Actions for CI/CD:
- Builds automatically on push/PR using `maxime1907/action-sourceknight@v1`
- Creates packages with both plugin and config files
- Generates releases with downloadable tar.gz archives

### File Locations After Build
- Compiled plugin: `.sourceknight/package/common/addons/sourcemod/plugins/ServerAdvertisements.smx`
- Config files: `configs/ServerAdvertisements.cfg` → copies to package structure
- Include files: All dependencies are automatically resolved by SourceKnight

### Auto-Generated Config
The plugin creates a ConVar config file automatically:
- Generated: `cfg/sourcemod/ServerAdvertisements.cfg` (contains ConVars)
- Manual config: `configs/ServerAdvertisements.cfg` (contains messages and settings)

### Testing
- Deploy to a SourceMod development server
- Test with various game modes and maps
- Verify multi-language functionality
- Check memory usage with SourceMod profiler
- Test all message types (T, H, C, M)

## Configuration

The main configuration file (`configs/ServerAdvertisements.cfg`) uses KeyValues format:

```
"ServerAdvertisements"
{
    "Settings"
    {
        "ServerName"        "[SERVER]"
        "Time"              "30.0"
        "Languages"         "EN;CZ"
        // ... more settings
    }
    "Messages"
    {
        "1"
        {
            "enabled"       "1"
            "maps"          "all"
            "type"          "T"
            "en"            "Message text"
            // ... per message config
        }
    }
}
```

## Text Variables System

The plugin supports dynamic text replacement:
- `{PLAYERNAME}`, `{CURRENTMAP}`, `{NEXTMAP}`
- `{PLAYERCOUNT}`, `{ADMINSONLINE}`, `{VIPONLINE}`
- `{SERVERIP}`, `{SERVERNAME}`, `{CURRENTTIME}`
- `{STEAMID}`, `{TIMELEFT}`, `{CURRENTDATE}`
- `{CONVAR}` - Any ConVar value (e.g., `{mp_friendlyfire}`)

## Common Development Tasks

### Adding New Message Types
1. Extend the message type enum in `globals.inc`
2. Add handling logic in the message display functions
3. Update configuration documentation

### Adding New Text Variables
1. Add variable parsing in the text replacement function
2. Update documentation with new variable syntax
3. Test with various message types

### Debugging
- Use `LogError()` for error messages
- Enable "Log expired messages" in config for debugging
- Check SourceMod error logs
- Use SourceMod's built-in profiler for performance issues

## Version Control

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Update `PLUGIN_VERSION` in `globals.inc`
- Commit messages should clearly describe changes
- Keep plugin versions synchronized with repository tags

## Common Pitfalls to Avoid

1. **Memory leaks**: Never use `.Clear()` on StringMap/ArrayList
2. **Hardcoded strings**: Use translation system for user messages
3. **Blocking operations**: Keep operations non-blocking for server performance
4. **Invalid clients**: Always validate client indices with `IsClientValid()`
5. **Color syntax**: Ensure color tags match the target game's support
6. **Configuration syntax**: KeyValues format is sensitive to brackets and quotes

## Performance Considerations

- Minimize operations in frequently called functions (OnGameFrame, etc.)
- Cache expensive operations (string parsing, calculations)
- Be mindful of timer usage - avoid excessive timers
- Consider impact on server tick rate
- Use efficient data structures (StringMap for lookups)
- Optimize from O(n) to O(1) complexity where possible

## Testing Checklist

When making changes, verify:
- [ ] Plugin compiles without errors/warnings
- [ ] All message types display correctly
- [ ] Multi-language functionality works
- [ ] Map filtering works as expected
- [ ] Admin flag filtering works correctly
- [ ] Welcome messages display properly
- [ ] Text variables are replaced correctly
- [ ] No memory leaks detected
- [ ] Performance impact is minimal
- [ ] Configuration file syntax is valid

## Release Process

1. Update version in `globals.inc`
2. Test thoroughly on development server
3. Commit changes with descriptive message
4. Tag release with version number
5. GitHub Actions automatically builds and releases
6. Verify release artifacts include all necessary files

## Additional Resources

- [SourceMod Scripting Documentation](https://wiki.alliedmods.net/Category:SourceMod_Scripting)
- [SourcePawn Language Reference](https://wiki.alliedmods.net/Category:SourcePawn)
- [Plugin Thread](https://forums.alliedmods.net/showthread.php?t=248314)
- [MultiColors Documentation](https://github.com/srcdslab/sm-plugin-MultiColors)