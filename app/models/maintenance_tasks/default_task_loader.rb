# frozen_string_literal: true

module MaintenanceTasks
  # This class defines how the gem will find and load all tasks defined by the application.
  # It can be overridden by the application to change the way tasks are loaded.
  class DefaultTaskLoader
    class << self
      # Recursively browse the MaintenanceTasks.tasks_module namespace to load all defined tasks.
      #
      # @return [void]
      def load_all
        load_constants(MaintenanceTasks.tasks_module.safe_constantize)
      end

      private

      def load_constants(namespace)
        namespace.constants.each do |name|
          object = namespace.const_get(name)
          load_constants(object) if object.instance_of?(Module)
        end
      end
    end
  end
end
