#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# SessionStart Entry Point
# ==============================================================================
# Runs once when a new Claude Code session begins. Responsibilities:
#   - Reset transient state (requirements, edits)
#   - Preserve persistent state (circuit breaker)
#   - Archive stale SaneLoops
#   - Ensure .claude directory exists
# ==============================================================================

require 'json'
require 'fileutils'
require_relative '../core/state_manager'

PROJECT_DIR = ENV['CLAUDE_PROJECT_DIR'] || Dir.pwd
CLAUDE_DIR = File.join(PROJECT_DIR, '.claude')
ARCHIVE_DIR = File.join(CLAUDE_DIR, 'saneloop-archive')
STALE_THRESHOLD = 4 * 60 * 60 # 4 hours

def archive_stale_saneloops
  saneloop_state = StateManager.get(:saneloop)
  return unless saneloop_state[:active]

  started_at = saneloop_state[:started_at]
  return unless started_at

  age = Time.now - Time.parse(started_at)
  return if age < STALE_THRESHOLD

  # Archive stale SaneLoop
  FileUtils.mkdir_p(ARCHIVE_DIR)
  archive_file = File.join(ARCHIVE_DIR, "saneloop-#{Time.now.strftime('%Y%m%d-%H%M%S')}.json")
  File.write(archive_file, JSON.pretty_generate(saneloop_state))

  # Clear SaneLoop state
  StateManager.reset(:saneloop)

  warn "⚠️  Archived stale SaneLoop (#{(age / 3600).round(1)}h old)"
rescue StandardError => e
  warn "Warning: Could not archive SaneLoop: #{e.message}"
end

# === Main execution ===
# Ensure .claude directory exists
FileUtils.mkdir_p(CLAUDE_DIR)

# Archive stale SaneLoops
archive_stale_saneloops

# Reset state for new session, preserving circuit breaker
StateManager.reset_except(:circuit_breaker, :enforcement)

# Clear any bypass flags (fresh session = fresh start)
bypass_file = File.join(CLAUDE_DIR, 'bypass_active.json')
FileUtils.rm_f(bypass_file)

warn '✅ Session initialized'
exit 0
