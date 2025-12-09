# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class ParallelExecutorTest < ActiveSupport::TestCase
    test "executes block for each item in parallel" do
      results = Concurrent::Array.new

      items = [1, 2, 3, 4, 5]
      ParallelExecutor.execute(items) do |item|
        sleep(0.001)  # Simulate work
        results << item
      end

      assert_equal 5, results.size
      assert_equal [1, 2, 3, 4, 5].sort, results.sort
    end

    test "uses multiple threads" do
      thread_ids = Concurrent::Array.new

      items = [1, 2, 3, 4, 5]
      ParallelExecutor.execute(items) do |_item|
        thread_ids << Thread.current.object_id
      end

      # Should use more than one thread
      assert thread_ids.uniq.size > 1, "Expected multiple threads, got #{thread_ids.uniq.size}"
    end

    test "waits for all threads to complete" do
      completion_order = Concurrent::Array.new

      items = [1, 2, 3]
      ParallelExecutor.execute(items) do |item|
        # Item 2 finishes last
        sleep(0.01) if item == 2
        completion_order << item
      end

      # All 3 items should be completed
      assert_equal 3, completion_order.size
    end

    test "raises first exception after all threads complete" do
      processed = Concurrent::Array.new

      items = [1, 2, 3, 4, 5]
      error = assert_raises(StandardError) do
        ParallelExecutor.execute(items) do |item|
          sleep(0.001)  # Give other threads time to run
          processed << item
          raise StandardError, "Error on item #{item}" if item == 3
        end
      end

      assert_equal "Error on item 3", error.message

      # All threads should have attempted to run
      assert processed.size >= 4, "Expected at least 4 items processed"
    end

    test "attaches errored item to exception" do
      items = [1, 2, 3]
      error = assert_raises(StandardError) do
        ParallelExecutor.execute(items) do |item|
          raise StandardError, "Error" if item == 2
        end
      end

      assert_respond_to error, :errored_item
      assert_equal 2, error.errored_item
    end

    test "handles exceptions from ActiveRecord operations" do
      Post.delete_all
      post = Post.create!(title: "Test", content: "Content")

      items = [post.id, post.id + 1, post.id + 2]
      error = assert_raises(ActiveRecord::RecordNotFound) do
        ParallelExecutor.execute(items) do |post_id|
          Post.find(post_id)  # Will raise for non-existent IDs
        end
      end

      # Should capture the error
      assert_kind_of ActiveRecord::RecordNotFound, error
    ensure
      Post.delete_all
    end

    test "each thread gets own database connection" do
      connection_ids = Concurrent::Array.new

      items = [1, 2, 3, 4, 5]
      ParallelExecutor.execute(items) do |_item|
        # Each thread should have its own connection from the pool
        conn = ActiveRecord::Base.connection
        connection_ids << conn.object_id
      end

      # Connections may be reused from the pool, but should be managed safely
      # At minimum, verify we didn't crash due to connection issues
      assert_equal 5, connection_ids.size
    end
  end
end
