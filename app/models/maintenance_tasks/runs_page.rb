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
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>] a limited amount
    #  of Run records.
    def records
      @records ||= begin
        runs_after_cursor = if @cursor.present?
          @runs.where("id < ?", @cursor)
        else
          @runs
        end
        runs_after_cursor.limit(RUNS_PER_PAGE)
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
    # @return [Boolean] whether this Page contains the last Run record in the
    #   Runs dataset that is being paginated.
    def last?
      @runs.unscope(:includes).pluck(:id).last == next_cursor
    end
  end
end
