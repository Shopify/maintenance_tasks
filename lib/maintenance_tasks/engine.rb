# frozen_string_literal: true

require "active_record/railtie"

module MaintenanceTasks
  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks

    initializer "maintenance_tasks.warn_classic_autoloader" do
      unless Rails.autoloaders.zeitwerk_enabled?
        ActiveSupport::Deprecation.warn(<<~MSG.squish)
          Autoloading in classic mode is deprecated and support will be removed in the next
          release of Maintenance Tasks. Please use Zeitwerk to autoload your application.
        MSG
      end
    end

    initializer "maintenance_tasks.eager_load_for_classic_autoloader" do
      eager_load! unless Rails.autoloaders.zeitwerk_enabled?
    end

    initializer "maintenance_tasks.configs" do
      MaintenanceTasks.backtrace_cleaner = Rails.backtrace_cleaner
    end

    config.to_prepare do
      _ = TaskJobConcern # load this for JobIteration compatibility check
      unless Rails.autoloaders.zeitwerk_enabled?
        tasks_module = MaintenanceTasks.tasks_module.underscore
        Dir["#{Rails.root}/app/tasks/#{tasks_module}/*.rb"].each do |file|
          require_dependency(file)
        end
      end
    end

    config.after_initialize do
      JobIteration.max_job_runtime ||= 5.minutes
    end

    config.action_dispatch.rescue_responses.merge!(
      "MaintenanceTasks::Task::NotFoundError" => :not_found,
    )
  end
end
