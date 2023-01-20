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

      expected = '<div class="block"><progress value="42" max="84" '\
        'class="progress is-primary is-light"></progress>'\
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

      expected = '<div class="block"><progress max="84" '\
        'class="progress is-primary is-light"></progress>'\
        "<p><i>Almost there!</i></p></div>"
      assert_equal expected, progress(@run)
    end

    test "#status_tag renders a span with the appropriate tag based on status" do
      expected = '<span class="tag is-warning is-light">Pausing</span>'
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
      assert_equal '<span class="ruby-int">1</span>' + "\n"\
        '<span class="ruby-int">2</span>',
        highlight_code("1\n2")
      assert_equal '<span class="ruby-int">1</span>' + " "\
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
  end
end
