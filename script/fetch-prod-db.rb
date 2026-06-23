#!/usr/bin/env ruby
require "tmpdir"
require "fileutils"
require "open3"

if ARGV.size != 1
  warn "Usage: #{$PROGRAM_NAME} TENANT_ID"
  exit 1
end

tenant_id = ARGV[0]

# Automatically detect the mudda-web-production container
puts "→ Detecting mudda-web-production container..."
container_output, status = Open3.capture2(%(ssh app@mudda-app-101 "docker ps --format '{{.Names}}' | grep mudda-web-production"))
abort("Failed to detect container") unless status.success?

CONTAINER = container_output.strip
abort("No mudda-web-production container found") if CONTAINER.empty?
puts "→ Using container: #{CONTAINER}"

REMOTE_PATH = "/rails/storage/tenants/production/#{tenant_id}/db/main.sqlite3.1"

Dir.mktmpdir do |tmpdir|
  local_file = File.join(tmpdir, "main.sqlite3")

  puts "→ Copying #{REMOTE_PATH} from container to #{local_file}"
  cmd = %(ssh app@mudda-app-101 "docker cp #{CONTAINER}:#{REMOTE_PATH} -" | tar -xOf - > #{local_file})
  system(cmd) or abort("Failed to copy database file")

  puts "→ Running script/load-prod-db-in-dev.rb with #{local_file}"
  exec("bundle", "exec", "ruby", "script/load-prod-db-in-dev.rb", local_file)
end
