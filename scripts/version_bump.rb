#!/usr/bin/env ruby
# frozen_string_literal: true

#
# SaneProcess Version Bump
# Updates version strings across all files
#
# Usage:
#   ruby scripts/version_bump.rb          # Show current version
#   ruby scripts/version_bump.rb 2.3      # Bump to 2.3
#

require 'date'

class VersionBump
  FILES = {
    'README.md' => /(\*SaneProcess v)(\d+\.\d+)( - )/,
    'docs/SaneProcess.md' => /(\*SaneProcess v)(\d+\.\d+)( - )/,
    'scripts/init.sh' => /(# Version )(\d+\.\d+)( - )/
  }.freeze

  def initialize(root = File.expand_path('..', __dir__))
    @root = root
  end

  def current_version
    versions = {}
    FILES.each do |file, pattern|
      path = File.join(@root, file)
      next unless File.exist?(path)

      content = File.read(path)
      if (match = content.match(pattern))
        versions[file] = match[2]
      end
    end
    versions
  end

  def show
    versions = current_version
    if versions.empty?
      puts "No version strings found"
      return
    end

    unique = versions.values.uniq
    if unique.count == 1
      puts "Current version: #{unique.first}"
    else
      puts "Version mismatch:"
      versions.each { |f, v| puts "  #{f}: #{v}" }
    end
  end

  def bump(new_version)
    unless new_version.match?(/^\d+\.\d+$/)
      puts "Invalid version format. Use X.Y (e.g., 2.3)"
      return false
    end

    current = current_version
    if current.empty?
      puts "No version strings found to update"
      return false
    end

    puts "Bumping version to #{new_version}..."
    puts

    FILES.each do |file, pattern|
      path = File.join(@root, file)
      next unless File.exist?(path)

      content = File.read(path)

      # Also update date if present
      updated = content.gsub(pattern) do
        "#{Regexp.last_match(1)}#{new_version}#{Regexp.last_match(3)}"
      end

      # Update month/year references
      current_month_year = Date.today.strftime('%B %Y')
      updated.gsub!(/January 2026|February 2026|March 2026/, current_month_year)

      if updated != content
        File.write(path, updated)
        puts "  ✅ #{file}"
      else
        puts "  ⏭️  #{file} (no change)"
      end
    end

    puts
    puts "Done! Run 'ruby scripts/qa.rb' to verify."
    true
  end
end

# CLI
if __FILE__ == $PROGRAM_NAME
  bumper = VersionBump.new

  if ARGV.empty?
    bumper.show
  else
    bumper.bump(ARGV[0])
  end
end
