# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class CsvCollectionBuilderTest < ActiveSupport::TestCase
    setup do
      @task = Maintenance::ImportPostsTask.new
      @builder = CsvCollectionBuilder.new
    end

    test "#collection" do
      @task.csv_content = <<~CSV
        header
        1
      CSV

      assert_instance_of(CSV, @builder.collection(@task))
    end

    test "count" do
      @task.csv_content = <<~CSV
        header
        1
        2
        3
      CSV

      assert_equal(3, @builder.count(@task))
    end

    test "#has_csv_content?" do
      assert_predicate(@builder, :has_csv_content?)
    end
  end
end
