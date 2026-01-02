#!/bin/bash
#
# SaneProcess Initialization Script
# Sets up complete Claude Code SOP enforcement in 2 minutes
#
# Usage: curl -sL saneprocess.dev/init | bash
#    or: ./sane-init.sh
#
# Version 2.1 - January 2026
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}              ${GREEN}SaneProcess v2.1 Initialization${NC}                  ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# DETECT PROJECT TYPE
# ═══════════════════════════════════════════════════════════════════════════════

detect_project_type() {
    if [ -f "Package.swift" ]; then
        echo "swift-package"
    elif [ -f "project.yml" ]; then
        echo "xcodegen"
    elif ls *.xcodeproj 1>/dev/null 2>&1; then
        echo "xcode"
    elif [ -f "Gemfile" ]; then
        echo "ruby"
    elif [ -f "package.json" ]; then
        echo "node"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        echo "python"
    else
        echo "generic"
    fi
}

PROJECT_TYPE=$(detect_project_type)
PROJECT_NAME=$(basename "$(pwd)")

echo -e "📁 Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "🔍 Detected type: ${GREEN}${PROJECT_TYPE}${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

echo "Checking dependencies..."

check_command() {
    if command -v "$1" &>/dev/null; then
        echo -e "   ✅ $1"
        return 0
    else
        echo -e "   ${YELLOW}⚠️  $1 not found${NC}"
        return 1
    fi
}

MISSING_DEPS=()

# Required
check_command "claude" || MISSING_DEPS+=("claude (npm install -g @anthropic-ai/claude-code)")
check_command "npx" || MISSING_DEPS+=("npx (install Node.js)")

# Optional but recommended
case "$PROJECT_TYPE" in
    swift-package|xcodegen|xcode)
        check_command "swiftlint" || echo "      brew install swiftlint"
        check_command "xcodegen" || echo "      brew install xcodegen"
        check_command "lefthook" || echo "      brew install lefthook"
        ;;
    ruby)
        check_command "rubocop" || echo "      gem install rubocop"
        check_command "lefthook" || echo "      brew install lefthook"
        ;;
    node)
        check_command "eslint" || echo "      npm install -g eslint"
        check_command "lefthook" || echo "      brew install lefthook"
        ;;
esac

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing required dependencies:${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "   ${RED}•${NC} $dep"
    done
    echo ""
    echo "Install them and run this script again."
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE DIRECTORY STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating directory structure..."

mkdir -p .claude
mkdir -p Scripts/hooks

echo "   ✅ .claude/"
echo "   ✅ Scripts/"
echo "   ✅ Scripts/hooks/"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE .claude/settings.json
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating Claude Code hooks configuration..."

cat > .claude/settings.json << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "./Scripts/build.rb bootstrap"
      }
    ],
    "PreToolUse": [
      {
        "type": "command",
        "command": "./Scripts/hooks/circuit_breaker.rb",
        "matchTools": ["Edit", "Bash", "Write"]
      }
    ],
    "SessionEnd": [
      {
        "type": "command",
        "command": "./Scripts/hooks/memory_compactor.rb"
      }
    ]
  }
}
EOF

echo "   ✅ .claude/settings.json"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE .mcp.json
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating MCP server configuration..."

