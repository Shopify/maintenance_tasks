# frozen_string_literal: true
module MaintenanceTasks
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
