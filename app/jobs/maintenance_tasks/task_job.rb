# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class TaskJob < ActiveJob::Base
    include JobIteration::Iteration

    before_perform(:before_perform)

    on_start(:on_start)
    on_complete(:on_complete)
    on_shutdown(:on_shutdown)

    after_perform(:after_perform)

    rescue_from StandardError, with: :on_error

    class << self
      # Overrides ActiveJob::Exceptions.retry_on to declare it unsupported.
      # The use of rescue_from prevents retry_on from being usable.
      def retry_on(*, **)
        raise NotImplementedError, 'retry_on is not supported'
      end
    end

    private

    def build_enumerator(_run, cursor:)
      cursor ||= @run.cursor
      collection = @task.collection

      case collection
      when ActiveRecord::Relation
        enumerator_builder.active_record_on_records(collection, cursor: cursor)
      when Array
        enumerator_builder.build_array_enumerator(collection, cursor: cursor)
      when CSV
        JobIteration::CsvEnumerator.new(collection).rows(cursor: cursor)
      else
        raise ArgumentError, "#{@task.class.name}#collection must be either "\
          'an Active Record Relation, Array, or CSV.'
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
      @task.process(input)
    rescue => error
      @errored_element = input
      raise error
    end

    def before_perform
      @run = arguments.first
      @task = Task.named(@run.task_name).new
      if @task.respond_to?(:csv_content=)
        @task.csv_content = @run.csv_file.download
      end
      @run.job_id = job_id

      @run.running! unless @run.stopping?

      @ticker = Ticker.new(MaintenanceTasks.ticker_delay) do |ticks, duration|
        @run.persist_progress(ticks, duration)
      end
    end

    def on_start
      @run.update!(started_at: Time.now, tick_total: @task.count)
    end

    def on_complete
      @run.status = :succeeded
      @run.ended_at = Time.now
    end

    def on_shutdown
      if @run.cancelling?
        @run.status = :cancelled
        @run.ended_at = Time.now
      else
        @run.status = @run.pausing? ? :paused : :interrupted
        @run.cursor = cursor_position
      end

      @ticker.persist
    end

    # We are reopening a private part of Job Iteration's API here, so we should
    # ensure the method is still defined upstream. This way, in the case where
    # the method changes upstream, we catch it at load time instead of at
    # runtime while calling `super`.
    unless private_method_defined?(:reenqueue_iteration_job)
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
      @run.save!
      if defined?(@reenqueue_iteration_job) && @reenqueue_iteration_job
        reenqueue_iteration_job(should_ignore: false)
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
      MaintenanceTasks.error_handler.call(error, task_context, errored_element)
    end
  end
end
