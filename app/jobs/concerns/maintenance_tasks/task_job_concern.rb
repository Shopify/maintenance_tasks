# frozen_string_literal: true

require "json"

module MaintenanceTasks
  # Concern that holds the behaviour of the job that runs the tasks. It is
  # included in {TaskJob} and if MaintenanceTasks.job is overridden, it must be
  # included in the job.
  module TaskJobConcern
    extend ActiveSupport::Concern

    included do
      include ActiveJob::Continuable

      self.resume_options = { wait: 0 }
      self.resume_errors_after_advancing = false

      before_perform(:before_perform)
      after_perform(:after_perform)

      rescue_from StandardError, with: :on_error

      define_method(:checkpoint!) do
        super()
        if @job_started_at && Time.now - @job_started_at >= MaintenanceTasks.max_job_runtime
          interrupt!(reason: :max_runtime)
        end
      end
    end

    class_methods do
      # Overrides ActiveJob::Exceptions.retry_on to declare it unsupported.
      # The use of rescue_from prevents retry_on from being usable.
      def retry_on(*, **)
        raise NotImplementedError, "retry_on is not supported"
      end
    end

    # Performs the task by iterating over its collection using a
    # Continuable step for cursor-based resumption.
    def perform(run)
      step(:iterate) do |s|
        cursor = s.cursor || deserialized_run_cursor
        collection_enum = build_collection_enum(cursor)

        unless @run.started?
          count = @task.count
          count = collection_enum.size if count == NO_COUNT_DEFINED
          @run.start(count)
        end

        halted = catch(:halt) do
          collection_enum.each do |item, item_cursor|
            if (backoff = check_throttle)
              on_shutdown
              @reenqueue_wait = backoff
              throw(:halt, true)
            end

            if @run.stopping?
              on_shutdown
              throw(:halt, true)
            end

            task_iteration(item)
            @ticker.tick
            reload_run_status

            @run.cursor = serialize_cursor(item_cursor)
            s.set!(item_cursor)
          end

          false
        end

        unless halted
          @ticker.persist
          @run.complete
        end
      end
    rescue ActiveJob::Continuation::Interrupt
      on_shutdown
      @run.persist_transition
      raise
    end

    private

    def serialize_cursor(value)
      value && @run.cursor_is_json? ? value.to_json : value&.to_s
    end

    def deserialized_run_cursor
      return JSON.parse(@run.cursor) if @run.cursor && @run.cursor_is_json?

      @run.cursor
    end

    def build_collection_enum(cursor)
      collection_enum = @task.enumerator_builder(cursor: cursor)
      return collection_enum if collection_enum

      case (collection = @task.collection)
      when :no_collection
        OnceEnumerator.new(cursor: nil)
      when ActiveRecord::Relation
        options = { cursor: cursor, columns: @task.cursor_columns }
        options[:batch_size] = @task.active_record_enumerator_batch_size if @task.active_record_enumerator_batch_size
        ActiveRecordRecordEnumerator.new(collection, **options)
      when ActiveRecord::Batches::BatchEnumerator
        if collection.start || collection.finish
          raise ArgumentError, <<~MSG.squish
            #{@task.class.name}#collection cannot support
            a batch enumerator with the "start" or "finish" options.
          MSG
        end

        ActiveRecordBatchEnumerator.new(
          collection.relation,
          cursor: cursor,
          batch_size: collection.batch_size,
          columns: @task.cursor_columns,
        )
      when Array
        ArrayEnumerator.new(collection, cursor: cursor&.to_i)
      when BatchCsvCollectionBuilder::BatchCsv
        CsvBatchEnumerator.new(collection.csv, batch_size: collection.batch_size, cursor: cursor&.to_i)
      when CSV
        CsvRowEnumerator.new(collection, cursor: cursor&.to_i)
      else
        raise ArgumentError, <<~MSG.squish
          #{@task.class.name}#collection must be either an
          Active Record Relation, ActiveRecord::Batches::BatchEnumerator,
          Array, or CSV.
        MSG
      end
    end

    def task_iteration(input)
      if @task.no_collection?
        @task.process
      else
        @task.process(input)
      end
    rescue => error
      @errored_element = input
      raise error unless @task.rescue_with_handler(error)
    end

    def check_throttle
      @task.throttle_conditions.each do |condition|
        return condition[:backoff].call if condition[:throttle_on].call
      end
      nil
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

      @last_status_reload = nil
      @job_started_at = Time.now
    end

    def on_shutdown
      @run.job_shutdown
      @ticker.persist
    end

    def after_perform
      @run.persist_transition
      if @reenqueue_wait && !@run.stopped?
        self.class.set(wait: @reenqueue_wait).perform_later(@run)
      end
    end

    def on_error(error)
      task_context = {}
      @ticker.persist if defined?(@ticker)

      if defined?(@run)
        @run.persist_error(error)

        task_context = {
          task_name: @run.task_name,
          started_at: @run.started_at,
          ended_at: @run.ended_at,
          run_id: @run.id,
          tick_count: @run.tick_count,
        }
      end
      task_context[:errored_element] = @errored_element if defined?(@errored_element)
    ensure
      if MaintenanceTasks.instance_variable_get(:@error_handler)
        errored_element = task_context.delete(:errored_element)
        MaintenanceTasks.error_handler.call(error, task_context.except(:run_id, :tick_count), errored_element)
      else
        Rails.error.report(
          error,
          handled: MaintenanceTasks.report_errors_as_handled,
          context: task_context,
          source: "maintenance-tasks",
        )
      end
    end

    def reload_run_status
      return unless should_reload_status?

      @run.reload_status
      @last_status_reload = Time.now
    end

    def should_reload_status?
      return true if @last_status_reload.nil?

      time_since_last_reload = Time.now - @last_status_reload
      time_since_last_reload >= @task.status_reload_frequency
    end
  end
end
