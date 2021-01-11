# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::CancelledEnqueueTask',
        'Maintenance::EnqueueErrorTask',
        'Maintenance::ErrorTask',
        'Maintenance::TestTask',
        'Maintenance::UpdatePostsTask',
      ]
      assert_equal expected,
        MaintenanceTasks::Task.available_tasks.map(&:name).sort
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named raises Not Found Error if the task doesn't exist" do
      error = assert_raises(Task::NotFoundError) do
        Task.named('Maintenance::DoesNotExist')
      end
      assert_equal 'Task Maintenance::DoesNotExist not found.', error.message
      assert_equal 'Maintenance::DoesNotExist', error.name
    end

    test '.process calls #process' do
      item = mock
      Maintenance::TestTask.any_instance.expects(:process).with(item)
      Maintenance::TestTask.process(item)
    end

    test '.collection calls #collection' do
      assert_equal [1, 2], Maintenance::TestTask.collection
    end

    test '.count calls #count' do
      assert_equal 2, Maintenance::TestTask.count
    end

    test '#count is nil by default' do
      task = Task.new
      assert_nil task.count
    end

    test '#collection raises NotImplementedError' do
      error = assert_raises(NotImplementedError) { Task.new.collection }
      message = 'MaintenanceTasks::Task must implement `collection`.'
      assert_equal message, error.message
    end

    test '#process raises NotImplementedError' do
      error = assert_raises(NotImplementedError) do
        Task.new.process('an item')
      end
      message = 'MaintenanceTasks::Task must implement `process`.'
      assert_equal message, error.message
    end

    test '#enumerator_builder is an instance of JobIteration::EnumeratorBuilder' do
      task = Task.new
      assert_kind_of JobIteration::EnumeratorBuilder, task.enumerator_builder
    end
  end
end
