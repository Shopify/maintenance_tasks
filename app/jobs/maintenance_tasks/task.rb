# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task < ActiveJob::Base
    include JobIteration::Iteration
    extend ActiveSupport::DescendantsTracker

    class << self
      # Returns list of objects that inherit from MaintenanceTasks::Task
      # @return [Array<Class>] the list of class names for classes that
      # inherit from MaintenanceTasks::Task.
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
  end
end
