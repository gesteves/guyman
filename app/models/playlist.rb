class Playlist < ApplicationRecord
  belongs_to :user
  belongs_to :activity, dependent: :destroy
  belongs_to :music_request, -> { with_deleted }, optional: true
  has_many :tracks, -> { order(:position) }, dependent: :destroy

  before_destroy :unfollow_spotify_playlist, if: :spotify_playlist_id?

  default_scope { order(created_at: :desc) }

  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destroy

  # Returns an array of Spotify URIs for all the tracks in the playlist.
  #
  # @return [Array<String>] An array of Spotify URIs.
  def spotify_uris
    tracks.pluck(:spotify_uri).compact
  end

  # Returns the URL for the Spotify playlist iframe, including a cache buster if the cover image was updated.
  #
  # @return [String] The URL for the Spotify playlist iframe.
  def spotify_iframe_url
    return if spotify_playlist_id.blank?
    cache_buster = "?#{cover_image_updated_at.to_i}" if cover_image_updated_at.present?
    "https://open.spotify.com/embed/playlist/#{spotify_playlist_id}#{cache_buster}"
  end

  # Get the most recent unique track URIs from the user's playlists, excluding the current playlist.
  #
  # @return [Array<String>] An array of recent unique track URIs.
  def recent_track_uris_from_other_playlists
    user.playlists.joins(:tracks)
          .where.not(id: id)
          .where.not(tracks: { spotify_uri: nil })
          .where('tracks.created_at >= ?', 2.weeks.ago)
          .select('tracks.spotify_uri, tracks.created_at')
          .order('tracks.created_at DESC')
          .pluck('tracks.spotify_uri')
          .uniq
  end

  # Checks if the playlist was created today in the user's preferred timezone.
  #
  # @return [Boolean] true if the playlist was created today, false otherwise.
  def todays?
    Time.current.in_time_zone(user.preference.timezone).to_date == created_at.in_time_zone(user.preference.timezone).to_date
  end

  # Sets the playlist's processing flag to true if it is not locked.
  #
  # @return [void]
  def processing!
    update!(processing: true) unless locked?
  end

  # Sets the playlist's processing flag to false.
  #
  # @return [void]
  def done_processing!
    update!(processing: false)
  end

  # Sets the cover_image_updated_at column to the current time.
  #
  # @return [void]
  def update_cover_image_timestamp!
    update!(cover_image_updated_at: Time.current)
  end

  # A playlist can be processed if:
  # - It doesn't have any tracks
  # - It's not being processed already
  # - It's not locked
  def can_be_processed?
    tracks.blank? && !processing? && !locked?
  end

  # Checks if the playlist is unlocked.
  #
  # @return [Boolean] true if the playlist is unlocked, false otherwise.
  def unlocked?
    !locked?
  end

  # Ensures the track positions are sequential.
  #
  # @return [void]
  def update_track_positions!
    tracks.order(:position).each_with_index do |track, index|
      track.update!(position: index + 1)
    end
  end

  # Adds up the duration of the tracks in the playlist.
  #
  # @return [Integer] The total duration of the playlist in milliseconds.
  def total_duration
    tracks.sum(:duration_ms)
  end

  private

  def unfollow_spotify_playlist
    UnfollowSpotifyPlaylistJob.perform_async(user.id, spotify_playlist_id)
  end

  def broadcast_create
    return if Rails.env.test?
    broadcast_append_to "playlists:index:user:#{user.id}", partial: "home/playlist", locals: { playlist: self }
    broadcast_update_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists }
  end

  def broadcast_update
    return if Rails.env.test?
    if saved_change_to_processing?
      broadcast_update_to "playlists:index:user:#{user.id}", partial: "home/playlist", locals: { playlist: self }
      broadcast_update_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists }
    elsif saved_change_to_cover_image_updated_at?
      broadcast_update_to "playlists:index:user:#{user.id}", partial: "home/playlist", locals: { playlist: self }
    elsif saved_change_to_locked? || saved_change_to_processing?
      broadcast_update_to "playlists:index:user:#{user.id}", target: "playlist_buttons_#{id}", partial: "home/playlist_buttons", locals: { playlist: self }
    end
  end

  def broadcast_destroy
    return if Rails.env.test?
    broadcast_remove_to "playlists:index:user:#{user.id}"
    broadcast_update_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists }
  end
end
