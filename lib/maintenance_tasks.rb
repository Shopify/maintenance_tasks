# frozen_string_literal: true
require 'maintenance_tasks/engine'
require 'pagy'
require 'pagy/extras/bulma'

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  # Sets the value of tasks_module, the intended module to namespace Tasks in.
  # Defaults to 'Maintenance'.
  mattr_writer :tasks_module, default: 'Maintenance'

  # Defines the job to be used to perform Tasks. This job must be either
  # `MaintenanceTasks::TaskJob` or a class that inherits from it.
  #
  # @param [String] the name of the job class.
  mattr_writer :job, default: 'MaintenanceTasks::TaskJob'

  # Retrieves the module that Tasks are namespaced in.
  #
  # @return [Module] the constantized tasks_module value.
  def self.tasks_module
    @@tasks_module.constantize
  end

  # Retrieves the class that is configured as the Task Job to be used to
  # perform Tasks.
  #
  # @return [TaskJob] the job class.
  def self.job
    @@job.constantize
  end
end
