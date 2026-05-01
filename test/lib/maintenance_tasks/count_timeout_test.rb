# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class CountTimeoutTest < ActiveSupport::TestCase
    test ".with_timeout yields without modifying the connection when timeout_ms is nil" do
      connection = mock("connection")
      connection.expects(:adapter_name).never

      result = CountTimeout.with_timeout(nil, connection: connection) { :ok }

      assert_equal :ok, result
    end

    test ".with_timeout yields without modifying the connection when timeout_ms is zero" do
      connection = mock("connection")
      connection.expects(:adapter_name).never

      assert_equal :ok, CountTimeout.with_timeout(0, connection: connection) { :ok }
    end

    test ".with_timeout yields without modifying the connection when timeout_ms is negative" do
      connection = mock("connection")
      connection.expects(:adapter_name).never

      assert_equal :ok, CountTimeout.with_timeout(-1, connection: connection) { :ok }
    end

    test ".with_timeout is a no-op on SQLite" do
      connection = mock("connection")
      connection.stubs(adapter_name: "SQLite")
      connection.expects(:execute).never
      connection.expects(:transaction).never

      assert_equal :ok, CountTimeout.with_timeout(5_000, connection: connection) { :ok }
    end

    test ".with_timeout is a no-op for unknown adapters" do
      connection = mock("connection")
      connection.stubs(adapter_name: "SomeFutureAdapter")
      connection.expects(:execute).never
      connection.expects(:transaction).never

      assert_equal :ok, CountTimeout.with_timeout(5_000, connection: connection) { :ok }
    end

    test ".with_timeout sets statement_timeout inside a transaction on PostgreSQL" do
      connection = mock("connection")
      connection.stubs(adapter_name: "PostgreSQL")

      transaction_seen = false
      connection.expects(:transaction).with(requires_new: true).yields.returns(:txn_result)
      connection.expects(:execute).with("SET LOCAL statement_timeout = 5000")

      result = CountTimeout.with_timeout(5_000, connection: connection) do
        transaction_seen = true
        :inner
      end

      assert transaction_seen, "block should have been invoked"
      assert_equal :txn_result, result
    end

    test ".with_timeout works on PostGIS" do
      connection = mock("connection")
      connection.stubs(adapter_name: "PostGIS")
      connection.expects(:transaction).with(requires_new: true).yields.returns(:done)
      connection.expects(:execute).with("SET LOCAL statement_timeout = 1234")

      assert_equal :done, CountTimeout.with_timeout(1_234, connection: connection) { :ignored }
    end

    test ".with_timeout sets and restores max_execution_time on Mysql2" do
      connection = mock("connection")
      connection.stubs(adapter_name: "Mysql2")

      seq = sequence("mysql")
      connection.expects(:select_value).with("SELECT @@SESSION.max_execution_time").returns("0").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 5000").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 0").in_sequence(seq)

      assert_equal :ok, CountTimeout.with_timeout(5_000, connection: connection) { :ok }
    end

    test ".with_timeout works on Trilogy" do
      connection = mock("connection")
      connection.stubs(adapter_name: "Trilogy")

      seq = sequence("trilogy")
      connection.expects(:select_value).returns("250").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 5000").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 250").in_sequence(seq)

      CountTimeout.with_timeout(5_000, connection: connection) { :ok }
    end

    test ".with_timeout restores max_execution_time on MySQL even if the block raises" do
      connection = mock("connection")
      connection.stubs(adapter_name: "Mysql2")

      seq = sequence("mysql")
      connection.expects(:select_value).returns("100").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 5000").in_sequence(seq)
      connection.expects(:execute).with("SET SESSION max_execution_time = 100").in_sequence(seq)

      assert_raises(RuntimeError) do
        CountTimeout.with_timeout(5_000, connection: connection) { raise "boom" }
      end
    end

    test ".with_timeout lets ActiveRecord::QueryCanceled propagate" do
      connection = mock("connection")
      connection.stubs(adapter_name: "Mysql2")
      connection.stubs(:select_value).returns("0")
      connection.stubs(:execute)

      assert_raises(ActiveRecord::QueryCanceled) do
        CountTimeout.with_timeout(5_000, connection: connection) do
          raise ActiveRecord::QueryCanceled, "timeout"
        end
      end
    end

    class PostgreSQLIntegrationTest < ActiveSupport::TestCase
      # `SET LOCAL` is transaction-scoped. With transactional fixtures the test
      # already runs inside an outer transaction, so the helper's
      # `transaction(requires_new: true)` opens a savepoint and the setting
      # leaks past the helper's block. Disable fixture wrapping so we exercise
      # the same code path the production job runs in.
      self.use_transactional_tests = false

      setup do
        skip "requires PostgreSQL" unless ["PostgreSQL", "PostGIS"].include?(
          ActiveRecord::Base.connection.adapter_name,
        )
      end

      test "a query exceeding the timeout raises ActiveRecord::QueryCanceled" do
        assert_raises(ActiveRecord::QueryCanceled) do
          CountTimeout.with_timeout(50) do
            ActiveRecord::Base.connection.select_value("SELECT pg_sleep(2)")
          end
        end
      end

      test "a fast query completes normally under the timeout" do
        result = CountTimeout.with_timeout(5_000) do
          ActiveRecord::Base.connection.select_value("SELECT 1")
        end

        assert_equal 1, result
      end

      test "statement_timeout is reset after the block returns" do
        CountTimeout.with_timeout(50) do
          ActiveRecord::Base.connection.select_value("SELECT 1")
        end

        timeout = ActiveRecord::Base.connection.select_value("SHOW statement_timeout")

        assert_equal "0", timeout
      end

      test "statement_timeout is reset after the block raises" do
        assert_raises(ActiveRecord::QueryCanceled) do
          CountTimeout.with_timeout(50) do
            ActiveRecord::Base.connection.select_value("SELECT pg_sleep(2)")
          end
        end

        timeout = ActiveRecord::Base.connection.select_value("SHOW statement_timeout")

        assert_equal "0", timeout
      end
    end
  end
end
