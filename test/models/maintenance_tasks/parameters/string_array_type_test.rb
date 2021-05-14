# frozen_string_literal: true
require "test_helper"

module MaintenanceTasks
  module Parameters
    class StringArrayTypeTest < ActiveSupport::TestCase
      test "#cast returns nil if input not present" do
        assert_nil StringArrayType.new.cast("")
      end

      test "#cast converts string to array of strings" do
        assert_equal ["abc", "def"], StringArrayType.new.cast("abc,def")
      end

      test "#cast converts string to array of strings, including extra whitespace" do
        assert_equal ["abc ", "def", " ghi", " jkl "],
          StringArrayType.new.cast("abc ,def, ghi, jkl ")
      end

      test "#cast raises if input is not valid" do
        input = "$!$"
        error = assert_raises(TypeError) do
          StringArrayType.new.cast(input)
        end

        expected_error_message = <<~MSG.squish
          MaintenanceTasks::Parameters::StringArrayType expects alphanumeric,
          comma-delimited string. Input received: #{input}
        MSG
        assert_equal(expected_error_message, error.message)
      end
    end
  end
end
