class SetSpotifyPlaylistCoverJob < ApplicationJob
  queue_as :default
  sidekiq_options retry_for: 1.hour

  def perform(user_id, playlist_id, image_url)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    spotify_client.set_playlist_cover(playlist.spotify_playlist_id, image_url)
  end
end
