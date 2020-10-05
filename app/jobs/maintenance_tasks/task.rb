# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task < ActiveJob::Base
    include JobIteration::Iteration
    extend ActiveSupport::DescendantsTracker

    class << self
      # Given the name of a Task, returns the Task subclass. Returns nil if
      # there's no task with that name.
      def named(name)
        name.constantize
      rescue NameError
        nil
      end

      # Returns a list of classes that inherit from the Task superclass.
      #
      # @return [Array<Class>] the list of classes.
      def descendants
        load_constants
        super
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end

    delegate :name, to: :class

    before_enqueue :create_run

    private

    def create_run
      run = arguments.dig(-1, :run)
      Run.create!(task_name: name) unless run
    end
  end
end
