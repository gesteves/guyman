class UnfollowSpotifyPlaylistJob < ApplicationJob
  queue_as :low

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    return if playlist.spotify_playlist_id.blank?

    # Unfollow the playlist on Spotify.
    # (This is the same as deleting it from the app.)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    spotify_client.unfollow_playlist(playlist.spotify_playlist_id)

    # Set the playlist's following attribute to false.
    playlist.update!(following: false)
  end
end
