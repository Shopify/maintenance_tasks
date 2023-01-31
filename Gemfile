# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "better_html"
gem "capybara"
gem "mocha"
gem "net-http" # Ruby 2.7 stdlib's net/http loads net/protocol relatively, which loads both the stdlib and gem version
gem "net-smtp" # mail is missing a dependency on net-smtp https://github.com/mikel/mail/pull/1439
gem "pry-byebug"
gem "puma", "< 7.0"
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
gem "webdrivers", require: false
gem "yard"
