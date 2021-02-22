# frozen_string_literal: true

module MaintenanceTasks
  # Generator used for creating maintenance tasks in the host application.
  #
  # @api private
  class TaskGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('templates', __dir__)
    desc 'This generator creates a task file at app/tasks and a corresponding '\
      'test.'

    TASK_TYPES = ['generic', 'csv']
    class_option :type, type: :string, default: 'generic',
      desc: "Specify the type of Task to generate (#{TASK_TYPES.join(', ')})"

    check_class_collision suffix: 'Task'

    # Ensure a valid task type has been provided
    def validate_task_type
      return if TASK_TYPES.include?(task_type)

      raise(Thor::Error, "Unknown task type #{task_type.inspect}. " \
            "Must be one of: #{TASK_TYPES.join(', ')}")
    end

    # Creates the Task file.
    def create_task_file
      task_file = File.join(
        "app/tasks/#{tasks_module_file_path}",
        class_path,
        "#{file_name}_task.rb"
      )
      template(task_template_file, task_file)
    end

    # Creates the Task test file, according to the app's test framework.
    # A spec file is created if the app uses RSpec.
    # Otherwise, an ActiveSupport::TestCase test is created.
    def create_test_file
      return unless test_framework

      if test_framework == :rspec
        create_task_spec_file
      else
        create_task_test_file
      end
    end

    private

    def create_task_test_file
      test_file = File.join(
        "test/tasks/#{tasks_module_file_path}",
        class_path,
        "#{file_name}_task_test.rb"
      )
      template(test_template_file, test_file)
    end

    def create_task_spec_file
      spec_file = File.join(
        "spec/tasks/#{tasks_module_file_path}",
        class_path,
        "#{file_name}_task_spec.rb"
      )
      template(spec_template_file, spec_file)
    end

    def task_template_file
      case task_type
      when 'generic'
        'task.rb'
      when 'csv'
        'csv_task.rb'
      end
    end

    def test_template_file
      case task_type
      when 'generic', 'csv'
        'task_test.rb'
      end
    end

    def spec_template_file
      case task_type
      when 'generic', 'csv'
        'task_spec.rb'
      end
    end

    def file_name
      super.sub(/_task\z/i, '')
    end

    def task_type
      options[:type]
    end

    def tasks_module
      MaintenanceTasks.tasks_module
    end

    def tasks_module_file_path
      tasks_module.underscore
    end

    def test_framework
      Rails.application.config.generators.options[:rails][:test_framework]
    end
  end
  private_constant :TaskGenerator
end
