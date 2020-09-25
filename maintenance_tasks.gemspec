# frozen_string_literal: true
$LOAD_PATH.push(File.expand_path("lib", __dir__))

# Maintain your gem's version:
require "maintenance_tasks/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "maintenance_tasks"
  spec.version     = MaintenanceTasks::VERSION
  spec.authors     = ["Shopify"]
  spec.email       = ["gems@shopify.com"]
  spec.homepage    = "https://github.com/Shopify/maintenance_tasks"
  spec.summary     = "A Rails engine for queuing and managing maintenance tasks"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://packages.shopify.io"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  spec.add_dependency("rails", "~> 6.0.3")
  spec.add_dependency("job-iteration")

  spec.add_development_dependency("sqlite3")
end
