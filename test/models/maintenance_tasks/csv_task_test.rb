# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class CsvTaskTest < ActiveSupport::TestCase
    test ".collection creates a CSV from the csv_content string" do
      csv_file = file_fixture("sample.csv")

      csv_task = Maintenance::ImportPostsTask.new
      csv_task.csv_content = csv_file.binread
      collection = csv_task.collection

      assert CSV, collection.class
      assert collection.headers

      first_row = collection.first
      assert_equal "My Title 1 あ", first_row["title"]
      assert_equal "Héllo World 1! い", first_row["content"]
      csv_task.process(first_row)
    end

    test ".collection passes options to the CSV parser" do
      csv_file = file_fixture("sample.csv")
      csv = csv_file.binread
      csv.prepend("# Comment\n")
      csv.concat("# Another comment\n")

      csv_task = Maintenance::ImportPostsWithOptionsTask.new
      csv_task.csv_content = csv
      collection = csv_task.collection

      assert CSV, collection.class
      assert collection.headers

      all_rows = collection.to_a
      assert_equal 5, all_rows.count

      first_row = all_rows.first
      assert_equal "MY TITLE 1 あ", first_row["title"]
      assert_equal "HÉLLO WORLD 1! い", first_row["content"]
    end

    test ".count returns the number of rows to process, excluding headers and assuming a trailing newline" do
      csv_file = file_fixture("sample.csv")

      csv_task = Maintenance::ImportPostsTask.new
      csv_task.csv_content = csv_file.binread
      assert_equal 5, csv_task.count
    end

    test ".collection opens CSV with provided encoding" do
      csv_file = file_fixture("sample.csv")
      csv_task = Maintenance::ImportPostsWithEncodingTask.new
      csv_task.csv_content = csv_file.binread
      collection = csv_task.collection

      assert_raises(CSV::InvalidEncodingError) do
        collection.to_a
      end
    end

    test ".collection opens CSV with default encoding" do
      csv_file = file_fixture("sample.csv")
      csv_task = Maintenance::ImportPostsTask.new
      csv_task.csv_content = csv_file.binread
      collection = csv_task.collection

      entry = collection.to_a.first
      assert_equal("My Title 1 あ", entry["title"])
      assert_equal("Héllo World 1! い", entry["content"])
    end
  end
end
