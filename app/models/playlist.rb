class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
  validates :workout_name, presence: true

  before_destroy :unfollow_spotify_playlist, if: :spotify_playlist_id?

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

  private

  def unfollow_spotify_playlist
    UnfollowSpotifyPlaylistJob.perform_async(user.id, id)
  end
end
