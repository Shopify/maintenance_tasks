# frozen_string_literal: true

# Custom configuration for the tasks namespace can be defined here, ie.
# MaintenanceTasks.tasks_module = 'Maintenance'

unless Rails.autoloaders.zeitwerk_enabled?
  MaintenanceTasks::Engine.eager_load!
  Rails.application.config.to_prepare do
    Dir["#{Rails.root}/app/tasks/maintenance/*.rb"].each do |file|
      require_dependency(file)
    end
  end
end
