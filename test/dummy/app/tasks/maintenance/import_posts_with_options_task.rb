# frozen_string_literal: true

module Maintenance
  class ImportPostsWithOptionsTask < MaintenanceTasks::Task
    csv_collection(skip_lines: /^#/, converters: ->(field) { field.to_s.upcase })

    def process(row)
      Post.create!(title: row["title"], content: row["content"])
    end
  end
end
