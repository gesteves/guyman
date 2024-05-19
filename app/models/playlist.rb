class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, dependent: :destroy

  validates :name, presence: true
  validates :workout_name, presence: true
  validates :workout_type, presence: true

  before_destroy :unfollow_spotify_playlist

  private

  def unfollow_spotify_playlist
    UnfollowSpotifyPlaylistWorker.perform_async(user.id, spotify_playlist_id)
  end
end
