require 'sidekiq'

Sidekiq.configure_server do |config|
  logger = Logger.new(STDOUT)
  logger.level = Logger::ERROR  # Only show errors
  config.logger = logger
end
