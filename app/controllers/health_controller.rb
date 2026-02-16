class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def show
    checks = {
      status: "ok",
      timestamp: Time.current.iso8601,
      redis: redis_healthy?,
      version: "1.0.0"
    }

    status_code = checks[:redis] ? :ok : :service_unavailable
    render json: checks, status: status_code
  end

  private

  def redis_healthy?
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")).ping == "PONG"
  rescue
    false
  end
end
