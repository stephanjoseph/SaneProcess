# frozen_string_literal: true

# Structural Compliance Checker
# Deterministic infrastructure checks — run from any project, get pass/fail with fix instructions.
#
# Usage:
#   SaneMaster.rb structural [path]   — run structural checks (path defaults to cwd)
#   SaneMaster.rb compliance [path]   — structural + session compliance

require 'yaml'
require 'json'

module SaneMasterModules
  module StructuralCompliance
    STANDARD_DOCS = %w[CLAUDE.md README.md DEVELOPMENT.md ARCHITECTURE.md SESSION_HANDOFF.md].freeze

    EXPECTED_HOOKS = {
      'SessionStart' => 'session_start.rb',
      'UserPromptSubmit' => 'saneprompt.rb',
      'PreToolUse' => 'sanetools.rb',
      'PostToolUse' => 'sanetrack.rb',
      'Stop' => 'sanestop.rb'
    }.freeze

    SANEPROCESS_DIR = File.expand_path('~/SaneApps/infra/SaneProcess')
    GLOBAL_SETTINGS = File.expand_path('~/.claude/settings.json')
    PLUGIN_CACHE = File.expand_path('~/.claude/plugins/cache/thedotmack/claude-mem')

    Result = Struct.new(:pass, :label, :detail, :fix, keyword_init: true)

    def run_structural_compliance(args)
      path = args.first || Dir.pwd
      path = File.expand_path(path)

      unless File.directory?(path)
        warn "#{path} is not a directory"
        exit 1
      end

      checker = ComplianceChecker.new(path)
      checker.run
      checker.print_report
      exit 1 if checker.errors?
    end

    class ComplianceChecker
      attr_reader :results

      def initialize(path)
        @path = path
        @manifest = nil
        @project_name = File.basename(path)
        @results = { critical: [], config: [], practice: [] }
      end

      def run
        # Tier 1: Critical
        check_manifest
        check_required_docs
        check_hook_registration
        check_no_local_hooks

        # Tier 2: Configuration
        check_clean_project_settings
        check_plugin_cache
        check_commands_runnable
        check_xcode_project

        # Tier 3: Best practices
        check_mcp_consistency
        check_website_config
      end

      def errors?
        @results[:critical].any? { |r| !r.pass }
      end

      def print_report
        puts ''
        puts '═' * 45
        puts "  Structural Compliance: #{@project_name}"
        puts '═' * 45
        puts ''

        print_tier('CRITICAL', @results[:critical])
        print_tier('CONFIGURATION', @results[:config])
        print_tier('BEST PRACTICES', @results[:practice])

        error_count = @results[:critical].count { |r| !r.pass }
        warn_count = @results[:config].count { |r| !r.pass }
        info_count = @results[:practice].count { |r| !r.pass }

        puts '═' * 45
        parts = []
        parts << "#{error_count} error#{'s' if error_count != 1}" if error_count > 0
        parts << "#{warn_count} warning#{'s' if warn_count != 1}" if warn_count > 0
        parts << "#{info_count} info" if info_count > 0
        if parts.empty?
          puts 'RESULT: All checks passed'
        else
          puts "RESULT: #{parts.join(', ')}"
        end
        puts '═' * 45
        puts ''
      end

      private

      def resolve_path(path_str)
        expanded = path_str.start_with?('/') ? path_str : File.join(@path, path_str)
        File.expand_path(expanded.gsub('~', Dir.home))
      end

      def system_binary?(name)
        return false if name.nil? || name.empty? || name.include?(File::SEPARATOR)
        return false if name.start_with?('.')

        ENV['PATH'].split(File::PATH_SEPARATOR).any? do |dir|
          exe = File.join(dir, name)
          File.executable?(exe) && !File.directory?(exe)
        end
      end

      def print_tier(name, results)
        icon = case name
               when 'CRITICAL' then "\u{1F4CB}"
               when 'CONFIGURATION' then "\u{2699}\uFE0F "
               when 'BEST PRACTICES' then "\u{1F4CA}"
               end
        puts "#{icon} #{name}"
        results.each do |r|
          status = r.pass ? "\u{2705}" : (name == 'CRITICAL' ? "\u{274C}" : "\u{26A0}\uFE0F ")
          puts "  #{status} #{r.label}#{r.detail ? " (#{r.detail})" : ''}"
          puts "      FIX: #{r.fix}" if !r.pass && r.fix
        end
        puts ''
      end

      # === Tier 1: Critical ===

      def check_manifest
        manifest_path = File.join(@path, '.saneprocess')

        unless File.exist?(manifest_path)
          @results[:critical] << Result.new(
            pass: false, label: 'Manifest valid',
            detail: '.saneprocess missing',
            fix: "Create #{manifest_path} — see SaneProcess/templates/"
          )
          return
        end

        begin
          @manifest = YAML.safe_load(File.read(manifest_path))
        rescue Psych::SyntaxError => e
          @results[:critical] << Result.new(
            pass: false, label: 'Manifest valid',
            detail: "YAML parse error: #{e.message.split("\n").first}",
            fix: 'Fix YAML syntax in .saneprocess'
          )
          return
        end

        missing_fields = %w[name type commands docs].reject { |f| @manifest&.key?(f) }
        if missing_fields.any?
          @results[:critical] << Result.new(
            pass: false, label: 'Manifest valid',
            detail: "missing fields: #{missing_fields.join(', ')}",
            fix: 'Add required fields to .saneprocess'
          )
          return
        end

        @project_name = @manifest['name']
        @results[:critical] << Result.new(pass: true, label: 'Manifest valid')
      end

      def check_required_docs
        unless @manifest
          @results[:critical] << Result.new(pass: false, label: 'Docs present', detail: 'skipped — no manifest')
          return
        end

        required = @manifest['docs'] || STANDARD_DOCS
        present = required.select { |doc| File.exist?(File.join(@path, doc)) && !File.zero?(File.join(@path, doc)) }
        missing = required - present

        if missing.empty?
          @results[:critical] << Result.new(pass: true, label: 'Docs present', detail: "#{present.count}/#{required.count}")
        else
          @results[:critical] << Result.new(
            pass: false, label: 'Docs present',
            detail: "#{present.count}/#{required.count}, missing: #{missing.join(', ')}",
            fix: "Create missing docs: #{missing.join(', ')}"
          )
        end
      end

      def check_hook_registration
        unless File.exist?(GLOBAL_SETTINGS)
          @results[:critical] << Result.new(
            pass: false, label: 'Hooks registered',
            detail: 'global settings.json missing',
            fix: "Create #{GLOBAL_SETTINGS}"
          )
          return
        end

        begin
          settings = JSON.parse(File.read(GLOBAL_SETTINGS))
        rescue JSON::ParserError
          @results[:critical] << Result.new(
            pass: false, label: 'Hooks registered',
            detail: 'settings.json parse error',
            fix: 'Fix JSON syntax in ~/.claude/settings.json'
          )
          return
        end

        hooks_section = settings['hooks'] || {}
        missing = []
        no_guard = []

        EXPECTED_HOOKS.each do |hook_type, hook_file|
          entries = hooks_section[hook_type] || []
          found = false
          guarded = false

          entries.each do |entry|
            (entry['hooks'] || []).each do |hook|
              cmd = hook['command'] || ''
              if cmd.include?(hook_file)
                found = true
                guarded = true if cmd.include?('.saneprocess')
              end
            end
          end

          missing << hook_file unless found
          no_guard << hook_file if found && !guarded
        end

        if missing.empty? && no_guard.empty?
          @results[:critical] << Result.new(
            pass: true, label: 'Hooks registered',
            detail: "global, #{EXPECTED_HOOKS.count}/#{EXPECTED_HOOKS.count}"
          )
        elsif missing.any?
          @results[:critical] << Result.new(
            pass: false, label: 'Hooks registered',
            detail: "missing: #{missing.join(', ')}",
            fix: 'Register hooks in ~/.claude/settings.json with .saneprocess guard'
          )
        else
          @results[:critical] << Result.new(
            pass: false, label: 'Hooks registered',
            detail: "no .saneprocess guard: #{no_guard.join(', ')}",
            fix: 'Add [ -f .saneprocess ] guard to hook commands'
          )
        end
      end

      def check_no_local_hooks
        # SaneProcess itself is the canonical location — skip this check
        if @path == SANEPROCESS_DIR
          @results[:critical] << Result.new(pass: true, label: 'No local hook copies', detail: 'SaneProcess — canonical')
          return
        end

        local_hooks_dir = File.join(@path, 'scripts', 'hooks')
        hook_files = EXPECTED_HOOKS.values.select { |f| File.exist?(File.join(local_hooks_dir, f)) }

        if hook_files.empty?
          @results[:critical] << Result.new(pass: true, label: 'No local hook copies')
        else
          @results[:critical] << Result.new(
            pass: false, label: 'No local hook copies',
            detail: "found in scripts/hooks/: #{hook_files.join(', ')}",
            fix: "Delete local hooks — centralized hooks run from #{SANEPROCESS_DIR}"
          )
        end
      end

      # === Tier 2: Configuration ===

      def check_clean_project_settings
        project_settings = File.join(@path, '.claude', 'settings.json')
        unless File.exist?(project_settings)
          @results[:config] << Result.new(pass: true, label: 'Project settings clean', detail: 'no project settings.json')
          return
        end

        begin
          settings = JSON.parse(File.read(project_settings))
        rescue JSON::ParserError
          @results[:config] << Result.new(
            pass: false, label: 'Project settings clean',
            detail: 'settings.json parse error',
            fix: 'Fix JSON syntax in .claude/settings.json'
          )
          return
        end

        issues = []

        # Check for hooks duplication (causes double-firing of every hook)
        if settings.key?('hooks')
          hook_types = (settings['hooks'] || {}).keys
          issues << "hooks duplicated (#{hook_types.join(', ')}) — causes double-firing"
        end

        # Check for permissions/plugins that mirror global exactly (noise, no value)
        if File.exist?(GLOBAL_SETTINGS)
          begin
            global = JSON.parse(File.read(GLOBAL_SETTINGS))

            if settings.key?('permissions') && settings['permissions'] == global['permissions']
              issues << 'permissions identical to global'
            end

            if settings.key?('enabledPlugins') && settings['enabledPlugins'] == global['enabledPlugins']
              issues << 'enabledPlugins identical to global'
            end
          rescue JSON::ParserError
            # Skip comparison if global can't be parsed
          end
        end

        if issues.empty?
          @results[:config] << Result.new(pass: true, label: 'Project settings clean')
        else
          @results[:config] << Result.new(
            pass: false, label: 'Project settings clean',
            detail: issues.join('; '),
            fix: 'Remove duplicated sections from .claude/settings.json — hooks/permissions/plugins are global. NOTE: Claude Code may auto-sync hooks back; verify after restart.'
          )
        end
      end

      def check_plugin_cache
        unless File.directory?(PLUGIN_CACHE)
          @results[:config] << Result.new(
            pass: false, label: 'Plugin cache',
            detail: 'claude-mem directory missing',
            fix: "mkdir -p #{PLUGIN_CACHE}"
          )
          return
        end

        # Find any symlink version dir inside
        symlinks = Dir.glob(File.join(PLUGIN_CACHE, '*')).select { |f| File.symlink?(f) }
        if symlinks.empty?
          @results[:config] << Result.new(
            pass: false, label: 'Plugin cache',
            detail: 'claude-mem symlink missing',
            fix: "ln -s ~/Dev/claude-mem-local/plugin #{PLUGIN_CACHE}/<version>"
          )
          return
        end

        # Check symlink target is valid
        broken = symlinks.reject { |s| File.exist?(s) }
        if broken.any?
          @results[:config] << Result.new(
            pass: false, label: 'Plugin cache',
            detail: 'claude-mem symlink broken',
            fix: "Fix symlink target: #{broken.first} -> #{File.readlink(broken.first)}"
          )
        else
          @results[:config] << Result.new(pass: true, label: 'Plugin cache', detail: 'claude-mem linked')
        end
      end

      def check_commands_runnable
        unless @manifest && @manifest['commands'].is_a?(Hash)
          @results[:config] << Result.new(pass: true, label: 'Commands runnable', detail: 'skipped — no commands')
          return
        end

        commands = @manifest['commands']
        missing = []

        commands.each do |name, cmd|
          parts = cmd.to_s.split
          executable = parts.first
          next if executable.nil? || executable.empty?

          # Skip system binaries (found in PATH)
          next if system_binary?(executable)

          # For interpreter commands (ruby/bash/sh), check the script argument
          if %w[ruby bash sh].include?(executable)
            script_arg = parts[1]
            next unless script_arg

            resolved = resolve_path(script_arg)
            missing << name unless File.exist?(resolved)
          else
            resolved = resolve_path(executable)
            missing << name unless File.exist?(resolved)
          end
        end

        total = commands.count
        if missing.empty?
          @results[:config] << Result.new(pass: true, label: 'Commands runnable', detail: "#{total}/#{total}")
        else
          @results[:config] << Result.new(
            pass: false, label: 'Commands runnable',
            detail: "missing: #{missing.join(', ')}",
            fix: "Create missing scripts for: #{missing.join(', ')}"
          )
        end
      end

      def check_xcode_project
        return unless @manifest && @manifest['type'] == 'macos_app'

        project = @manifest['project']
        scheme = @manifest['scheme']

        unless project
          @results[:config] << Result.new(
            pass: false, label: 'Xcode valid',
            detail: 'project field missing in manifest',
            fix: 'Add project: YourApp.xcodeproj to .saneprocess'
          )
          return
        end

        project_path = File.join(@path, project)
        unless File.exist?(project_path)
          @results[:config] << Result.new(
            pass: false, label: 'Xcode valid',
            detail: "#{project} not found",
            fix: "Ensure #{project} exists or update .saneprocess"
          )
          return
        end

        if scheme
          @results[:config] << Result.new(pass: true, label: 'Xcode valid', detail: project)
        else
          @results[:config] << Result.new(
            pass: false, label: 'Xcode valid',
            detail: 'scheme field missing',
            fix: 'Add scheme: YourApp to .saneprocess'
          )
        end
      end

      # === Tier 3: Best practices ===

      def check_mcp_consistency
        return unless @manifest && @manifest['mcps'].is_a?(Array)

        unless File.exist?(GLOBAL_SETTINGS)
          @results[:practice] << Result.new(pass: true, label: 'MCPs consistent', detail: 'skipped — no global settings')
          return
        end

        begin
          settings = JSON.parse(File.read(GLOBAL_SETTINGS))
        rescue JSON::ParserError
          @results[:practice] << Result.new(pass: true, label: 'MCPs consistent', detail: 'skipped — parse error')
          return
        end

        # Extract MCP names from permissions (mcp__name__*)
        allowed = (settings.dig('permissions', 'allow') || [])
        global_mcps = allowed.select { |p| p.start_with?('mcp__') }
                             .map { |p| p.match(/^mcp__([^_]+)__/)[1] rescue nil }
                             .compact.uniq

        manifest_mcps = @manifest['mcps']
        missing = manifest_mcps - global_mcps

        if missing.empty?
          @results[:practice] << Result.new(
            pass: true, label: 'MCPs consistent',
            detail: "#{manifest_mcps.count}/#{manifest_mcps.count}"
          )
        else
          @results[:practice] << Result.new(
            pass: false, label: 'MCPs consistent',
            detail: "not in global permissions: #{missing.join(', ')}",
            fix: "Add mcp__#{missing.first}__* to ~/.claude/settings.json permissions"
          )
        end
      end

      def check_website_config
        return unless @manifest

        has_website = @manifest['website'] == true
        return unless has_website

        domain = @manifest['website_domain']
        if domain && !domain.empty?
          @results[:practice] << Result.new(pass: true, label: 'Website config complete')
        else
          @results[:practice] << Result.new(
            pass: false, label: 'Website config complete',
            detail: 'website: true but no website_domain',
            fix: 'Add website_domain: yourdomain.com to .saneprocess'
          )
        end
      end
    end
  end
end
