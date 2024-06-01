class SetSpotifyPlaylistCoverJob < ApplicationJob
  queue_as :default
  sidekiq_options retry_for: 1.hour

  def perform(user_id, playlist_id, image_url)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.spotify_user_id, user.spotify_refresh_token)
    spotify_client.set_playlist_cover(playlist.spotify_playlist_id, image_url)
    playlist.update_cover_image_timestamp!
    playlist.done_generating_cover_image!
  end

  sidekiq_retries_exhausted do |msg, _|
    _user_id, playlist_id, _image_url = msg['args']
    playlist = Playlist.find(playlist_id)
    playlist.done_generating_cover_image!
  end
end
