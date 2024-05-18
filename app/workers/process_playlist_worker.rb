class ProcessPlaylistWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    spotify_client = SpotifyClient.new(user.authentications.find_by(provider: 'spotify').refresh_token)

    search_term = "Today’s #{playlist.workout_type} Workout:"
    spotify_playlist_id = spotify_client.search_playlists(search_term)

    if spotify_playlist_id.nil?
      spotify_playlist_id = spotify_client.create_playlist(playlist.name, playlist.description)
    else
      spotify_client.modify_playlist(spotify_playlist_id, playlist.name, playlist.description)
    end

    track_uris = []
    total_duration = 0
    workout_duration_ms = playlist.workout_duration * 60 * 1000 # Convert workout duration from minutes to milliseconds

    playlist.tracks.each do |track|
      spotify_track = spotify_client.search_tracks(track.title, track.artist)
      next unless spotify_track

      track_uris << spotify_track['uri']
      total_duration += spotify_track['duration_ms']

      break if total_duration >= workout_duration_ms
    end

    spotify_client.replace_playlist_tracks(spotify_playlist_id, track_uris)
    GenerateCoverImageWorker.perform_async(user.id, spotify_playlist_id, playlist.cover_dalle_prompt)
  end
end
