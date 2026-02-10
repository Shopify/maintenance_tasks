# frozen_string_literal: true

module MaintenanceTasks
  # Model that persists information related to a task being run from the UI.
  #
  # @api private
  class Run < ApplicationRecord
    include RunConcern
  end
end
