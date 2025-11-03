# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  module Concerns
    class ParallelizableTest < ActiveSupport::TestCase
      class TestTask < MaintenanceTasks::Task
        include Parallelizable

        attr_accessor :processed_items

        def initialize
          super
          @processed_items = Concurrent::Array.new
        end

        def collection
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].each_slice(5)
        end

        def process_item(item)
          # Simulate some work
          sleep(0.01)
          @processed_items << { item: item, thread_id: Thread.current.object_id }
        end
      end

      test "processes items in parallel within each batch" do
        task = TestTask.new
        collection = task.collection

        # Get the first batch
        first_batch = collection.first

        # Process the batch
        task.process(first_batch)

        # Should have processed 5 items (batch size)
        assert_equal 5, task.processed_items.size

        # Items should have been processed by different threads
        thread_ids = task.processed_items.map { |item| item[:thread_id] }.uniq
        assert thread_ids.size > 1, "Expected multiple threads, got #{thread_ids.size}"
      end

      test "raises error if process_item not implemented" do
        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          def collection
            [1, 2, 3].each_slice(3)
          end
        end.new

        batch = task.collection.first

        error = assert_raises(NoMethodError) do
          task.process(batch)
        end

        assert_includes error.message, "must implement `process_item(item)`"
      end

      test "propagates exceptions from threads" do
        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          def collection
            [1, 2, 3, 4, 5].each_slice(5)
          end

          def process_item(item)
            # Sleep briefly to ensure all threads run
            sleep(0.001)
            raise StandardError, "Error processing item #{item}" if item == 3
          end
        end.new

        batch = task.collection.first

        error = assert_raises(StandardError) do
          task.process(batch)
        end

        assert_includes error.message, "Error processing item 3"
        assert_equal 3, task.instance_variable_get(:@errored_element)
      end

      test "all threads complete even if one fails" do
        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          attr_reader :processed_items

          def initialize
            super
            @processed_items = Concurrent::Array.new
          end

          def collection
            [1, 2, 3, 4, 5].each_slice(5)
          end

          def process_item(item)
            sleep(0.01)  # Ensure other threads have time to run
            @processed_items << item
            raise StandardError, "Error on item 3" if item == 3
          end
        end.new

        batch = task.collection.first

        assert_raises(StandardError) do
          task.process(batch)
        end

        # All 5 threads should have attempted to process
        # (though one failed, all should have been spawned)
        assert task.processed_items.size >= 4, "Expected at least 4 items processed, got #{task.processed_items.size}"
      end

      test "works with ActiveRecord::Relation batches" do
        # Create a simple model for testing
        Post.delete_all
        5.times { |i| Post.create!(title: "Post #{i}", content: "Content #{i}") }

        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          attr_accessor :processed_ids

          def initialize
            super
            @processed_ids = Concurrent::Array.new
          end

          def collection
            Post.all.in_batches(of: 5)
          end

          def process_item(post)
            @processed_ids << post.id
          end
        end.new

        # Get first batch (AR::Relation)
        first_batch = task.collection.first
        task.process(first_batch)

        assert_equal 5, task.processed_ids.size
      ensure
        Post.delete_all
      end

      test "works with batched CSV collections" do
        csv_content = <<~CSV
          name,age
          Alice,30
          Bob,25
          Charlie,35
          David,28
          Eve,32
        CSV

        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          csv_collection(in_batches: 3)

          attr_accessor :processed_names

          def initialize
            super
            @processed_names = Concurrent::Array.new
          end

          def process_item(row)
            @processed_names << row["name"]
          end
        end.new

        task.csv_content = csv_content

        # Get the collection
        collection = task.collection
        assert_kind_of BatchCsvCollectionBuilder::BatchCsv, collection

        # Simulate what job-iteration does
        csv_enum = JobIteration::CsvEnumerator.new(collection.csv).batches(
          batch_size: collection.batch_size,
          cursor: nil
        )

        # Get first batch - job-iteration yields [rows, cursor]
        # but only passes rows to process()
        rows, _cursor = csv_enum.first
        task.process(rows)

        assert_equal 3, task.processed_names.size
        assert_includes task.processed_names, "Alice"
        assert_includes task.processed_names, "Bob"
        assert_includes task.processed_names, "Charlie"
      end

      test "converts ActiveRecord::Relation to array" do
        Post.delete_all
        3.times { |i| Post.create!(title: "Post #{i}", content: "Content") }

        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          attr_accessor :processed_count

          def initialize
            super
            @processed_count = Concurrent::AtomicFixnum.new(0)
          end

          def collection
            Post.all.in_batches(of: 3)
          end

          def process_item(post)
            @processed_count.increment
          end
        end.new

        batch = task.collection.first
        assert_kind_of ActiveRecord::Relation, batch

        task.process(batch)
        assert_equal 3, task.processed_count.value
      ensure
        Post.delete_all
      end

      test "handles plain arrays" do
        task = Class.new(MaintenanceTasks::Task) do
          include Parallelizable

          attr_accessor :sum

          def initialize
            super
            @sum = Concurrent::AtomicFixnum.new(0)
          end

          def collection
            [1, 2, 3, 4, 5].each_slice(5)
          end

          def process_item(num)
            @sum.update { |v| v + num }
          end
        end.new

        batch = task.collection.first
        task.process(batch)

        assert_equal 15, task.sum.value
      end
    end
  end
end
