class ProductTask < MaintenanceTasks::Task
  include MaintenanceTasks::Adapters::ActiveRecord

  def collection() Product.all end
  def process(product) product.discontinue! end
end

class SeedTask < MaintenanceTasks::Task
  include MaintenanceTasks::Adapters::Array

  def collection() %w[Alice Bob Chantalle] end
  def process(name) Person.create!(name: name) end
end

class BetaFlagTask < MaintenanceTasks::Task
  include MaintenanceTasks::Adapters::CSV

  def process(row) BetaFlag[:whatever].enable(row.shop_id) end
end

class PaymentTask < MaintenanceTasks::Task
  def enumerator(cursor:)
    Enumerator.new do |yielder|
      loop do
        page = cursor ? InvoiceAPI.fetch(after: cursor) : InvoiceAPI.fetch_all
        break if page.empty?
        page.each do |invoice|
          cursor = invoice.id
          yielder.yield(invoice, cursor)
        end
      end
    end
  end

  def count() InvoiceAPI.unpaid_count end

  def process(invoice) invoice.pay! if invoice.unpaid? end
end
