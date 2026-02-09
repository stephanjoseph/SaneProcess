#!/usr/bin/env ruby
# frozen_string_literal: true

# sane_launch_guard.rb — PreToolUse hook
# Blocks improper app launches. Forces use of sane_test.rb.
#
# BLOCKS:
#   - Direct binary execution (Contents/MacOS/<SaneApp>)
#   - Manual `open *.app` for SaneApps without sane_test.rb
#
# ALLOWS:
#   - `ruby scripts/sane_test.rb <AppName>` (the proper way)
#   - Non-SaneApp commands

require 'json'

SANE_APPS = %w[SaneBar SaneClick SaneClip SaneHosts SaneSales SaneSync SaneVideo].freeze
SANE_APP_PATTERN = Regexp.new(SANE_APPS.join('|'))

begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError, Errno::ENOENT
  exit 0
end

tool_name = input['tool_name']
exit 0 unless tool_name == 'Bash'

command = (input['tool_input'] || {})['command'].to_s
exit 0 if command.empty?

# Always allow sane_test.rb invocations
exit 0 if command.include?('sane_test.rb')

# Block 1: Direct binary execution (breaks TCC)
if command.match?(%r{Contents/MacOS/(#{SANE_APP_PATTERN})})
  warn '🔴 BLOCKED: Direct binary execution of SaneApp'
  warn '   Running the binary directly breaks TCC permission grants.'
  warn ''
  warn '   ✅ Use instead: ruby scripts/sane_test.rb <AppName>'
  warn '   This resets TCC, builds fresh, deploys to mini, and launches via `open`.'
  exit 2
end

# Block 2: Manual `open` of a SaneApp .app bundle
# Matches: open ~/Applications/SaneBar.app, open /tmp/SaneClip.app, ssh mini 'open ...'
if command.match?(/open\s+.*\b(#{SANE_APP_PATTERN})\.app\b/)
  warn '🔴 BLOCKED: Manual launch of SaneApp'
  warn '   Launching without TCC reset causes stale permissions.'
  warn ''
  warn '   ✅ Use instead: ruby scripts/sane_test.rb <AppName>'
  warn '   Handles: kill → clean → TCC reset → build → deploy → launch → logs'
  exit 2
end

exit 0
