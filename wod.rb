require 'httparty'
require 'dotenv'
require 'json'
require 'mini_magick'
require 'base64'
require 'icalendar'

Dotenv.load

class WorkoutPlaylistGenerator
  SPOTIFY_API_URL = 'https://api.spotify.com/v1'
  OPENAI_API_URL = 'https://api.openai.com/v1'
  MAX_IMAGE_FILE_SIZE = 256 * 1024
  MIN_IMAGE_QUALITY = 10

  def initialize
    @access_token = refresh_access_token
    @user_id = get_spotify_user_id
    @calendar_url = ENV['ICAL_FEED_URL']
  end

  def generate_playlist
    workouts = get_workouts
    workouts.each do |workout|
      workout_name = workout.summary.split(' - ').last.strip
      search_term = workout.summary.include?("Run") ? "Today’s Running Workout:" : "Today’s Cycling Workout:"
      playlist_name = "#{search_term} #{workout_name}"

      puts "\nGenerating your playlist for \"#{workout_name}\", please wait…\n\n"

      chatgpt_response = get_playlist_from_chatgpt("#{workout.summary}\n\n#{workout.description}")
      return puts "Oops, failed to generate a playlist. Please try again!" if chatgpt_response.nil?

      playlist_id = search_playlists(search_term)

      if playlist_id.nil?
        playlist_id = create_playlist(playlist_name, chatgpt_response['description'])
      else
        modify_playlist(playlist_id, playlist_name, chatgpt_response['description'])
      end

      playlist_url = "https://open.spotify.com/playlist/#{playlist_id}"
      puts "#{playlist_name}\n#{chatgpt_response['description']}\n#{playlist_url}\n\n"

      track_uris = chatgpt_response['tracks'].map { |track| search_tracks(track['track'], track['artist']) }.compact
      replace_playlist_tracks(playlist_id, track_uris)

      puts "\nGenerating a cover for your playlist: #{chatgpt_response['cover_prompt']}"
      jpeg_data = generate_playlist_cover(chatgpt_response['cover_prompt'])
      handle_cover_image(playlist_id, jpeg_data)
    end
  end

  private

  def get_workouts
    calendar_data = HTTParty.get(@calendar_url)
    calendars = Icalendar::Calendar.parse(calendar_data)
    calendar = calendars.first
  
    today = Time.current.in_time_zone('America/Denver').to_date
    calendar.events.select { |e| e.dtstart.value.to_date == today}.reject { |e| e.summary.include?("Swim") }
  end

  def refresh_access_token
    options = {
      body: { grant_type: 'refresh_token', refresh_token: ENV['SPOTIFY_REFRESH_TOKEN'] },
      headers: { "Authorization" => "Basic " + Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}"), "Content-Type" => "application/x-www-form-urlencoded" }
    }
    response = HTTParty.post("https://accounts.spotify.com/api/token", options)
    response.parsed_response['access_token']
  end

  def get_spotify_user_id
    response = HTTParty.get("#{SPOTIFY_API_URL}/me", headers: { "Authorization" => "Bearer #{@access_token}" })
    response.parsed_response['id']
  end

  def get_top_artists(limit = 10, time_range = 'long_term')
    response = HTTParty.get("#{SPOTIFY_API_URL}/me/top/artists", query: { limit: limit, time_range: time_range }, headers: { "Authorization" => "Bearer #{@access_token}" })
    if response.success?
      response.parsed_response['items']
    else
      []
    end
  end

  def get_top_genres(limit = 50, time_range = 'long_term')
    top_artists = get_top_artists(50)
    genres = top_artists.map { |artist| artist['genres'] }.flatten
    genre_counts = genres.each_with_object(Hash.new(0)) { |genre, counts| counts[genre] += 1 }
    sorted_genres = genre_counts.select { |genre, count| count > 1 }.sort_by { |genre, count| -count }.map(&:first)
    sorted_genres.take(limit)
  end

  def create_playlist(playlist_name, playlist_description = '')
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { name: playlist_name, description: playlist_description, public: true }.to_json
    }
    response = HTTParty.post("#{SPOTIFY_API_URL}/users/#{@user_id}/playlists", options)
    response.parsed_response['id']
  end

  def modify_playlist(playlist_id, name, description)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { name: name, description: description }.to_json
    }
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}", options)
    response.success?
  end

  def search_playlists(search_string)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}" },
      query: { limit: 50, offset: 0 }
    }
    response = HTTParty.get("#{SPOTIFY_API_URL}/users/#{@user_id}/playlists", options)
    playlist_id = find_playlist_id(response.parsed_response['items'], search_string)
    return playlist_id unless playlist_id.nil?

    while response.parsed_response['next']
      next_url = response.parsed_response['next']
      response = HTTParty.get(next_url, headers: { "Authorization" => "Bearer #{@access_token}" })
      playlist_id = find_playlist_id(response.parsed_response['items'], search_string)
      return playlist_id unless playlist_id.nil?
    end

    nil
  end

  def find_playlist_id(playlists, search_string)
    playlist = playlists.find { |p| p['name'].downcase.include?(search_string.downcase) }
    playlist['id'] if playlist
  end

  def search_tracks(track_name, artist_name)
    return if track_name.nil? || artist_name.nil?
    query = "#{track_name} artist:#{artist_name}"
    response = HTTParty.get("#{SPOTIFY_API_URL}/search", query: { type: 'track', limit: 1, q: query }, headers: { "Authorization" => "Bearer #{@access_token}" })
    if response.parsed_response['tracks'] && response.parsed_response['tracks']['items'].any?
      artists = response.parsed_response['tracks']['items'].first['artists'].map { |artist| artist['name'] }.join(", ")
      puts "#{artists} – #{response.parsed_response['tracks']['items'].first['name']}"
      response.parsed_response['tracks']['items'].first['uri']
    else
      puts "Searched for: #{artist_name} – #{track_name}, found nothing."
      nil
    end
  end

  def replace_playlist_tracks(playlist_id, track_uris)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { uris: track_uris }.to_json
    }
    HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/tracks", options)
  end

  def get_playlist_from_chatgpt(prompt)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'gpt-4-turbo-preview',
        response_format: { type: "json_object" },
        messages: [
          {
            role: 'system',
            content: chatgpt_system_prompt
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      }.to_json
    }
    response = HTTParty.post("#{OPENAI_API_URL}/chat/completions", options)
    JSON.parse(response.parsed_response['choices'].first['message']['content']) if response.success?
  end

  def generate_playlist_cover(prompt)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: "1024x1024",
        response_format: "b64_json",
        quality: 'hd'
      }.to_json
    }
    response = HTTParty.post("#{OPENAI_API_URL}/images/generations", options)
    return unless response.success?

    data = response.parsed_response['data']&.first['b64_json']
    return if data.nil?

    png = Base64.decode64(data)
    image = MiniMagick::Image.read(png)
    image.format("jpeg")
    image.resize("640x640")
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
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "image/jpeg" },
      body: base64_image
    }
    response = nil
    retries = 5
    backoff = 1
    while retries > 0
      response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/images", options)
      break if response.success?
      sleep backoff
      backoff *= 2
      retries -= 1
    end
    response.success?
  end

  def chatgpt_system_prompt
    <<-CHATGPT
      You are a helpful assistant tasked with creating a cohesive Spotify playlist to power your user's cycling or running workout of the day. Your task is the following:

      - You will receive the title and description of the user's workout. The title contains the duration of the workout.
      - Based on the workout's description, you will generate a playlist where each song matches each of the workout's structure in duration and intensity as closely as possible.
      - The structure of the workout is usually a warmup, followed by the main set, and then a cooldown. The main set may consist of a long continuous interval, or multiple repeats of shorter intervals with or without recoveries in between.
      - For example, if the workout calls for 4 intervals of 5 minutes each at 90% FTP, with 1-minute recoveries in between, then the main set is about 24 minutes long in total, so you should set up about 24 minutes of intense, powerful, energetic, motivating songs.
      - You can choose softer, chiller, more relaxing songs for the cooldown. Acoustic songs are great for cooldowns, for example.
      - The playlist must be as long as the whole workout. This is a hard requirement, the playlist must never, ever be shorter than the workout. Just to be safe, add 10 more minutes or so of additional cooldown songs at the end. 
      - The user can't skip, extend or shorten the workout intervals to match the duration of the songs.
      - The user can't control the Spotify player during the workout, so it's very important that the intensity and duration of the songs match the structure of the workout as closely as possible, because the user can't fast forward, rewind, repeat, loop, fade out, or skip tracks.
      - The user's most-listened genres are: #{get_top_genres.join(", ")}. You may use this information to guide your choices, but don't limit yourself to these genres; you may stray from this list as long as it fits within the playlist and fulfills the needs of the workout.
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
    CHATGPT
  end
end

generator = WorkoutPlaylistGenerator.new
generator.generate_playlist
