class CleanUpSpotifyPlaylistsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.includes(:preference, :playlists).find_each do |user|
      preference = user.preference
      next unless preference

      current_date = Time.current.in_time_zone(preference.timezone)
      todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
      workout_names = todays_workouts.map { |workout| workout[:name] }

      # Unfollow any Spotify playlists created before the current day.
      # These playlists were likely used in a workout, so we want to unfollow them
      # to avoid cluttering the user's Spotify account, but we don't want to delete them
      # from the database so we don't reuse their songs in future playlists.
      user.playlists.where('created_at < ?', current_date.beginning_of_day).find_each do |playlist|
        UnfollowSpotifyPlaylistJob.perform_async(user.id, playlist.spotify_playlist_id)
      end

      # Unfollow and delete from the database any Spotify playlists created today that don't match today's workouts.
      # These playlists probably reference a workout that was previously scheduled for today and has since been removed
      # from the calendar, probably because the user either deleted it, rescheduled it, or replaced it with an alternate.
      # In this case we DO want to delete the playlist from the database so we can reuse its songs in future playlists,
      # since the playlist was likely never used.
      # Note that destroying the playlist will also unfollow it in Spotify.
      user.playlists.where(created_at: current_date.beginning_of_day..current_date.end_of_day).find_each do |playlist|
        playlist.destroy unless workout_names.include?(playlist.workout_name)
      end
    end
  end
end
