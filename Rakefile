# frozen_string_literal: true

begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "rdoc/task"
RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title    = "MaintenanceTasks"
  rdoc.options << "--line-numbers"
  rdoc.rdoc_files.include("README.md")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load("rails/tasks/engine.rake")

load("rails/tasks/statistics.rake")

require "bundler/gem_tasks"

require "rubocop/rake_task"
RuboCop::RakeTask.new.tap do |rubocop|
  rubocop.options += ["--no-parallel"]
end

task(test: "app:test")
task("test:system" => "app:test:system")
task(default: ["db:test:prepare", "test", "test:system", "rubocop"])

namespace :vendor do
  task :bulma do
    require "importmap-rails"
    require "importmap/packager"

    packager = Importmap::Packager.new(vendor_path: "vendor/assets/stylesheets")
    package, url = packager.import("bulma@0.9.4", from: "unpkg").first
    filename = "#{package}.min.css"
    source_url = File.dirname(url) + "/css/#{filename}"
    target_file = "#{packager.vendor_path}/#{filename}"

    puts %(Vendoring #{source_url} to #{target_file})

    response = Net::HTTP.get_response(URI(source_url))
    if response.code == "200"
      File.open(target_file, "w+") do |file|
        file.write(response.body)
      end
    else
      raise "Unexpected response code (#{response.code})"
    end
  end
end
