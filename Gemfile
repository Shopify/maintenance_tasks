# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "better_html"
gem "capybara"
gem "debug"
gem "mocha"
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
gem "selenium-webdriver"
gem "sprockets-rails"
if @sqlite3_requirement
  # causes Dependabot to ignore the next line and update the next gem "sqlite3"
  sqlite3 = "sqlite3"
  gem sqlite3, @sqlite3_requirement
else
  gem "sqlite3"
end
gem "yard"
