# frozen_string_literal: true

module Maintenance
  class CallbackTestTask < MaintenanceTasks::Task
    after_start :after_start_callback
    after_complete :after_complete_callback
    after_pause :after_pause_callback
    after_interrupt :after_interrupt_callback
    after_cancel :after_cancel_callback
    after_error :after_error_callback

    def collection
      [1, 2]
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end

    def after_start_callback; end

    def after_complete_callback; end

    def after_pause_callback; end

    def after_interrupt_callback; end

    def after_cancel_callback; end

    def after_error_callback; end
  end
end
