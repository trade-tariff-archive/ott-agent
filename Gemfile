# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "propshaft"
gem "importmap-rails"

gem "faraday", "~> 2.12"
gem "faraday-retry"

gem "aws-sdk-bedrockruntime"

gem "turbo-rails"
gem "redis", "~> 5.0"

gem "govuk-components"
gem "govuk_design_system_formbuilder"

gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"

gem "bootsnap", require: false

group :development, :test do
  gem "dotenv-rails"
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "shoulda-matchers", "~> 6.0"
  gem "webmock"
  gem "brakeman", require: false
  gem "rubocop-govuk", require: false
end

group :production do
  gem "lograge"
end
