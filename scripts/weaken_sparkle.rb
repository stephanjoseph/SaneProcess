#!/usr/bin/env ruby
# frozen_string_literal: true

# weaken_sparkle.rb — Patch Sparkle's load command from LC_LOAD_DYLIB to LC_LOAD_WEAK_DYLIB
#
# SPM links Sparkle unconditionally for all build configurations. When building
# for App Store (where Sparkle.framework is stripped from the bundle), the binary
# still has a strong @rpath/Sparkle.framework load command, causing dyld to crash
# on launch ("Library not loaded").
#
# This script changes the load command type from LC_LOAD_DYLIB (0x0C) to
# LC_LOAD_WEAK_DYLIB (0x80000018), which tells dyld to skip the framework
# if missing instead of crashing. Combined with #if !APP_STORE guards in code,
# no Sparkle code paths are reachable, making this safe.
#
# Usage: ruby weaken_sparkle.rb /path/to/binary
#
# Called by release.sh after App Store archive, before export.

LC_LOAD_DYLIB      = 0x0000000C
LC_LOAD_WEAK_DYLIB = 0x80000018
SPARKLE_DYLIB_NAME = "@rpath/Sparkle.framework/Versions/B/Sparkle"

binary_path = ARGV[0]

unless binary_path && File.exist?(binary_path)
  warn "Usage: ruby weaken_sparkle.rb /path/to/binary"
  exit 1
end

data = File.binread(binary_path)

# Find every Sparkle dylib name string in the binary (fat binaries can have one per slice)
first_offset = data.index(SPARKLE_DYLIB_NAME)
unless first_offset
  warn "No Sparkle dylib reference found in binary — nothing to patch."
  exit 0
end

# The dylib_command structure:
#   cmd      (4 bytes) — LC_LOAD_DYLIB or LC_LOAD_WEAK_DYLIB
#   cmdsize  (4 bytes)
#   name     (4 bytes) — offset from cmd start to the string
#   timestamp(4 bytes)
#   current  (4 bytes)
#   compat   (4 bytes)
# Total header: 24 bytes, then the name string follows.
#
# The name field is an offset from the start of the load command to the string.
# Walk backwards from the string to find the matching LC_LOAD_DYLIB command.

patched_count = 0
already_weak_count = 0
search_from = 0

while (str_offset = data.index(SPARKLE_DYLIB_NAME, search_from))
  search_from = str_offset + SPARKLE_DYLIB_NAME.bytesize
  patched_for_this_reference = false

  (24..1024).each do |offset|
    cmd_start = str_offset - offset
    next if cmd_start < 0

    cmd = data[cmd_start, 4].unpack1("V")
    # Verify: the name offset field should point back to our string
    name_offset = data[cmd_start + 8, 4].unpack1("V")
    next unless name_offset == offset

    if cmd == LC_LOAD_DYLIB
      # Patch LC_LOAD_DYLIB → LC_LOAD_WEAK_DYLIB
      data[cmd_start, 4] = [LC_LOAD_WEAK_DYLIB].pack("V")
      patched_count += 1
      patched_for_this_reference = true
      break
    end

    if cmd == LC_LOAD_WEAK_DYLIB
      already_weak_count += 1
      patched_for_this_reference = true
      break
    end
  end

  next if patched_for_this_reference
end

if patched_count.zero?
  if already_weak_count.positive?
    warn "Sparkle dylib reference already weak-linked — nothing to patch."
    exit 0
  end
  warn "Found Sparkle string but could not locate matching LC_LOAD_DYLIB command."
  exit 1
end

File.binwrite(binary_path, data)
warn "Patched #{patched_count} Sparkle load command(s) to LC_LOAD_WEAK_DYLIB"
exit 0
