#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# SanePrompt - UserPromptSubmit Hook
# ==============================================================================
# Classifies prompts, injects context, detects patterns.
#
# Exit codes:
#   0 = allow (context injected via stdout if needed)
#   2 = block (rare - only for truly dangerous prompts)
#
# What this does:
#   1. Classifies: passthrough, question, task, big_task
#   2. Detects task types: bug_fix, new_feature, refactor, etc.
#   3. Shows applicable rules
#   4. Detects pattern triggers (words that predict rule violations)
#   5. Updates state for other hooks
# ==============================================================================

require 'json'
require 'fileutils'
require 'time'
require_relative 'core/state_manager'

LOG_FILE = File.expand_path('../../.claude/saneprompt.log', __dir__)

# === CONFIGURATION ===

# Pre-compiled regex unions for O(1) matching instead of O(n) array iteration
PASSTHROUGH_PATTERN = Regexp.union(
  /^(y|yes|n|no|ok|done|continue|approved|cancel|sure|thanks|thx)$/i,
  /^\/\w+/,  # slash commands
  /^[^a-zA-Z]*$/  # no letters (just symbols/numbers)
).freeze

# === SAFEMODE COMMANDS ===
BYPASS_FILE = File.expand_path('../../.claude/bypass_active.json', __dir__)

def handle_safemode_command(prompt)
  cmd = prompt.strip.downcase

  if cmd.start_with?('s+') || cmd.start_with?('safemode on')
    # Enable safemode = delete bypass file
    if File.exist?(BYPASS_FILE)
      File.delete(BYPASS_FILE)
      warn ''
      warn 'SAFEMODE ON - enforcement active'
      warn ''
    else
      warn ''
      warn 'SAFEMODE already on'
      warn ''
    end
    true
  elsif cmd.start_with?('s-') || cmd.start_with?('safemode off')
    # Disable safemode = create bypass file
    FileUtils.mkdir_p(File.dirname(BYPASS_FILE))
    File.write(BYPASS_FILE, '{}')
    warn ''
    warn 'SAFEMODE OFF - enforcement bypassed'
    warn ''
    true
  elsif cmd.start_with?('s?') || cmd == 'safemode' || cmd.start_with?('safemode status')
    status = File.exist?(BYPASS_FILE) ? 'OFF (bypassed)' : 'ON (enforcing)'
    warn ''
    warn "SAFEMODE: #{status}"
    warn ''
    true
  elsif cmd.start_with?('reset breaker') || cmd.start_with?('reset circuit') || cmd.start_with?('rb-') || cmd.start_with?('rb+')
    # Reset circuit breaker state (rb- and rb+ both reset)
    debug_log("RESET BREAKER: cmd='#{cmd}'") rescue nil
    debug_log("BEFORE RESET: #{StateManager.get(:circuit_breaker).inspect}") rescue nil
    StateManager.reset(:circuit_breaker)
    debug_log("AFTER RESET: #{StateManager.get(:circuit_breaker).inspect}") rescue nil
    warn ''
    warn 'CIRCUIT BREAKER RESET'
    warn '  Failures: 0'
    warn '  Tripped: false'
    warn '  Error signatures: cleared'
    warn ''
    true
  elsif cmd.start_with?('rb?') || cmd == 'breaker status'
    # Show circuit breaker status
    cb = StateManager.get(:circuit_breaker)
    warn ''
    warn 'CIRCUIT BREAKER STATUS'
    warn "  Tripped: #{cb[:tripped] || false}"
    warn "  Failures: #{cb[:failures] || 0}"
    if cb[:error_signatures]&.any?
      warn '  Error signatures:'
      cb[:error_signatures].each { |sig, count| warn "    #{sig}: #{count}" }
    end
    warn ''
    true
  else
    false
  end
end

QUESTION_PATTERN = Regexp.union(
  /^(what|where|when|why|how|which|who|can you explain|tell me about)\b/i,
  /\?$/,  # ends with question mark
  /^(does|is|are|do|should|could|would)\s+(this|it|the|that)\b/i
).freeze

TASK_INDICATOR = Regexp.union(
  /\b(fix|add|create|implement|build|refactor|update|change|modify|delete|remove)\b/i,
  /\b(bug|error|issue|problem|broken|failing|crash)\b/i,
  /\b(feature|functionality|capability)\b/i,
  /\b(write|make|generate|set ?up|rewrite|overhaul|redesign)\b/i
).freeze

