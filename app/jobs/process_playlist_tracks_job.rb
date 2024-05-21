class ProcessPlaylistTracksJob < ApplicationJob
  queue_as :high

  # This job processes the tracks for a given playlist. It performs the following steps:
  # 1. Collects the Spotify URIs of tracks already present in the user's other playlists to avoid duplicates.
  # 2. Iterates over the tracks in the playlist and searches for them on Spotify using their title and artist.
  # 3. Filters out tracks that:
  #    - Are not found on Spotify.
  #    - Are already present in other playlists.
  #    - Are already in the current playlist.
  # 4. Stores the Spotify URI for each valid track and updates the total duration of the playlist.
  # 5. Stops adding tracks once the total duration meets or exceeds the workout duration.
  # 6. Removes any leftover tracks.
  # 7. Enqueues a job to update the Spotify playlist with the remaining tracks.
  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)

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

      # Store the Spotify track URI in the track record for future reference.
      # It's important that we DON'T store the track names and artists returned by Spotify,
      # because we'll use them in future prompts,
      # and Spotify's terms of use forbid passing Spotify data to ChatGPT.
      # We'll only use the Spotify track URIs for track deduplication, as seen above.
      track.update(spotify_uri: spotify_track['uri'])

      # Add the Spotify track URI to the list of URIs we've added to the Spotify playlist.
      track_uris << spotify_track['uri']
      
      # Increment the total duration of the tracks in the playlist
      total_duration += spotify_track['duration_ms']

      # If the total duration of the tracks is greater than or equal to the workout duration,
      # stop adding more tracks
      break if total_duration >= workout_duration_ms
    end

    # Remove the tracks that were not added to the Spotify playlist from our playlist.
    playlist.tracks.where(spotify_uri: nil).destroy_all

    # Now that our playlist is ready, enqueue a job to update the tracks
    # on the Spotify playlist.
    UpdateSpotifyPlaylistTracksJob.perform_async(user.id, playlist.id)
  end
end
