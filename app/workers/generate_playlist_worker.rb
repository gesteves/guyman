class GeneratePlaylistWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, workout_name, workout_description, workout_type, workout_duration)
    user = User.find(user_id)
    preference = user.preference

    existing_tracks = user.unique_tracks
    prompt = chatgpt_user_prompt(workout_name, workout_description, workout_type, preference, existing_tracks)
    response = ChatgptClient.new.ask_for_json(chatgpt_system_prompt, prompt)
    playlist_tracks = response['tracks']
    dalle_prompt = response['cover_prompt']

    playlist_name = "Today’s #{workout_type} Workout: #{workout_name}"

    playlist = user.playlists.create!(
      name: playlist_name,
      description: response['description'],
      workout_description: workout_description,
      workout_type: workout_type,
      workout_name: workout_name,
      cover_dalle_prompt: dalle_prompt,
      workout_duration: workout_duration
    )

    playlist_tracks.each do |track|
      playlist.tracks.create!(title: track['track'], artist: track['artist'])
    end

    ProcessPlaylistWorker.perform_async(user.id, playlist.id)
  end

  private

  def chatgpt_system_prompt
    <<~PROMPT
      You are a helpful assistant tasked with creating a cohesive Spotify playlist to power your user's workout of the day. Your task is the following:

      - You will receive the title and description of the user's workout. The title includes the duration of the workout, in the format h:mm.
      - Based on the workout's description, you will generate a playlist that matches the workout's intensity as closely as possible.
      - The intensity is provided usually in terms of cycling power zones or percentages of FTP for cycling workouts, or RPE for swim and running workouts.
      - Lower intensity workouts should have softer, chiller songs. Higher intensity workouts should have more intense, energetic songs.
      - The playlist must contain at least 100 songs. 
      - The user may specify genres and bands they like. You may use this information to guide your choices.
      - The user may also specify genres, bands, or specific tracks they want to avoid. Do not include them in the playlist.
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

  def chatgpt_user_prompt(workout_name, workout_description, workout_type, preference, existing_tracks)
    exclusions = existing_tracks.any? ? "Do not include the following tracks: #{existing_tracks.map { |t| "#{t.first} - #{t.last}"}.join(', ')}." : ""

    <<~PROMPT
      Today's workout is called: "#{workout_name}"
      #{workout_description}

      #{preference.musical_tastes}
      #{exclusions}

      Please generate a playlist for this workout.
    PROMPT
  end
end
