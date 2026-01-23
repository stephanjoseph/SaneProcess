# Code Conventions for SaneProcess

## Ruby Style

### File Header
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
```

### Exit Codes (Critical for Hooks)
- `exit 0` = Allow the operation
- `exit 1` = Warning only (shows message, operation proceeds)
- `exit 2` = BLOCK the operation (Claude Code standard)

### Output
- Use `warn` for messages (stderr) - user sees these
- Use `puts` only for JSON output to stdout
- Never use `puts` for debugging in hooks

### Error Handling
```ruby
begin
  # risky operation
rescue JSON::ParserError, Errno::ENOENT
  exit 0  # Don't block on parse errors
rescue StandardError => e
  warn "⚠️  Hook error: #{e.message}"
  exit 0  # Don't block on unexpected errors
end
```

## State Management
- All state in `.claude/state/enforcement_state.json`
- Thread-safe access via `StateManager` class
- HMAC signatures prevent tampering
- File locking for concurrent access

## Naming Conventions
- Hook files: `sane*.rb` (saneprompt, sanetools, etc.)
- Core modules: `snake_case.rb`
- Constants: `SCREAMING_SNAKE_CASE`
- Methods: `snake_case`
