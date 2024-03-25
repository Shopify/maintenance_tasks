# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "better_html", "< 2.2.0"
gem "capybara"
gem "debug"
gem "mocha"
gem "puma"
if defined?(@rails_gem_requirement) && @rails_gem_requirement
  # causes Dependabot to ignore the next line and update the next gem "rails"
  rails = "rails"
  gem rails, @rails_gem_requirement
else
  gem "rails"
end
gem "rubocop"
gem "rubocop-shopify"
gem "selenium-webdriver"
gem "sprockets-rails"
gem "sqlite3"
gem "yard"
