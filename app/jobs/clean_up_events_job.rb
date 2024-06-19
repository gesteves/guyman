class CleanUpEventsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.joins(:preference).includes(:preference, :playlists).find_each do |user|
      user.destroy_activities_removed_from_calendar
    end
  end
end
