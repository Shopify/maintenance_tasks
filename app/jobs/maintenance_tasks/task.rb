# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task < ActiveJob::Base
    include JobIteration::Iteration
    extend ActiveSupport::DescendantsTracker

    before_perform(:job_running)
    on_complete(:job_completed)
    on_shutdown(:shutdown_job)

    before_perform(:setup_ticker)
    on_shutdown(:record_tick)

    rescue_from StandardError, with: :job_errored

    # After each iteration, the progress of the task may be updated.
    # This duration in seconds limits these updates, skipping if the duration
    # since the last update is lower than this value, except if the job is
    # interrupted, in which case the progress will always be recorded.
    #
    # @api private
    class_attribute :minimum_duration_for_tick_update, default: 1.0,
      instance_accessor: false, instance_predicate: false, instance_reader: true

    class << self
      # Controls the value of abstract_class, which indicates whether the class
      # is abstract or not. Abstract classes are excluded from the list of
      # available_tasks.
      #
      # @return [Boolean] the value of abstract_class
      attr_accessor :abstract_class

      # @return [Boolean] whether or not the class is abstract
      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      # Given the name of a Task, returns the Task subclass. Returns nil if
      # there's no task with that name.
      def named(name)
        name.constantize
      rescue NameError
        nil
      end

      # Returns a list of concrete classes that inherit from
      # the Task superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        load_constants
        descendants.reject(&:abstract_class?)
      end

      # Returns the set of Run records associated with the Task.
      #
      # @return [ActiveRecord::Relation<MaintenanceTasks::Run>]
      #   the relation of Run records.
      def runs
        Run.where(task_name: name)
      end

      # Returns the active Run associated with the Task, if any.
      # An active run is defined as enqueued, running, or paused.
      #
      # @return [MaintenanceTasks::Run] the Run record.
      def active_run
        runs.active.first
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end

    private

    def build_enumerator(_run, cursor:)
      task_enumerator(cursor: cursor)
    end

    # Performs task iteration logic for the current input returned by the
    # enumerator.
    #
    # @param input [Object] the current element from the enumerator.
    # @param _run [Run] the current Run, passed as an argument by Job Iteration.
    def each_iteration(input, _run)
      throw(:abort, :skip_complete_callbacks) if task_stopped?
      task_iteration(input)
      @ticker.tick
    end

    def job_running
      @run = arguments.first
      @run.job_id = job_id

      @run.running! unless task_stopped?
    end

    def job_completed
      @run.succeeded!
    end

    def shutdown_job
      @run.interrupted! unless task_stopped?
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
      # a paused or aborted status
      @task_stopped ||= begin
        run = Run.select(:status).find(@run.id)
        run.paused? || run.aborted?
      end
    end

    def setup_ticker
      @ticker = Ticker.new(minimum_duration_for_tick_update) do |ticks|
        @run.increment_ticks(ticks)
      end
    end

    def record_tick
      @ticker.persist
    end
  end
end
