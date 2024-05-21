class UpdateSpotifyPlaylistTracksJob < ApplicationJob
  queue_as :high

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)

    # Update the Spotify playlist with our playlist's tracks.
    spotify_client.update_playlist_tracks(playlist.spotify_playlist_id, playlist.spotify_uris)
  end
end
