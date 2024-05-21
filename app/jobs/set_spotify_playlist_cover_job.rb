class SetSpotifyPlaylistCoverJob < ApplicationJob
  queue_as :default
  sidekiq_options retry_for: 1.hour

  def perform(user_id, spotify_playlist_id, image_url)
    user = User.find(user_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    # This API call fails frequently, so we rely on Sidekiq's retry behavior.
    spotify_client.set_playlist_cover(spotify_playlist_id, image_url)
  end
end
