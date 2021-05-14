# frozen_string_literal: true
module MaintenanceTasks
  module Parameters
    # Type class representing an array of strings. Tasks using the Attributes
    # API for parameter support can use this class to turn input from the UI
    # into an array of strings within their Task.
    class StringArrayType < ActiveModel::Type::Value
      # Casts string from form input field to an array of strings after
      # validating that the input is correct.
      #
      # @param input [String] the value to cast to an array of strings.
      # @return [Array<Integer>] the data cast as an array of strings.
      def cast(input)
        return unless input.present?

        validate_input(input)
        input.split(",")
      end

      private

      def validate_input(input)
        unless /\A(\s?\w+\s?(,\s?\w+\s?)*)\z/.match?(input)
          error_message = "#{self.class} expects alphanumeric, "\
            "comma-delimited string. Input received: #{input}"
          raise TypeError, error_message
        end
      end
    end
  end
end
