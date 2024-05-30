class AddTracksToPlaylistJob < ApplicationJob
  queue_as :high
  sidekiq_options retry_for: 5.minutes

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    return unless user.current_music_request.present?
    
    playlist = user.playlists.find(playlist_id)

    prompt = chatgpt_user_prompt(user, playlist)
    response = ChatgptClient.new.ask_for_json(chatgpt_system_prompt, prompt, user_id)

    validate_response(response)

    playlist_tracks = response['tracks']

    # Mark the current music request as used
    user.current_music_request.used!

    # Get the position of the last track in the playlist.
    last_position = playlist.tracks.last&.position || 0

    # Add the tracks ChatGPT generated to the playlist.
    # It's important that we store the track names and artists returned by ChatGPT,
    # not the ones from Spotify, because we'll use them in future prompts,
    # and Spotify's terms of use forbid passing Spotify data to ChatGPT.
    playlist_tracks.each_with_index do |track, index|
      position = last_position + index + 1
      playlist.tracks.create!(title: track['track'], artist: track['artist'], position: position)
    end
    
    # Enqueue a job to process the tracks on the playlist.
    ProcessPlaylistTracksJob.perform_async(user.id, playlist.id)
  end

  private

  # ChatGPT's JSON mode doesn't guarantee that the response will match the structure specified in the prompt,
  # only that it's valid JSON, so we must validate it.
  # This also guards against prompt injection, e.g. if someone enters "disregard all previous instructions"
  # as their musical taste.
  def validate_response(response)
    required_keys = ['tracks']
    missing_keys = required_keys.select { |key| response[key].blank? }

    if missing_keys.any?
      raise "Invalid response from ChatGPT: Missing keys: #{missing_keys.join(', ')}"
    end

    unless response['tracks'].is_a?(Array) && response['tracks'].all? { |track| track.is_a?(Hash) && track['artist'].present? && track['track'].present? }
      raise "Invalid response from ChatGPT: 'tracks' must be an array of hashes with 'artist' and 'track' keys."
    end
  end

  # A few things worth noting about this system prompt:
  # - Ideally, we'd ask ChatGPT to give us a playlist of the specific duration we need,
  #   but ChatGPT is notoriously bad at this because it can't actually do math to add up the song lengths.
  #   Instead, we ask it to generate an arbitrarily large number of songs and then trim the playlist to the right length.
  # - Because we're using the `json_object` response format in the API call to ChatGPT,
  #   we MUST specify in the prompt that it must return a JSON object with the given structure we expect.
  # - Spotify's terms of use forbid passing Spotify data to ChatGPT, so it's important that we never do that in the prompt.
  def chatgpt_system_prompt
    <<~PROMPT
      You are a helpful music assistant tasked with suggesting songs to add to the user's Spotify playlist. Your task is the following:

      - You will receive a list of songs in the user's playlist, and you must suggest new songs to add to it.
      - You must suggest at least 50 songs. 
      - The user may specify genres and bands they like; use this information to guide your choices.
      - The user may specify genres, bands, or specific tracks they want to avoid; do not include them in your suggestions.
      - You may receive a list of songs used in other playlists; do not include them in your response.
      - Do not include songs with significant amounts of silence (such as songs with hidden tracks).
      
      You must return your response in JSON format using this exact structure:
      
      {
        "tracks": [
          {"artist": "Artist Name 1", "track": "Track Name 1"},
          {"artist": "Artist Name 2", "track": "Track Name 2"}
        ]
      }    
    PROMPT
  end

  # In the user prompt, we pass the songs currently in the playlist, along with the musical preferences the user specified. 
  # ChatGPT is not super original at creating playlists, and tends to return the same songs over and over.
  # To try to work around this, we store in the database the songs that have already been used in other playlists,
  # then tell it to avoid using those songs in the current playlist.
  # It sorta works, but also makes the prompts much more expensive.
  #
  # Note that Spotify's terms of use forbid passing Spotify data to ChatGPT, so it's important that we never do that in the prompt.
  # We avoid that by using the song names and artists from previous ChatGPT responses, not ones from the Spotify API.
  def chatgpt_user_prompt(user, playlist)  
    <<~PROMPT
      Here are the songs currently in the playlist:
      #{playlist.tracks.map { |track| "- #{track.artist} - #{track.title}" }.join("\n")}
  
      #{user.current_music_request.prompt}
  
      #{user.excluded_tracks_string}
    PROMPT
  end
end
