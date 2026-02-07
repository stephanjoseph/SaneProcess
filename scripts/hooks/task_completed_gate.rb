#!/usr/bin/env ruby
# frozen_string_literal: true

# TaskCompleted hook: warns if tests haven't been verified before marking a task done
# Currently WARNS only (exit 0) — change to exit 2 to enforce blocking
# Checks for recent test/build results from local or mini builds

require 'json'
require 'time'

begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError, Errno::ENOENT
  exit 0
end

# Only check for SaneApps projects
cwd = Dir.pwd
exit 0 unless cwd.include?('SaneApps/apps/')

app_name = cwd.match(%r{SaneApps/apps/(\w+)})&.[](1)
exit 0 unless app_name

task_subject = input['task_subject'] || 'unknown task'

# Check 1: Recent mini build result (within last 10 minutes)
mini_result_file = "/tmp/mini-build-#{app_name}.result"
mini_ok = false
if File.exist?(mini_result_file)
  lines = File.readlines(mini_result_file).map(&:strip)
  if lines[0] == 'PASS' && lines[1]
    result_time = Time.parse(lines[1]) rescue nil
    mini_ok = result_time && (Time.now - result_time) < 600 # 10 minutes
  end
end

# Check 2: Recent local test result (SaneMaster verify writes this)
local_result_file = "/tmp/sanemaster-#{app_name}-verify.result"
local_ok = false
if File.exist?(local_result_file)
  lines = File.readlines(local_result_file).map(&:strip)
  if lines[0] == 'PASS' && lines[1]
    result_time = Time.parse(lines[1]) rescue nil
    local_ok = result_time && (Time.now - result_time) < 600
  end
end

if mini_ok || local_ok
  source = mini_ok ? 'mini' : 'local'
  warn "✅ Task \"#{task_subject}\" completed — verified by #{source} build"
  exit 0
else
  warn "⚠️  Task \"#{task_subject}\" completed without recent test verification"
  warn "   Run: ./scripts/SaneMaster.rb verify  OR  mini-build.sh #{app_name}"
  warn "   (This is a warning — not blocking. Set exit 2 in task_completed_gate.rb to enforce.)"
  exit 0 # Change to `exit 2` to block task completion without tests
end
