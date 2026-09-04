# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class RunsPageTest < ActiveSupport::TestCase
    setup do
      @task_name = "Maintenance::TestTask"
      21.times do
        Run.create!(
          task_name: @task_name,
          started_at: Time.now,
          tick_count: 10,
          tick_total: 10,
          status: :succeeded,
          ended_at: Time.now,
        )
      end
      @runs = Run.where(task_name: @task_name).order(created_at: :desc)
    end

    test "#records returns the most recent 20 runs when there is no cursor" do
      runs_page = RunsPage.new(@runs, nil)
      assert_equal @runs.first(20), runs_page.records
    end

    test "#records returns 20 runs after cursor if one is present" do
      runs_page = RunsPage.new(@runs, @runs.first.id)
      assert_equal @runs.last(20), runs_page.records
    end

    test "#next_cursor returns the id of the last run in the record set" do
      last_id = @runs.last.id
      runs_page = RunsPage.new(@runs, @runs.first.id)
      assert_equal last_id, runs_page.next_cursor
    end

    test "#last? returns true if the last run in the record set is the last run for the relation" do
      runs_page = RunsPage.new(@runs, @runs.first.id)
      assert_predicate runs_page, :last?
    end

    test "#last? returns false if the last run in the record set is not the last run for the relation" do
      runs_page = RunsPage.new(@runs, nil)
      refute_predicate runs_page, :last?
    end

    test "#records does not duplicate or omit runs when ids and timestamps have different orders" do
      Run.where(task_name: @task_name).delete_all
      base_time = Time.current
      Run.create!(task_name: @task_name, status: :succeeded, created_at: base_time - 1.hour)
      21.times do |i|
        Run.create!(task_name: @task_name, status: :succeeded, created_at: base_time - i.minutes)
      end

      runs = Run.where(task_name: @task_name).order(created_at: :desc)
      first_page = RunsPage.new(runs, nil)
      second_page = RunsPage.new(runs, first_page.next_cursor)

      expected_ids = runs.reorder(created_at: :desc, id: :desc).pluck(:id)
      assert_equal expected_ids, (first_page.records + second_page.records).map(&:id)
    end

    test "#records uses the id to order runs with identical timestamps" do
      Run.where(task_name: @task_name).delete_all
      created_at = Time.current
      22.times do
        Run.create!(task_name: @task_name, status: :succeeded, created_at: created_at)
      end

      runs = Run.where(task_name: @task_name).order(created_at: :desc)
      first_page = RunsPage.new(runs, nil)
      second_page = RunsPage.new(runs, first_page.next_cursor)

      expected_ids = runs.reorder(created_at: :desc, id: :desc).pluck(:id)
      assert_equal expected_ids, (first_page.records + second_page.records).map(&:id)
    end
  end
end
