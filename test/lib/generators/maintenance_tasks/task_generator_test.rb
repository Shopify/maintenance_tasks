# frozen_string_literal: true

require "test_helper"
require "generators/maintenance_tasks/task_generator"

module MaintenanceTasks
  class GeneratorTest < Rails::Generators::TestCase
    tests TaskGenerator
    SAMPLE_APP_PATH = Engine.root.join("tmp/sample_app")
    destination SAMPLE_APP_PATH
    setup :prepare_destination

    def teardown
      FileUtils.rm_rf(SAMPLE_APP_PATH)
    end

    test "generator creates task skeleton and task test" do
      run_generator ["sleepy"]
      assert_file "app/tasks/maintenance/sleepy_task.rb" do |task|
        assert_match(/module Maintenance/, task)
        assert_match(/class SleepyTask < MaintenanceTasks::Task/, task)
        assert_match(/def collection/, task)
        assert_match(/def process\(element\)/, task)
        assert_match(/def count/, task)
      end
      assert_file "test/tasks/maintenance/sleepy_task_test.rb" do |task_test|
        assert_match(/module Maintenance/, task_test)
        assert_match(
          /class SleepyTaskTest < ActiveSupport::TestCase/,
          task_test,
        )
      end
    end

    test "generator creates a task spec if the application is using RSpec" do
      generators_config = Rails.application.config.generators
      old_test_framework = generators_config.options[:rails][:test_framework]
      generators_config.options[:rails][:test_framework] = :rspec

      run_generator(["sleepy"])

      assert_file("spec/tasks/maintenance/sleepy_task_spec.rb") do |task_spec|
        assert_match(/module Maintenance/, task_spec)
        assert_match(/RSpec.describe SleepyTask/, task_spec)
      end
    ensure
      generators_config.options[:rails][:test_framework] = old_test_framework
    end

    test "generator uses configured tasks module" do
      previous_task_module = MaintenanceTasks.tasks_module
      MaintenanceTasks.tasks_module = "Foo"

      run_generator(["sleepy"])
      assert_file("app/tasks/foo/sleepy_task.rb") do |task|
        assert_match(/module Foo/, task)
      end
    ensure
      MaintenanceTasks.tasks_module = previous_task_module
    end

    test "generator namespaces task properly" do
      run_generator ["admin/sleepy"]
      assert_file "app/tasks/maintenance/admin/sleepy_task.rb" do |task|
        assert_match(/class Admin::SleepyTask < MaintenanceTasks::Task/, task)
      end
    end

    test "generator does not duplicate task suffix" do
      run_generator ["sleepy_task"]

      assert_no_file "app/tasks/maintenance/sleepy_task_task.rb"
      assert_file "app/tasks/maintenance/sleepy_task.rb"
    end

    test "generator creates a CSV Task if the --csv option is supplied" do
      run_generator ["sleepy", "--csv"]
      assert_file "app/tasks/maintenance/sleepy_task.rb" do |task|
        assert_match(/class SleepyTask < MaintenanceTasks::Task/, task)
        assert_match(/csv_collection/, task)
        assert_match(/def process\(row\)/, task)
      end
    end

    test "generator creates a collection-less Task if the --no-collection option is supplied" do
      run_generator ["sleepy", "--no-collection"]
      assert_file "app/tasks/maintenance/sleepy_task.rb" do |task|
        assert_match(/class SleepyTask < MaintenanceTasks::Task/, task)
        assert_match(/no_collection/, task)
        assert_match(/def process/, task)
      end
    end

    test "generator raises if multiple collection options provided" do
      error = assert_raises do
        run_generator(["sleepy", "--csv", "--no-collection"])
      end

      expected = "Multiple Task type options provided. "\
        "Please use either --csv or --no-collection."
      assert_equal(expected, error.message)
    end
  end
end
