# frozen_string_literal: true

# TODO: Remove this patch once all supported Rails versions include the changes
# upstream - https://github.com/rails/rails/pull/42312/commits/a031a43d969c87542c4ee8d0d338d55fcbb53376
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
