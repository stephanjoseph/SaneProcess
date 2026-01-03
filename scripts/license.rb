#!/usr/bin/env ruby
# frozen_string_literal: true

# SaneProcess License Validation
# Copyright (c) 2026 Stephan Joseph. All Rights Reserved.
#
# This software requires a valid license for any use.
# Purchase: stephanjoseph2007@gmail.com

require 'digest'
require 'fileutils'
require 'json'
require 'date'

module SaneProcess
  class License
    LICENSE_DIR = File.expand_path('~/.saneprocess')
    LICENSE_FILE = File.join(LICENSE_DIR, 'license.key')
    VALIDATION_URL = 'https://saneprocess.dev/api/validate'
    
    # License key format: SP-XXXX-XXXX-XXXX-XXXX
    KEY_PATTERN = /^SP-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/
    
    # Salt for offline validation (rotate periodically)
    SALT = 'SaneProcess2026'
    
    class << self
      def validate!
        key = find_license_key
        
        if key.nil?
          show_no_license_error
          exit 1
        end
        
        unless valid_format?(key)
          show_invalid_format_error
          exit 1
        end
        
        unless valid_key?(key)
          show_invalid_key_error
          exit 1
        end
        
        # Check expiration for time-limited licenses
        if expired?(key)
          show_expired_error
          exit 1
        end
        
        true
      end
      
      def activate(key)
        unless valid_format?(key)
          puts "\033[31m❌ Invalid license key format\033[0m"
          puts "   Expected: SP-XXXX-XXXX-XXXX-XXXX"
          return false
        end
        
        unless valid_key?(key)
          puts "\033[31m❌ Invalid license key\033[0m"
          puts "   Please check your key or contact stephanjoseph2007@gmail.com"
          return false
        end
        
        FileUtils.mkdir_p(LICENSE_DIR)
        File.write(LICENSE_FILE, key.strip)
        File.chmod(0600, LICENSE_FILE)
        
        puts "\033[32m✅ License activated successfully!\033[0m"
        puts "   License stored in: #{LICENSE_FILE}"
        true
      end
      
      def info
        key = find_license_key
        return puts "No license found" unless key
        
        type = license_type(key)
        puts "License: #{mask_key(key)}"
        puts "Type: #{type}"
        puts "Status: #{valid_key?(key) ? '✅ Valid' : '❌ Invalid'}"
      end
      
      private
      
      def find_license_key
        # Check environment variable first
        return ENV['SANEPROCESS_LICENSE'] if ENV['SANEPROCESS_LICENSE']
        
        # Check license file
        return File.read(LICENSE_FILE).strip if File.exist?(LICENSE_FILE)
        
        nil
      end
      
      def valid_format?(key)
        key.match?(KEY_PATTERN)
      end
      
      def valid_key?(key)
        # Extract components
        parts = key.split('-')
        return false unless parts.length == 5
        
        prefix = parts[0]     # SP
        type_code = parts[1]  # License type (encoded)
        user_id = parts[2]    # User identifier
        date_code = parts[3]  # Issue date (encoded)
        checksum = parts[4]   # Validation checksum
        
        # Validate checksum
        data = "#{prefix}-#{type_code}-#{user_id}-#{date_code}"
        expected_checksum = generate_checksum(data)
        
        checksum == expected_checksum
      end
      
      def generate_checksum(data)
        Digest::SHA256.hexdigest("#{data}#{SALT}")[0, 4].upcase
      end
      
      def license_type(key)
        type_code = key.split('-')[1]
        case type_code[0]
        when 'P' then 'Personal'
        when 'C' then 'Commercial'
        when 'E' then 'Enterprise'
        when 'T' then 'Trial'
        else 'Standard'
        end
      end
      
      def expired?(key)
        # Trial licenses (T prefix) expire after 14 days
        type_code = key.split('-')[1]
        return false unless type_code.start_with?('T')
        
        date_code = key.split('-')[3]
        # Date is encoded as days since 2026-01-01
        begin
          days = date_code.to_i(36)
          issue_date = Date.new(2026, 1, 1) + days
          Date.today > issue_date + 14
        rescue
          true # If we can't parse, assume expired
        end
      end
      
      def mask_key(key)
        parts = key.split('-')
        "SP-#{parts[1]}-****-****-#{parts[4]}"
      end
      
      def show_no_license_error
        puts <<~ERROR
        
        \033[31m╔═══════════════════════════════════════════════════════════════╗
        ║                    LICENSE REQUIRED                           ║
        ╚═══════════════════════════════════════════════════════════════╝\033[0m
        
        SaneProcess requires a valid license for any use.
        
        \033[33mTo purchase a license:\033[0m
           Email: stephanjoseph2007@gmail.com
        
        \033[33mTo activate your license:\033[0m
           ./scripts/license.rb activate SP-XXXX-XXXX-XXXX-XXXX
        
        \033[33mOr set environment variable:\033[0m
           export SANEPROCESS_LICENSE=SP-XXXX-XXXX-XXXX-XXXX
        
        ERROR
      end
      
      def show_invalid_format_error
        puts <<~ERROR
        
        \033[31m❌ Invalid license key format\033[0m
        
        Expected format: SP-XXXX-XXXX-XXXX-XXXX
        
        Please check your license key or contact:
           stephanjoseph2007@gmail.com
        
        ERROR
      end
      
      def show_invalid_key_error
        puts <<~ERROR
        
        \033[31m❌ Invalid license key\033[0m
        
        This license key is not valid. Possible reasons:
           • Typo in the license key
           • License has been revoked
           • Key was generated incorrectly
        
        Please contact: stephanjoseph2007@gmail.com
        
        ERROR
      end
      
      def show_expired_error
        puts <<~ERROR
        
        \033[31m❌ License has expired\033[0m
        
        Your trial license has expired.
        
        To purchase a full license:
           Email: stephanjoseph2007@gmail.com
        
        ERROR
      end
    end
  end
end

# CLI interface
if __FILE__ == $0
  case ARGV[0]
  when 'activate'
    if ARGV[1]
      SaneProcess::License.activate(ARGV[1])
    else
      puts "Usage: #{$0} activate SP-XXXX-XXXX-XXXX-XXXX"
    end
  when 'validate'
    SaneProcess::License.validate!
    puts "\033[32m✅ License is valid\033[0m"
  when 'info'
    SaneProcess::License.info
  when 'generate'
    # Hidden command for generating keys (owner only)
    if ARGV[1] == ENV['SANEPROCESS_ADMIN_SECRET']
      type = ARGV[2] || 'P' # P=Personal, C=Commercial, E=Enterprise, T=Trial
      user = ARGV[3] || SecureRandom.hex(2).upcase
      days = (Date.today - Date.new(2026, 1, 1)).to_i
      date_code = days.to_s(36).upcase.rjust(4, '0')
      type_code = "#{type}#{SecureRandom.hex(1).upcase}#{SecureRandom.hex(1).upcase[0]}"
      
      data = "SP-#{type_code}-#{user.upcase.ljust(4, '0')[0,4]}-#{date_code}"
      checksum = Digest::SHA256.hexdigest("#{data}SaneProcess2026")[0, 4].upcase
      
      puts "#{data}-#{checksum}"
    else
      puts "Unauthorized"
    end
  else
    puts <<~USAGE
    SaneProcess License Manager
    
    Usage:
      #{$0} activate SP-XXXX-XXXX-XXXX-XXXX   Activate a license
      #{$0} validate                           Check current license
      #{$0} info                               Show license info
    
    Purchase: stephanjoseph2007@gmail.com
    USAGE
  end
end
