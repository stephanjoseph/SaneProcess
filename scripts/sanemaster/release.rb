# frozen_string_literal: true

module SaneMasterModules
  # Unified release entrypoint (delegates to SaneProcess release.sh)
  module Release
    def release(args)
      release_script = File.expand_path('../release.sh', __dir__)
      unless File.exist?(release_script)
        puts "❌ Release script not found: #{release_script}"
        exit 1
      end

      cmd = [release_script]
      unless args.include?('--project')
        cmd += ['--project', Dir.pwd]
      end
      cmd.concat(args)

      puts '🚀 --- [ SANEMASTER RELEASE ] ---'
      puts "Using: #{release_script}"
      puts "Project: #{Dir.pwd}" unless args.include?('--project')
      puts ''

      exec(*cmd)
    end
  end
end
