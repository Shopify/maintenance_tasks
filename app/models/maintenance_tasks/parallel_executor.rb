# frozen_string_literal: true

module MaintenanceTasks
  # Executes items in parallel using a thread pool.
  #
  # Handles thread creation, error collection, and ensures all threads
  # complete before raising exceptions.
  #
  # @api private
  class ParallelExecutor
    class << self
      # Executes a block for each item in parallel.
      #
      # @param items [Array] items to process
      # @yield [item] block to execute for each item
      # @return [void]
      # @raise [StandardError] the first exception encountered during execution
      def execute(items, &block)
        exceptions = []
        exception_mutex = Mutex.new

        threads = items.map do |item|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              block.call(item)
            rescue => error
              exception_mutex.synchronize do
                exceptions << { item: item, error: error }
              end
            end
          end
        end

        # Wait for all threads to complete
        threads.each(&:join)

        # Raise first exception if any occurred
        raise_first_exception(exceptions) if exceptions.any?
      end

      private

      # Raises the first exception from the collection.
      #
      # @param exceptions [Array<Hash>] array of {item:, error:} hashes
      # @return [void]
      # @raise [StandardError] the first error from the collection
      def raise_first_exception(exceptions)
        first_exception = exceptions.first

        # Store context for error reporting (matches maintenance_tasks convention)
        # The calling task will set @errored_element for error context
        error = first_exception[:error]
        error.define_singleton_method(:errored_item) { first_exception[:item] }

        raise error
      end
    end
  end
end
