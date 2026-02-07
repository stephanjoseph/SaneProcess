#!/usr/bin/env ruby
# frozen_string_literal: true

# Async PostToolUse hook: triggers Mac Mini build after Swift file edits
# Runs in background (async: true) — does not block Claude
# Debounces: skips if build triggered in last 60 seconds
# Graceful: silently exits if mini unreachable or not in SaneApps

require 'json'
require 'fileutils'

begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError, Errno::ENOENT
  exit 0
end

# Only trigger for Swift files
file_path = input.dig('tool_input', 'file_path') ||
            input.dig('tool_input', 'path') || ''
exit 0 unless file_path.end_with?('.swift')

# Only trigger in SaneApps app projects
cwd = Dir.pwd
exit 0 unless cwd.include?('SaneApps/apps/')

# Determine app name from cwd
app_name = cwd.match(%r{SaneApps/apps/(\w+)})&.[](1)
exit 0 unless app_name

# Debounce: skip if build triggered in last 60 seconds
lockfile = "/tmp/mini-build-#{app_name}.lock"
if File.exist?(lockfile) && (Time.now - File.mtime(lockfile)) < 60
  exit 0
end

# Check mini reachability (fast 2-second timeout, batch mode = no password prompt)
unless system('ssh -o ConnectTimeout=2 -o BatchMode=yes mini true 2>/dev/null')
  exit 0 # Mini not reachable (coffee shop, etc.) — silently skip
end

# Touch lockfile for debounce (owner-only permissions)
FileUtils.touch(lockfile)
File.chmod(0600, lockfile)

# Log and build
log_file = "/tmp/mini-build-#{app_name}.log"
warn "🔨 Mini build triggered for #{app_name} (async, log: #{log_file})"

# Run the build — this IS the async process, so we can run synchronously here
system("#{ENV['HOME']}/SaneApps/infra/scripts/mini-build.sh #{app_name} > #{log_file} 2>&1")

result_file = "/tmp/mini-build-#{app_name}.result"
if $?.success?
  # Record success for TaskCompleted hook to check
  File.write(result_file, "PASS\n#{Time.now.iso8601}")
  File.chmod(0600, result_file)
  warn "✅ Mini build PASSED for #{app_name}"
else
  File.write(result_file, "FAIL\n#{Time.now.iso8601}")
  File.chmod(0600, result_file)
  warn "❌ Mini build FAILED for #{app_name} — check #{log_file}"
end
