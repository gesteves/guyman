class UpdateSpotifyPlaylistTracksJob < ApplicationJob
  queue_as :high
  sidekiq_options retry_for: 1.hour

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.spotify_user_id, user.spotify_refresh_token)

    # Update the Spotify playlist with our playlist's tracks.
    spotify_client.update_playlist_tracks(playlist.spotify_playlist_id, playlist.spotify_uris)

    playlist.done_processing!
  end

  sidekiq_retries_exhausted do |msg, exception|
    playlist_id = msg['args'][1]
    playlist = Playlist.find(playlist_id)
    playlist.activity.destroy if playlist.present?
  end
end
