# frozen_string_literal: true

module MaintenanceTasks
  # Helpers for formatting data in the maintenance_tasks views.
  module TaskHelper
    # Formats a run backtrace.
    #
    # @param backtrace [Array<String>] the backtrace associated with an
    #   exception on a Task that ran and raised.
    # @return [String] the parsed, HTML formatted version of the backtrace.
    def format_backtrace(backtrace)
      safe_join(backtrace.to_a, tag.br)
    end
  end
end
