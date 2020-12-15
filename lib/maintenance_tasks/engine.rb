# frozen_string_literal: true
require 'active_record/railtie'

module MaintenanceTasks
  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks

    config.to_prepare do
      unless Rails.autoloaders.zeitwerk_enabled?
        tasks_module = MaintenanceTasks.tasks_module.underscore
        Dir["#{Rails.root}/app/tasks/#{tasks_module}/*.rb"].each do |file|
          require_dependency(file)
        end
      end
    end

    config.after_initialize do
      eager_load! unless Rails.autoloaders.zeitwerk_enabled?
      JobIteration.max_job_runtime ||= 5.minutes
    end

    config.action_dispatch.rescue_responses.merge!(
      'MaintenanceTasks::Task::NotFoundError' => :not_found,
    )
  end
end
