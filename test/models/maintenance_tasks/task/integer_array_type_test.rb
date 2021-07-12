# frozen_string_literal: true
require "test_helper"

module MaintenanceTasks
  class Task
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

      test "#cast handles non-integer input" do
        assert_equal [0], IntegerArrayType.new.cast("abc")
      end
    end
  end
end
