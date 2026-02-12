# iclaude.sh Modular Architecture

## Overview

This directory contains the modularized implementation of iclaude.sh. The monolithic script (~8,195 lines, 129 target functions) has been refactored into 44 specialized modules with clear boundaries of responsibility.

## Modularization Progress

**Current Status:** 86.5% Complete (Phase 0-11)

- **47 modules** created across 16 categories
- **105 functions** extracted from monolith
- **7,093 lines** moved to dedicated modules (of 8,195 total)
- **88 guard patterns** prevent conflicts with legacy code

**Migration Status:** Phase 0-11 complete (Loop Mode - Task Loading ✅)

**Current Version:** 3.3 (Modular Architecture - Phase 0-11)

---

## Directory Structure

```
lib/
├── core/                      # ✅ Phase 0 - Infrastructure (COMPLETE)
│   ├── init.sh                # Constants, environment initialization
│   ├── logging.sh             # Colored output (print_info/success/warning/error)
│   ├── validation.sh          # validate_dependency(), validate_file_exists()
│   └── json.sh                # get_lockfile_field(), set_lockfile_field()
│
├── proxy/                     # ✅ Phase 2 - Proxy management (COMPLETE)
│   ├── validate.sh            # validate_proxy_url(), resolve_domain_to_ip()
│   ├── credentials.sh         # save/load credentials
│   ├── configure.sh           # configure_proxy_from_url(), test_proxy()
│   └── git.sh                 # Git proxy backup/restore
│
├── nvm/                       # 🔜 Phase 3 - NVM environment (PLANNED)
│   ├── detect.sh              # detect_nvm(), get_nvm_claude_path()
│   ├── setup.sh               # setup_isolated_nvm()
│   ├── install.sh             # install_isolated_nvm(), install_npm_package_with_lockfile()
│   ├── claude.sh              # install/update Claude Code
│   ├── repair.sh              # repair_isolated_environment()
│   └── cleanup.sh             # cleanup_isolated_nvm()
│
├── lockfile/                  # 🔜 Phase 4 - Version management (PLANNED)
│   ├── save.sh                # save_isolated_lockfile()
│   ├── load.sh                # install_from_lockfile()
│   └── validate.sh            # validate_lockfile()
│
├── config/                    # 🔜 Phase 5 - Configuration (PLANNED)
│   ├── detect.sh              # get_config_dir()
│   ├── setup.sh               # setup_isolated_config()
│   └── migrate.sh             # export/import config
│
├── oauth/                     # 🔜 Phase 5 - OAuth tokens (PLANNED)
│   ├── check.sh               # check_oauth_token()
│   └── refresh.sh             # refresh_oauth_token()
│
├── router/                    # 🔜 Phase 5 - Router integration (PLANNED)
│   ├── detect.sh              # detect_router()
│   ├── install.sh             # install_isolated_router()
│   └── status.sh              # check_router_status()
│
├── lsp/                       # 🔜 Phase 5 - LSP servers (PLANNED)
│   ├── detect.sh              # detect_lsp_server()
│   ├── install.sh             # install_isolated_lsp_servers()
│   └── status.sh              # check_lsp_status()
│
├── statusline/                # 🔜 Phase 5 - Status line (PLANNED)
│   ├── detect.sh              # detect_statusline()
│   ├── install.sh             # install_statusline_script()
│   └── configure.sh           # configure_statusline_in_settings()
│
├── ohmyposh/                  # 🔜 Phase 5 - Oh My Posh (PLANNED)
│   ├── detect.sh              # detect_ohmyposh()
│   ├── install.sh             # install_isolated_ohmyposh()
│   └── status.sh              # check_ohmyposh_status()
│
├── sandbox/                   # 🔜 Phase 5 - Sandboxing (PLANNED)
│   ├── detect.sh              # detect_sandbox_platform()
│   ├── install.sh             # install_sandbox_dependencies()
│   └── status.sh              # check_sandbox_status()
│
├── gh/                        # 🔜 Phase 5 - GitHub CLI (PLANNED)
│   ├── detect.sh              # detect_gh_cli()
│   ├── install.sh             # install_isolated_gh()
│   └── status.sh              # check_gh_status()
│
├── loop/                      # 🔜 Phase 6 - Loop/Task mode (PLANNED)
│   ├── parser.sh              # load_markdown_task()
│   ├── validator.sh           # validate_task_file_format()
│   ├── executor.sh            # execute_task_with_retry()
│   ├── retry.sh               # retry_task_with_backoff()
│   ├── git.sh                 # git_commit_task_changes()
│   └── state.sh               # save/load loop state
│
├── context/                   # 🔜 Phase 7 - Context management (PLANNED)
│   ├── init.sh                # init_context_directories()
│   ├── export.sh              # context_cmd_export()
│   ├── import.sh              # context_cmd_import()
│   ├── sync.sh                # context_cmd_sync()
│   ├── clean.sh               # context_cmd_clean()
│   ├── backup.sh              # context_cmd_backup()
│   ├── status.sh              # context_cmd_status()
│   └── memory.sh              # context_memory_*()
│
├── update/                    # 🔜 Phase 8 - Update management (PLANNED)
│   ├── check.sh               # check_claude_version()
│   ├── update.sh              # update_isolated_claude()
│   └── cleanup.sh             # cleanup_old_claude_installations()
│
├── autoupdates/               # 🔜 Phase 8 - Auto-updates control (PLANNED)
│   ├── detect.sh              # get_autoupdate_status()
│   └── disable.sh             # disable_auto_updates()
│
└── launcher/                  # 🔜 Phase 8 - Launch logic (PLANNED)
    ├── detect.sh              # get_launch_binary()
    ├── launch.sh              # launch_claude()
    └── args.sh                # process_claude_args()
```

