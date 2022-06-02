# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class BatchCsvCollectionBuilderTest < ActiveSupport::TestCase
    test "count" do
      task = Maintenance::ImportPostsTask.new
      builder = BatchCsvCollectionBuilder.new(2)
      task.csv_content = <<~CSV
        header
        1
        2
        3
      CSV

      assert_equal(2, builder.count(task))
    end

    test "count modulo batch" do
      task = Maintenance::ImportPostsTask.new
      builder = BatchCsvCollectionBuilder.new(2)
      task.csv_content = <<~CSV
        header
        1
        2
        3
        4
      CSV

      assert_equal(2, builder.count(task))
    end

    test "count no lines" do
      task = Maintenance::ImportPostsTask.new
      builder = BatchCsvCollectionBuilder.new(1)
      task.csv_content = <<~CSV
        header
      CSV

      assert_equal(0, builder.count(task))
    end
  end
end
