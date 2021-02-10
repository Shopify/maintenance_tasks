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

    EnumerationContext = Struct.new(:cursor, keyword_init: true)

    def build_enumerator(_run, cursor:)
      context = EnumerationContext.new(
        cursor: cursor || @run.cursor,
      )

      @task.enumerator_builder.enumerator(context: context)
    end

    # Performs task iteration logic for the current input returned by the
    # enumerator.
    #
    # @param input [Object] the current element from the enumerator.
    # @param _run [Run] the current Run, passed as an argument by Job Iteration.
    def each_iteration(input, _run)
      throw(:abort, :skip_complete_callbacks) if @run.stopping?
      @task.process(input)
      @ticker.tick
      @run.reload_status
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

    def after_perform
      @run.save!
    end

    def on_error(error)
      @ticker.persist if defined?(@ticker)
      @run.persist_error(error)
      MaintenanceTasks.error_handler.call(error)
    end
  end
end
