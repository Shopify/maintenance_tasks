# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class ApplicationRecordTest < ActiveSupport::TestCase
    setup do
      ActiveSupport.on_load(:maintenance_tasks_record) do |_|
        define_method :defined_by_load_hook do
          puts "I am defined dynamically by activesupport load hook"
        end
      end
    end

    teardown do
      MaintenanceTasks::ApplicationRecord.class_eval { undef :defined_by_load_hook }
    end

    test "load hook called when model is loaded" do
      assert_includes MaintenanceTasks::ApplicationRecord.instance_methods, :defined_by_load_hook
    end
  end
end
