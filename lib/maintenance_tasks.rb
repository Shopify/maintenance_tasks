# frozen_string_literal: true
require 'maintenance_tasks/engine'

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  # Sets the value of tasks_module, the intended module to namespace Tasks in.
  # Defaults to 'Maintenance'.
  #
  # @attr_writer [String] the tasks_module value.
  mattr_writer :tasks_module, default: 'Maintenance'

  # Retrieves the module that Tasks are namespaced in.
  #
  # @return [Module] the constantized tasks_module value.
  def self.tasks_module
    @@tasks_module.constantize
  end
end
