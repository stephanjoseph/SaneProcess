#!/usr/bin/env ruby
# frozen_string_literal: true

#
# SaneProcess License Key Generator
# Generates valid license keys for customers
#
# Usage:
#   ruby scripts/license_gen.rb              # Generate 1 key
#   ruby scripts/license_gen.rb 5            # Generate 5 keys
#   ruby scripts/license_gen.rb --validate SP-XXXX-XXXX-XXXX-XXXX
#

require 'digest'
require 'securerandom'

class LicenseGenerator
  # Key format: SP-XXXX-XXXX-XXXX-XXXX
  # Last segment is SHA256 checksum of first 4 segments + salt

  SALT = 'SaneProcess2026'
  CHARS = ('A'..'Z').to_a + ('0'..'9').to_a

  def generate
    # Generate 4 random segments
    segments = 4.times.map { random_segment }
    data = "SP-#{segments.join('-')}"

    # Calculate checksum
    checksum = Digest::SHA256.hexdigest("#{data}#{SALT}")[0..3].upcase

    "#{data}-#{checksum}"
  end

  def validate(key)
    # Check format: SP-XXXX-XXXX-XXXX-XXXX-XXXX (5 segments after SP-)
    unless key.match?(/^SP-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/)
      return { valid: false, error: 'Invalid format' }
    end

    # Extract parts: SP + 4 data segments + 1 checksum
    parts = key.split('-')
    data = parts[0..4].join('-')  # SP-XXXX-XXXX-XXXX-XXXX
    checksum = parts[5]           # Last segment is checksum

    # Verify checksum
    expected = Digest::SHA256.hexdigest("#{data}#{SALT}")[0..3].upcase

    if checksum == expected
      { valid: true }
    else
      { valid: false, error: 'Invalid checksum' }
    end
  end

  private

  def random_segment
    4.times.map { CHARS.sample }.join
  end
end

# CLI
if __FILE__ == $PROGRAM_NAME
  gen = LicenseGenerator.new

  if ARGV[0] == '--validate'
    key = ARGV[1]
    if key.nil?
      puts 'Usage: ruby license_gen.rb --validate SP-XXXX-XXXX-XXXX-XXXX'
      exit 1
    end

    result = gen.validate(key)
    if result[:valid]
      puts "✅ Valid license key"
      exit 0
    else
      puts "❌ Invalid: #{result[:error]}"
      exit 1
    end
  else
    count = (ARGV[0] || 1).to_i
    count = 1 if count < 1
    count = 100 if count > 100

    if count == 1
      # Single key - just output the key for scripting
      puts gen.generate
    else
      puts "Generated #{count} license keys:"
      puts
      count.times { puts gen.generate }
    end
  end
end
