# frozen_string_literal: true

require 'application_system_test_case'

module MaintenanceTasks
  class RunsTest < ApplicationSystemTestCase
    test 'run a Task' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'
      assert_text 'Enqueued'
      assert_text 'Waiting to start.'
      assert_no_button 'Run'
    end

    test 'run a CSV Task' do
      visit maintenance_tasks_path

      click_on('Maintenance::ImportPostsTask')
      attach_file('csv_file', 'test/fixtures/files/sample.csv')
      click_on 'Run'

      assert_title 'Maintenance::ImportPostsTask'
      assert_text 'Enqueued'
      assert_text 'Waiting to start.'
      assert_no_button 'Run'
    end

    test 'pause a Run' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'
      click_on 'Pause'

      assert_text 'Pausing'
      assert_text 'Pausing…'
    end

    test 'resume a Run' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'
      click_on 'Pause'
      perform_enqueued_jobs
      page.refresh
      click_on 'Resume'

      assert_text 'Enqueued'
      assert_text 'Waiting to start.'
    end

    test 'cancel a Run' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'
      click_on 'Cancel'

      assert_text 'Cancelling'
      assert_text 'Cancelling…'
    end

    test 'cancel a pausing Run' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'
      click_on 'Pause'
      assert_text 'Pausing'

      click_on 'Cancel'
      assert_text 'Cancelling…'
    end

    test 'cancel a stuck Run' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')
      click_on 'Run'
      click_on 'Cancel'

      assert_text 'Cancelling…'
      refute_button 'Cancel'

      travel 5.minutes

      refresh
      click_on 'Cancel'
    end

    test 'cancel a deleted task' do
      visit maintenance_tasks_path + '/tasks/Maintenance::PausedDeletedTask'

      click_on 'Cancel'

      assert_text 'Cancelled'
    end

    test 'run a Task that errors' do
      visit maintenance_tasks_path

      click_on('Maintenance::ErrorTask')

      perform_enqueued_jobs do
        click_on 'Run'
      end

      assert_text 'Errored'
      assert_text 'Ran for less than 5 seconds until an error happened '\
        'less than a minute ago.'
      assert_text 'ArgumentError'
      assert_text 'Something went wrong'
      assert_text "app/tasks/maintenance/error_task.rb:9:in `process'"
    end

    test 'errors for double enqueue are shown' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')

      url = page.current_url
      using_session(:other_tab) do
        visit url
        click_on 'Run'
        click_on 'Pause'
      end

      click_on 'Run'

      alert_text = 'Validation failed: ' \
        'Status Cannot transition run from status pausing to enqueued'
      assert_text alert_text
    end

    test 'errors when enqueuing are shown' do
      visit maintenance_tasks_path

      click_on 'Maintenance::EnqueueErrorTask'
      click_on 'Run'
      assert_text 'The job to perform Maintenance::EnqueueErrorTask '\
        'could not be enqueued'
      assert_text 'Error enqueuing'

      visit maintenance_tasks_path
      click_on 'Maintenance::CancelledEnqueueTask'
      click_on 'Run'
      assert_text 'The job to perform Maintenance::CancelledEnqueueTask '\
        'could not be enqueued'
      assert_text 'The job to perform Maintenance::CancelledEnqueueTask '\
        'could not be enqueued. Enqueuing has been prevented by a callback.'
    end

    test 'errors for invalid pause or cancel due to stale UI are shown' do
      visit maintenance_tasks_path
      click_on('Maintenance::UpdatePostsTask')

      url = page.current_url
      click_on 'Run'

      using_session(:other_tab) do
        visit url
        click_on 'Cancel'
      end

      click_on 'Pause'

      alert_text = 'Validation failed: ' \
        'Status Cannot transition run from status cancelling to pausing'
      assert_text alert_text
    end

    test 'list Runs including from deleted Tasks' do
      visit maintenance_tasks_path
      click_on 'Runs'

      assert_text 'Ran for', count: 3
      assert_text 'Maintenance::DeletedTask'
    end

    test 'search for a Run by Task name' do
      visit maintenance_tasks_path
      click_on 'Runs'

      fill_in 'Task name', with: 'deleted'
      click_on 'Search'

      assert_text 'Ran for', count: 2
      assert_text 'Maintenance::DeletedTask'
      assert_text 'Maintenance::PausedDeletedTask'
    end
  end
end
