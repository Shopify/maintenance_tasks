# frozen_string_literal: true
module MaintenanceTasks
  class Task
    # Type class representing an array of integers. Tasks using the Attributes
    # API for parameter support can use this class to turn input from the UI
    # into an array of integers within their Task.
    class IntegerArrayType < ActiveModel::Type::Value
      # Casts string from form input field to an array of integers.
      #
      # @param input [String] the value to cast to an array of integers.
      # @return [Array<Integer>] the data cast as an array of integers.
      def cast(input)
        return unless input.present?
        input.split(",").map(&:to_i)
      end
    end
  end
end
