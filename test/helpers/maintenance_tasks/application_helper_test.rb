# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class ApplicationHelperTest < ActionView::TestCase
    setup { @pagy = mock }

    test '#pagination returns nil if pages is less than or equal to 1' do
      @pagy.expects(pages: 1)
      expects(:pagy_bulma_nav).never
      assert_nil pagination(@pagy)
    end

    test '#pagination returns pagination element if pages is greater than 1' do
      @pagy.expects(pages: 2)
      expects(:pagy_bulma_nav).with(@pagy).returns('pagination')
      assert_equal 'pagination', pagination(@pagy)
    end

    test '#formatted_datetime returns time element with local datetime and ISO 8601 UTC time in title attribute' do
      time = Time.zone.local(2020, 01, 01, 01, 00, 00)

      datetime = '2020-01-01T01:00:00Z'
      title = '2020-01-01T01:00:00Z'
      text = 'January 01, 2020 01:00'
      exp = "<time datetime=\"#{datetime}\" title=\"#{title}\">#{text}</time>"
      assert_equal exp, formatted_datetime(time)
    end
  end
end
