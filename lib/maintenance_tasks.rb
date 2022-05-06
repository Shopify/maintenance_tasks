# frozen_string_literal: true

require "action_controller"
require "action_view"
require "active_job"
require "active_record"

require "job-iteration"
require "maintenance_tasks/engine"

require "patches/active_record_batch_enumerator"

# The engine's namespace module. It provides isolation between the host
# application's code and the engine-specific code. Top-level engine constants
# and variables are defined under this module.
module MaintenanceTasks
  # @!attribute tasks_module
  #   @scope class
  #
  #   The module to namespace Tasks in, as a String. Defaults to 'Maintenance'.
  #   @return [String] the name of the module.
  mattr_accessor :tasks_module, default: "Maintenance"

  # @!attribute job
  #   @scope class
  #
  #   The name of the job to be used to perform Tasks. Defaults to
  #   `"MaintenanceTasks::TaskJob"`. This job must be either a class that
  #   inherits from {TaskJob} or a class that includes {TaskJobConcern}.
  #
  #   @return [String] the name of the job class.
  mattr_accessor :job, default: "MaintenanceTasks::TaskJob"

  # @!attribute ticker_delay
  #   @scope class
  #
  #   The delay between updates to the tick count. After each iteration, the
  #   progress of the Task may be updated. This duration in seconds limits
  #   these updates, skipping if the duration since the last update is lower
  #   than this value, except if the job is interrupted, in which case the
  #   progress will always be recorded.
  #
  #   @return [ActiveSupport::Duration, Numeric] duration of the delay between
  #     updates to the tick count during Task iterations.
  mattr_accessor :ticker_delay, default: 1.second

  # @!attribute active_storage_service
  #   @scope class
  #
  #   The Active Storage service to use for uploading CSV file blobs.
  #
  #   @return [Symbol] the key for the storage service, as specified in the
  #     app's config/storage.yml.
  mattr_accessor :active_storage_service

  # @!attribute backtrace_cleaner
  #   @scope class
  #
  #   The Active Support backtrace cleaner that will be used to clean the
  #   backtrace of a Task that errors.
  #
  #   @return [ActiveSupport::BacktraceCleaner, nil] the backtrace cleaner to
  #     use when cleaning a Run's backtrace.
  mattr_accessor :backtrace_cleaner

  # @!attribute error_handler
  #   @scope class
  #
  #   The callback to perform when an error occurs in the Task.  See the
  #   {file:README#label-Customizing+the+error+handler} for details.
  #
  #   @return [Proc] the callback to perform when an error occurs in the Task.
  mattr_accessor :error_handler, default:
    ->(_error, _task_context, _errored_element) {}
end
