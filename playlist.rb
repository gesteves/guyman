require 'httparty'
require 'dotenv'
require 'json'
require 'mini_magick'
require 'base64'

Dotenv.load

class PlaylistGenerator
  SPOTIFY_API_URL = 'https://api.spotify.com/v1'
  OPENAI_API_URL = 'https://api.openai.com/v1'
  MAX_IMAGE_FILE_SIZE = 256 * 1024
  MIN_IMAGE_QUALITY = 10

  def initialize
    @access_token = refresh_access_token
    @user_id = get_spotify_user_id
  end

  def generate_playlist(prompt)
    puts "\nGenerating your playlist, please wait…\n"
    chatgpt_response = get_playlist_from_chatgpt(prompt)
    return puts "Oops, failed to generate a playlist. Please try again!" if chatgpt_response.nil?

    playlist_id = create_playlist(chatgpt_response[:name], chatgpt_response[:description])
    playlist_url = "https://open.spotify.com/playlist/#{playlist_id}"
    puts "#{chatgpt_response[:name]}\n#{chatgpt_response[:description]}\n#{playlist_url}\n"

    track_uris = chatgpt_response[:tracks].map { |track| search_tracks(track[:track], track[:artist]) }.compact
    add_tracks_to_playlist(playlist_id, track_uris)

    puts "Generating a cover for your playlist: #{chatgpt_response[:cover_prompt]}"
    jpeg_data = generate_playlist_cover(chatgpt_response[:cover_prompt])
    handle_cover_image(playlist_id, jpeg_data)
  end

  private

  def refresh_access_token
    body = { grant_type: 'refresh_token', refresh_token: ENV['SPOTIFY_REFRESH_TOKEN'] }
    auth = { username: ENV['SPOTIFY_CLIENT_ID'], password: ENV['SPOTIFY_CLIENT_SECRET'] }
    response = HTTParty.post("https://accounts.spotify.com/api/token", body: body, basic_auth: auth)
    response.parsed_response['access_token']
  end

  def get_spotify_user_id
    response = HTTParty.get("#{SPOTIFY_API_URL}/me", headers: { "Authorization" => "Bearer #{@access_token}" })
    response.parsed_response['id']
  end

  def create_playlist(playlist_name, playlist_description = '')
    headers = { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" }
    body = { name: playlist_name, description: playlist_description, public: true }
    response = HTTParty.post("#{SPOTIFY_API_URL}/users/#{@user_id}/playlists", headers: headers, body: body.to_json)
    response.parsed_response['id']
  end

  def search_tracks(track_name, artist_name)
    return if track_name.nil? || artist_name.nil?
    query = "#{track_name} artist:#{artist_name}"
    response = HTTParty.get("#{SPOTIFY_API_URL}/search?type=track&limit=1&q=#{CGI.escape(query)}", headers: { "Authorization" => "Bearer #{@access_token}" })
    if response.parsed_response['tracks'] && response.parsed_response['tracks']['items'].any?
      artists = response.parsed_response['tracks']['items'].first['artists'].map { |artist| artist['name'] }.join(", ")
      puts "#{artists} – #{response.parsed_response['tracks']['items'].first['name']}"
      response.parsed_response['tracks']['items'].first['uri']
    else
      nil
    end
  end

  def add_tracks_to_playlist(playlist_id, track_uris)
    HTTParty.post("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/tracks", headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" }, body: { uris: track_uris }.to_json)
  end

  def get_playlist_from_chatgpt(prompt)
    headers = { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" }
    messages = [{ role: 'system', content: self.class.chatgpt_system_prompt }, { role: 'user', content: prompt }]
    body = { model: 'gpt-4-turbo-preview', response_format: { type: "json_object" }, messages: messages }
    response = HTTParty.post("#{OPENAI_API_URL}/chat/completions", headers: headers, body: body.to_json)
    JSON.parse(response.parsed_response['choices'].first['message']['content'], symbolize_names: true)
  rescue => e
    puts e
    nil
  end

  def generate_playlist_cover(prompt)
    headers = { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" }
    body = {
      model: 'dall-e-3',
      prompt: prompt,
      n: 1,
      size: "1024x1024",
      response_format: "b64_json",
      quality: 'hd'
    }
    response = HTTParty.post("#{OPENAI_API_URL}/images/generations", headers: headers, body: body.to_json)
    return unless response.success?
  
    data = response.parsed_response['data']&.first['b64_json']
    return if data.nil?
  
    png = Base64.decode64(data)
    image = MiniMagick::Image.read(png)
    image.format("jpeg")
    image.resize("512x512")
    quality = 80
    image.quality(quality)
    jpeg_data = image.to_blob
  
    # Reduce the quality until the file size is less than MAX_IMAGE_FILE_SIZE
    while jpeg_data.length > MAX_IMAGE_FILE_SIZE && quality > MIN_IMAGE_QUALITY
      quality -= 5
      image.quality(quality)
      jpeg_data = image.to_blob
    end
  
    Base64.strict_encode64(jpeg_data)
  rescue => e
    puts "Error generating cover image: #{e}"
    nil
  end
  
  def handle_cover_image(playlist_id, jpeg_data)
    if jpeg_data.nil?
      puts "Sorry! I couldn't generate a playlist cover image."
    elsif set_playlist_cover(playlist_id, jpeg_data)
      puts "Playlist cover image saved."
    else
      puts "Sorry! I couldn't save the playlist cover image."
    end
  end

  def set_playlist_cover(playlist_id, base64_image)
    headers = { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "image/jpeg" }
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/images", headers: headers, body: base64_image)
    response.success?
  end

  def self.chatgpt_system_message
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
end

generator = PlaylistGenerator.new
puts "What kind of playlist would you like me to generate?"
prompt = gets.chomp
generator.generate_playlist(prompt)
