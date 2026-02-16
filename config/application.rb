require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module SpatialWorkspace
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins = [/https?:\/\/.*/, /file:\/\/.*/]

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*",
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ["X-Request-Id"]
      end
    end
  end
end
