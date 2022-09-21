# frozen_string_literal: true

module MaintenanceTasks
  # Concern that holds the behaviour of the job that runs the tasks. It is
  # included in {TaskJob} and if MaintenanceTasks.job is overridden, it must be
  # included in the job.
  module TaskJobConcern
    extend ActiveSupport::Concern
    include JobIteration::Iteration

    included do
      before_perform(:before_perform)

      on_start(:on_start)
      on_shutdown(:on_shutdown)
      on_complete(:on_complete)

      after_perform(:after_perform)

      rescue_from StandardError, with: :on_error
    end

    class_methods do
      # Overrides ActiveJob::Exceptions.retry_on to declare it unsupported.
      # The use of rescue_from prevents retry_on from being usable.
      def retry_on(*, **)
        raise NotImplementedError, "retry_on is not supported"
      end
    end

    private

    def build_enumerator(_run, cursor:)
      cursor ||= @run.cursor
      collection = @task.collection
      @enumerator = nil

      @collection_enum = case collection
      when :no_collection
        enumerator_builder.build_once_enumerator(cursor: nil)
      when ActiveRecord::Relation
        enumerator_builder.active_record_on_records(collection, cursor: cursor)
      when ActiveRecord::Batches::BatchEnumerator
        if collection.start || collection.finish
          raise ArgumentError, <<~MSG.squish
            #{@task.class.name}#collection cannot support
            a batch enumerator with the "start" or "finish" options.
          MSG
        end

        # For now, only support automatic count based on the enumerator for
        # batches
        enumerator_builder.active_record_on_batch_relations(
          collection.relation,
          cursor: cursor,
          batch_size: collection.batch_size,
        )
      when Array
        enumerator_builder.build_array_enumerator(collection, cursor: cursor)
      when BatchCsvCollectionBuilder::BatchCsv
        JobIteration::CsvEnumerator.new(collection.csv).batches(
          batch_size: collection.batch_size,
          cursor: cursor,
        )
      when CSV
        JobIteration::CsvEnumerator.new(collection).rows(cursor: cursor)
      else
        raise ArgumentError, <<~MSG.squish
          #{@task.class.name}#collection must be either an
          Active Record Relation, ActiveRecord::Batches::BatchEnumerator,
          Array, or CSV.
        MSG
      end
      throttle_enumerator(@collection_enum)
    end

    def throttle_enumerator(collection_enum)
      @task.throttle_conditions.reduce(collection_enum) do |enum, condition|
        enumerator_builder.build_throttle_enumerator(
          enum,
          throttle_on: condition[:throttle_on],
          backoff: condition[:backoff].call,
        )
      end
    end

    # Performs task iteration logic for the current input returned by the
    # enumerator.
    #
    # @param input [Object] the current element from the enumerator.
    # @param _run [Run] the current Run, passed as an argument by Job Iteration.
    def each_iteration(input, _run)
      throw(:abort, :skip_complete_callbacks) if @run.stopping?
      task_iteration(input)
      @ticker.tick
      @run.reload_status
    end

    def task_iteration(input)
      if @task.no_collection?
        @task.process
      else
        @task.process(input)
      end
    rescue => error
      @errored_element = input
      raise error
    end

    def before_perform
      @run = arguments.first
      @task = @run.task
      if @task.has_csv_content?
        @task.csv_content = @run.csv_file.download
      end

      @run.running

      @ticker = Ticker.new(MaintenanceTasks.ticker_delay) do |ticks, duration|
        @run.persist_progress(ticks, duration)
      end
    end

    def on_start
      count = @task.count
      count = @collection_enum.size if count == :no_count
      @run.start(count)
    end

    def on_shutdown
      @run.job_shutdown
      @run.cursor = cursor_position
      @ticker.persist
    end

    def on_complete
      @run.complete
    end

    # We are reopening a private part of Job Iteration's API here, so we should
    # ensure the method is still defined upstream. This way, in the case where
    # the method changes upstream, we catch it at load time instead of at
    # runtime while calling `super`.
    unless JobIteration::Iteration
        .private_method_defined?(:reenqueue_iteration_job)
      error_message = <<~HEREDOC
        JobIteration::Iteration#reenqueue_iteration_job is expected to be
        defined. Upgrading the maintenance_tasks gem should solve this problem.
      HEREDOC
      raise error_message
    end
    def reenqueue_iteration_job(should_ignore: true)
      super() unless should_ignore
      @reenqueue_iteration_job = true
    end

    def after_perform
      @run.persist_transition
      if defined?(@reenqueue_iteration_job) && @reenqueue_iteration_job
        reenqueue_iteration_job(should_ignore: false) unless @run.stopped?
      end
    end

    def on_error(error)
      @ticker.persist if defined?(@ticker)

      if defined?(@run)
        @run.persist_error(error)

        task_context = {
          task_name: @run.task_name,
          started_at: @run.started_at,
          ended_at: @run.ended_at,
        }
      else
        task_context = {}
      end
      errored_element = @errored_element if defined?(@errored_element)
    ensure
      MaintenanceTasks.error_handler.call(error, task_context, errored_element)
    end
  end
end
