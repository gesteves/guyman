class CleanUpPlaylistsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.joins(:preference)
        .includes(:preference, :playlists)
        .where(preferences: { automatically_clean_up_old_playlists: true })
        .find_each do |user|
      user.unfollow_old_playlists
    end
  end
end