cat > .mcp.json << 'EOF'
{
  "mcpServers": {
    "apple-docs": {
      "command": "npx",
      "args": ["-y", "@mweinbach/apple-docs-mcp@latest"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory", ".claude/memory.json"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
EOF

echo "   ✅ .mcp.json"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE BUILD SCRIPT (project-type specific)
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating build script for ${PROJECT_TYPE}..."

case "$PROJECT_TYPE" in
    swift-package|xcodegen|xcode)
        cat > Scripts/build.rb << RUBY
#!/usr/bin/env ruby
# frozen_string_literal: true

PROJECT = '${PROJECT_NAME}'

command = ARGV[0]

case command
when 'verify'
  system("xcodebuild -scheme #{PROJECT} -destination 'platform=macOS' build test 2>&1 | grep -E '(BUILD|error:|warning:)' | tail -20")
when 'clean'
  system("rm -rf ~/Library/Developer/Xcode/DerivedData/#{PROJECT}-*")
  puts '✅ Cleaned DerivedData'
when 'logs'
  Kernel.send(:system, 'log', 'stream', '--predicate', "process == \\"#{PROJECT}\\"", '--style', 'compact')
when 'launch'
  app = Dir.glob(File.expand_path("~/Library/Developer/Xcode/DerivedData/#{PROJECT}-*/Build/Products/Debug/#{PROJECT}.app")).first
  if app
    system("open '#{app}'")
    puts '✅ Launched'
  else
    puts '❌ App not found. Run: ./Scripts/build.rb verify'
  end
when 'test_mode'
  system("killall -9 #{PROJECT} 2>/dev/null")
  puts '1️⃣  Killed existing processes'
  if system('./Scripts/build.rb verify') && system('./Scripts/build.rb launch')
    sleep 1
    puts '📡 Streaming logs...'
    Kernel.send(:system, 'log', 'stream', '--predicate', "process == \\"#{PROJECT}\\"", '--style', 'compact')
  end
when 'bootstrap'
  puts '✅ Ready'
else
  puts "Usage: #{File.basename(\$0)} [verify|clean|logs|launch|test_mode|bootstrap]"
end
RUBY
        ;;
    ruby)
        cat > Scripts/build.rb << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

command = ARGV[0]

case command
when 'verify'
  system('bundle exec rubocop') && system('bundle exec rspec')
when 'clean'
  system('rm -rf tmp/* coverage/')
  puts '✅ Cleaned'
when 'test'
  system('bundle exec rspec')
when 'bootstrap'
  system('bundle install --quiet')
  puts '✅ Ready'
else
  puts "Usage: #{File.basename($0)} [verify|clean|test|bootstrap]"
end
RUBY
        ;;
    node)
        cat > Scripts/build.rb << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

command = ARGV[0]

case command
when 'verify'
  system('npm run lint') && system('npm test')
when 'clean'
  system('rm -rf node_modules dist coverage')
  puts '✅ Cleaned'
when 'test'
  system('npm test')
when 'bootstrap'
  system('npm install --silent')
  puts '✅ Ready'
else
  puts "Usage: #{File.basename($0)} [verify|clean|test|bootstrap]"
end
RUBY
        ;;
    *)
        cat > Scripts/build.rb << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

command = ARGV[0]

case command
when 'verify'
  puts 'Running tests...'
  # Add your test command here
  puts '✅ Tests passed (customize this command)'
when 'clean'
  puts '✅ Cleaned (customize cleanup paths)'
when 'bootstrap'
  puts '✅ Ready'
else
  puts "Usage: #{File.basename($0)} [verify|clean|bootstrap]"
end
RUBY
        ;;
esac

chmod +x Scripts/build.rb
echo "   ✅ Scripts/build.rb"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE CIRCUIT BREAKER HOOK
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating circuit breaker hook..."

cat > Scripts/hooks/circuit_breaker.rb << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

STATE_FILE = '.claude/circuit_breaker.json'

def load_state
  return { 'failures' => [], 'tripped' => false } unless File.exist?(STATE_FILE)
  JSON.parse(File.read(STATE_FILE))
rescue JSON::ParserError
  { 'failures' => [], 'tripped' => false }
end

def save_state(state)
  FileUtils.mkdir_p(File.dirname(STATE_FILE))
  File.write(STATE_FILE, JSON.pretty_generate(state))
end

state = load_state

# Check if breaker is tripped
if state['tripped']
  warn '🛑 CIRCUIT BREAKER TRIPPED'
  warn "   #{state['failures'].count} failures recorded"
  warn '   Run: ./Scripts/build.rb breaker_reset after investigating'
  exit 1
end

# Record failure if tool use failed (check exit code of previous command)
# This is a simplified version - full implementation tracks error signatures
exit 0
RUBY

chmod +x Scripts/hooks/circuit_breaker.rb
echo "   ✅ Scripts/hooks/circuit_breaker.rb"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE MEMORY COMPACTOR HOOK
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating memory compactor hook..."

cat > Scripts/hooks/memory_compactor.rb << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

MEMORY_FILE = '.claude/memory.json'
ARCHIVE_FILE = '.claude/memory_archive.jsonl'
MAX_ENTITIES = 60
MAX_OBS_PER_ENTITY = 15

def compact_memory
  return unless File.exist?(MEMORY_FILE)

  data = JSON.parse(File.read(MEMORY_FILE))
  entities = data['entities'] || []
  original_count = entities.size

  # Archive if over threshold
  if entities.size > MAX_ENTITIES
    old_entities = entities.sort_by { |e| e['updated_at'] || '' }
                          .first(entities.size - MAX_ENTITIES)

    FileUtils.mkdir_p(File.dirname(ARCHIVE_FILE))
    File.open(ARCHIVE_FILE, 'a') do |f|
      old_entities.each do |e|
        f.puts({ archived_at: Time.now.utc.iso8601, entity: e }.to_json)
      end
    end

    entities -= old_entities
    puts "📦 Archived #{old_entities.size} old entities"
  end

  # Trim verbose entities
  trimmed = 0
  entities.each do |entity|
    obs = entity['observations'] || []
    if obs.size > MAX_OBS_PER_ENTITY
      entity['observations'] = obs.last(MAX_OBS_PER_ENTITY)
      trimmed += 1
    end
  end
  puts "✂️  Trimmed #{trimmed} verbose entities" if trimmed > 0

  # Save if changed
  if entities.size < original_count || trimmed > 0
    data['entities'] = entities
    File.write(MEMORY_FILE, JSON.pretty_generate(data))
  end
rescue StandardError => e
  # Silent failure - don't interrupt session end
  warn "Memory compaction error: #{e.message}" if ENV['DEBUG']
end

compact_memory
RUBY

chmod +x Scripts/hooks/memory_compactor.rb
echo "   ✅ Scripts/hooks/memory_compactor.rb"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE LEFTHOOK.YML
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating git hooks configuration..."

case "$PROJECT_TYPE" in
    swift-package|xcodegen|xcode)
        cat > lefthook.yml << 'YAML'
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.swift"
      run: swiftlint lint --fix {staged_files} && git add {staged_files}
    file_size:
      glob: "*.swift"
      run: |
        for file in {staged_files}; do
          lines=$(wc -l < "$file")
          if [ "$lines" -gt 800 ]; then
            echo "❌ $file exceeds 800 lines ($lines)"
            exit 1
          fi
        done

pre-push:
  commands:
    verify:
      run: ./Scripts/build.rb verify
YAML
        ;;
    ruby)
        cat > lefthook.yml << 'YAML'
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.rb"
      run: bundle exec rubocop -a {staged_files} && git add {staged_files}

