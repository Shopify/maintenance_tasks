# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "better_html"
gem "debug"
gem "puma"
if !@rails_gem_requirement
  gem "rails", ">= 7.1"
  ruby ">= 3.2.0"
else
  # causes Dependabot to ignore the next line and update the previous gem "rails"
  rails = "rails"
  gem rails, @rails_gem_requirement
end
gem "rubocop"
gem "rubocop-shopify"
gem "sprockets-rails"
gem "sqlite3"
gem "yard"

group :test do
  gem "capybara"
  gem "capybara-lockstep"
  gem "minitest", "< 6"
  gem "mocha"
  gem "selenium-webdriver"
end
