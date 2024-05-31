class CleanUpEventsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.joins(:preference).includes(:preference, :playlists).find_each do |user|
      preference = user.preference

      current_date = Time.current.in_time_zone(preference.timezone)
      event_names = user.todays_calendar_events.map { |event| event[:name] }

      # Unfollow and delete from the database any events created today that don't match today's events in the calendar,
      # and don't have any locked playlists
      # These events probably reference a workout that was previously scheduled for today and has since been removed
      # from the calendar, probably because the user either deleted it, rescheduled it, replaced it with an alternate,
      # or TrainerRoad adapted the plan.
      user.activities.joins(:playlist)
          .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
          .where(playlists: { locked: false })
          .where.not(name: event_names)
          .each do |activity|
        activity.destroy
      end
    end
  end
end
