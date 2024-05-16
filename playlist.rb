require_relative 'spotify_client'
require_relative 'chatgpt_client'
require_relative 'dalle_client'

class PlaylistGenerator
  def initialize
    @spotify = SpotifyClient.new
    @chatgpt = ChatgptClient.new
    @dalle = DalleClient.new
  end

  def generate_playlist(prompt)
    puts "\nGenerating your playlist, please wait…\n"
    chatgpt_response = @chatgpt.ask_for_json(chatgpt_system_prompt, prompt)
    return puts "Oops, failed to generate a playlist. Please try again!" if chatgpt_response.nil?

    playlist_id = @spotify.create_playlist(chatgpt_response['name'], chatgpt_response['description'])
    playlist_url = "https://open.spotify.com/playlist/#{playlist_id}"
    puts "#{chatgpt_response['name']}\n#{chatgpt_response['description']}\n#{playlist_url}\n\n"

    track_uris = chatgpt_response['tracks'].map { |track| @spotify.search_tracks(track['track'], track['artist']) }.compact
    @spotify.replace_playlist_tracks(playlist_id, track_uris)

    puts "\nGenerating a cover for your playlist: #{chatgpt_response['cover_prompt']}"
    image_url = @dalle.generate(chatgpt_response['cover_prompt'])
    @spotify.set_playlist_cover(playlist_id, image_url)
  end

  private

  def chatgpt_system_prompt
    <<-CHATGPT
      You are a helpful DJ assistant tasked with creating a thoughtful, cohesive playlist for your user. The user will be asked "What kind of playlist would you like me to generate?". Using their answer as a prompt, your task is the following:

      - Interpret the user's prompt creatively to generate a playlist that fits the theme or mood requested.
      - If the prompt requests specific songs, artists, albums or genres, use that information to select the appropriate tracks.
      - If the prompt is ambiguous or abstract, use your best judgment and creativity to interpret the user's likely intent or desired mood for the playlist when choosing the songs.
      - Unless the user specifies otherwise, the resulting playlist must contain at least 30 tracks.
      - The playlist must be cohesive and have a consistent theme or genre, unless the user requests something more eclectic.
      - Creatively name and describe the playlist based on the theme or mood suggested by the prompt. The description must not be longer than 300 characters.
      - Generate a prompt to create, using Dall-E, a playlist cover image that visually represents the playlist's theme or mood in a creative way, but avoid anything that may cause content policy violations in Dall-E or get flagged by OpenAI's safety systems.

      You must return your response in JSON format using this exact structure:

      {
        "name": "Your creatively named playlist",
        "description": "A creative description based on the user's prompt.",
        "cover_prompt": "A prompt to generate a playlist cover image.",
        "tracks": [
          {"artist": "Artist Name 1", "track": "Track Name 1"},
          {"artist": "Artist Name 2", "track": "Track Name 2"}
        ]
      }
    CHATGPT
  end

  def save_image_to_file(image_url, filename)
    response = HTTParty.get(image_url)
    if response.success?
      File.open(filename, 'wb') do |file|
        file.write(response.body)
      end
      puts "Image saved as #{filename}"
    else
      puts "Failed to download the image: HTTP Status #{response.code}"
    end
  rescue => e
    puts "An error occurred while saving the image: #{e.message}"
  end
end

generator = PlaylistGenerator.new
puts "What kind of playlist would you like me to generate?"
prompt = gets.chomp
generator.generate_playlist(prompt)
