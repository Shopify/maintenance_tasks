module MaintenanceTasks
  class Page
    RECORD_LIMIT = 20

    def initialize(relation:, cursor:)
      @relation = relation
      @cursor = cursor || relation.first.id
    end

    def records
      @records ||= @relation.where('id < ?', @cursor).limit(RECORD_LIMIT)
    end

    def next_cursor
      @cursor - RECORD_LIMIT
    end

    def previous_cursor
      @cursor + RECORD_LIMIT
    end

    def first_page?
      @cursor == @relation.first.id
    end

    def last_page?
      @relation.last == records.last
    end
  end
end
