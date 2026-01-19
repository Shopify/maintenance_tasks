# frozen_string_literal: true

class Order < ApplicationRecord
  self.primary_key = [:shop_id, :number]
end
