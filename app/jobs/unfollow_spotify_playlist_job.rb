class UnfollowSpotifyPlaylistJob < ApplicationJob
  queue_as :low

  def perform(user_id, spotify_playlist_id = nil)
    return if spotify_playlist_id.blank?
    user = User.find(user_id)
    # Unfollow the plauslist on Spotify.
    # (This is the same as deleting it from the app.)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    spotify_client.unfollow_playlist(spotify_playlist_id)

    # Set the playlist's following attribute to false.
    playlist = user.playlists.find_by(spotify_playlist_id: spotify_playlist_id)
    playlist.update(following: false) if playlist
  end
end
