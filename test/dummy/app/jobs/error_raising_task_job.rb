# frozen_string_literal: true

class ErrorRaisingTaskJob < MaintenanceTasks::TaskJob
  # HACK: overriding on_error for better development experience:
  # instead of swallowing errors in the Run, we get a nice backtrace.
  raise unless defined?(on_error)
  def on_error(error)
    raise error unless error.is_a?(Maintenance::ErrorTask::Error)
    super
  end
end
