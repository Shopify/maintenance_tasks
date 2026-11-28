# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  module Types
    class StringListTest < ActiveSupport::TestCase
      setup do
        @type = StringList.new
      end

      test "casts a value to a one-element string list" do
        assert_equal ["posts"], @type.cast(:posts)
      end

      test "casts array values to strings and removes blank select values" do
        assert_equal ["posts", "users"], @type.cast(["posts", "", nil, :users])
      end

      test "casts an empty selection to an empty list" do
        assert_equal [], @type.cast([""])
      end

      test "preserves nil" do
        assert_nil @type.cast(nil)
      end
    end
  end
end
