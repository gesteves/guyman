class CleanUpPlaylistsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.joins(:preference)
        .includes(:preference, :playlists)
        .where(preferences: { automatically_clean_up_old_playlists: true })
        .find_each do |user|
      preference = user.preference

      current_date = Time.current.in_time_zone(preference.timezone)

      # Unfollow any Spotify playlists created before the current day and are still being followed.
      # These playlists were likely used in a workout, so we want to unfollow them
      # to avoid cluttering the user's Spotify account, but we don't want to delete them
      # from the database so we don't reuse their songs in future playlists.
      user.playlists.where('created_at < ?', current_date.beginning_of_day).where(following: true, locked: false).each do |playlist|
        UnfollowSpotifyPlaylistJob.perform_async(user.id, playlist.spotify_playlist_id)
      end
    end
  end
end
