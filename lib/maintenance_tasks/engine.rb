# frozen_string_literal: true

require "active_record/railtie"

module MaintenanceTasks
  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks

    initializer "maintenance_tasks.warn_classic_autoloader" do
      unless Rails.autoloaders.zeitwerk_enabled?
        raise <<~MSG.squish
          Autoloading in classic mode is not supported.
          Please use Zeitwerk to autoload your application.
        MSG
      end
    end

    initializer "maintenance_tasks.configs" do
      MaintenanceTasks.backtrace_cleaner = Rails.backtrace_cleaner
    end

    config.to_prepare do
      _ = TaskJobConcern # load this for JobIteration compatibility check
    end

    config.after_initialize do
      JobIteration.max_job_runtime ||= 5.minutes
    end

    config.action_dispatch.rescue_responses.merge!(
      "MaintenanceTasks::Task::NotFoundError" => :not_found,
    )
  end
end