---

## Phase 0: Infrastructure (COMPLETE ✅)

### Created Modules

**lib/core/init.sh**
- `init_environment()` - Initialize all environment variables
- `resolve_script_directory()` - Resolve SCRIPT_DIR (follows symlinks)
- Exports: `SCRIPT_DIR`, `CREDENTIALS_FILE`, `ISOLATED_NVM_DIR`, `ISOLATED_LOCKFILE`, etc.

**lib/core/logging.sh**
- `print_info(msg)` - Print blue info message
- `print_success(msg)` - Print green success message
- `print_warning(msg)` - Print yellow warning message
- `print_error(msg)` - Print red error message

**lib/core/validation.sh**
- `validate_dependency "cmd" "install_hint"` - Check if command exists (replaces 7+ `jq` checks)
- `validate_file_exists "path"` - Check if file exists
- `validate_directory_exists "path"` - Check if directory exists

**lib/core/json.sh**
- `get_lockfile_field "field_path"` - Read field from lockfile (replaces 15+ `jq` calls)
- `set_lockfile_field "field_path" "value"` - Write field to lockfile
- `get_lockfile_object "field_path"` - Read nested object from lockfile

### Benefits Achieved

✅ **Code duplication reduced by 70%**
- 7+ `jq` validation checks → 1 function `validate_dependency()`
- 15+ `jq` lockfile reads → 1 function `get_lockfile_field()`

✅ **100% backward compatibility**
- All regression tests pass
- Legacy implementation (`iclaude-legacy.sh`) uses core modules
- No breaking changes

✅ **Modular foundation**
- Clear module boundaries
- Consistent error handling
- Reusable utilities for Phase 1-9

---

## Phase 2: Proxy Module (COMPLETE ✅)

### Created Modules

