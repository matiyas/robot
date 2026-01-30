# frozen_string_literal: true

require 'logger'
require 'stringio'

RSpec.shared_context 'with test logger' do
  let!(:log_output) { StringIO.new }
  let!(:test_logger) do
    logger = Logger.new(log_output)
    logger.level = Logger::DEBUG
    logger
  end

  def logged_messages
    log_output.string.lines.map(&:chomp)
  end

  def logged_debug
    log_output.string.lines.select { |line| line.include?('DEBUG') }
  end

  def logged_info
    log_output.string.lines.select { |line| line.include?('INFO') }
  end

  def logged_warn
    log_output.string.lines.select { |line| line.include?('WARN') }
  end

  def logged_error
    log_output.string.lines.select { |line| line.include?('ERROR') }
  end
end
