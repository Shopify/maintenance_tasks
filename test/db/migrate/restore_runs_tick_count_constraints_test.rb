# frozen_string_literal: true

require "test_helper"
require_relative "../../../db/migrate/20260819071249_restore_runs_tick_count_constraints"

class RestoreRunsTickCountConstraintsTest < ActiveSupport::TestCase
  class TestRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  setup do
    TestRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    @connection = TestRecord.connection
  end

  teardown do
    TestRecord.remove_connection
  end

  test "repairs an affected SQLite database" do
    create_runs_table
    @connection.execute(<<~SQL.squish)
      INSERT INTO maintenance_tasks_runs (tick_count, tick_total)
      VALUES (NULL, NULL), (5, 10)
    SQL

    run_migration_up

    column = @connection.columns(:maintenance_tasks_runs).find do |candidate|
      candidate.name == "tick_count"
    end
    assert_equal "bigint", column.sql_type
    assert_includes [0, "0"], column.default
    refute column.null
    assert_equal(
      [[0, nil], [5, 10]],
      @connection.select_rows(<<~SQL.squish),
        SELECT tick_count, tick_total
        FROM maintenance_tasks_runs
        ORDER BY id
      SQL
    )

    assert_empty(capture_writes { run_migration_up })
  end

  test "does not change an already healthy SQLite database" do
    create_runs_table(default: 0, null: false)

    assert_empty(capture_writes { run_migration_up })
  end

  test "is irreversible" do
    error = assert_raises(ActiveRecord::IrreversibleMigration) do
      migration.down
    end
    assert_match(/NULL tick counts were normalized to zero/, error.message)
  end

  private

  def create_runs_table(default: nil, null: true)
    options = { null: null }
    options[:default] = default unless default.nil?

    @connection.create_table(:maintenance_tasks_runs) do |table|
      table.bigint(:tick_count, **options)
      table.bigint(:tick_total)
    end
  end

  def migration
    connection = @connection
    RestoreRunsTickCountConstraints.new.tap do |instance|
      instance.define_singleton_method(:connection) { connection }
    end
  end

  def run_migration_up
    migration.suppress_messages { migration.up }
  end

  def capture_writes(&block)
    writes = []
    callback = lambda do |*arguments|
      sql = arguments.last[:sql]
      writes << sql if sql.match?(/\A(?:ALTER|CREATE|DROP|INSERT|UPDATE)/i)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    writes
  end
end
