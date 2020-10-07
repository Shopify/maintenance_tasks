# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveJob::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = ['Maintenance::UpdatePostsTask']
      assert_equal expected, MaintenanceTasks::Task.available_tasks.map(&:name)
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end

    class ExampleTask < Task
      self.abstract_class = true

      attr_reader :task_enumerator_called
      attr_reader :task_enumerator_cursor
      attr_reader :task_iteration_called
      attr_reader :task_iteration_argument

      def task_enumerator(cursor:)
        @task_enumerator_called = true
        @task_enumerator_cursor = cursor
      end

      def task_iteration(argument)
        @task_iteration_called = true
        @task_iteration_argument = argument
      end
    end

    test '#build_enumerator calls task_enumerator' do
      task = ExampleTask.new
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
      task.send(:build_enumerator, run, cursor: :some_cursor)
      assert(task.task_enumerator_called)
      assert_equal(:some_cursor, task.task_enumerator_cursor)
    end

    test '#build_enumerator persists the job_id' do
      task = ExampleTask.new
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
      task.send(:build_enumerator, run, cursor: nil)
      assert_equal(task.job_id, run.job_id)
    end

    test '#each_iteration calls .task_iteration' do
      task = ExampleTask.new
      run = nil
      task.send(:each_iteration, :some_record, run)
      assert(task.task_iteration_called)
      assert_equal(:some_record, task.task_iteration_argument)
    end
  end
end
