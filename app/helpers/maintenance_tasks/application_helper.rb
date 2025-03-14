# frozen_string_literal: true

module MaintenanceTasks
  # Module for common view helpers.
  #
  # @api private
  module ApplicationHelper
    # Renders a time element with the given datetime, worded as relative to the
    # current time.
    #
    # The ISO 8601 version of the datetime is shown on hover
    # via a title attribute.
    #
    # @param datetime [ActiveSupport::TimeWithZone] the time to be presented.
    # @return [String] the HTML to render with the relative datetime in words.
    def time_ago(datetime)
      time_tag(datetime, title: datetime.utc, class: "is-clickable") do
        time_ago_in_words(datetime) + " ago"
      end
    end

    # Checks if an attribute is required for a given Task.
    #
    # @param task_data_show [MaintenanceTasks::TaskDataShow] The TaskDataShow instance.
    # @param attribute_name [Symbol] The name of the attribute to check.
    # @return [Boolean] Whether the attribute is required.
    def attribute_required?(task_data_show, attribute_name)
      model_class = task_data_show.name.constantize
      model_class.validators_on(attribute_name).any? do |validator|
        validator.is_a?(ActiveModel::Validations::PresenceValidator)
      end
    end
  end
end
