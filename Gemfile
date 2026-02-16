source "https://rubygems.org"

ruby ">= 3.3.0"

gem "rails", "~> 8.0"
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "puma", ">= 6.0"
gem "redis", ">= 5.0"
gem "kredis"
gem "jbuilder"
gem "bootsnap", require: false

# Audio & AI
gem "ruby-openai", "~> 7.0"
gem "anthropic", "~> 0.3"

# Background jobs
gem "solid_queue"

# Database
gem "sqlite3", ">= 2.1"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "webmock"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
