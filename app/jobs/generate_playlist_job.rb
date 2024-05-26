class GeneratePlaylistJob < ApplicationJob
  queue_as :high
  sidekiq_options retry_for: 5.minutes

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    return unless user.current_music_request.present?
    
    playlist = user.playlists.find(playlist_id)

    return if playlist.locked?

    playlist.update!(processing: true)

    # Ask ChatGPT to produce a playlist using the workout details and user's music preferences.
    prompt = chatgpt_user_prompt(user, playlist)
    response = ChatgptClient.new.ask_for_json(chatgpt_system_prompt, prompt, user_id)

    validate_response(response)

    dalle_prompt = response['cover_prompt']
    playlist_tracks = response['tracks']
    playlist_description = response['description']
    playlist_name = response['name']

    # Update the existing playlist
    playlist.update!(
      name: playlist_name,
      description: playlist_description,
      cover_dalle_prompt: dalle_prompt
    )

    # Remove existing tracks
    playlist.tracks.destroy_all

    # Add the tracks ChatGPT generated to the playlist.
    # It's important that we store the track names and artists returned by ChatGPT,
    # not the ones from Spotify, because we'll use them in future prompts,
    # and Spotify's terms of use forbid passing Spotify data to ChatGPT.
    playlist_tracks.each_with_index do |track, index|
      playlist.tracks.create!(title: track['track'], artist: track['artist'], position: index + 1)
    end

    # Enqueue a job to create or update the playlist in Spotify
    # with the name and description ChatGPT generated.
    SetUpSpotifyPlaylistJob.perform_async(user.id, playlist.id)
  rescue StandardError => e
    playlist.update!(processing: false)
    raise e
  end

  private

  # ChatGPT's JSON mode doesn't guarantee that the response will match the structure specified in the prompt,
  # only that it's valid JSON, so we must validate it.
  # This also guards against prompt injection, e.g. if someone enters "disregard all previous instructions"
  # as their musical taste.
  def validate_response(response)
    required_keys = ['name', 'description', 'cover_prompt', 'tracks']
    missing_keys = required_keys.select { |key| response[key].blank? }

    if missing_keys.any?
      raise "Invalid response from ChatGPT: Missing keys: #{missing_keys.join(', ')}"
    end

    unless response['tracks'].is_a?(Array) && response['tracks'].all? { |track| track.is_a?(Hash) && track['artist'].present? && track['track'].present? }
      raise "Invalid response from ChatGPT: 'tracks' must be an array of hashes with 'artist' and 'track' keys."
    end
  end

  # A few things worth noting about this system prompt:
  # - Ideally we'd want to generate a playlist that matches the workout's intensity;
  #   but ChatGPT is pretty bad at that, so despite specifying it in the prompt,
  #   it rarely works.
  # - We want a playlist that matches the workout's duration,
  #   but ChatGPT is notoriously bad at generating playlists of the right duration
  #   because it can't actually do math to add up the song lengths.
  #   Instead, we ask it to generate at least 100 songs and then build the playlist manually until it's the right length.
  # - Because we're using the `json_object` response format in the API call to ChatGPT,
  #   we MUST specify in the prompt that it must return a JSON object with the given structure we expect.
  # - Spotify's terms of use forbid passing Spotify data to ChatGPT, so it's important that we never do that in the prompt.
  def chatgpt_system_prompt
    <<~PROMPT
      You are a helpful assistant tasked with creating a cohesive Spotify playlist to power your user's workout of the day. Your task is the following:

      - You will receive the name of the user's workout, followed by a description of the workout.
      - You must generate a playlist tailored to the workout's structure and intensity.
      - The playlist must contain at least 100 songs. 
      - The user may specify genres and bands they like; use this information to guide your choices.
      - The user may specify genres, bands, or specific tracks they want to avoid; do not include them in the playlist.
      - You may receive a list of songs used in playlists for previous workouts; do not include them in the playlist.
      - You must come up with a name for the playlist following this exact format: "[name_of_the_workout]: [very_short_description_of_the_playlist]"
      - You must write a description that summarizes the playlist in 300 characters or less and includes details about the workout.
      - Generate a detailed prompt to create, using Dall-E, a playlist cover image that visually represents the workout and the playlist in a creative way, but avoid anything that may cause content policy violations in Dall-E or get flagged by OpenAI's safety systems.
      
      You must return your response in JSON format using this exact structure:
      
      {
        "name": "The name of the playlist",
        "description": "The summary of the workout.",
        "cover_prompt": "A prompt to generate a playlist cover image.",
        "tracks": [
          {"artist": "Artist Name 1", "track": "Track Name 1"},
          {"artist": "Artist Name 2", "track": "Track Name 2"}
        ]
      }    
    PROMPT
  end

  # In the user prompt, we pass the workout name and description, along with the musical preferences the user specified. 
  # ChatGPT is not super original at creating playlists, and tends to return the same songs over and over.
  # To try to work around this, we store in the database the songs that have already been used in other playlists,
  # then tell it to avoid using those songs in the current playlist.
  # It sorta works, but also makes the prompts much more expensive.
  #
  # Note that Spotify's terms of use forbid passing Spotify data to ChatGPT, so it's important that we never do that in the prompt.
  # We avoid that by using the song names and artists from previous ChatGPT responses, not ones from the Spotify API.
  def chatgpt_user_prompt(user, playlist)  
    <<~PROMPT
      #{playlist.workout_name}
      #{playlist.workout_description}
  
      #{user.current_music_request.prompt}
  
      #{user.excluded_tracks_string}
    PROMPT
  end
end
