# frozen_string_literal: true

module MaintenanceTasks
  # Generator used for creating maintenance tasks in the host application.
  #
  # @api private
  class TaskGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('templates', __dir__)
    desc 'This generator creates a task file at app/tasks.'

    check_class_collision suffix: 'Task'

    # Creates the Task file.
    def create_task_file
      template_file = File.join(
        "app/tasks/#{tasks_module_file_path}",
        class_path,
        "#{file_name}_task.rb"
      )
      template('task.rb', template_file)
    end

    # Create the Task test file.
    def create_task_test_file
      template_file = File.join(
        "test/tasks/#{tasks_module_file_path}",
        class_path,
        "#{file_name}_task_test.rb"
      )
      template('task_test.rb', template_file)
    end

    private

    def file_name
      super.sub(/_task\z/i, '')
    end

    def tasks_module
      MaintenanceTasks.tasks_module
    end

    def tasks_module_file_path
      tasks_module.to_s.underscore
    end
  end
  private_constant :TaskGenerator
end
