class User < ApplicationRecord
  devise :rememberable, :omniauthable, omniauth_providers: %i[spotify]

  has_many :authentications, dependent: :destroy
  has_one :preference, dependent: :destroy
  has_many :playlists, -> { order(created_at: :desc)}, dependent: :destroy
  has_many :music_requests, dependent: :destroy
  has_many :activities, -> { order(created_at: :desc) }, dependent: :destroy

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

  # Retrieves today's events in the user's calendar.
  #
  # @return [Array] The events for today.
  def todays_calendar_events
    if preference&.has_trainerroad_calendar?
      TrainerroadClient.new(preference.calendar_url, preference.timezone).get_events_for_today
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
      playlists.joins(:activity)
               .where(playlists: { created_at: current_date.beginning_of_day..current_date.end_of_day })
    else
      []
    end
  end

  # Checks if the user has any playlist that are in the process of being generated.
  #
  # @return [Boolean] True if the user has any playlist being generated, false otherwise.
  def is_generating_playlists?
    playlists.present? && playlists.any?(&:processing)
  end

  # Returns the activity associated with a given event today in the user's calendar.
  #
  # @param event_name [String] The name of the event to search for.
  # @return [Activity] The activity associated with the event, or nil if not found.
  def activity_for_calendar_event(event_name)
    current_date = Time.current.in_time_zone(preference.timezone)
    activities.where(name: event_name)
              .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
              .first
  end

  # Get the most recent tracks from across all of the user's playlists.
  #
  # @return [Array<Track>] An array of recent tracks.
  def recent_tracks
    Track.joins(:playlist)
         .where(playlists: { user_id: id })
         .where.not(spotify_uri: nil)
         .where('tracks.created_at >= ?', 2.weeks.ago)
         .order('tracks.created_at DESC')
         .distinct(:spotify_uri)
  end


  # Generates a string of tracks to be excluded from the playlist generation prompt.
  #
  # @return [String] A formatted string listing the tracks to be excluded from the playlist.
  def excluded_tracks_string
    if recent_tracks.any?
      "The following songs have already been used in previous playlists, don't include them:\n" +
      recent_tracks.uniq { |track| track.spotify_uri }.map { |track| "- #{track.artist} - #{track.title}" }.join("\n")
    else
      ""
    end
  end

  # Returns the active music request for the user
  #
  # @return [MusicRequest, nil] The active music request, or nil if not found.
  def current_music_request
    music_requests.find_by(active: true)
  end

  # Checks if the user has a valid Spotify token.
  #
  # @return [Boolean] True if the user has a valid Spotify token, false otherwise.
  def has_valid_spotify_token?
    spotify_auth = authentications.find_by(provider: 'spotify')
    return false unless spotify_auth

    begin
      spotify_client = SpotifyClient.new(spotify_auth.uid, spotify_auth.refresh_token)
      spotify_client.valid_token?
    rescue
      false
    end
  end

  def spotify_user_id
    authentications.find_by(provider: 'spotify')&.uid
  end

  def spotify_refresh_token
    authentications.find_by(provider: 'spotify')&.refresh_token
  end

  # Unfollows any Spotify playlists created before the current day and are still being followed.
  # These playlists were likely used in a workout, so we want to unfollow them
  # to avoid cluttering the user's Spotify account, but we don't want to delete them
  # from the database so we don't reuse their songs in future playlists.
  def unfollow_old_playlists
    return unless preference.automatically_clean_up_old_playlists

    current_date = Time.current.in_time_zone(preference.timezone)
    playlists.where('created_at < ?', current_date.beginning_of_day).where(following: true, locked: false).each do |playlist|
      UnfollowSpotifyPlaylistJob.perform_async(id, playlist.spotify_playlist_id)
    end
  end

  # Deletes from the database any activities created today that don't match today's events in the calendar, and don't have any locked playlists.
  # These events probably reference a workout that was previously scheduled for today and has since been removed
  # from the calendar, probably because the user either deleted it, rescheduled it, replaced it with an alternate,
  # or TrainerRoad adapted the plan.
  def destroy_activities_removed_from_calendar
    current_date = Time.current.in_time_zone(preference.timezone)
    event_names = todays_calendar_events.map { |event| event[:name] }

    activities.joins(:playlist)
        .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
        .where(playlists: { locked: false })
        .where.not(name: event_names)
        .each do |activity|
      activity.destroy
    end
  end
end
