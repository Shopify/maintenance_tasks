# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class CsvTaskTest < ActiveSupport::TestCase
    test '.collection creates a CSV from the csv_content string' do
      csv_file = file_fixture('sample.csv')

      csv_task = Maintenance::TestCsvTask.new
      csv_task.csv_content = csv_file.read
      collection = csv_task.collection

      assert CSV, collection.class
      assert collection.headers

      first_row = collection.first
      assert_equal '1', first_row['shop_id']
      assert_equal '101', first_row['product_id']
      assert_equal 'Apple', first_row['title']
    end

    test '.count returns the number of rows to process, excluding headers and assuming a trailing newline' do
      csv_file = file_fixture('sample.csv')

      csv_task = Maintenance::TestCsvTask.new
      csv_task.csv_content = csv_file.read
      assert_equal 11, csv_task.count
    end
  end
end
