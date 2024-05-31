require 'httparty'
require 'icalendar'
require 'active_support/time'

# The TrainerroadClient class is responsible for interacting with the TrainerRoad calendar feed
class TrainerroadClient
  # Initializes a new instance of the TrainerroadClient class.
  #
  # @param calendar_url [String] The URL of the calendar to fetch events from.
  # @param timezone [String] The timezone to use for date and time calculations.
  def initialize(calendar_url, timezone)
    @calendar_url = calendar_url
    @timezone = timezone
  end

  # Retrieves the events for today from the TrainerRoad calendar.
  #
  # @return [Array<Hash>] An array of event hashes, each containing the event name, description, and duration.
  def get_events_for_today
    Rails.cache.fetch("trainerroad:calendar:#{@calendar_url.parameterize}", expires_in: 1.minute) do
      response = HTTParty.get(@calendar_url)

      calendar_data = handle_response(response)
      calendars = Icalendar::Calendar.parse(calendar_data)
      calendar = calendars.first

      today = Time.current.in_time_zone(@timezone).to_date
      events = calendar.events.select do |event|
        event.dtstart.to_date == today && duration_present?(event.summary)
      end

      parse_events(events)
    end
  end

  private

  # Handles the response from the TrainerRoad calendar.
  #
  # @param response [HTTParty::Response] The response object.
  # @return [Hash] The response body if the request was successful.
  # @raise [RuntimeError] If the request failed.
  def handle_response(response)
    if response.success?
      response.body
    else
      raise "TrainerRoad calendar request failed with status code #{response.code}: #{response.message}"
    end
  end

  # Checks if the event duration is present in the summary.
  #
  # @param summary [String] The event summary.
  # @return [Boolean] True if the duration is present, false otherwise.
  def duration_present?(summary)
    summary.match(/^\d+:\d+/)
  end

  # Parses the events and converts them into a structured format.
  #
  # @param events [Array<Icalendar::Event>] An array of Icalendar::Event objects.
  # @return [Array<Hash>] An array of event hashes, each containing the event name, description, and duration.
  def parse_events(events)
    events.map do |event|
      summary_parts = event.summary.split(' - ')
      duration = summary_parts[0].strip
      name = summary_parts[1].strip
      duration_in_minutes = convert_duration_to_minutes(duration)

      {
        name: name,
        description: event.description.to_s,
        duration: duration_in_minutes
      }
    end
  end

  # Converts the duration from HH:MM format to minutes.
  #
  # @param duration [String] The duration in HH:MM format.
  # @return [Integer] The duration in minutes.
  def convert_duration_to_minutes(duration)
    hours, minutes = duration.split(':').map(&:to_i)
    (hours * 60) + minutes
  end
end
