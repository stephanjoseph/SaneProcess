#!/usr/bin/env ruby
# frozen_string_literal: true

# Safety Module - Shared safety toggle for all hooks
#
# Commands (in user prompt):
#   S-    → Safety OFF (manual mode, no guardrails)
#   S+    → Safety ON (guardrails active)
#   S?    → Check status (no change)
#   skip  → Allow ONE action, then guardrails back on (user-initiated only)
#
# Usage in hooks:
#   require_relative 'bypass'
#   exit 0 if Bypass.active?
#   exit 0 if Bypass.skip_once?  # Consumes the skip

require 'json'
require 'fileutils'

module Bypass
  BYPASS_FILE = File.expand_path('~/.claude/bypass.json')
  SKIP_FILE = File.expand_path('~/.claude/skip_once.json')
  SKIP_LOG_FILE = File.expand_path('~/.claude/skip_audit.jsonl')

  class << self
    # Check if safety is OFF (all guardrails disabled)
    def active?
      return false unless File.exist?(BYPASS_FILE)
      state = JSON.parse(File.read(BYPASS_FILE))
      state['active'] == true
    rescue StandardError
      false
    end

    def safety_off!
      write_state(true)
      warn ''
      warn '🔓 SAFETY OFF - Manual mode'
      warn ''
    end

    def safety_on!
      write_state(false)
      warn ''
      warn '🔒 SAFETY ON - Guardrails active'
      warn ''
    end

    def status
      if active?
        warn ''
        warn '🔓 SAFETY OFF - Manual mode'
        warn ''
      else
        warn ''
        warn '🔒 SAFETY ON - Guardrails active'
        warn ''
      end
    end

    # User requested one-time skip
    def skip_requested!
      FileUtils.mkdir_p(File.dirname(SKIP_FILE))
      File.write(SKIP_FILE, JSON.pretty_generate({
        'active' => true,
        'requested_at' => Time.now.iso8601
      }))
      warn ''
      warn '⏭️  SKIP: Next blocked action will be allowed once'
      warn ''
    end

    # Check if skip is active, CONSUMES the skip (one-time use)
    # C2 FIX: Uses file locking to prevent race condition where parallel hooks
    # could each consume the same skip, allowing multiple actions through.
    def skip_once?
      return false unless File.exist?(SKIP_FILE)

      # Use a lock file for atomic check-and-consume
      lock_file = "#{SKIP_FILE}.lock"
      FileUtils.mkdir_p(File.dirname(lock_file))

      File.open(lock_file, File::RDWR | File::CREAT, 0o644) do |lock|
        # Try to get exclusive lock (non-blocking)
        # If another hook has the lock, we lose the race - return false
        unless lock.flock(File::LOCK_EX | File::LOCK_NB)
          return false
        end

        # We have the lock - now check if skip file still exists and is active
        # (another hook might have consumed it before we got the lock)
        return false unless File.exist?(SKIP_FILE)

        state = JSON.parse(File.read(SKIP_FILE))
        return false unless state['active'] == true

        # Consume the skip by deleting the file
        File.delete(SKIP_FILE)

        # Log for audit (while holding lock)
        log_skip_used

        warn ''
        warn '⏭️  SKIP USED: Action allowed, guardrails restored'
        warn ''

        # Lock automatically released when block exits
        true
      end
    rescue StandardError
      false
    end

    # Check prompt for safety commands, returns true if handled
    def check_prompt(prompt)
      return false unless prompt

      # Natural language patterns
      safety_off_patterns = [
        /\bS-(?:\s|$)/i,
        /\bturn\s+safety\s+(off|mode\s+off)\b/i,
        /\bsafety\s+(off|mode\s+off)\b/i,
        /\bdisable\s+safety\b/i,
        /\bno\s+guardrails\b/i
      ]

      safety_on_patterns = [
        /\bS\+(?:\s|$)/i,
        /\bturn\s+safety\s+(on|mode\s+on|back\s+on)\b/i,
        /\bsafety\s+(on|mode\s+on|back\s+on)\b/i,
        /\benable\s+safety\b/i,
        /\bguardrails\s+(on|back\s+on)\b/i
      ]

      status_patterns = [
        /\bS\?(?:\s|$)/i,
        /\bsafety\s+status\b/i,
        /\bcheck\s+safety\b/i
      ]

      skip_patterns = [
        /\bskip(?:\s|$|,)/i,
        /\bskip\s+(this|the|that|sop|check|enforcement)\b/i
      ]

      if safety_off_patterns.any? { |p| prompt.match?(p) }
        safety_off!
        true
      elsif safety_on_patterns.any? { |p| prompt.match?(p) }
        safety_on!
        true
      elsif status_patterns.any? { |p| prompt.match?(p) }
        status
        true
      elsif skip_patterns.any? { |p| prompt.match?(p) }
        skip_requested!
        true
      else
        false
      end
    end

    private

    def log_skip_used
      FileUtils.mkdir_p(File.dirname(SKIP_LOG_FILE))
      entry = {
        'used_at' => Time.now.iso8601,
        'hook' => caller_locations(2, 1).first&.path&.split('/')&.last || 'unknown'
      }
      File.open(SKIP_LOG_FILE, 'a') { |f| f.puts entry.to_json }
    rescue StandardError
      # Don't fail on logging errors
    end

    def write_state(active)
      FileUtils.mkdir_p(File.dirname(BYPASS_FILE))
      File.write(BYPASS_FILE, JSON.pretty_generate({
        'active' => active,
        'updated_at' => Time.now.iso8601,
        'updated_by' => 'user'
      }))
    end
  end
end
