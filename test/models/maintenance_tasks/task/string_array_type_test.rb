# frozen_string_literal: true
require "test_helper"

module MaintenanceTasks
  class Task
    class StringArrayTypeTest < ActiveSupport::TestCase
      test "#cast returns nil if input not present" do
        assert_nil StringArrayType.new.cast("")
      end

      test "#cast converts string to array of strings" do
        assert_equal ["abc", "def"], StringArrayType.new.cast("abc,def")
      end
    end
  end
end
