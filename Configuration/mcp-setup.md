# MCP Server Setup for Auto-Focus

## Overview
Model Context Protocol (MCP) servers provide Claude with enhanced capabilities for interacting with your Auto-Focus project. This setup enables better code analysis, file operations, and Git integration.

## MCP Servers Configuration

### 1. Filesystem Server
Provides direct access to project files for reading, writing, and analysis.

**Capabilities:**
- Read any file in the project
- Write new files
- List directory contents
- Search file contents

### 2. Git Server  
Enables Git repository operations and history analysis.

**Capabilities:**
- View commit history
- Check repository status
- Analyze code changes
- Branch management information

### 3. Time Server
Provides temporal context for operations.

**Capabilities:**
- Current date/time
- Time zone information
- Date calculations

## Setup Instructions

### 1. Copy Configuration
Copy the MCP configuration to Claude Desktop:

```bash
# macOS
cp Configuration/claude-desktop-config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Or manually add to your existing config
```

### 2. Restart Claude Desktop
After adding the configuration, restart Claude Desktop to load the MCP servers.

### 3. Verify Setup
In Claude Desktop, you should see MCP servers listed in the settings or status area.

## Use Cases for Auto-Focus Development

### Code Analysis
- **Architecture Review**: "Analyze the current project structure and suggest improvements"
- **Performance Optimization**: "Review the FocusManager for performance bottlenecks"
- **Security Audit**: "Check for potential security issues in the license validation code"

### File Operations
- **Batch Refactoring**: "Move all license-related files to the new feature structure"
- **Template Generation**: "Create ViewModels for all views missing them"
- **Documentation**: "Generate API documentation for the public interfaces"

### Git Integration
- **Commit Analysis**: "Review the recent commits and suggest areas for improvement"
- **Branch Management**: "Show the differences between feature branches"
- **Release Planning**: "Analyze changes since the last release"

### Development Workflow
- **AI Context Generation**: Use `make ai-context` to create structured context files
- **Automated Refactoring**: Let Claude suggest and implement code improvements
- **Testing Strategy**: Generate comprehensive test plans based on code analysis

## Best Practices

### 1. Structured Queries
When asking Claude to work on the project, provide clear context:

```
"Review the LicenseManager class in Features/LicenseManagement/Services/ and:
1. Add comprehensive error logging
2. Improve error handling
3. Add performance metrics
4. Ensure thread safety"
```

### 2. Incremental Changes
Make small, focused changes that can be easily reviewed and tested.

### 3. Logging Integration
Always ensure new code includes proper logging with AppLogger.

### 4. Test Coverage
Request test coverage analysis and improvements for critical paths.

## Configuration Customization

### Path Configuration
Update the `ROOT_PATH` in the configuration to match your project location:

```json
{
  "mcpServers": {
    "filesystem": {
      "env": {
        "ROOT_PATH": "/your/custom/path/to/auto-focus"
      }
    }
  }
}
```

### Additional Servers
Consider adding other MCP servers based on your needs:

- **Database Server**: If you add Core Data or SQLite
- **Web Server**: For API testing and development
- **Docker Server**: If you containerize the build process

## Troubleshooting

### MCP Servers Not Loading
1. Check the configuration file syntax
2. Verify file paths are correct
3. Ensure Claude Desktop has necessary permissions
4. Restart Claude Desktop after changes

### Permission Issues
1. Ensure Claude Desktop has file system access
2. Check that the project directory is accessible
3. Verify Git repository permissions

### Performance Issues
1. Limit file searches to relevant directories
2. Use specific queries rather than broad analysis
3. Consider excluding build artifacts from searches

## Integration with Makefile

The Makefile includes an `ai-context` target that generates structured context files for Claude:

```bash
make ai-context
```

This creates:
- `Configuration/.claude/swift-context.txt`: All Swift source code
- `Configuration/.claude/structure.txt`: Project structure
- `Configuration/.claude/features.txt`: Feature analysis

These files help Claude understand your project structure and provide better assistance.