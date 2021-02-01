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

  # Retrieves the callback to be performed when an error occurs in the task.
  def self.error_handler
    return @error_handler if defined?(@error_handler)
    @error_handler = ->(_error, _task_context, _errored_element) {}
  end

  # Defines a callback to be performed when an error occurs in the task.
  def self.error_handler=(error_handler)
    unless error_handler.arity == 3
      ActiveSupport::Deprecation.warn(
        'MaintenanceTasks.error_handler should be a lambda that takes three '\
         'arguments: error, task_context, and errored_element.'
      )
      @error_handler = ->(error, _task_context, _errored_element) do
        error_handler.call(error)
      end
    end
    @error_handler = error_handler
  end
end
