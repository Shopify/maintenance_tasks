# frozen_string_literal: true

require "ripper"

module MaintenanceTasks
  # Helpers for formatting data in the maintenance_tasks views.
  #
  # @api private
  module TasksHelper
    STATUS_COLOURS = {
      "new" => ["is-primary"],
      "enqueued" => ["is-primary is-light"],
      "running" => ["is-info"],
      "interrupted" => ["is-info", "is-light"],
      "pausing" => ["is-warning", "is-light"],
      "paused" => ["is-warning"],
      "succeeded" => ["is-success"],
      "cancelling" => ["is-light"],
      "cancelled" => ["is-dark"],
      "errored" => ["is-danger"],
    }

    # Formats a run backtrace.
    #
    # @param backtrace [Array<String>] the backtrace associated with an
    #   exception on a Task that ran and raised.
    # @return [String] the parsed, HTML formatted version of the backtrace.
    def format_backtrace(backtrace)
      safe_join(backtrace.to_a, tag.br)
    end

    # Renders the progress bar.
    #
    # The style of the progress tag depends on the Run status. It also renders
    # an infinite progress when a Run is active but there is no total
    # information to estimate completion.
    #
    # @param run [Run] the Run which the progress bar will be based on.
    #
    # @return [String] the progress information properly formatted.
    # @return [nil] if the run has not started yet.
    def progress(run)
      return unless run.started?

      progress = Progress.new(run)

      progress_bar = tag.progress(
        value: progress.value,
        max: progress.max,
        class: ["progress", "mt-4"] + STATUS_COLOURS.fetch(run.status),
      )
      progress_text = tag.p(tag.i(progress.text))
      tag.div(progress_bar + progress_text, class: "block")
    end

    # Renders a span with a Run's status, with the corresponding tag class
    # attached.
    #
    # @param status [String] the status for the Run.
    # @return [String] the span element containing the status, with the
    #   appropriate tag class attached.
    def status_tag(status)
      tag.span(
        status.capitalize,
        class: ["tag", "has-text-weight-medium", "pr-2", "mr-4"] + STATUS_COLOURS.fetch(status),
      )
    end

    # Reports the approximate elapsed time a Run has been processed so far based
    # on the Run's time running attribute.
    #
    # @param run [Run] the source of the time to be reported.
    #
    # @return [String] the description of the time running attribute.
    def time_running_in_words(run)
      distance_of_time_in_words(0, run.time_running, include_seconds: true)
    end

    # Very simple syntax highlighter based on Ripper.
    #
    # It returns the same code except identifiers, keywords, etc. are wrapped
    # in +<span>+ tags with CSS classes that match the types returned by
    # Ripper.lex.
    #
    # @param code [String] the Ruby code source to syntax highlight.
    # @return [ActiveSupport::SafeBuffer] HTML of the code.
    def highlight_code(code)
      tokens = Ripper.lex(code).map do |(_position, type, content, _state)|
        case type
        when :on_nl, :on_sp, :on_ignored_nl
          content
        else
          tag.span(content, class: type.to_s.sub("on_", "ruby-").dasherize)
        end
      end
      safe_join(tokens)
    end

    # Returns a download link for a Run's CSV attachment
    def csv_file_download_path(run)
      Rails.application.routes.url_helpers.rails_blob_path(
        run.csv_file,
        only_path: true,
      )
    end

    # Resolves values covered by the inclusion validator for a Task attribute.
    # Supported option types:
    # - Arrays
    # - Procs and lambdas that optionally accept the Task instance, and return an Array.
    # - Callable objects that receive one argument, the Task instance, and return an Array.
    # - Methods that return an Array, called on the Task instance.
    #
    # Other types are not supported and will return nil.
    #
    # Returned values are used to populate a dropdown list of options.
    #
    # @param task [Task] The Task for which the value needs to be resolved.
    # @param parameter_name [String] The parameter name.
    #
    # @return [Array] value of the resolved inclusion option.
    def resolve_inclusion_value(task, parameter_name)
      task_class = task.class
      inclusion_validator = task_class.validators_on(parameter_name).find do |validator|
        validator.kind == :inclusion
      end
      return unless inclusion_validator

      in_option = inclusion_validator.options[:in] || inclusion_validator.options[:within]
      resolved_in_option = case in_option
      when Proc
        if in_option.arity == 0
          in_option.call
        else
          in_option.call(task)
        end
      when Symbol
        method = task.method(in_option)
        method.call if method.arity.zero?
      else
        if in_option.respond_to?(:call)
          in_option.call(task)
        else
          in_option
        end
      end

      resolved_in_option if resolved_in_option.is_a?(Array)
    end

    # Return the appropriate field tag for the parameter, based on its type.
    # If the parameter has a `validates_inclusion_of` validator, return a dropdown list of options instead.
    def parameter_field(form_builder, parameter_name)
      inclusion_values = resolve_inclusion_value(form_builder.object, parameter_name)
      if inclusion_values
        return tag.div(form_builder.select(parameter_name, inclusion_values, prompt: "Select a value"), class: "select")
      end

      case form_builder.object.class.attribute_types[parameter_name]
      when ActiveModel::Type::Integer
        form_builder.number_field(parameter_name, class: "input")
      when ActiveModel::Type::Decimal, ActiveModel::Type::Float
        form_builder.number_field(parameter_name, { step: "any", class: "input" })
      when ActiveModel::Type::DateTime
        form_builder.datetime_field(parameter_name, class: "input") + datetime_field_help_text
      when ActiveModel::Type::Date
        form_builder.date_field(parameter_name, class: "input")
      when ActiveModel::Type::Time
        form_builder.time_field(parameter_name, class: "input")
      when ActiveModel::Type::Boolean
        form_builder.check_box(parameter_name, class: "checkbox")
      else
        form_builder.text_area(parameter_name, class: "textarea")
      end
        .then { |input| tag.div(input, class: "control") }
    end

    # Return helper text for the datetime-local form field.
    def datetime_field_help_text
      text =
        if Time.zone_default.nil? || Time.zone_default.name == "UTC"
          "Timezone: UTC."
        else
          "Timezone: #{Time.now.zone}."
        end
      tag.div(
        tag.p(text),
        class: "content is-small",
      )
    end

    # Checks if an attribute is required for a given Task.
    #
    # @param task [MaintenanceTasks::TaskDataShow] The TaskDataShow instance.
    # @param parameter_name [Symbol] The name of the attribute to check.
    # @return [Boolean] Whether the attribute is required.
    def attribute_required?(task, parameter_name)
      task.class.validators_on(parameter_name).any? do |validator|
        validator.kind == :presence
      end
    end
  end
end
