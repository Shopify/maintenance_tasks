# frozen_string_literal: true
module MaintenanceTasks
  module Parameters
    # Error to raise when parameter ActiveModel::Value::Type objects fail
    # validation.
    class TypeError < StandardError; end
  end
end
