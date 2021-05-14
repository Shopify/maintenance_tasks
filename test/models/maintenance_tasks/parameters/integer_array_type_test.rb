# frozen_string_literal: true
require "test_helper"

module MaintenanceTasks
  module Parameters
    class IntegerArrayTypeTest < ActiveSupport::TestCase
      test "#cast returns nil if input not present" do
        assert_nil IntegerArrayType.new.cast("")
      end

      test "#cast converts string to array of strings" do
        assert_equal [1, 2, 3], IntegerArrayType.new.cast("1,2,3")
      end

      test "#cast converts string to array of integers, excluding extra whitespace" do
        assert_equal [123, 456, 78], IntegerArrayType.new.cast("123 ,456, 78 ")
      end

      test "#cast raises if input is not valid" do
        input = "abc"
        error = assert_raises(TypeError) do
          IntegerArrayType.new.cast(input)
        end

        expected_error_message = <<~MSG.squish
          MaintenanceTasks::Parameters::IntegerArrayType expects a
          comma-delimited string of integers. Input received: #{input}
        MSG
        assert_equal(expected_error_message, error.message)
      end
    end
  end
end
