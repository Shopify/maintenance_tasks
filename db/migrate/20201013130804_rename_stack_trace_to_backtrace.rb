
# frozen_string_literal: true
class RenameStackTraceToBacktrace < ActiveRecord::Migration[6.0]
  def change
    rename_column(:maintenance_tasks_runs, :stack_trace, :backtrace)
  end
end
