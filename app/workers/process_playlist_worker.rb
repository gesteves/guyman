class ProcessPlaylistWorker < ApplicationWorker
  queue_as :default

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
      playlist.update(spotify_playlist_id: spotify_playlist_id)
    end

    track_uris = []
    total_duration = 0
    workout_duration_ms = playlist.workout_duration * 60 * 1000 # Convert workout duration from minutes to milliseconds

    # Collect all track URIs from the user's other playlists
    recent_track_uris = user.recent_track_uris_from_other_playlists(playlist.id)

    playlist.tracks.each do |track|
      # Search for the track in Spotify using its title and artist
      spotify_track = spotify_client.search_tracks(track.title, track.artist)
      
      # If the track was not found on Spotify, skip to the next track
      next if spotify_track.blank?

      # Skip tracks that are already in other playlists
      next if recent_track_uris.include?(spotify_track['uri'])

      # Skip the track if it is already in the Spotify playlist
      next if track_uris.include?(spotify_track['uri'])

      # Store the Spotify track URI in the track record for future reference
      track.update(spotify_uri: spotify_track['uri'])

      # Add the Spotify track URI to the list of URIs to be added to the Spotify playlist
      track_uris << spotify_track['uri']
      
      # Increment the total duration of the tracks in the playlist
      total_duration += spotify_track['duration_ms']

      # If the total duration of the tracks is greater than or equal to the workout duration,
      # stop adding more tracks
      break if total_duration >= workout_duration_ms
    end

    # Replace the tracks in the Spotify playlist with the ones we found.
    spotify_client.update_playlist_tracks(spotify_playlist_id, track_uris)

    # Remove the tracks that were not added to the Spotify playlist from our playlist.
    playlist.tracks.where(spotify_uri: nil).destroy_all

    # Enqueue a job to generate a cover image for the playlist using Dall-E.
    GenerateCoverImageWorker.perform_async(user.id, spotify_playlist_id, playlist.cover_dalle_prompt)
  end
end
