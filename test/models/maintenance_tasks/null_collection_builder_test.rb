# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class NullCollectionBuilderTest < ActiveSupport::TestCase
    setup do
      @task = Maintenance::TestTask.new
      @builder = NullCollectionBuilder.new
    end

    test "#collection" do
      assert_raises(NoMethodError) do
        @builder.collection(@task)
      end
    end

    test "count" do
      assert_equal(:no_count, @builder.count(@task))
    end

    test "#has_csv_content?" do
      assert_not_predicate(@builder, :has_csv_content?)
    end
  end
end
