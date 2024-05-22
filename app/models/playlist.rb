class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
  validates :workout_name, presence: true

  before_destroy :unfollow_spotify_playlist, if: :spotify_playlist_id?

  def spotify_uris
    tracks.pluck(:spotify_uri).compact
  end

  private

  def unfollow_spotify_playlist
    UnfollowSpotifyPlaylistJob.perform_async(user.id, spotify_playlist_id)
  end
end
