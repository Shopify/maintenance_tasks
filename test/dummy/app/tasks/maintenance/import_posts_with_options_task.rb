# frozen_string_literal: true

module Maintenance
  class ImportPostsWithOptionsTask < MaintenanceTasks::Task
    csv_collection(skip_lines: /^#/, converters: ->(field) { field.upcase })

    def process(row)
      Post.create!(title: row["title"], content: row["content"])
    end
  end
end
