#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# PreToolUse Entry Point
# ==============================================================================
# Main entry point for all PreToolUse enforcement. Loads all detectors and
# delegates to the Coordinator for the detection-decision-action pipeline.
#
# This replaces the monolithic process_enforcer.rb with a clean architecture:
#   - Detectors: Pure detection logic (no side effects)
#   - Coordinator: Orchestration (classify, detect, decide, act)
#   - Actions: Output and logging (blocker, warner, logger)
#
# Usage (in .claude/settings.json):
#   "PreToolUse": {
#     "hooks": [{
#       "command": "ruby ~/.claude/hooks/hooks/pre_tool_use.rb",
#       "timeout": 5000
#     }]
#   }
# ==============================================================================

# Load core components
require_relative '../core/state_manager'
require_relative '../core/hook_registry'
require_relative '../core/coordinator'

# Load all detectors (auto-register via inherited callback)
Dir[File.join(__dir__, '../detectors/*.rb')].sort.each { |f| require f }

# Run the coordinator pipeline
Coordinator.run(hook_type: :pre_tool_use)
