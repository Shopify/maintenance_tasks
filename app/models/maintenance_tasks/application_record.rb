# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all records used by this engine.
  #
  # Can be extended to setup different database where all tables related to
  # maintenance tasks will live.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
