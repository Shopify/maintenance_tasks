# frozen_string_literal: true

module Maintenance
  class CacheOutputTask < MaintenanceTasks::Task
    @cache = {}

    class << self
      attr_accessor :cache
    end

    def collection
      [1, 2]
    end

    def process(number)
      self.output = output.to_s + "Completed number #{number}.\n"
    end

    def output=(message)
      self.class.cache[run_data.id] = message
    end

    def output
      self.class.cache[run_data.id]
    end
  end
end
