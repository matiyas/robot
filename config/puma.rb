# frozen_string_literal: true

# Puma configuration file for robot application

# Load settings to get port configuration
require 'yaml'

env = ENV['RACK_ENV'] || 'development'
settings_file = File.join(__dir__, 'settings.yml')
all_settings = YAML.load_file(settings_file, aliases: true)
config = all_settings['default'].merge(all_settings[env] || {})

# Number of worker processes (0 = single mode, no forking - best for Pi Zero 2W)
workers ENV.fetch('WEB_CONCURRENCY', 0)

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
# Note: In production with systemd, logs are captured via StandardOutput=journal
# No need for file redirection - use: journalctl -u robot.service -f
if env == 'production'
  # Log to stdout/stderr (captured by systemd)
  log_requests true
elsif env == 'development'
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
