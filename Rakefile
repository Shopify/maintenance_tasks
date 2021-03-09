# frozen_string_literal: true
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'
RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'MaintenanceTasks'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

APP_RAKEFILE = File.expand_path('test/dummy/Rakefile', __dir__)
load('rails/tasks/engine.rake')

load('rails/tasks/statistics.rake')

require 'bundler/gem_tasks'

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task(test: 'app:test')
task('test:system' => 'app:test:system')
task(default: ['db:test:prepare', 'test', 'test:system', 'rubocop'])
