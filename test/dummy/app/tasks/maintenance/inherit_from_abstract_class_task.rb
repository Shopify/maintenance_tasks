# frozen_string_literal: true

module Maintenance
  class InheritFromAbstractClassTask < ApplicationTask
    no_collection

    def process
      # Task only exists to verify it is correctly loaded when inheriting.
    end
  end
end
