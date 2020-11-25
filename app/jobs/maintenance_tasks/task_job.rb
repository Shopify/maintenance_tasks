# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class TaskJob < ActiveJob::Base
    include JobIteration::Iteration

    before_perform(:job_running)
    on_start(:job_started)
    on_complete(:job_completed)
    on_shutdown(:shutdown_job)

    before_perform(:setup_ticker)
    on_shutdown(:record_tick)

    after_perform(:save_run)

    rescue_from StandardError, with: :job_errored

    private

    def build_enumerator(_run, cursor:)
      cursor ||= @run.cursor
      collection = @task.collection

      case collection
      when ActiveRecord::Relation
        enumerator_builder.active_record_on_records(collection, cursor: cursor)
      when Array
        enumerator_builder.build_array_enumerator(collection, cursor: cursor)
      else
        raise ArgumentError, "#{@task.class.name}#collection must be either "\
          'an Active Record Relation or an Array.'
      end
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

    def job_running
      @run = arguments.first
      @task = Task.named(@run.task_name).new
      @run.job_id = job_id

      @run.running! unless @run.stopping?
    end

    def job_started
      @run.update!(
        started_at: Time.now,
        tick_total: @task.count
      )
    end

    def shutdown_job
      if @run.cancelling?
        @run.status = :cancelled
        @run.ended_at = Time.now
      else
        @run.status = @run.pausing? ? :paused : :interrupted
        @run.cursor = cursor_position
      end
    end

    def job_completed
      @run.status = :succeeded
      @run.ended_at = Time.now
    end

    def save_run
      @run.save!
    end

    def job_errored(exception)
      exception_class = exception.class.to_s
      exception_message = exception.message
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace)

      record_tick
      @run.update!(
        status: :errored,
        error_class: exception_class,
        error_message: exception_message,
        backtrace: backtrace,
        ended_at: Time.now
      )
    end

    def setup_ticker
      @ticker = Ticker.new(MaintenanceTasks.ticker_delay) do |ticks, duration|
        @run.persist_progress(ticks, duration)
      end
    end

    def record_tick
      @ticker.persist
    end
  end
end
