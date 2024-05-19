require 'httparty'
require 'icalendar'
require 'active_support/time'

# The TrainerroadClient class is responsible for interacting with the TrainerRoad calendar feed
class TrainerroadClient
  # Initializes a new instance of the TrainerroadClient class.
  #
  # @param calendar_url [String] The URL of the calendar to fetch workouts from.
  # @param timezone [String] The timezone to use for date and time calculations.
  def initialize(calendar_url, timezone)
    @calendar_url = calendar_url
    @timezone = timezone
  end

  # Retrieves the workouts for today from the TrainerRoad calendar.
  #
  # @return [Array<Hash>] An array of workout hashes, each containing the workout name, description, type, and duration.
  def get_workouts_for_today
    response = HTTParty.get(@calendar_url)

    if response.success?
      calendar_data = response.body
      calendars = Icalendar::Calendar.parse(calendar_data)
      calendar = calendars.first

      today = Time.current.in_time_zone(@timezone).to_date
      workouts = calendar.events.select do |event|
        event.dtstart.to_date == today && valid_workout?(event.summary)
      end

      parse_workouts(workouts)
    else
      handle_response_error(response)
    end
  end

  private

  # Handles the error response from the TrainerRoad API.
  #
  # @param response [HTTParty::Response] The HTTP response object.
  # @return [Array] An empty array.
  def handle_response_error(response)
    case response.code
    when 500..599
      raise "TrainerRoad API request failed with status code #{response.code}: #{response.message}"
    else
      []
    end
  end

  # Checks if a workout is valid based on its summary.
  #
  # A workout is considered valid if:
  # 1. It has a duration present (the TrainerRoad calendar includes events and annotations, which don't include
  #    a duration in the summary, in the H:MM format). I don't need playlists for those.
  # 2. It doesn't include "Swim" in the summary (swims aren't valid workouts because how am I gonna listen to the playlist?)
  #
  # @param summary [String] the summary of the workout
  # @return [Boolean] true if the workout is valid, false otherwise
  def valid_workout?(summary)
    duration_present?(summary) && !summary.include?("Swim")
  end

  # Checks if the workout duration is present in the summary.
  #
  # @param summary [String] The workout summary.
  # @return [Boolean] True if the duration is present, false otherwise.
  def duration_present?(summary)
    summary.match(/^\d+:\d+/)
  end

  # Parses the workout events and converts them into a structured format.
  #
  # @param events [Array<Icalendar::Event>] An array of Icalendar::Event objects representing the workouts.
  # @return [Array<Hash>] An array of workout hashes, each containing the workout name, description, type, and duration.
  def parse_workouts(events)
    events.map do |event|
      summary_parts = event.summary.split(' - ')
      duration = summary_parts[0].strip
      name = summary_parts[1].strip
      type = if summary_parts[1].include?("Run")
        "Run"
      elsif summary_parts[1].include?("Swim")
        "Swim"
      else
        "Cycling"
      end
      duration_in_minutes = convert_duration_to_minutes(duration)

      {
        name: name,
        description: event.description.to_s,
        type: type,
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
