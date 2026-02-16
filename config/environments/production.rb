require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # PaaS serves static files directly from Puma (no nginx)
  config.public_file_server.enabled = ENV.fetch("RAILS_SERVE_STATIC_FILES", "true").present?

  # Most PaaS (Heroku, Render, Railway) terminate TLS at the load balancer.
  # Set FORCE_SSL=true only if your PaaS doesn't handle this for you.
  config.force_ssl = ENV["FORCE_SSL"].present?
  config.assume_ssl = ENV["FORCE_SSL"].present?

  config.logger = ActiveSupport::Logger.new($stdout)
    .tap  { |logger| logger.formatter = Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []
end
