# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TasksHelperTest < ActionView::TestCase
    setup do
      @run = Run.new
    end

    test "#format_backtrace converts the backtrace to a formatted string" do
      backtrace = [
        "app/jobs/maintenance/error_task.rb:13:in `foo'",
        "app/jobs/maintenance/error_task.rb:9:in `process'",
      ]

      expected_trace = "app/jobs/maintenance/error_task.rb:13:in `foo&#39;" \
        "<br>app/jobs/maintenance/error_task.rb:9:in `process&#39;"

      assert_equal expected_trace, format_backtrace(backtrace)
    end

    test "#progress returns a <div> with a <progress> and progress text when Run has started" do
      @run.started_at = Time.now

      Progress.expects(:new).with(@run).returns(
        mock(value: 42, max: 84, text: "Almost there!"),
      )

      expected = '<div class="block"><progress value="42" max="84" ' \
        'class="progress mt-4 is-primary is-light"></progress>' \
        "<p><i>Almost there!</i></p></div>"
      assert_equal expected, progress(@run)
    end

    test "#progress is nil if the Run has not started" do
      assert_nil progress(@run)
    end

    test "#progress returns a a <div> with a <progress> with no value when the Progress value is nil" do
      @run.started_at = Time.now
      Progress.expects(:new).with(@run).returns(
        mock(value: nil, max: 84, text: "Almost there!"),
      )

      expected = '<div class="block"><progress max="84" ' \
        'class="progress mt-4 is-primary is-light"></progress>' \
        "<p><i>Almost there!</i></p></div>"
      assert_equal expected, progress(@run)
    end

    test "#progress returns a <div> with a <progress> with no value when Run is succeeded and tick_total is 0" do
      @run.status = :succeeded
      @run.started_at = Time.now

      Progress.expects(:new).with(@run).returns(
        mock(value: 0, max: nil, text: "Processed 0 items."),
      )

      expected = '<div class="block"><progress value="0" ' \
        'class="progress mt-4 is-success"></progress>' \
        "<p><i>Processed 0 items.</i></p></div>"
      assert_equal expected, progress(@run)
    end

    test "#status_tag renders a span with the appropriate tag based on status" do
      expected = '<span class="tag has-text-weight-medium pr-2 mr-4 is-warning is-light">Pausing</span>'
      assert_equal expected, status_tag("pausing")
    end

    test "#time_running_in_words reports the approximate time running of the given Run" do
      @run.time_running = 182.5
      assert_equal "3 minutes", time_running_in_words(@run)
    end

    test "#highlight_code returns a HTML safe string" do
      assert_predicate highlight_code("self"), :html_safe?
    end

    test "#highlight_code wraps syntax in span" do
      assert_equal '<span class="ruby-kw">self</span>', highlight_code("self")
      assert_equal '<span class="ruby-const">CSV</span>', highlight_code("CSV")
      assert_equal '<span class="ruby-int">42</span>', highlight_code("42")
      assert_equal '<span class="ruby-float">4.2</span>', highlight_code("4.2")
      assert_equal '<span class="ruby-ivar">@foo</span>', highlight_code("@foo")
    end

    test "#highlight_code does not wrap whitespace" do
      assert_equal '<span class="ruby-int">1</span>' + "\n" \
        '<span class="ruby-int">2</span>',
        highlight_code("1\n2")
      assert_equal '<span class="ruby-int">1</span>' + " " \
        '<span class="ruby-int">2</span>',
        highlight_code("1 2")
      assert_equal "\n", highlight_code("\n")
    end

    test "#csv_file_download_path generates a download link to the CSV attachment for a Run" do
      run = Run.new(task_name: "Maintenance::ImportPostsTask")
      csv = Rack::Test::UploadedFile.new(file_fixture("sample.csv"), "text/csv")
      run.csv_file.attach(csv)
      run.save!

      assert_match %r{rails/active_storage/blobs/\S+/sample.csv},
        csv_file_download_path(run)
    end

    test "#resolve_inclusion_value resolves inclusion validator for task attributes" do
      [
        "integer_dropdown_attr",
        "boolean_dropdown_attr",
        "integer_dropdown_attr_proc_no_arg",
        "integer_dropdown_attr_proc_arg",
        "integer_dropdown_attr_from_method",
        "integer_dropdown_attr_callable",
      ].each do |attribute|
        assert_match "Select a value", markup(attribute).squish
      end

      refute_match "Select a value", markup("text_integer_attr_unbounded_range").squish
    end

    test "#parameter_field adds information about datetime fields when Time.zone_default is not set" do
      with_zone_default(nil) do
        assert_match "UTC", markup("datetime_attr")
      end
    end

    test "#datetime_field_help_text is correct about the timezone when Time.zone_default is not set/default" do
      with_zone_default(nil) do
        value = ActiveModel::Type::DateTime.new.cast("2023-06-01T12:00:00") # a local ISO8601 time (no timezone)
        assert_predicate(value, :utc?) # uses UTC
      end
    end

    test "#parameter_field adds information about datetime fields when Time.zone_default is set" do
      with_zone_default(Time.find_zone!("EST")) do # ignored
        assert_match Time.now.zone.to_s, markup("datetime_attr")
      end
    end

    test "#datetime_field_help_text is correct about the timezone when Time.zone_default is set" do
      now = Time.now
      sign = now.utc_offset > 0 ? -1 : 1 # make sure we don't overflow
      # Time.use_zone leaks Time.zone_default in the IsolatedExecutionState, so it needs to be called before changing
      # Time.zone_default
      Time.use_zone(now.utc_offset + 2.hour * sign) do # a timezone that is not the system timezone
        with_zone_default(Time.find_zone!(now.utc_offset + 1.hour * sign)) do # another non-system timezone
          value = ActiveModel::Type::DateTime.new.cast(now.strftime("%FT%T")) # a local ISO8601 time (no timezone)
          refute_predicate(value, :utc?)
          assert_equal(now.utc_offset, value.utc_offset) # uses system time zone
        end
      end
    end

    test "#attribute_required? returns true if the attribute has a presence validator" do
      task = Maintenance::ParamsTask.new
      assert attribute_required?(task, :post_ids)
    end

    test "#attribute_required? returns false if the attribute does not have a presence validator" do
      task = Maintenance::ParamsTask.new
      assert_not attribute_required?(task, :content)
    end

    private

    def with_zone_default(new_zone)
      zone = Time.zone_default
      Time.zone_default = new_zone
      yield
    ensure
      Time.zone_default = zone
    end

    def markup(attribute)
      render(inline: <<~TEMPLATE)
        <%= fields_for(Maintenance::ParamsTask.new) do |form| %>
          <%= parameter_field(form, '#{attribute}') %>
        <% end %>
      TEMPLATE
    end
  end
end
