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

    class TaskError < StandardError; end

    class InvalidCollectionError < StandardError; end

    rescue_from TaskError, with: :on_task_error

    private

    def build_enumerator(_run, cursor:)
      cursor ||= @run.cursor
      begin
        collection = @task.collection
        case collection
        when ActiveRecord::Relation
          enumerator_builder.active_record_on_records(
            collection,
            cursor: cursor
          )
        when Array
          enumerator_builder.build_array_enumerator(collection, cursor: cursor)
        else
          raise InvalidCollectionError, "#{@task.class.name}#collection must "\
            'be either an Active Record Relation or an Array.'
        end
      rescue
        raise TaskError
      end
    end

    # Performs task iteration logic for the current input returned by the
    # enumerator.
    #
    # @param input [Object] the current element from the enumerator.
    # @param _run [Run] the current Run, passed as an argument by Job Iteration.
    def each_iteration(input, _run)
      throw(:abort, :skip_complete_callbacks) if @run.stopping?
      begin
        @task.process(input)
      rescue
        raise TaskError
      end
      @ticker.tick
      @run.reload_status
    end

    def before_perform
      @run = arguments.first
      @task = Task.named(@run.task_name).new
      @run.job_id = job_id

      @run.running! unless @run.stopping?

      @ticker = Ticker.new(MaintenanceTasks.ticker_delay) do |ticks, duration|
        @run.persist_progress(ticks, duration)
      end
    end

    def on_start
      tick_total =
        begin
          @task.count
        rescue
          raise TaskError
        end
      @run.update!(started_at: Time.now, tick_total: tick_total)
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

    def on_task_error(error)
      @ticker.persist

      original_error = error.cause
      @run.update!(
        status: :errored,
        error_class: original_error.class.to_s,
        error_message: original_error.message,
        backtrace: Rails.backtrace_cleaner.clean(original_error.backtrace),
        ended_at: Time.now
      )
    end
  end
end
