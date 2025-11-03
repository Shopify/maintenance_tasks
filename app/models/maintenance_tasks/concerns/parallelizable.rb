# frozen_string_literal: true

module MaintenanceTasks
  module Concerns
    # Concern that adds parallel processing capability to maintenance tasks.
    #
    # When included in a task, this concern enables processing items in parallel
    # using threads. Task authors define their collection with batching
    # (using in_batches, csv_collection(in_batches:), or each_slice), and
    # implement process_item(item) instead of process(item).
    #
    # The concern works by:
    # 1. Receiving a batch from the job iteration framework
    # 2. Converting the batch to an array of items
    # 3. Spawning one thread per item to process them concurrently
    # 4. Waiting for all threads to complete before moving to the next batch
    #
    # @example ActiveRecord with batching
    #   class Maintenance::UpdateUsersTask < MaintenanceTasks::Task
    #     include MaintenanceTasks::Concerns::Parallelizable
    #
    #     def collection
    #       User.where(status: 'pending').in_batches(of: 10)
    #     end
    #
    #     def process_item(user)
    #       # This will be called in parallel (10 concurrent threads per batch)
    #       user.update!(status: 'processed', processed_at: Time.current)
    #     end
    #   end
    #
    # @example CSV processing with batching
    #   class Maintenance::ProcessCsvTask < MaintenanceTasks::Task
    #     include MaintenanceTasks::Concerns::Parallelizable
    #
    #     csv_collection(in_batches: 10)
    #
    #     def process_item(row)
    #       # Process CSV row in parallel (10 concurrent threads per batch)
    #       User.create!(name: row['name'], email: row['email'])
    #     end
    #   end
    #
    # @example Array processing with batching
    #   class Maintenance::ProcessIdsTask < MaintenanceTasks::Task
    #     include MaintenanceTasks::Concerns::Parallelizable
    #
    #     def collection
    #       [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].each_slice(5)
    #     end
    #
    #     def process_item(id)
    #       # Process each ID in parallel (5 concurrent threads per batch)
    #       SomeService.call(id)
    #     end
    #   end
    #
    # @note Cursor granularity: The cursor tracks batches, not individual items.
    #   If the task is interrupted mid-batch, items from that batch will be
    #   reprocessed on resume. Ensure your process_item method is idempotent.
    #
    # @note Thread safety requirements:
    #   - Your process_item method MUST be thread-safe
    #   - Avoid shared mutable state between items
    #   - Most ActiveRecord operations are thread-safe if each thread gets its own connection
    #   - ActiveRecord handles connection pooling automatically
    #
    # @note Error handling: If any thread raises an exception, the entire batch
    #   fails and the exception is propagated to the maintenance task's error handler.
    #   The first exception encountered is raised.
    #
    # @note Progress tracking: Progress is tracked per batch, not per item.
    #   The UI will show "X batches processed" rather than "X items processed".
    module Parallelizable
      extend ActiveSupport::Concern

      # Process a batch by spawning threads for parallel execution.
      # This is called by the job iteration framework with a batch of items.
      #
      # @param batch [Object] batch (ActiveRecord::Relation, Array of items/rows)
      def process(batch)
        # Convert batch to array of items
        # ActiveRecord::Relation responds to to_a, arrays are already arrays
        items = batch.respond_to?(:to_a) ? batch.to_a : Array(batch)

        # Execute items in parallel, storing errored item for context
        ParallelExecutor.execute(items) do |item|
          process_item(item)
        end
      rescue => error
        # Store the errored item for maintenance tasks error reporting
        @errored_element = error.errored_item if error.respond_to?(:errored_item)
        raise
      end

      # Task authors implement this method instead of process(item).
      # It will be called in parallel for each item in a batch.
      #
      # @param item [Object] the individual item to process
      def process_item(item)
        raise NoMethodError, <<~MSG.squish
          #{self.class.name} must implement `process_item(item)` when using
          Parallelizable concern.
        MSG
      end
    end
  end
end
