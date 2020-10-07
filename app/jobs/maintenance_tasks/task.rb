# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task < ActiveJob::Base
    include JobIteration::Iteration
    extend ActiveSupport::DescendantsTracker

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

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end
  end
end
