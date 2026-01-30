# frozen_string_literal: true

# Puma configuration file for robot application

# Load settings to get port configuration
require 'yaml'

env = ENV['RACK_ENV'] || 'development'
settings_file = File.join(__dir__, 'settings.yml')
all_settings = YAML.load_file(settings_file, aliases: true)
config = all_settings['default'].merge(all_settings[env] || {})

# Number of worker processes (use 1 for Raspberry Pi Zero 2W)
workers ENV.fetch('WEB_CONCURRENCY', 1)

# Number of threads per worker
threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
threads threads_count, threads_count

# Bind to the configured host and port
bind "tcp://#{config['host']}:#{config['port']}"

# Specifies the `environment` that Puma will run in
environment env

# Preload the application
preload_app!

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Log configuration
stdout_redirect '/app/logs/puma_stdout.log', '/app/logs/puma_stderr.log', true if env == 'production'

# Logging
if env == 'development'
  # In development, log to stdout
  log_requests true
end

# Worker-specific configuration
on_worker_boot do
  # Worker-specific setup for Rails applications, if needed
  # For Sinatra, usually not needed
end

# Before forking configuration
before_fork do
  # Close any connections before forking
end
