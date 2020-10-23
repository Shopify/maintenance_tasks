# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::ErrorTask',
        'Maintenance::UpdatePostsTask',
        'MaintenanceTasks::TaskJobTest::TestTask',
      ]
      assert_equal expected,
        MaintenanceTasks::Task.available_tasks.map(&:name).sort
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end

    test '.runs returns the Active Record relation of the runs associated with a Task' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')

      assert_equal 1, Maintenance::UpdatePostsTask.runs.count
      assert_equal run, Maintenance::UpdatePostsTask.runs.first
    end

    test '.active_run returns the only enqueued, running, or paused run associated with a Task' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.paused!
      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.enqueued!
      run.running!
      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.succeeded!
      assert_nil Maintenance::UpdatePostsTask.active_run
    end

    test '#task_count is nil by default' do
      task = Task.new
      assert_nil task.task_count
    end

    test '#collection raises NotImplementedError' do
      error = assert_raises(NotImplementedError) { Task.new.collection }
      message = 'MaintenanceTasks::Task must implement `collection`.'
      assert_equal message, error.message
    end

    test '#task_iteration raises NotImplementedError' do
      error = assert_raises(NotImplementedError) do
        Task.new.task_iteration('an item')
      end
      message = 'MaintenanceTasks::Task must implement `task_iteration`.'
      assert_equal message, error.message
    end

    test '#enumerator_builder is an instance of JobIteration::EnumeratorBuilder' do
      task = Task.new
      assert_kind_of JobIteration::EnumeratorBuilder, task.enumerator_builder
    end
  end
end
