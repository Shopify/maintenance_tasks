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

require "bundler/gem_tasks"

require "rubocop/rake_task"
RuboCop::RakeTask.new.tap do |rubocop|
  rubocop.options += ["--no-parallel"]
end

task(test: "app:test")
task("test:system" => "app:test:system")
task(default: ["db:test:prepare", "test", "test:system", "rubocop"])

task("integrity-hashes") do
  require "net/http"
  require "uri"
  doc = Nokogiri::HTML5.parse(Net::HTTP.get(URI("http://localhost:3000/maintenance_tasks")))
  puts "app/controllers/maintenance_tasks/application_controller.rb:"
  print("  style_src_elem: ")
  puts "'sha256-#{Digest::SHA256.base64digest(doc.css("html>head>style").sole.text)}'"
  print("  script_src_elem: ")
  puts "'sha256-#{Digest::SHA256.base64digest(doc.css("html>head>script").sole.text)}'"
  puts "app/views/layouts/maintenance_tasks/application.html.erb:"
  print("  Bulma integrity: ")
  bulma = Net::HTTP.get(URI(doc.css("html>head>link[rel=stylesheet]").sole[:href]))
  puts "'sha256-#{Digest::SHA256.base64digest(bulma)}'"
rescue SystemCallError
  puts "Could not compute CSP integrity hashes: start development server and try again."
  exit(1)
end
