class GeneratePlaylistWorker < ApplicationWorker
  queue_as :high

  def perform(user_id, workout_name, workout_description, workout_type, workout_duration)
    user = User.find(user_id)
    preference = user.preference

    # Find the tracks already used in other playlists for this user.
    recent_tracks = user.recent_tracks
    prompt = chatgpt_user_prompt(workout_name, workout_description, preference.musical_tastes, recent_tracks)
    response = ChatgptClient.new(user_id).ask_for_json(chatgpt_system_prompt, prompt)

    playlist_tracks = response['tracks']
    dalle_prompt = response['cover_prompt']
    playlist_name = "#{Time.current.in_time_zone(preference.timezone).strftime('%B %-d, %Y')}: #{workout_name}"

    # Create a new playlist with the workout details and the response from ChatGPT.
    playlist = user.playlists.create!(
      name: playlist_name,
      description: response['description'],
      workout_description: workout_description,
      workout_type: workout_type,
      workout_name: workout_name,
      cover_dalle_prompt: dalle_prompt,
      workout_duration: workout_duration
    )

    # Add the tracks ChatGPT generated to the playlist.
    playlist_tracks.each do |track|
      playlist.tracks.create!(title: track['track'], artist: track['artist'])
    end

    # Enqueue a job to create the playlist in Spotify.
    ProcessPlaylistWorker.perform_async(user.id, playlist.id)
  end

  private

  # A few things worth nothing about this system prompt:
  # - Ideally we'd want to generate a playlist that matches the workout's intensity;
  #   but ChatGPT is pretty bad at that, so despite specifying it in the prompt,
  #   it rarely works.
  # - We want a playlist that matches the workout's duration,
  #   but ChatGPT is notoriously bad at generating playlists of the right duration
  #   because it can't actually do math to add up the song lengths.
  #   Instead, we ask it to generate at least 200 songs and then build the playlist manually until it's the right length.
  # - Because we're using the `json_object` response format in the API call to ChatGPT,
  #   we MUST specify in the prompt that it must return a JSON object with the given structure we expect.
  def chatgpt_system_prompt
    <<~PROMPT
      You are a helpful assistant tasked with creating a cohesive Spotify playlist to power your user's workout of the day. Your task is the following:

      - You will receive the title and description of the user's workout.
      - Based on the workout's description, you will generate a playlist that matches the workout's intensity as closely as possible.
      - The intensity is provided usually in terms of cycling power zones or percentages of FTP for cycling workouts, or RPE for swim and running workouts.
      - Lower intensity workouts should have softer, chiller songs. Higher intensity workouts should have more intense, energetic songs.
      - The playlist must contain at least 200 songs. 
      - The user may specify genres and bands they like. You may use this information to guide your choices.
      - The user may also specify genres, bands, or specific tracks they want to avoid. Do not include them in the playlist.
      - The playlist should have variety; try to avoid adding the same artist more than once.
      - Since we want playlists to vary from day to day, you may also receive a list of songs used in previous playlists. Do not include these in the playlist.
      - Come up with a name for the playlist that is creative and catchy, but also informative and descriptive.
      - Compose a description for the playlist, which should be a summary of the workout. The description must not be longer than 300 characters.
      - Generate a detailed prompt to create, using Dall-E, a playlist cover image that visually represents the workout and the playlist in a creative way, but avoid anything that may cause content policy violations in Dall-E or get flagged by OpenAI's safety systems.
      
      You must return your response in JSON format using this exact structure:
      
      {
        "name": "Your creatively named playlist",
        "description": "The summary of the workout.",
        "cover_prompt": "A prompt to generate a playlist cover image.",
        "tracks": [
          {"artist": "Artist Name 1", "track": "Track Name 1"},
          {"artist": "Artist Name 2", "track": "Track Name 2"}
        ]
      }    
    PROMPT
  end

  # ChatGPT is not super original at creating playlists, and tends to return the same songs over and over.
  # To try to work around this, we store in the database the songs that have already been used in other playlists,
  # then tell it to avoid using those songs in the current playlist.
  # It sorta works, but also makes the prompts much more expensive.
  def chatgpt_user_prompt(workout_name, workout_description, musical_tastes, recent_tracks)
    exclusions = if recent_tracks.any?
                   "The following songs have already been used in previous playlists, please don't include them:\n" +
                   recent_tracks.map { |t| "- #{t.first} - #{t.last}" }.join("\n")
                 else
                   ""
                 end
  
    <<~PROMPT
      #{workout_name}
      #{workout_description}
  
      #{musical_tastes}
  
      #{exclusions}
    PROMPT
  end
end