BIG_TASK_INDICATOR = Regexp.union(
  /\b(everything|all|entire|whole|complete|full)\b/i,
  /\b(rewrite|overhaul|redesign|architecture)\b/i,
  /\b(system|framework|infrastructure)\b/i,
  /\bmultiple (files|components|modules)\b/i
).freeze

# Trigger words that predict rule violations (learned from patterns)
PATTERN_TRIGGERS = {
  'quick' => { rules: ['#3'], warning: 'quick often leads to skipped research' },
  'just' => { rules: ['#3', '#2'], warning: '"just" suggests underestimating complexity' },
  'simple' => { rules: ['#2'], warning: '"simple" changes often need API verification' },
  'fast' => { rules: ['#3'], warning: 'rushing predicts #3 violations' },
  'easy' => { rules: ['#3', '#2'], warning: '"easy" often means skipped due diligence' },
  'minor' => { rules: ['#7'], warning: '"minor" changes still need tests' },
  'small' => { rules: ['#7'], warning: '"small" fixes still need tests' },
}.freeze

# === INTELLIGENCE: Frustration Detection ===
FRUSTRATION_PATTERNS = {
  correction: [/^no[,.]?\s/i, /that'?s not/i, /I said/i, /I meant/i, /I already/i],
  impatience: [/use your head/i, /\bthink\b/i, /stop rushing/i, /\bidiot\b/i],
  repetition: [/I just said/i, /like I said/i, /as I mentioned/i, /again/i]
}.freeze

# === BUTT-KICKER: Catch ignored warnings ===
def check_ignored_warning(prompt)
  return nil unless File.exist?(LOG_FILE)

  # Get last non-passthrough entry
  last_entry = nil
  File.readlines(LOG_FILE).reverse_each do |line|
    entry = JSON.parse(line) rescue next
    next if entry['type'] == 'passthrough'
    last_entry = entry
    break
  end

  return nil unless last_entry
  return nil if last_entry['triggers'].nil? || last_entry['triggers'].empty?

  # Check if current prompt has same triggers
  current_triggers = detect_triggers(prompt).map { |t| t[:word] }
  repeated = last_entry['triggers'] & current_triggers

  return nil if repeated.empty?

  # BUTT-KICK
  "STOP. You were just warned about: #{repeated.join(', ')}. READ THE WARNING."
rescue StandardError
  nil
end

# === INTELLIGENCE: Requirement Triggers ===
# When user says these, store as REQUIREMENT that must be satisfied
REQUIREMENT_TRIGGERS = {
  saneloop: [/\bsaneloop\b/i, /\bsane ?loop\b/i, /start the loop/i],
  commit: [/\bcommit\b/i, /\bgit commit\b/i, /commit the changes/i],
  plan: [/\bplan\s*(first|before)\b/i, /\bmake a plan\b/i, /\bplan this\b/i],
  research: [/\bresearch\s*(first|this)\b/i, /\binvestigate\b/i, /\blook into\b/i]
}.freeze

# Fresh start = reset requirements; Additive = add to existing
FRESH_START_TRIGGERS = %w[saneloop commit test_mode].freeze
ADDITIVE_TRIGGERS = %w[research plan explain verify].freeze

RULES_BY_TASK = {
  bug_fix: ['#3 Two Strikes', '#7 No Test No Rest', '#8 Bug Found Write Down'],
  new_feature: ['#0 Name Rule First', '#2 Verify API', '#9 Gen Pile'],
  refactor: ['#4 Green Means Go', '#10 File Size'],
  file_create: ['#1 Stay in Lane', '#9 Gen Pile'],
  general: ['#0 Name Rule First', '#5 Their House Their Rules'],
}.freeze

# === CLASSIFICATION ===

def classify_prompt(prompt)
  return :passthrough if prompt.match?(PASSTHROUGH_PATTERN)
  return :passthrough if prompt.length < 10

  # Questions don't need full enforcement
  return :question if prompt.match?(QUESTION_PATTERN)

  # Check for task indicators
  return :question unless prompt.match?(TASK_INDICATOR)

  # Check for big task indicators
  prompt.match?(BIG_TASK_INDICATOR) ? :big_task : :task
end

def detect_task_types(prompt)
  types = []
  types << :bug_fix if prompt.match?(/\b(fix|bug|error|broken|failing|crash)\b/i)
  types << :new_feature if prompt.match?(/\b(add|create|implement|new|feature)\b/i)
  types << :refactor if prompt.match?(/\b(refactor|reorganize|restructure|clean ?up)\b/i)
  types << :file_create if prompt.match?(/\b(create|new) (file|class|struct|view|model)\b/i)
  types << :general if types.empty?
  types
end

def rules_for_prompt(prompt)
  types = detect_task_types(prompt)
  types.flat_map { |t| RULES_BY_TASK[t] }.uniq
end

def detect_triggers(prompt)
  triggers = []
  prompt_lower = prompt.downcase

  PATTERN_TRIGGERS.each do |word, info|
    if prompt_lower.include?(word)
      triggers << { word: word, rules: info[:rules], warning: info[:warning] }
    end
  end

  triggers
end

# === INTELLIGENCE: Frustration Detection ===

def detect_frustration(prompt)
  frustrations = []

  FRUSTRATION_PATTERNS.each do |type, patterns|
    patterns.each do |pattern|
      if prompt.match?(pattern)
        frustrations << { type: type, pattern: pattern.source }
        break  # One match per type is enough
      end
    end
  end

  frustrations
end

# === INTELLIGENCE: Requirement Extraction ===

def extract_requirements(prompt)
  detected = []

  REQUIREMENT_TRIGGERS.each do |req_type, patterns|
    if patterns.any? { |p| prompt.match?(p) }
      detected << req_type.to_s
    end
  end

  detected
end

def update_requirements(detected_reqs)
  return if detected_reqs.empty?

  StateManager.update(:requirements) do |reqs|
    # Check if any detected requirement is a fresh start trigger
    is_fresh = detected_reqs.any? { |r| FRESH_START_TRIGGERS.include?(r) }

    if is_fresh
      # Reset and set new requirements
      reqs[:requested] = detected_reqs
      reqs[:satisfied] = []
    else
      # Additive: merge with existing
      reqs[:requested] = ((reqs[:requested] || []) + detected_reqs).uniq
    end

    reqs
  end
rescue StandardError
  # Don't fail on state errors
end

# === INTELLIGENCE: Pattern Learning ===

def learn_from_frustration(prompt, frustrations)
  return if frustrations.empty?

  StateManager.update(:requirements) do |reqs|
    reqs[:frustration_count] = (reqs[:frustration_count] || 0) + 1
    reqs
  end

  # Get recent actions for correlation
  action_log = StateManager.get(:action_log) || []
  recent_actions = action_log.last(3)

  learning = {
    type: frustrations.first[:type],
    pattern: frustrations.first[:pattern],
    recent_actions: recent_actions.map { |a| a[:tool] rescue a['tool'] },
    prompt_fragment: prompt.slice(0, 100),
    timestamp: Time.now.iso8601
  }

  # Store locally for session use
  StateManager.update(:learnings) do |learnings|
    learnings ||= []
    learnings << learning
    learnings.last(50)  # Keep last 50 learnings
  end

  # Log for analysis
  log_learning(learning)
rescue StandardError
  # Don't fail on learning errors
end

def log_learning(learning)
  learnings_file = File.expand_path('../../.claude/learnings.jsonl', __dir__)
  FileUtils.mkdir_p(File.dirname(learnings_file))
  File.open(learnings_file, 'a') { |f| f.puts(learning.to_json) }
rescue StandardError
  # Don't fail on logging errors
end

def check_past_learnings
  learnings = StateManager.get(:learnings) || []
  return nil if learnings.empty?

  # Check if we have recent repeated corrections
  recent = learnings.last(5)
  correction_count = recent.count { |l| l[:type] == :correction || l['type'] == 'correction' }

  if correction_count >= 3
    return "PATTERN: #{correction_count} corrections in recent prompts. Read user message carefully."
  end

  nil
end

# === STATE & LOGGING ===

def log_prompt(prompt_type, rules, triggers)
  FileUtils.mkdir_p(File.dirname(LOG_FILE))
  entry = {
    timestamp: Time.now.iso8601,
    type: prompt_type,
    rules: rules,
    triggers: triggers.map { |t| t[:word] },
    pid: Process.pid
  }
  File.open(LOG_FILE, 'a') { |f| f.puts(entry.to_json) }
rescue StandardError
  # Don't fail on logging errors
end

def update_state(prompt_type, is_big_task)
  StateManager.update(:requirements) do |req|
    req[:is_task] = [:task, :big_task].include?(prompt_type)
    req[:is_big_task] = prompt_type == :big_task
    req
  end
rescue StandardError
  # Don't fail on state errors
end

# === OUTPUT ===

def output_context(prompt_type, rules, triggers, prompt, frustrations = [], detected_reqs = [], learning_warning = nil)
  lines = []

  # Only show context for tasks
  return if [:passthrough, :question].include?(prompt_type)

  lines << '---'
  lines << "Task type: #{prompt_type}"

  # INTELLIGENCE: Learning pattern warning
  if learning_warning
    lines << ''
    lines << "LEARNING WARNING: #{learning_warning}"
  end

  # INTELLIGENCE: Frustration detected
  if frustrations.any?
    lines << ''
    lines << 'FRUSTRATION DETECTED:'
    frustrations.each do |f|
      lines << "  Type: #{f[:type]} - User may be correcting you. Read carefully."
    end
  end

  # INTELLIGENCE: Requirements extracted
  if detected_reqs.any?
    lines << ''
    lines << 'REQUIREMENTS DETECTED:'
    detected_reqs.each do |r|
      lines << "  #{r} - Must be satisfied before editing"
    end
  end

  if triggers.any?
    lines << ''
    lines << 'PATTERN ALERT:'
    triggers.each do |t|
      lines << "  #{t[:word]}: #{t[:warning]}"
    end
  end

  if rules.any?
    lines << ''
    lines << 'Applicable rules:'
    rules.each { |r| lines << "  #{r}" }
  end

  lines << '---'

  # Output to stdout - this becomes context for Claude
  puts lines.join("\n")
end

def output_warning(prompt_type, rules, triggers, frustrations = [], detected_reqs = [])
  # Only show warnings for tasks (stderr shown to user)
  return if [:passthrough, :question].include?(prompt_type)

  warn '---'
  warn "SanePrompt: #{prompt_type.to_s.gsub('_', ' ').upcase}"

  # INTELLIGENCE: Show frustration warning to user
  if frustrations.any?
    warn ''
    warn 'Frustration detected - Claude will read carefully'
  end

  # INTELLIGENCE: Show detected requirements
  if detected_reqs.any?
    warn ''
    warn "Requirements: #{detected_reqs.join(', ')}"
  end

  if triggers.any?
    warn ''
    warn 'Pattern triggers detected:'
    triggers.each { |t| warn "  #{t[:word]} -> #{t[:warning]}" }
  end

  if rules.any?
    warn ''
    warn 'Rules to follow:'
    rules.first(3).each { |r| warn "  #{r}" }
  end

  warn '---'
end

# === MAIN PROCESSING ===

def process_prompt(prompt)
  # Handle safemode commands first
  if handle_safemode_command(prompt)
    return 0
  end

  prompt_type = classify_prompt(prompt)

  if prompt_type == :passthrough
    log_prompt(:passthrough, [], [])
    return 0
  end

  rules = rules_for_prompt(prompt)
  triggers = detect_triggers(prompt)

  # === INTELLIGENCE ===

  # 0. BUTT-KICKER: Check if ignoring previous warning
  butt_kick = check_ignored_warning(prompt)
  if butt_kick
    warn ''
    warn '=' * 50
    warn butt_kick
    warn '=' * 50
    warn ''
  end

  # 1. Detect frustration signals
  frustrations = detect_frustration(prompt)

  # 2. Extract and store requirements
  detected_reqs = extract_requirements(prompt)
  update_requirements(detected_reqs)

  # 3. Learn from frustration
  learn_from_frustration(prompt, frustrations)

  # 4. Check past learnings for patterns
  learning_warning = check_past_learnings

  # === END INTELLIGENCE ===

  log_prompt(prompt_type, rules, triggers)
  update_state(prompt_type, prompt_type == :big_task)

  # Output context to Claude (stdout)
  output_context(prompt_type, rules, triggers, prompt, frustrations, detected_reqs, learning_warning)

  # Output warning to user (stderr)
  output_warning(prompt_type, rules, triggers, frustrations, detected_reqs)

  0  # Always allow prompts
end

# === SELF-TEST ===

def self_test
  warn 'SanePrompt Self-Test'
  warn '=' * 40

  passed = 0
  failed = 0

  # === TEST COMMANDS FIRST (the ones that were never tested!) ===
  warn ''
  warn 'Testing commands:'

  # Test rb- resets circuit breaker
  StateManager.update(:circuit_breaker) { |cb| cb[:tripped] = true; cb[:failures] = 5; cb }
  original_stderr = $stderr.clone
  $stderr.reopen('/dev/null', 'w')
  result = handle_safemode_command('rb-')
  $stderr.reopen(original_stderr)
  cb_after = StateManager.get(:circuit_breaker)
  if result == true && cb_after[:tripped] == false && cb_after[:failures] == 0
    passed += 1
    warn '  PASS: rb- resets circuit breaker'
  else
    failed += 1
    warn "  FAIL: rb- - result=#{result}, tripped=#{cb_after[:tripped]}"
  end

  # Test rb? returns true
  $stderr.reopen('/dev/null', 'w')
  result = handle_safemode_command('rb?')
  $stderr.reopen(original_stderr)
  if result == true
    passed += 1
    warn '  PASS: rb? shows status'
  else
    failed += 1
    warn '  FAIL: rb? should return true'
  end

  # Test s- creates bypass file
  bypass_file = File.expand_path('../../.claude/bypass_active.json', __dir__)
  File.delete(bypass_file) if File.exist?(bypass_file)
  $stderr.reopen('/dev/null', 'w')
  handle_safemode_command('s-')
  $stderr.reopen(original_stderr)
  if File.exist?(bypass_file)
    passed += 1
    warn '  PASS: s- creates bypass file'
  else
    failed += 1
    warn '  FAIL: s- should create bypass file'
  end

  # Test s+ deletes bypass file
  $stderr.reopen('/dev/null', 'w')
  handle_safemode_command('s+')
  $stderr.reopen(original_stderr)
  if !File.exist?(bypass_file)
    passed += 1
    warn '  PASS: s+ deletes bypass file'
  else
    failed += 1
    warn '  FAIL: s+ should delete bypass file'
    File.delete(bypass_file) rescue nil
  end

  # === TEST JSON PARSING (the real production flow) ===
  warn ''
  warn 'Testing JSON parsing:'

  # Test correct JSON structure
  require 'open3'
  json_input = '{"session_id":"test","prompt":"rb?"}'
  stdout, stderr, status = Open3.capture3("ruby #{__FILE__}", stdin_data: json_input)
  if status.exitstatus == 0
    passed += 1
    warn '  PASS: JSON with prompt key parsed correctly'
  else
    failed += 1
    warn "  FAIL: JSON parsing failed - exit #{status.exitstatus}"
  end

  # Test missing prompt key defaults to empty
  json_input = '{"session_id":"test"}'
  stdout, stderr, status = Open3.capture3("ruby #{__FILE__}", stdin_data: json_input)
  if status.exitstatus == 0
    passed += 1
    warn '  PASS: Missing prompt key handled gracefully'
  else
    failed += 1
    warn "  FAIL: Missing prompt key should not crash"
  end

  # Test invalid JSON doesn't crash
  json_input = 'not valid json {'
  stdout, stderr, status = Open3.capture3("ruby #{__FILE__}", stdin_data: json_input)
  if status.exitstatus == 0
    passed += 1
    warn '  PASS: Invalid JSON handled gracefully'
  else
    failed += 1
    warn "  FAIL: Invalid JSON should exit 0, not crash"
  end

  warn ''
  warn 'Testing prompt classification:'

  tests = [
    # Passthroughs
    { input: 'y', expect: :passthrough },
    { input: 'yes', expect: :passthrough },
    { input: '/commit', expect: :passthrough },
    { input: '123', expect: :passthrough },
    { input: 'ok', expect: :passthrough },

    # Questions
    { input: 'what does this function do?', expect: :question },
    { input: 'how does the authentication work?', expect: :question },
    { input: 'can you explain the architecture?', expect: :question },
    { input: 'is this correct?', expect: :question },

    # Tasks
    { input: 'fix the bug in the login flow', expect: :task, rules: ['#3'] },
    { input: 'add a new feature for user auth', expect: :task, rules: ['#0'] },
    { input: 'refactor the database layer', expect: :task, rules: ['#4'] },
    { input: 'create a new file for settings', expect: :task, rules: ['#1'] },

    # Big tasks
    { input: 'rewrite the entire authentication system', expect: :big_task },
    { input: 'refactor everything in the core module', expect: :big_task },
    { input: 'update all the components to use new API', expect: :big_task },

    # Pattern triggers
    { input: 'quick fix for the login', expect: :task, trigger: 'quick' },
    { input: 'just add a button', expect: :task, trigger: 'just' },
    { input: 'simple change to the config', expect: :task, trigger: 'simple' },

    # INTELLIGENCE: Frustration detection
    { input: 'no, I said fix the login', expect: :task, frustration: :correction },
    { input: "that's not what I meant", expect: :question, frustration: :correction },
    { input: 'I just said fix it the other way again', expect: :task, frustration: :repetition },

    # INTELLIGENCE: Requirement extraction (classification may vary, requirement extraction is independent)
    { input: 'start a saneloop and fix the bug', expect: :task, requirement: 'saneloop' },
    { input: 'commit the changes after you fix it', expect: :task, requirement: 'commit' },
    { input: 'make a plan first then implement', expect: :task, requirement: 'plan' },
    { input: 'research this API then add the feature', expect: :task, requirement: 'research' },
  ]

  passed = 0
  failed = 0

  tests.each do |test|
    result_type = classify_prompt(test[:input])
    type_ok = result_type == test[:expect]

    rules_ok = true
    if test[:rules]
      result_rules = rules_for_prompt(test[:input])
      rules_ok = test[:rules].all? { |r| result_rules.any? { |rr| rr.include?(r) } }
    end

    trigger_ok = true
    if test[:trigger]
      triggers = detect_triggers(test[:input])
      trigger_ok = triggers.any? { |t| t[:word] == test[:trigger] }
    end

    # INTELLIGENCE: Frustration detection test
    frustration_ok = true
    if test[:frustration]
      frustrations = detect_frustration(test[:input])
      frustration_ok = frustrations.any? { |f| f[:type] == test[:frustration] }
    end

    # INTELLIGENCE: Requirement extraction test
    requirement_ok = true
    if test[:requirement]
      requirements = extract_requirements(test[:input])
      requirement_ok = requirements.include?(test[:requirement])
    end

    if type_ok && rules_ok && trigger_ok && frustration_ok && requirement_ok
      passed += 1
      warn "  PASS: '#{test[:input][0..40]}' -> #{result_type}"
    else
      failed += 1
      warn "  FAIL: '#{test[:input][0..40]}'"
      warn "        expected #{test[:expect]}, got #{result_type}" unless type_ok
      warn "        missing rule #{test[:rules]}" unless rules_ok
      warn "        missing trigger #{test[:trigger]}" unless trigger_ok
      warn "        missing frustration #{test[:frustration]}" unless frustration_ok
      warn "        missing requirement #{test[:requirement]}" unless requirement_ok
    end
  end

  warn ''
  warn "#{passed}/#{tests.length} tests passed"

  if failed == 0
    warn ''
    warn 'ALL TESTS PASSED'
    exit 0
  else
    warn ''
    warn "#{failed} TESTS FAILED"
    exit 1
  end
end

def check_heartbeat
  begin
    last_line = File.readlines(LOG_FILE).last
    entry = JSON.parse(last_line)
    last = Time.parse(entry['timestamp'])
    age = Time.now - last
    warn "Last prompt: #{entry['type']} at #{entry['timestamp']} (#{age.round}s ago)"
    exit(age < 300 ? 0 : 1)
  rescue StandardError => e
    warn "No heartbeat: #{e.message}"
    exit 1
  end
end

# === DEBUG LOGGING ===
DEBUG_FILE = File.expand_path('../../.claude/saneprompt_debug.log', __dir__)

def debug_log(msg)
  FileUtils.mkdir_p(File.dirname(DEBUG_FILE))
  File.open(DEBUG_FILE, 'a') { |f| f.puts("[#{Time.now.iso8601}] #{msg}") }
rescue StandardError
  # ignore
end

# === MAIN ===

if ARGV.include?('--self-test')
  self_test
elsif ARGV.include?('--check-heartbeat')
  check_heartbeat
else
  begin
    raw = $stdin.read
    debug_log("RAW INPUT: #{raw[0..200]}")
    input = JSON.parse(raw)
    debug_log("PARSED KEYS: #{input.keys.inspect}")
    prompt = input['prompt'] || input['user_prompt'] || ''
    debug_log("EXTRACTED PROMPT: '#{prompt}'")
    exit process_prompt(prompt)
  rescue JSON::ParserError, Errno::ENOENT => e
    debug_log("PARSE ERROR: #{e.message}")
    exit 0  # Don't block on parse errors
  end
end
