# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "maintenance_tasks"
  spec.version = "2.12.0"
  spec.author = "Shopify Engineering"
  spec.email = "gems@shopify.com"
  spec.homepage = "https://github.com/Shopify/maintenance_tasks"
  spec.summary = "A Rails engine for queuing and managing maintenance tasks"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" =>
      "https://github.com/Shopify/maintenance_tasks/tree/v#{spec.version}",
    "allowed_push_host" => "https://rubygems.org",
  }

  spec.files = Dir["{app,config,db,lib}/**/*", "LICENSE.md", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["maintenance_tasks"]

  minimum_rails_version = "7.0"
  spec.add_dependency("actionpack", ">= #{minimum_rails_version}")
  spec.add_dependency("activejob", ">= #{minimum_rails_version}")
  spec.add_dependency("activerecord", ">= #{minimum_rails_version}")
  spec.add_dependency("csv")
  spec.add_dependency("job-iteration", ">= 1.3.6")
  spec.add_dependency("railties", ">= #{minimum_rails_version}")
  spec.add_dependency("zeitwerk", ">= 2.6.2")
end
