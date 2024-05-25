class User < ApplicationRecord
  devise :rememberable, :omniauthable, omniauth_providers: %i[spotify]

  has_many :authentications, dependent: :destroy
  has_one :preference, dependent: :destroy
  has_many :playlists, dependent: :destroy

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

  # Retrieves today's workouts for the user.
  #
  # @return [Array] The workouts for today.
  def todays_workouts
    if preference&.has_trainerroad_calendar?
      TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    elsif preference&.has_trainingpeaks_calendar?
      TrainingpeaksClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    else
      []
    end
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

  # Get the most recent unique tracks from across all of the user's playlists.
  #
  # @return [Array<Array<String>>] An array of arrays containing the spotify_uri, artist, and title of the recent tracks.
  def recent_tracks
    playlists.joins(:tracks)
            .where.not(tracks: { spotify_uri: nil })
            .where('tracks.created_at >= ?', 2.weeks.ago)
            .select('tracks.spotify_uri, tracks.artist, tracks.title, tracks.created_at')
            .order('tracks.created_at DESC')
            .pluck('tracks.spotify_uri', 'tracks.artist', 'tracks.title')
            .uniq { |track| track.first }
  end

  # Generates a string of tracks to be excluded from the playlist generation prompt.
  #
  # @return [String] A formatted string listing the tracks to be excluded from the playlist.
  def excluded_tracks_string
    recent_tracks_list = recent_tracks
    if recent_tracks_list.any?
      "The following songs have already been used in previous playlists, don't include them:\n" +
      recent_tracks_list.map { |track| "- #{track[1]} - #{track[2]}" }.join("\n")
    else
      ""
    end
  end

  # Checks if the user has a valid Spotify token.
  #
  # @return [Boolean] True if the user has a valid Spotify token, false otherwise.
  def has_valid_spotify_token?
    spotify_auth = authentications.find_by(provider: 'spotify')
    return false unless spotify_auth

    begin
      spotify_client = SpotifyClient.new(spotify_auth.refresh_token)
      spotify_client.valid_token?
    rescue
      false
    end
  end
end
