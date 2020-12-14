# frozen_string_literal: true
module MaintenanceTasks
  # Module for common view helpers.
  #
  # @api private
  module ApplicationHelper
    include Pagy::Frontend

    # Renders pagination for the page, if there is more than one page present.
    #
    # @param pagy [Pagy] the pagy instance containing pagination details,
    #   including the number of pages the results are spread across.
    # @return [String] the HTML to render for pagination.
    def pagination(pagy)
      raw(pagy_bulma_nav(pagy)) if pagy.pages > 1
    end

    # Renders a time element with the given datetime, worded as relative to the
    # current time.
    #
    # The ISO 8601 version of the datetime is shown on hover
    # via a title attribute.
    #
    # @param datetime [ActiveSupport::TimeWithZone] the time to be presented.
    # @return [String] the HTML to render with the relative datetime in words.
    def time_ago(datetime)
      time_tag(datetime, title: datetime.utc.iso8601, class: 'is-clickable') do
        time_ago_in_words(datetime) + ' ago'
      end
    end

    # Fix stylesheet_link_tag to handle integrity when preloading.
    # To be reverted once fixed upstream in Rails.
    def stylesheet_link_tag(*sources)
      options = sources.extract_options!.stringify_keys
      path_options = options.extract!('protocol', 'host', 'skip_pipeline')
        .symbolize_keys
      preload_links = []
      crossorigin = options.delete('crossorigin')
      crossorigin = 'anonymous' if crossorigin == true
      nopush = options['nopush'].nil? ? true : options.delete('nopush')
      integrity = options['integrity']

      sources_tags = sources.uniq.map do |source|
        href = path_to_stylesheet(source, path_options)
        preload_link = "<#{href}>; rel=preload; as=style"
        preload_link += "; crossorigin=#{crossorigin}" unless crossorigin.nil?
        preload_link += "; integrity=#{integrity}" unless integrity.nil?
        preload_link += '; nopush' if nopush
        preload_links << preload_link
        tag_options = {
          'rel' => 'stylesheet',
          'media' => 'screen',
          'crossorigin' => crossorigin,
          'href' => href,
        }.merge!(options)
        tag(:link, tag_options)
      end

      send_preload_links_header(preload_links)

      safe_join(sources_tags)
    end
  end
  private_constant :ApplicationHelper
end
