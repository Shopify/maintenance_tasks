class ProductTask < MaintenanceTasks::ActiveRecordTask
  # Consumers implement these method
  def collection() Product.all end
  def process(product) product.discontinue! end

  # .count implementation provided, but could be overriden if consumer has some
  # optimization or if the relation is too expensive to count

  # Could easily add
  #   run_in_batches_of 50
  # or
  #   def batch_size() 50 end
end

class SeedTask < MaintenanceTasks::ArrayTask
  # Similar API to ActiveRecordTask
  def collection() %w[Alice Bob Chantalle] end
  def process(name) Person.create!(name: name) end
  # Again, .count provided
end

class BetaFlagTask < MaintenanceTasks::CsvTask
  # CSV infra handles everything except .process
  def process(row) BetaFlag[:whatever].enable(row.shop_id) end
end

class PaymentTask < MaintenanceTasks::Task
  # Consumers implement .enumerator instead of .collection, without having to
  # know that other tasks actually also use .enumerator internally
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

  # Again, can be implemented if appropriate
  def count() InvoiceAPI.unpaid_count end

  def process(invoice) invoice.pay! if invoice.unpaid? end
end
