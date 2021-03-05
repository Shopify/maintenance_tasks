# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class ApplicationHelperTest < ActionView::TestCase
    setup do
      @pagy = mock
      @page = mock
    end

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

    test '#pagination_text returns nil if pages is less than or equal to 1' do
      @page.stubs(recordset: mock(page_count: 1))
      assert_nil pagination_text(@page, 'run')
    end

    test '#pagination_text returns text with pagination info if pages is greater than 1' do
      page_number = 1
      total_pages = 2
      records_count = 12
      @page.stubs(
        number: page_number,
        recordset: mock(page_count: total_pages, records_count: records_count)
      )
      assert_equal '<span>Showing page 1 of 2 (12 total runs)</span>',
        pagination_text(@page, 'run')
    end

    test '#time_ago returns a time element with the given datetime worded as relative to now and ISO 8601 UTC time in title attribute' do
      travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
      time = Time.zone.local(2020, 01, 01, 01, 00, 00)

      expected = '<time datetime="2020-01-01T01:00:00Z" '\
        'title="2020-01-01T01:00:00Z" class="is-clickable">8 days ago</time>'
      assert_equal expected, time_ago(time)
    end
  end
end
