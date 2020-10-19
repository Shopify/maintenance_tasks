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
  end
end
