# frozen_string_literal: true
require 'test_helper'
require 'generators/maintenance_task_generator'

class MaintenanceTaskGeneratorTest < Rails::Generators::TestCase
  tests MaintenanceTaskGenerator
  SAMPLE_APP_PATH = MaintenanceTasks::Engine.root.join('tmp/sample_app')
  destination SAMPLE_APP_PATH
  setup :prepare_destination

  def teardown
    FileUtils.rm_rf(SAMPLE_APP_PATH)
  end

  test 'generator creates task skeleton and task test' do
    run_generator ['sleepy']
    assert_file 'app/tasks/maintenance/sleepy_task.rb' do |task|
      assert_match(/module Maintenance/, task)
      assert_match(/class SleepyTask < MaintenanceTasks::Task/, task)
      assert_match(/def collection/, task)
      assert_match(/def process\(element\)/, task)
      assert_match(/def count/, task)
    end
    assert_file 'test/tasks/maintenance/sleepy_task_test.rb' do |task_test|
      assert_match(/module Maintenance/, task_test)
      assert_match(
        /class SleepyTaskTest < ActiveSupport::TestCase/,
        task_test
      )
    end
  end

  test 'generator namespaces task properly' do
    run_generator ['admin/sleepy']
    assert_file 'app/tasks/maintenance/admin/sleepy_task.rb' do |task|
      assert_match(/class Admin::SleepyTask < MaintenanceTasks::Task/, task)
    end
  end

  test 'generator does not duplicate task suffix' do
    run_generator ['sleepy_task']

    assert_no_file 'app/tasks/maintenance/sleepy_task_task.rb'
    assert_file 'app/tasks/maintenance/sleepy_task.rb'
  end
end
