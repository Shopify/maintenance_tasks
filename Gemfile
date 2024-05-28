# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "better_html"
gem "capybara"
gem "debug"
gem "mocha"
gem "puma"
if @rails_gem_requirement
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
if @sqlite3_requirement
  # causes Dependabot to ignore the next line and update the next gem "sqlite3"
  sqlite3 = "sqlite3"
  gem sqlite3, @sqlite3_requirement
else
  gem "sqlite3"
end
gem "importmap-rails"
gem "yard"
