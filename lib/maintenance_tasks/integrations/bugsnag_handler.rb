# frozen_string_literal: true
require 'bugsnag'

MaintenanceTasks.error_handler = ->(error) { Bugsnag.notify(error) }
