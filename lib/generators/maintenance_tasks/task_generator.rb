# frozen_string_literal: true

module MaintenanceTasks
  # Generator used for creating maintenance tasks in the host application.
  #
  # @api private
  class TaskGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)
    desc "This generator creates a task file at app/tasks " \
      "or the specified tasks_path and a corresponding test."

    class_option :csv,
      type: :boolean,
      default: false,
      desc: "Generate a CSV Task."

    class_option :no_collection,
      type: :boolean,
      default: false,
      desc: "Generate a collection-less Task."

    class_option :tasks_path,
      type: :string,
      default: "",
      desc: "Specify the path where the task should be generated."

    check_class_collision suffix: "Task"

    # Creates the Task file.
    def create_task_file
      if options[:csv] && options[:no_collection]
        raise "Multiple Task type options provided. Please use either " \
          "--csv or --no-collection."
      end
      template_file = File.join(
        "app",
        module_path,
        class_path,
        "#{file_name}_task.rb",
      )
      if options[:csv]
        template("csv_task.rb", template_file)
      elsif no_collection?
        template("no_collection_task.rb", template_file)
      else
        template("task.rb", template_file)
      end
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
      template_file = File.join(
        "test",
        module_path,
        class_path,
        "#{file_name}_task_test.rb",
      )
      template("task_test.rb", template_file)
    end

    def create_task_spec_file
      template_file = File.join(
        "spec",
        module_path,
        class_path,
        "#{file_name}_task_spec.rb",
      )
      template("task_spec.rb", template_file)
    end

    def file_name
      super.sub(/_task\z/i, "")
    end

    def module_path
      File.join(tasks_path, tasks_module_file_path)
    end

    def tasks_path
      File.join(options[:tasks_path], "tasks")
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

    def no_collection?
      options[:no_collection]
    end
  end
end
