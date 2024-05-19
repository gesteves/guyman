class CleanUpSpotifyPlaylistsWorker < ApplicationWorker
  queue_as :low

  def perform
    User.includes(:preference, :playlists).find_each do |user|
      preference = user.preference
      next unless preference

      current_date = Time.current.in_time_zone(preference.timezone)
      todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
      workout_names = todays_workouts.map { |workout| workout[:name] }

      # Unfollow any Spotify playlists created before the current day
      user.playlists.where('created_at < ?', current_date.beginning_of_day).find_each do |playlist|
        if playlist.spotify_playlist_id.present?
          UnfollowSpotifyPlaylistWorker.perform_async(user.id, playlist.spotify_playlist_id)
        end
      end

      # Unfollow and delete from the database any Spotify playlists created today that don't match today's workouts
      user.playlists.where(created_at: current_date.beginning_of_day..current_date.end_of_day).find_each do |playlist|
        unless workout_names.include?(playlist.workout_name)
          playlist.destroy
        end
      end
    end
  end
end
