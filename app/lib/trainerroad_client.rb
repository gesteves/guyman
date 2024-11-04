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
    response = HTTParty.get(@calendar_url)

    calendar_data = handle_response(response)
    calendars = Icalendar::Calendar.parse(calendar_data)
    calendar = calendars.first

    today = Time.current.in_time_zone(@timezone).to_date
    events = calendar.events.select do |event|
      event.dtstart.to_date == today && valid_event?(event)
    end

    parse_and_combine_events(events)
  end

  private

  # Handles the response from the TrainerRoad calendar.
  #
  # @param response [HTTParty::Response] The response object.
  # @return [String] The response body if the request was successful.
  # @raise [RuntimeError] If the request failed.
  def handle_response(response)
    if response.success?
      response.body
    else
      raise "TrainerRoad calendar request failed with status code #{response.code}: #{response.message}"
    end
  end

  # Checks if the event duration is present in the summary and if the event is valid.
  #
  # @param event [Icalendar::Event] The calendar event.
  # @return [Boolean] True if the duration is present and the event is valid, false otherwise.
  def valid_event?(event)
    summary = event.summary.downcase
    description = event.description.to_s.downcase

    duration_present?(summary) && !description.include?("#nomusic")
  end

  # Checks if the event duration is present in the summary.
  #
  # @param summary [String] The event summary.
  # @return [Boolean] True if the duration is present, false otherwise.
  def duration_present?(summary)
    summary.match(/^\d+:\d+/)
  end

  # Parses and combines events with the same name, summing their durations.
  #
  # @param events [Array<Icalendar::Event>] An array of Icalendar::Event objects.
  # @return [Array<Hash>] An array of event hashes, each containing the event name, description, and duration.
  def parse_and_combine_events(events)
    event_hash = Hash.new { |hash, key| hash[key] = { name: key, duration: 0, description: '' } }

    events.each do |event|
      summary_parts = event.summary.split(' - ')
      duration = summary_parts[0].strip
      name = summary_parts[1].strip
      duration_in_minutes = convert_duration_to_minutes(duration)

      event_hash[name][:duration] += duration_in_minutes
      event_hash[name][:description] = event.description.to_s
    end

    event_hash.values
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
