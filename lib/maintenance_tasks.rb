# frozen_string_literal: true

require "action_controller"
require "action_view"
require "active_job"
require "active_record"

require "job-iteration"
require "maintenance_tasks/engine"

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

  # @!attribute parent_controller
  #   @scope class
  #
  #   The parent controller all web UI controllers will inherit from.
  #   Must be a class that inherits from `ActionController::Base`.
  #   Defaults to `"ActionController::Base"`
  #
  #   @return [String] the name of the parent controller for web UI.
  mattr_accessor :parent_controller, default: "ActionController::Base"

  # @!attribute metadata
  #  @scope class
  #   The Proc to call from the controller to generate metadata that will be persisted on the Run.
  #
  #   @return [Proc] generates a hash containing the metadata to be stored on the Run
  mattr_accessor :metadata, default: nil

  # @!attribute stuck_task_duration
  #  @scope class
  #  The duration after which a task is considered stuck and can be force cancelled.
  #
  #  @return [ActiveSupport::Duration] the threshold in seconds after which a task is considered stuck.
  mattr_accessor :stuck_task_duration, default: 5.minutes

  # @!attribute status_reload_frequency
  #  @scope class
  #  The frequency at which to reload the run status during iteration.
  #  Defaults to 1 second, meaning reload status every second.
  #
  #  @return [ActiveSupport::Duration, Numeric] the time interval between status reloads.
  mattr_accessor :status_reload_frequency, default: 1.second

  # @!attribute report_errors_as_handled
  #  @scope class
  #  How unexpected errors are reported to Rails.error.report.
  #
  #  When an error occurs that isn't explicitly handled (e.g., via `report_on`),
  #  it gets reported to Rails.error.report. This setting determines whether
  #  these errors are marked as "handled" or "unhandled".
  #
  #  The current default of `true` is for backwards compatibility, but it prevents
  #  error subscribers from distinguishing between expected and unexpected errors.
  #  Setting this to `false` provides more accurate error reporting and will become the default in v3.0.
  #
  #  @see https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-report
  #  @return [Boolean] whether to report unexpected errors as handled (true) or unhandled (false).
  mattr_accessor :report_errors_as_handled, default: true

  class << self
    DEPRECATION_MESSAGE = "MaintenanceTasks.error_handler is deprecated and will be removed in the 3.0 release. " \
      "Instead, reports will be sent to the Rails error reporter. Do not set a handler and subscribe " \
      "to the error reporter instead."
    private_constant :DEPRECATION_MESSAGE

    # @deprecated
    def error_handler
      deprecator.warn(DEPRECATION_MESSAGE)

      @error_handler
    end

    # @deprecated
    def error_handler=(proc)
      deprecator.warn(DEPRECATION_MESSAGE)

      @error_handler = proc
    end

    # @api-private
    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("3.0", "MaintenanceTasks")
    end
  end
end
