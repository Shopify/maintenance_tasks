# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::CancelledEnqueueTask',
        'Maintenance::EnqueueErrorTask',
        'Maintenance::ErrorTask',
        'Maintenance::ImportPostsTask',
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

    test '.enumerator_builder calls #enumerator_builder' do
      enumerator_builder = stub('FakeEnumeratorBuilder')
      Maintenance::TestTask.any_instance.expects(:enumerator_builder)
        .with.returns(enumerator_builder)
      assert_equal enumerator_builder, Maintenance::TestTask.enumerator_builder
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

    test '#collection raises NoMethodError' do
      error = assert_raises(NoMethodError) { Task.new.collection }
      message = 'MaintenanceTasks::Task must implement `collection`.'
      assert_equal message, error.message
    end

    test '#process raises NoMethodError' do
      error = assert_raises(NoMethodError) { Task.new.process('an item') }
      message = 'MaintenanceTasks::Task must implement `process`.'
      assert_equal message, error.message
    end
  end
end
