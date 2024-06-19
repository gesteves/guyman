class ProcessEventsJob < ApplicationJob
  queue_as :high

  # This fetches new workouts in every users' calendars.
  def perform
    return unless Rails.env.production?
    User.joins(:preference).where.not(preferences: { id: nil }).find_each do |user|
      user.process_todays_activities
    end
  end
end
