# Serena LSP Setup for SaneProcess

## Status: Ready for next session (Feb 1, 2026)

Solargraph (Ruby LSP) was installed and symlinked:
- Installed: `/opt/homebrew/lib/ruby/gems/4.0.0/gems/solargraph-0.58.2/`
- Symlinked: `/opt/homebrew/bin/solargraph` -> gems bin
- Version: 0.58.2
- Verified visible from Serena's shell (`execute_shell_command` confirms)

## Why it doesn't work yet
The Serena MCP server initializes the LSP manager at startup. Since Solargraph wasn't installed when the current session started, the LSP init failed and won't retry on `activate_project`. A new Claude Code session will start a fresh MCP server that will find Solargraph.

## What to test next session
1. `activate_project` -> SaneProcess
2. `get_symbols_overview` -> should now return Ruby symbols
3. `find_symbol` with name_path_pattern -> test navigation
4. `find_referencing_symbols` -> test caller discovery
5. `replace_symbol_body` -> test safe editing

## Project config
- `.serena/project.yml` uses `languages: [ruby]` (Serena auto-selects Solargraph for Ruby)
- If `ruby` doesn't pick up Solargraph, try changing to `ruby_solargraph`

## Value for SaneProcess
- `get_symbols_overview` -> See all classes/methods in 700+ line hook files without reading the whole file
- `find_referencing_symbols` -> "Who calls check_research_before_edit?" across all hooks
- `replace_symbol_body` -> Safer than regex edits on large methods
- `rename_symbol` -> Codebase-wide renames without grep/sed
