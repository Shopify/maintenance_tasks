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
        class: ["progress"] + STATUS_COLOURS.fetch(run.status),
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
      tag.span(status.capitalize, class: ["tag"] + STATUS_COLOURS.fetch(status))
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

    # Return the appropriate field tag for the parameter
    def parameter_field(form_builder, parameter_name)
      case form_builder.object.class.attribute_types[parameter_name]
      when ActiveModel::Type::Integer, ActiveModel::Type::Decimal,
           ActiveModel::Type::Float
        form_builder.number_field(parameter_name)
      when ActiveModel::Type::DateTime
        form_builder.datetime_field(parameter_name)
      when ActiveModel::Type::Date
        form_builder.date_field(parameter_name)
      when ActiveModel::Type::Time
        form_builder.time_field(parameter_name)
      when ActiveModel::Type::Boolean
        form_builder.check_box(parameter_name)
      else
        form_builder.text_area(parameter_name, class: "textarea")
      end
    end
  end
end
