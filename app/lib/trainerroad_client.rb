require 'httparty'
require 'icalendar'
require 'active_support/time'

class TrainerroadClient
  def initialize(calendar_url, timezone)
    @calendar_url = calendar_url
    @timezone = timezone
  end

  def get_workouts_for_today
    calendar_data = HTTParty.get(@calendar_url).body
    calendars = Icalendar::Calendar.parse(calendar_data)
    calendar = calendars.first

    today = Time.current.in_time_zone(@timezone).to_date
    workouts = calendar.events.select do |event|
      event.dtstart.to_date == today && valid_workout?(event.summary)
    end

    parse_workouts(workouts)
  end

  private

  def valid_workout?(summary)
    duration_present?(summary) && !summary.include?("Swim")
  end

  def duration_present?(summary)
    summary.match(/^\d+:\d+/)
  end

  def parse_workouts(events)
    events.map do |event|
      summary_parts = event.summary.split(' - ')
      duration = summary_parts[0].strip
      name = summary_parts[1].strip
      type = summary_parts[1].include?("Run") ? "Running" : "Cycling"
      duration_in_minutes = convert_duration_to_minutes(duration)

      {
        name: name,
        description: event.description.to_s,
        type: type,
        duration: duration_in_minutes
      }
    end
  end

  def convert_duration_to_minutes(duration)
    hours, minutes = duration.split(':').map(&:to_i)
    (hours * 60) + minutes
  end
end
