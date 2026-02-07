#!/usr/bin/env ruby
# frozen_string_literal: true

# PostToolUse hook: auto-format Swift files after Write/Edit
# Inspired by Boris Cherny's bun format hook - fixes the last 10% that causes CI failures

require 'json'

begin
  input = JSON.parse($stdin.read)
  tool_input = input['tool_input'] || {}
  file_path = tool_input['file_path']

  if file_path && file_path.end_with?('.swift') && File.exist?(file_path)
    # swiftformat is fast on single files (~50ms), won't slow down the hook
    system('swiftformat', file_path, '--quiet', '--swiftversion', '5.9')
    # Also run swiftlint autocorrect for fixable violations
    system('swiftlint', 'lint', '--fix', '--quiet', file_path)
  end
rescue StandardError
  # Never block on format errors
end

exit 0
