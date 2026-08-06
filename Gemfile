# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "importmap-rails"
gem "pg", "~> 1.5"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1"

gem "faraday", "~> 2.12"
gem "faraday-retry"

gem "aws-sdk-bedrockruntime"

gem "redis", "~> 6.0"
gem "turbo-rails"

gem "govuk-components"
gem "govuk_design_system_formbuilder"

gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"

gem "bootsnap", require: false
gem "csv"
gem "redcarpet", "~> 3.6"

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-govuk", require: false
  gem "shoulda-matchers", "~> 6.0"
  gem "webmock"
end

group :production do
  gem "lograge"
end
