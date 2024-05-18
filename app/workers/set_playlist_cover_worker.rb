class SetPlaylistCoverWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, spotify_playlist_id, image_url)
    user = User.find(user_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    spotify_client.set_playlist_cover(spotify_playlist_id, image_url)
  end
end
