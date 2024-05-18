class ProcessPlaylistWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)

    # We don't want to end with hundreds of playlists, so whenever possible, we'll reuse an existing playlist
    # for each workout type.
    search_term = "Today’s #{playlist.workout_type} Workout:"
    spotify_playlist_id = spotify_client.search_playlists(search_term)

    # If we couldn't find a playlist for this workout type, create a new one.
    # Otherwise, we'll update the title and description of the existing one.
    if spotify_playlist_id.nil?
      spotify_playlist_id = spotify_client.create_playlist(playlist.name, playlist.description)
    else
      spotify_client.modify_playlist(spotify_playlist_id, playlist.name, playlist.description)
    end

    track_uris = []
    total_duration = 0
    workout_duration_ms = playlist.workout_duration * 60 * 1000 # Convert workout duration from minutes to milliseconds

    added_tracks = []

    # Collect all track titles and artists from the user's other playlists
    existing_tracks = user.playlists.where.not(id: playlist_id).joins(:tracks).pluck('tracks.title', 'tracks.artist')

    # Search tracks by title and artist in Spotify,
    # and add them to the playlist.
    # Stop until the total duration of the tracks is greater than or equal to the workout duration.
    playlist.tracks.each do |track|
      # Skip tracks that are already in other playlists
      next if existing_tracks.include?([track.title, track.artist])

      spotify_track = spotify_client.search_tracks(track.title, track.artist)
      # Skip tracks that we couldn't find on Spotify.
      next unless spotify_track

      track_uris << spotify_track['uri']
      total_duration += spotify_track['duration_ms']
      added_tracks << track

      break if total_duration >= workout_duration_ms
    end

    # Replace the tracks in the Spotify playlist with the ones we found.
    spotify_client.replace_playlist_tracks(spotify_playlist_id, track_uris)

    # Remove the tracks that were not added to the Spotify playlist from our playlist.
    playlist.tracks.where.not(id: added_tracks.map(&:id)).destroy_all

    # Enqueue a job to generate a cover image for the playlist using Dall-E.
    GenerateCoverImageWorker.perform_async(user.id, spotify_playlist_id, playlist.cover_dalle_prompt)
  end
end
