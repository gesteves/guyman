class SetUpSpotifyPlaylistJob < ApplicationJob
  queue_as :high

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)

    # Check if the Spotify playlist ID is already present in the database
    if playlist.spotify_playlist_id.present?
      # If it is present, update the existing playlist
      spotify_playlist_id = playlist.spotify_playlist_id
      spotify_client.modify_playlist(spotify_playlist_id, playlist.name, playlist.description)
    else
      # If it is not present, create a new playlist and save the Spotify playlist ID to the database
      spotify_playlist_id = spotify_client.create_playlist(playlist.name, playlist.description)
      playlist.update(spotify_playlist_id: spotify_playlist_id, following: true)
    end

    # Process the tracks before adding them to the Spotify playlist.
    ProcessPlaylistTracksJob.perform_async(user.id, playlist.id)

    # Enqueue a job to generate a cover image for the playlist using Dall-E.
    GenerateCoverImageJob.perform_async(user.id, spotify_playlist_id, playlist.cover_dalle_prompt)
  end
end
