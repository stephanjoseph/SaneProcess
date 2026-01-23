#!/usr/bin/env ruby
# frozen_string_literal: true

# CRITICAL HOOK: Block killing Sane-Mem process
# Reason: Kills lose all accumulated memory/observations
# This runs GLOBALLY across all projects

require 'json'

begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError, Errno::ENOENT
  exit 0
end

tool_name = input['tool_name']
tool_input = input['tool_input'] || {}

# Only check Bash commands
exit 0 unless tool_name == 'Bash'

command = tool_input['command'].to_s

# Patterns that would kill Sane-Mem
kill_patterns = [
  /kill.*claude-?mem/i,
  /kill.*sane-?mem/i,
  /killall.*claude-?mem/i,
  /killall.*sane-?mem/i,
  /pkill.*claude-?mem/i,
  /pkill.*sane-?mem/i,
  /kill.*37777/i,                    # The port it runs on
  /launchctl.*unload.*claudemem/i,
  /launchctl.*remove.*claudemem/i,
  /kill.*worker-service/i,           # The actual process name
  /killall.*bun.*worker/i,
]

# Check if command matches any kill pattern
kill_patterns.each do |pattern|
  if command.match?(pattern)
    warn '🛑 BLOCKED: Cannot kill Sane-Mem'
    warn ''
    warn '   Killing Sane-Mem loses ALL accumulated memory and observations.'
    warn '   Two days of learnings were lost on Jan 24 2026 due to this.'
    warn ''
    warn '   If Sane-Mem is misbehaving:'
    warn '   1. Check logs: tail ~/.claude-mem/logs/worker-launchd*.log'
    warn '   2. Restart (not kill): launchctl kickstart -k gui/$(id -u)/com.claudemem.worker'
    warn '   3. Ask the user before taking any action'
    warn ''
    exit 2
  end
end

exit 0