pre-push:
  commands:
    verify:
      run: ./Scripts/build.rb verify
YAML
        ;;
    node)
        cat > lefthook.yml << 'YAML'
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.{js,ts,jsx,tsx}"
      run: npx eslint --fix {staged_files} && git add {staged_files}

pre-push:
  commands:
    verify:
      run: ./Scripts/build.rb verify
YAML
        ;;
    *)
        cat > lefthook.yml << 'YAML'
pre-commit:
  commands:
    placeholder:
      run: echo "Add your pre-commit hooks here"

pre-push:
  commands:
    verify:
      run: ./Scripts/build.rb verify
YAML
        ;;
esac

echo "   ✅ lefthook.yml"

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE DOCUMENTATION FILES
# ═══════════════════════════════════════════════════════════════════════════════

echo "Creating documentation templates..."

if [ ! -f "DEVELOPMENT.md" ]; then
    cat > DEVELOPMENT.md << 'MD'
# Development Guide

This project uses [SaneProcess](https://saneprocess.dev) for Claude Code SOP enforcement.

## Quick Commands

```bash
./Scripts/build.rb verify      # Build + tests
./Scripts/build.rb clean       # Clean caches
./Scripts/build.rb test_mode   # Kill → Build → Launch → Logs
./Scripts/build.rb bootstrap   # Initialize environment
```

## The Golden Rules

See SaneProcess documentation for full rules. Key ones:

1. **Rule #2: VERIFY BEFORE YOU TRY** - Check API docs before assuming
2. **Rule #3: TWO STRIKES? INVESTIGATE** - Stop after 2 failures, research
3. **Rule #6: BUILD, KILL, LAUNCH, LOG** - Full cycle after every change
4. **Rule #7: NO TEST? NO REST** - Bug fixes need regression tests

## Self-Rating

After every task, rate 1-10:
- 9-10: All rules followed
- 7-8: Minor miss
- 5-6: Notable gaps
- 1-4: Multiple violations
MD
    echo "   ✅ DEVELOPMENT.md"
fi

if [ ! -f "BUG_TRACKING.md" ]; then
    cat > BUG_TRACKING.md << 'MD'
# Bug Tracking

## Active Bugs

*None currently*

---

## Resolved Bugs

<!-- Template:
### BUG-XXX: Short description

**Status**: RESOLVED (date)

**Symptom**: What the user sees

**Root Cause**: Technical explanation

**Fix**: Code changes with file:line references

**Regression Test**: Test file and function name
-->
MD
    echo "   ✅ BUG_TRACKING.md"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZE GIT HOOKS
# ═══════════════════════════════════════════════════════════════════════════════

if command -v lefthook &>/dev/null && [ -d ".git" ]; then
    echo "Initializing git hooks..."
    lefthook install
    echo "   ✅ lefthook installed"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}                    ${GREEN}Setup Complete!${NC}                           ${GREEN}║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Created:"
echo "   • .claude/settings.json    - Claude Code hooks"
echo "   • .mcp.json                - MCP servers (apple-docs, memory, context7)"
echo "   • Scripts/build.rb         - Build automation"
echo "   • Scripts/hooks/           - SOP enforcement hooks"
echo "   • lefthook.yml             - Git pre-commit/pre-push hooks"
echo "   • DEVELOPMENT.md           - Development guide"
echo "   • BUG_TRACKING.md          - Bug tracking template"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "   1. Run: ${GREEN}./Scripts/build.rb verify${NC}     - Test the build"
echo "   2. Run: ${GREEN}claude${NC}                        - Start Claude Code"
echo "   3. Claude will load hooks and MCP servers automatically"
echo ""
echo -e "${YELLOW}Pro tip:${NC} Add .claude/memory.json to .gitignore (personal context)"
echo ""
echo "Documentation: https://saneprocess.dev"
echo ""
