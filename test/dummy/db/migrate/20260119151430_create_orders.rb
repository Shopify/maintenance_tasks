# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table(:orders, primary_key: [:shop_id, :number]) do |t|
      t.bigint(:shop_id, null: false)
      t.bigint(:number, null: false)
      t.string(:name)
    end
  end
end
