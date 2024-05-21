class ProcessPlaylistTracksJob < ApplicationJob
  queue_as :high

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

      # Store the Spotify track URI in the track record for future reference
      track.update(spotify_uri: spotify_track['uri'])

      # Add the Spotify track URI to the list of URIs to be added to the Spotify playlist.
      # It's important that we DON'T store the track names and artists returned by Spotify,
      # because we'll use them in future prompts,
      # and Spotify's terms of use forbid passing Spotify data to ChatGPT.
      # We'll only use the Spotify track URIs for track deduplication, as seen above.
      track_uris << spotify_track['uri']
      
      # Increment the total duration of the tracks in the playlist
      total_duration += spotify_track['duration_ms']

      # If the total duration of the tracks is greater than or equal to the workout duration,
      # stop adding more tracks
      break if total_duration >= workout_duration_ms
    end

    # Remove the tracks that were not added to the Spotify playlist from our playlist.
    playlist.tracks.where(spotify_uri: nil).destroy_all

    UpdateSpotifyPlaylistTracksJob.perform_async(user.id, playlist.id)
  end
end