**lib/proxy/validate.sh**
- `validate_proxy_url(url)` - Validate format, return 0 (valid IP), 1 (invalid), 2 (domain)
- `is_ip_address(host)` - Check if host is valid IPv4
- `resolve_domain_to_ip(domain)` - DNS resolution fallback chain (getent→host→dig→nslookup)
- `parse_proxy_url(url)` - Extract protocol/username/password/host/port

**lib/proxy/credentials.sh**
- `save_credentials(url, no_proxy)` - Save to file (chmod 600), handle domain→IP conversion
- `load_credentials()` - Load from file, return "URL|NO_PROXY"
- `clear_credentials()` - Delete credentials file
- `prompt_proxy_url()` - Interactive prompt with validation

**lib/proxy/configure.sh**
- `configure_proxy_from_url(url, no_proxy)` - Set env vars (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
- `configure_git_no_proxy()` - Configure git to respect NO_PROXY
- `display_proxy_info(show_password)` - Display proxy config (mask passwords)
- `test_proxy()` - Test connectivity via curl

**lib/proxy/git.sh**
- `save_git_proxy_settings()` - Backup git config to file
- `restore_git_proxy()` - Restore git config from backup

### Benefits Achieved

✅ **Modular proxy management** - 4 focused modules instead of monolith
✅ **Clear separation of concerns** - Validation, credentials, configuration, git integration
✅ **~711 lines extracted** from legacy into proxy modules
✅ **100% backward compatibility** - All regression tests pass
✅ **Reusable components** - Each module testable independently

---

## Migration Roadmap

| Phase | Status | Focus | Files Changed | Timeline |
|-------|--------|-------|---------------|----------|
| 0 | ✅ COMPLETE | Infrastructure | +550 lines | Week 1 |
| 1 | ⚠️ PARTIAL | Core utilities | ~15 lines | Week 2 |
| 2 | ✅ COMPLETE | **Proxy module** | +711 lines | Week 3 🔥 |
| 3 | 🔜 PLANNED | **NVM module** | ~1200 lines | Week 4 🔥 |
| 4 | 🔜 PLANNED | Lockfile | ~400 lines | Week 5 |
| 5 | 🔜 PLANNED | Small modules | ~1500 lines | Week 6 |
| 6 | 🔜 PLANNED | Loop module | ~1400 lines | Week 7 |
| 7 | 🔜 PLANNED | Context module | ~1200 lines | Week 8 |
| 8 | 🔜 PLANNED | Update/Launcher | ~700 lines | Week 9 |
| 9 | 🔜 PLANNED | Optimization | ~500 lines | Week 10 |

**Total:** 10 weeks, ~8000 lines migrated, 70% duplication eliminated

---

## Testing

### Regression Test Suite

**tests/regression-phase0.sh** - Phase 0 backward compatibility tests

Run tests:
```bash
./tests/regression-phase0.sh
```

Expected result: All 8 tests pass

---

## Development Guidelines

### Adding New Modules (Phase 1-9)

1. **Create module file** in appropriate `lib/*/` directory
2. **Add documentation** in function headers
3. **Source module** in `iclaude.sh` wrapper
4. **Update regression tests** in `tests/regression-phaseN.sh`
5. **Test backward compatibility** before committing

### Module Design Principles

- ✅ **Single responsibility** - Each module handles one concern
- ✅ **Minimal coupling** - Modules depend only on `lib/core/`
- ✅ **Consistent error handling** - Use `print_error()` + `return 1`
- ✅ **Clear API** - Document function arguments and return values

---

## Rollback Strategy

If regression tests fail:

```bash
# Discard Phase N changes
git reset --hard origin/master

# Or restore legacy version
git checkout v1.0.0 -- iclaude.sh
```

**Emergency rollback:**
```bash
# Use legacy implementation directly
mv iclaude-legacy.sh iclaude.sh
```

---

## References

- **Main Plan:** See `plan.md` in project root (if created)
- **CLAUDE.md:** Architecture documentation and critical functions
- **iclaude-legacy.sh:** Monolithic implementation (will be phased out)
