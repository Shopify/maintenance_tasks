# frozen_string_literal: true
require 'action_controller'
require 'action_view'
require 'active_job'
require 'active_record'

require 'job-iteration'
require 'maintenance_tasks/engine'
require 'pagy'
require 'pagy/extras/bulma'

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  # The module to namespace Tasks in, as a String. Defaults to 'Maintenance'.
  # @param [String] the tasks_module value.
  mattr_accessor :tasks_module, default: 'Maintenance'

  # Defines the job to be used to perform Tasks. This job must be either
  # `MaintenanceTasks::TaskJob` or a class that inherits from it.
  #
  # @param [String] the name of the job class.
  mattr_accessor :job, default: 'MaintenanceTasks::TaskJob'

  # After each iteration, the progress of the task may be updated. This duration
  # in seconds limits these updates, skipping if the duration since the last
  # update is lower than this value, except if the job is interrupted, in which
  # case the progress will always be recorded.
  #
  # @param [ActiveSupport::Duration, Numeric] Duration of the delay to update
  #   the ticker during Task iterations.
  mattr_accessor :ticker_delay, default: 1.second

  # Defines a callback to be performed when an error occurs in the task.
  mattr_accessor :error_handler, default: ->(_error) {}
end
