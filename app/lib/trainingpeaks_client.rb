require 'httparty'
require 'icalendar'
require 'active_support/time'

# The TrainingpeaksClient class is responsible for interacting with the TrainingPeaks calendar feed
class TrainingpeaksClient
  # Initializes a new instance of the TrainingPeaksClient class.
  #
  # @param calendar_url [String] The URL of the calendar to fetch workouts from.
  # @param timezone [String] The timezone to use for date and time calculations.
  def initialize(calendar_url, timezone)
    @calendar_url = calendar_url
    @timezone = timezone
  end

  # Retrieves the workouts for today from the TrainingPeaks calendar.
  #
  # @return [Array<Hash>] An array of workout hashes, each containing the workout name, description, and duration.
  def get_workouts_for_today
    response = HTTParty.get(@calendar_url)

    calendar_data = handle_response(response)
    calendars = Icalendar::Calendar.parse(calendar_data)
    calendar = calendars.first

    today = Time.current.in_time_zone(@timezone).to_date
    workouts = calendar.events.select do |event|
      event.dtstart.to_date == today && event.description.to_s.include?("Planned Time:")
    end

    parse_workouts(workouts)
  end

  private

  # Handles the response from the TrainingPeaks calendar.
  #
  # @param response [HTTParty::Response] The response object.
  # @return [Hash] The response body if the request was successful.
  # @raise [RuntimeError] If the request failed.
  def handle_response(response)
    if response.success?
      response.body
    else
      raise "TrainingPeaks calendar request failed with status code #{response.code}: #{response.message}"
    end
  end

  # Parses the workout events and converts them into a structured format.
  #
  # @param events [Array<Icalendar::Event>] An array of Icalendar::Event objects representing the workouts.
  # @return [Array<Hash>] An array of workout hashes, each containing the workout name, description, and duration.
  def parse_workouts(events)
    events.map do |event|
      name = extract_workout_name(event.summary)
      duration = extract_workout_duration(event.description.to_s)
      duration_in_minutes = convert_duration_to_minutes(duration)

      {
        name: name,
        description: event.description.to_s,
        duration: duration_in_minutes
      }
    end
  end

  # Extracts the workout name from the summary.
  #
  # @param summary [String] The workout summary.
  # @return [String] The workout name.
  def extract_workout_name(summary)
    summary.split(':', 2).last.strip
  end

  # Extracts the workout duration from the description.
  #
  # @param description [String] The workout description.
  # @return [String] The workout duration in HH:MM format.
  def extract_workout_duration(description)
    duration_line = description.split("\n").find { |line| line.include?("Planned Time:") }
    duration_line.split(':', 2).last.strip if duration_line
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
