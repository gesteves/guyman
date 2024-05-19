class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, dependent: :destroy

  validates :name, presence: true
  validates :workout_name, presence: true
  validates :workout_type, presence: true

  before_destroy :schedule_spotify_playlist_unfollow, if: :spotify_playlist_id?

  private

  def schedule_spotify_playlist_unfollow
    UnfollowSpotifyPlaylistJob.perform_later(user.id, spotify_playlist_id)
  end
end
