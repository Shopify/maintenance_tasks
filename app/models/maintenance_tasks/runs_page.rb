# frozen_string_literal: true

module MaintenanceTasks
  # This class is responsible for handling cursor-based pagination for Run
  # records.
  #
  # @api private
  class RunsPage
    # The number of Runs to show on a single Task page.
    RUNS_PER_PAGE = 20

    # Initializes a Runs Page with a Runs relation and a cursor. This page is
    # used by the views to render a set of Runs.
    # @param runs [ActiveRecord::Relation<MaintenanceTasks::Run>] the relation
    #   of Run records to be paginated.
    # @param cursor [String, nil] the id that serves as the cursor when
    #   querying the Runs dataset to produce a page of Runs. If nil, the first
    #   Runs in the relation are used.
    def initialize(runs, cursor)
      @runs = runs
      @cursor = cursor
    end

    # Returns the records for a Page, taking into account the cursor if one is
    # present. Limits the number of records to 20.
    #
    # An extra Run is loaded so that we can verify whether we're on the last Page.
    #
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>] a limited amount
    #  of Run records.
    def records
      @records ||= begin
        runs_after_cursor = if @cursor.present?
          @runs.where("id < ?", @cursor)
        else
          @runs
        end
        limited_runs = runs_after_cursor.limit(RUNS_PER_PAGE + 1).load
        @extra_run = limited_runs.length > RUNS_PER_PAGE ? limited_runs.last : nil
        limited_runs.take(RUNS_PER_PAGE)
      end
    end

    # Returns the cursor to use for the next Page of Runs. It is the id of the
    # last record on the current Page.
    #
    # @return [Integer] the id of the last record for the Page.
    def next_cursor
      records.last.id
    end

    # Returns whether this Page is the last one.
    #
    # @return [Boolean] whether this Page contains the last Run record in the Runs
    #   dataset that is being paginated. This is done by checking whether an extra
    #   Run was loaded by #records - if no extra Run was loaded, this is the last page.
    def last?
      records
      @extra_run.nil?
    end
  end
end
