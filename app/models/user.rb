class User < ApplicationRecord
  devise :rememberable, :omniauthable, omniauth_providers: %i[spotify]

  has_many :authentications, dependent: :destroy
  has_one :preference, dependent: :destroy
  has_many :playlists, dependent: :destroy

  # Sets the number of tracks that should not be reused in playlists.
  # Kinda guessing at the number here, but a 2-hour playlist has around 30 tracks,
  # so 180 tracks should be enough for 12 hours, or a week, of training, without reusing songs.
  NON_REUSABLE_TRACK_COUNT = ENV.fetch('NON_REUSABLE_TRACK_COUNT', 180)

  def self.from_omniauth(auth)
    authentication = Authentication.where(provider: auth.provider, uid: auth.uid).first_or_initialize
    if authentication.user.blank?
      user = User.where(email: auth.info.email).first_or_initialize do |user|
        user.email = auth.info.email # Ensure the email is set
      end
      user.save!
      authentication.user = user
    end
    authentication.token = auth.credentials.token
    authentication.refresh_token = auth.credentials.refresh_token
    authentication.save!
    authentication.user
  end

  # Returns an array of playlists for today's workouts.
  #
  # @return [Array<Playlist>] An array of playlists created today.
  def todays_playlists
    if preference
      current_date = Time.current.in_time_zone(preference.timezone)
      playlists.where(created_at: current_date.beginning_of_day..current_date.end_of_day)
    else
      []
    end
  end

  # Get the most recent unique tracks from across all of the user's playlists.
  #
  # @param count [Integer] The number of recent tracks to retrieve.
  # @return [Array<Array<String>>] An array of arrays containing the spotify_uri, artist, and title of the recent tracks.
  def recent_tracks(count = NON_REUSABLE_TRACK_COUNT)
    playlists.joins(:tracks)
            .where.not(tracks: { spotify_uri: nil })
            .select('tracks.spotify_uri, tracks.artist, tracks.title, tracks.created_at')
            .order('tracks.created_at DESC')
            .limit(count)
            .pluck('tracks.spotify_uri', 'tracks.artist', 'tracks.title')
            .uniq { |track| track.first }
  end

  # Generates a string of tracks to be excluded from the playlist generation prompt.
  #
  # @param count [Integer] The number of recent tracks to retrieve for exclusion.
  # @return [String] A formatted string listing the tracks to be excluded from the playlist.
  def excluded_tracks_string(count = NON_REUSABLE_TRACK_COUNT)
    if recent_tracks.any?
      "The following songs have already been used in previous playlists, please don't include them:\n" +
      recent_tracks(count).map { |track| "- #{track[1]} - #{track[2]}" }.join("\n")
    else
      ""
    end
  end

  # Get the most recent unique track URIs from the user's playlists, excluding a specified playlist.
  #
  # @param playlist_id [Integer] The ID of the playlist to exclude.
  # @param count [Integer] The number of recent track URIs to retrieve.
  # @return [Array<String>] An array of recent unique track URIs.
  def recent_track_uris_from_other_playlists(playlist_id, count = NON_REUSABLE_TRACK_COUNT)
    playlists.joins(:tracks)
            .where.not(id: playlist_id)
            .where.not(tracks: { spotify_uri: nil })
            .select('tracks.spotify_uri, tracks.created_at')
            .order('tracks.created_at DESC')
            .limit(count)
            .pluck('tracks.spotify_uri')
            .uniq
  end

  # Get the playlist for a specific workout scheduled for today.
  #
  # @param workout_name [String] The name of the workout.
  # @return [Playlist, nil] The playlist associated with the workout, or nil if not found.
  def playlist_for_todays_workout(workout_name)
    current_date = Time.current.in_time_zone(preference.timezone)
    playlists.where(workout_name: workout_name)
             .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
             .first
  end
end
