class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, -> { order(:position) }, dependent: :destroy

  validates :workout_name, presence: true

  before_destroy :unfollow_spotify_playlist, if: :spotify_playlist_id?

  default_scope { order(created_at: :desc) }

  # Returns an array of Spotify URIs for all the tracks in the playlist.
  #
  # @return [Array<String>] An array of Spotify URIs.
  def spotify_uris
    tracks.pluck(:spotify_uri).compact
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

  # Checks if the playlist is unlocked.
  #
  # @return [Boolean] true if the playlist is unlocked, false otherwise.
  def unlocked?
    !locked?
  end

  private

  def unfollow_spotify_playlist
    UnfollowSpotifyPlaylistJob.perform_async(user.id, spotify_playlist_id)
  end
end
