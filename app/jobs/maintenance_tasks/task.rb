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

    rescue_from StandardError, with: :job_errored

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
        running = Run.select(&:running?).pluck(:task_name).map(&:constantize)
        descendants.reject(&:abstract_class?) - running
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
      task_iteration(input)
      if Run.select(:status).find(@run.id).paused?
        @job_should_exit = true
        @retried = true
      end
    end

    def job_running
      @run = arguments.first
      @run.job_id = job_id
      @run.running!
    end

    def job_completed
      @run.succeeded!
    end

    def shutdown_job
      @run.interrupted! if @run.running?
    end

    def job_should_exit?
      (defined?(@job_should_exit) && @job_should_exit == true) || super
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
  end
end
