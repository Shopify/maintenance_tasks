# frozen_string_literal: true

if Rails.gem_version < Gem::Version.new("7.0")
  # Add attribute readers.
  module ActiveRecordBatchEnumerator
    # The primary key value from which the BatchEnumerator starts,
    #   inclusive of the value.
    attr_reader :start

    # The primary key value at which the BatchEnumerator ends,
    #   inclusive of the value.
    attr_reader :finish

    # The relation from which the BatchEnumerator yields batches.
    attr_reader :relation

    # The size of the batches yielded by the BatchEnumerator.
    def batch_size
      @of
    end
  end

  ActiveRecord::Batches::BatchEnumerator.include(ActiveRecordBatchEnumerator)
end
