# frozen_string_literal: true

module MaintenanceTasks
  # This class encapsulates the logic behind updating the tick counter.
  #
  # It's initialized with a duration for the throttle, and a block to persist
  # the number of ticks to increment.
  #
  # When +tick+ is called, the block will be called with the increment,
  # provided the duration since the last update (or initialization) has been
  # long enough.
  #
  # To not lose any increments, +persist+ should be used, which may call the
  # block with any leftover ticks.
  #
  # @api private
  class Ticker
    # Creates a Ticker that will call the block each time +tick+ is called,
    # unless the tick is being throttled.
    #
    # @param throttle_duration [ActiveSupport::Duration, Numeric] Duration
    #   since initialization or last call that will cause a throttle.
    # @yieldparam ticks [Integer] the increment in ticks to be persisted.
    def initialize(throttle_duration, &persist)
      @throttle_duration = throttle_duration
      @persist = persist
      @last_persisted = Time.now
      @ticks_recorded = 0
    end

    # Increments the tick count by one, and may persist the new value if the
    # threshold duration has passed since initialization or the tick count was
    # last persisted.
    def tick
      @ticks_recorded += 1
      persist if persist?
    end

    # Persists the tick increments by calling the block passed to the
    # initializer. This is idempotent in the sense that calling it twice in a
    # row will call the block at most once (if it had been throttled).
    def persist
      return if @ticks_recorded == 0
      @last_persisted = Time.now
      @persist.call(@ticks_recorded)
      @ticks_recorded = 0
    end

    private

    def persist?
      Time.now - @last_persisted >= @throttle_duration
    end
  end
end
