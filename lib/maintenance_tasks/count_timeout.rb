# frozen_string_literal: true

module MaintenanceTasks
  # Wraps a block in a database-level statement timeout so a slow query is
  # cancelled by the server rather than left running indefinitely.
  #
  # Used by {TaskJobConcern} to bound the {Task#count} query that populates
  # the progress bar — a count failure must not stall or fail a task run.
  #
  # The mechanism is adapter-specific:
  #
  # * **PostgreSQL** — `SET LOCAL statement_timeout` inside
  #   `transaction(requires_new: true)`; automatically reset on commit or
  #   rollback. When invoked inside an existing transaction (e.g. test
  #   fixtures), AR's `requires_new` opens a savepoint rather than a real
  #   transaction; the timeout is still enforced for the duration of the
  #   block, but the `SET LOCAL` setting is only cleared when the outer
  #   transaction ends. {TaskJobConcern#on_start} is not wrapped in a
  #   transaction in production, so this is invisible there.
  # * **MySQL / Trilogy** — `SET SESSION max_execution_time`, with the prior
  #   value restored in an `ensure` block.
  # * **SQLite / unknown adapters** — no-op; the block runs without a timeout.
  #
  # On timeout the database raises {ActiveRecord::QueryCanceled} (or its
  # subclass {ActiveRecord::StatementTimeout}). Callers are expected to
  # rescue and treat the result as unknown.
  #
  # @example
  #   MaintenanceTasks::CountTimeout.with_timeout(5_000) do
  #     User.where(active: true).count
  #   end
  module CountTimeout
    extend self

    # Run +block+ with a server-side statement timeout of +timeout_ms+
    # milliseconds applied to +connection+.
    #
    # When +timeout_ms+ is +nil+, +0+, or negative the block runs unmodified —
    # callers can pass the configured value directly without a guard.
    #
    # @param timeout_ms [Integer, nil] the timeout in milliseconds.
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
    #   the connection to apply the timeout to. Defaults to
    #   `ActiveRecord::Base.connection`.
    # @yield the block to execute under the timeout.
    # @return the value returned by the block.
    # @raise [ActiveRecord::QueryCanceled] if the database cancels a query.
    def with_timeout(timeout_ms, connection: ActiveRecord::Base.connection, &block)
      return yield if timeout_ms.nil? || timeout_ms <= 0

      case connection.adapter_name
      when "PostgreSQL", "PostGIS"
        with_postgresql_timeout(connection, timeout_ms.to_i, &block)
      when "Mysql2", "Trilogy"
        with_mysql_timeout(connection, timeout_ms.to_i, &block)
      else
        yield
      end
    end

    private

    def with_postgresql_timeout(connection, timeout_ms, &block)
      connection.transaction(requires_new: true) do
        connection.execute("SET LOCAL statement_timeout = #{timeout_ms}")
        block.call
      end
    end

    def with_mysql_timeout(connection, timeout_ms)
      previous = connection.select_value("SELECT @@SESSION.max_execution_time").to_i
      connection.execute("SET SESSION max_execution_time = #{timeout_ms}")
      begin
        yield
      ensure
        connection.execute("SET SESSION max_execution_time = #{previous}")
      end
    end
  end
end
