# frozen_string_literal: true
require 'maintenance_tasks/engine'

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  DEFAULT_TASKS_MODULE = 'Maintenance'

  # Sets the value of tasks_module, the intended module to namespace Tasks in.
  # @attr_writer [String] the tasks_module value
  mattr_writer :tasks_module

  # Gets the tasks_module that Tasks are namespaced in.
  # If one is not set, defaults to Maintenance.
  # @return [Module] the constantized tasks_module value
  def self.tasks_module
    (@@tasks_module || DEFAULT_TASKS_MODULE).constantize
  end
end
