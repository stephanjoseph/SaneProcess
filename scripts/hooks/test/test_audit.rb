#!/usr/bin/env ruby
# frozen_string_literal: true

# Test Audit: Scan test files for assertion strength
#
# Classifies each test as Strong or Weak:
#   Strong: has expected_exit != default, expected_output, expected_not_output, or state_check
#   Weak: only checks expected_exit matching hook default (0)
#
# Run: ruby scripts/hooks/test/test_audit.rb

TIER_TEST_FILE = File.join(__dir__, 'tier_tests.rb')

# Hooks and their default exit codes
HOOK_DEFAULTS = {
  'saneprompt' => 0,
  'sanetools' => 0,
  'sanetrack' => 0,
  'sanestop' => 0
}.freeze

def audit_tests(file_path)
  content = File.read(file_path)
  results = {}
  current_suite = nil

  # Track which suite we're in
  content.each_line.with_index(1) do |line, line_num|
    # Detect suite start
    if (match = line.match(/def test_(\w+)/))
      current_suite = match[1]
      results[current_suite] = { strong: 0, weak: 0, tests: [] }
      next
    end

    next unless current_suite
    next unless line.match?(/t\.test\(/)

    # Extract test name
    name_match = line.match(/t\.test\([^,]+,\s*["']([^"']+)["']/)
    name = name_match ? name_match[1] : "line #{line_num}"

    # Read the full test block (may span multiple lines)
    # Look for assertion parameters in nearby lines
    block_start = line_num - 1
    block_end = [block_start + 5, content.lines.length - 1].min
    block_lines = content.lines[block_start..block_end].join

    # Check for real assertions
    has_expected_output = block_lines.match?(/expected_output:\s*['"]/)
    has_expected_not_output = block_lines.match?(/expected_not_output:\s*['"]/)
    has_state_check = block_lines.match?(/state_check:/)
    has_non_default_exit = false

    if (exit_match = block_lines.match(/expected_exit:\s*(\d+)/))
      exit_code = exit_match[1].to_i
      default = HOOK_DEFAULTS[current_suite] || 0
      has_non_default_exit = exit_code != default
    end

    is_strong = has_expected_output || has_expected_not_output ||
                has_state_check || has_non_default_exit

    if is_strong
      results[current_suite][:strong] += 1
    else
      results[current_suite][:weak] += 1
      results[current_suite][:tests] << { name: name, line: line_num }
    end
  end

  results
end

def print_report(results)
  total_strong = 0
  total_weak = 0

  warn "=" * 60
  warn "TEST ASSERTION AUDIT"
  warn "=" * 60

  results.each do |suite, data|
    total = data[:strong] + data[:weak]
    total_strong += data[:strong]
    total_weak += data[:weak]

    status = data[:weak] == 0 ? '✅' : '⚠️'
    warn ""
    warn "#{status} #{suite}: #{data[:strong]} strong, #{data[:weak]} weak (#{total} total)"

    next if data[:tests].empty?

    data[:tests].each do |t|
      warn "   ⚠️  #{t[:name]} (line #{t[:line]})"
    end
  end

  warn ""
  warn "=" * 60
  grand_total = total_strong + total_weak
  warn "TOTAL: #{total_strong} strong, #{total_weak} weak (#{grand_total} unique call sites)"
  warn "NOTE: .each loops expand at runtime — run tier_tests.rb for exact counts"

  if total_weak > 0
    pct = ((total_strong.to_f / grand_total) * 100).round(1)
    warn "Assertion coverage: #{pct}%"
    warn ""
    warn "Weak tests only check default exit code — no behavioral verification."
    warn "Fix: add expected_output:, expected_not_output:, or state_check:"
  else
    warn "All tests have real assertions."
  end
  warn "=" * 60

  total_weak
end

if __FILE__ == $PROGRAM_NAME
  unless File.exist?(TIER_TEST_FILE)
    warn "ERROR: #{TIER_TEST_FILE} not found"
    exit 1
  end

  results = audit_tests(TIER_TEST_FILE)
  weak_count = print_report(results)
  exit(weak_count > 0 ? 1 : 0)
end
