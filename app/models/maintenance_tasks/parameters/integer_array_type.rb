# frozen_string_literal: true
module MaintenanceTasks
  module Parameters
    # Type class representing an array of integers. Tasks using the Attributes
    # API for parameter support can use this class to turn input from the UI
    # into an array of integers within their Task.
    class IntegerArrayType < ActiveModel::Type::Value
      # Casts string from form input field to an array of integers after
      # validating that the input is correct.
      #
      # @param input [String] the value to cast to an array of integers.
      # @return [Array<Integer>] the data cast as an array of integers.
      def cast(input)
        return unless input.present?

        validate_input(input)
        input.split(",").map(&:to_i)
      end

      private

      def validate_input(input)
        unless /\A(\s?\d+\s?(,\s?\d+\s?)*\s?)\z/.match?(input)
          error_message = "#{self.class} expects a " \
            "comma-delimited string of integers. Input received: #{input}"
          raise TypeError, error_message
        end
      end
    end
  end
end
