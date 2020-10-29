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
      throw(:abort, :skip_complete_callbacks) if task_stopped?
      @task.process(input)
      @ticker.tick
    end

    def job_running
      @run = arguments.first
      @task = Task.named(@run.task_name).new
      @run.job_id = job_id

      @run.running! unless task_stopped?
    end

    def job_started
      @run.update!(tick_total: @task.count)
    end

    def job_completed
      @run.succeeded!
    end

    def shutdown_job
      @run.cursor = cursor_position
      @run.status = :interrupted unless task_stopped?
      @run.save!
    end

    def job_errored(exception)
      exception_class = exception.class.to_s
      exception_message = exception.message
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace)

      @run.update!(
        status: :errored,
        error_class: exception_class,
        error_message: exception_message,
        backtrace: backtrace
      )
    end

    def task_stopped?
      # Note that as long as @task_stopped is false, this block will run.
      # It is still preferable to memoize here because it prevents us from
      #  having to perform more reloads after the task has entered
      # a paused or cancelled status
      @task_stopped ||= begin
        run = Run.select(:status).find(@run.id)
        run.paused? || run.cancelled?
      end
    end

    def setup_ticker
      @ticker = Ticker.new(MaintenanceTasks.ticker_delay) do |ticks|
        @run.increment_ticks(ticks)
      end
    end

    def record_tick
      @ticker.persist
    end
  end
end
