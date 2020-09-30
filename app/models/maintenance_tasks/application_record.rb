# frozen_string_literal: true
module MaintenanceTasks
  # Base class for all records used by this engine.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
