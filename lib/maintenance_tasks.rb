# frozen_string_literal: true
require 'maintenance_tasks/engine'

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  DEFAULT_TASKS_MODULE = 'Maintenance'
  mattr_writer :tasks_module

  def self.tasks_module
    (@@tasks_module || DEFAULT_TASKS_MODULE).constantize
  end
end
