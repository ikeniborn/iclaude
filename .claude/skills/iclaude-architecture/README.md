# iclaude-architecture Skill

Internal architecture and function reference for iclaude.sh bash wrapper script.

## Purpose

This skill provides comprehensive documentation of iclaude.sh's internal architecture, including:
- 8 main functional components with line number references
- 9 critical functions with implementation details
- JSON schemas for component and module specification
- 3 detailed examples demonstrating usage patterns

## Structure

```
iclaude-architecture/
├── SKILL.md                      # Main skill file (auto-loaded by Explore agent)
├── README.md                     # This file
├── templates/
│   └── component-spec.json       # JSON schema for component documentation
├── schemas/
│   └── module-schema.json        # JSON schema for module organization
└── examples/
    ├── proxy-management.md       # Proxy Management component example
    ├── isolated-environment.md   # Isolated Environment component example
    └── version-management.md     # Version Management component example
```

## Main Components

1. **Proxy Management** (iclaude.sh:1343-1666)
   - Proxy URL validation, credential storage, domain resolution
   - Functions: `save_credentials`, `load_credentials`, `configure_proxy_from_url`

2. **Isolated Environment** (iclaude.sh:361-978)
   - Portable NVM+Node.js+Claude installation in `.nvm-isolated/`
   - Functions: `setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`

3. **Version Management** (iclaude.sh:616-768)
   - Lockfile-based version tracking for reproducibility
   - Functions: `save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`

4. **Configuration Isolation** (iclaude.sh:1099-1341)
   - Separate Claude Code state between installations
   - Functions: `setup_isolated_config`, `check_config_status`, `export_config`

5. **NVM Detection** (iclaude.sh:200-318)
   - Binary detection across multiple installation modes
   - Functions: `detect_nvm`, `get_nvm_claude_path`

6. **Update Management** (iclaude.sh:529-2389)
   - Safe updates with temporary artifact cleanup
   - Functions: `update_isolated_claude`, `cleanup_old_claude_installations`

7. **OAuth Token Management** (iclaude.sh:2749-2874)
   - Automatic token validation and refresh
   - Functions: `check_oauth_token`, `refresh_oauth_token`

8. **Router Management** (iclaude.sh:324-379, 584-637, 1333-1430)
   - Alternative LLM provider integration
   - Functions: `detect_router`, `install_isolated_router`, `check_router_status`

## Critical Functions

### Proxy
- `validate_proxy_url()` - iclaude.sh:56
- `resolve_domain_to_ip()` - iclaude.sh:110

### Environment
- `get_nvm_claude_path()` - iclaude.sh:234
- `repair_isolated_environment()` - iclaude.sh:812

### Versioning
- `save_isolated_lockfile()` - iclaude.sh:616

### Router
- `detect_router()` - iclaude.sh:324
- `get_router_path()` - iclaude.sh:355
- `install_isolated_router()` - iclaude.sh:584
- `check_router_status()` - iclaude.sh:1333

## Usage

This skill is **not user-invocable** (user-invocable: false). It is automatically loaded by the **Explore agent** when analyzing iclaude.sh architecture.

### When This Skill Activates

The Explore agent uses this skill when:
- Investigating iclaude.sh code structure
- Understanding component relationships
- Looking up function implementations
- Debugging integration issues

### Quick Reference

```bash
# Component locations in iclaude.sh
Proxy Management:       lines 1343-1666
Isolated Environment:   lines 361-978
Version Management:     lines 616-768
Configuration:          lines 1099-1341
NVM Detection:          lines 200-318
Update Management:      lines 529-2389
OAuth Token:            lines 2749-2874
Router Management:      lines 324-379, 584-637, 1333-1430

# Critical functions
validate_proxy_url():           line 56
resolve_domain_to_ip():         line 110
get_nvm_claude_path():          line 234
repair_isolated_environment():  line 812
save_isolated_lockfile():       line 616
detect_router():                line 324
get_router_path():              line 355
install_isolated_router():      line 584
check_router_status():          line 1333
```

## JSON Schemas

### component-spec.json

Use this schema to document new components added to iclaude.sh:

```json
{
  "name": "Component Name",
  "location": "iclaude.sh:start-end",
  "purpose": "High-level description",
  "keyFeatures": ["feature1", "feature2"],
  "functions": ["function1", "function2"],
  "dependencies": ["component1"],
  "environmentVariables": [
    {
      "name": "VAR_NAME",
      "purpose": "What it configures",
      "example": "value"
    }
  ]
}
```

### module-schema.json

Use this schema to organize modules and their relationships:

```json
{
  "module": "ModuleName",
  "version": "1.0.0",
  "components": [
    {
      "name": "ComponentName",
      "functions": [
        {
          "name": "function_name",
          "line": 123,
          "returnValues": [
            {"code": 0, "meaning": "success"}
          ]
        }
      ]
    }
  ],
  "interfaces": [
    {
      "from": "ComponentA",
      "to": "ComponentB",
      "type": "function_call"
    }
  ]
}
```

## Examples

### Proxy Management Example

See `examples/proxy-management.md` for:
- Proxy URL validation workflow
- Credential storage and loading
- Domain resolution (HTTP vs HTTPS)
- Integration with OAuth and Router
- Security considerations
- Troubleshooting guide

### Isolated Environment Example

See `examples/isolated-environment.md` for:
- Directory structure and symlinks
- Installation and repair workflows
- Team setup and reproducibility
- Portability considerations
- Git-friendly structure

### Version Management Example

See `examples/version-management.md` for:
- Lockfile format and generation
- Version detection methods
- Installation from lockfile
- Update workflows
- CI/CD integration
- Rollback strategies

## Related Skills

- **iclaude-commands** - CLI command reference for iclaude.sh
- **iclaude-best-practices** - Development guidelines and common pitfalls
- **iclaude-validation** - Multi-perspective analysis and validation
- **bash-development** - Bash refactoring patterns
- **structured-planning** - Task decomposition

## Maintenance

### Updating Component Documentation

When modifying iclaude.sh components:

1. Update line numbers in SKILL.md
2. Add new functions to appropriate component section
3. Update examples if workflow changes
4. Regenerate JSON schemas if structure changes

### Adding New Components

1. Document in SKILL.md Main Components section
2. Create example file in `examples/`
3. Update this README
4. Follow component-spec.json schema

## References

- Main script: `/home/ikeniborn/Documents/Project/iclaude/iclaude.sh`
- Full documentation: `.nvm-isolated/.claude-isolated/CLAUDE.md`
- Lockfile: `.nvm-isolated-lockfile.json`

## Version

**Version**: 1.0.0
**Last Updated**: 2026-02-12
**Lines**: 1,664 total across 6 files
