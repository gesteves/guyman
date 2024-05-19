class UnfollowSpotifyPlaylistJob < ApplicationJob
  queue_as :low

  def perform(user_id, spotify_playlist_id = nil)
    return if spotify_playlist_id.blank?
    user = User.find(user_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)
    spotify_client.unfollow_playlist(spotify_playlist_id)
    user.playlists.where(spotify_playlist_id: spotify_playlist_id).update_all(spotify_playlist_id: nil)
  end
end
