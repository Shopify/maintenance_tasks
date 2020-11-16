# frozen_string_literal: true
require 'active_record/railtie'

module MaintenanceTasks
  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks

    config.to_prepare do
      unless Rails.autoloaders.zeitwerk_enabled?
        begin
          tasks_module = MaintenanceTasks.tasks_module.name.underscore
        rescue NameError
          nil
        end
        if tasks_module
          Dir["#{Rails.root}/app/tasks/#{tasks_module}/*.rb"].each do |file|
            require_dependency(file)
          end
        end
      end
    end

    config.after_initialize do
      eager_load! unless Rails.autoloaders.zeitwerk_enabled?
    end

    config.action_dispatch.rescue_responses.merge!(
      'MaintenanceTasks::Task::NotFoundError' => :not_found,
    )
  end
end
