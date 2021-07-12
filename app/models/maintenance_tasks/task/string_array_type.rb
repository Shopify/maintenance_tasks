# frozen_string_literal: true
module MaintenanceTasks
  class Task
    # Type class representing an array of strings. Tasks using the Attributes
    # API for parameter support can use this class to turn input from the UI
    # into an array of strings within their Task.
    class StringArrayType < ActiveModel::Type::Value
      # Casts string from form input field to an array of strings.
      #
      # @param input [String] the value to cast to an array of strings.
      # @return [Array<Integer>] the data cast as an array of strings.
      def cast(input)
        return unless input.present?
        input.split(",")
      end
    end
  end
end
