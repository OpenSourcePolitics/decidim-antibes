# frozen_string_literal: true

require "sentry-ruby"

if Rails.application.secrets.dig(:sentry, :enabled)
  Sentry.init do |config|
    # config.dsn = 'http://3911b1ade4414a7db38719db21c35a7f@sf-sentry-dev.ville-antibes.fr:9000/2'
    config.dsn = Rails.application.secrets.dig(:sentry, :dsn)
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # To activate performance monitoring, set one of these options.
    # We recommend adjusting the value in production:
    config.traces_sample_rate = ENV.fetch("SENTRY_SAMPLE_RATE", 0.5)
  end
end
