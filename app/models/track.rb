class Track < ApplicationRecord
  belongs_to :playlist

  validates :title, presence: true
  validates :artist, presence: true

  # Returns the URL for the Spotify iframe
  #
  # @return [String] The URL for the Spotify iframe.
  def spotify_iframe_url
    return if spotify_uri.blank?
    "https://open.spotify.com/embed/track/#{spotify_uri.split(':').last}"
  end
end
