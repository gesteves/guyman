require 'httparty'
require 'dotenv'
require 'icalendar'

require_relative 'spotify_client'
require_relative 'chatgpt_client'
require_relative 'dalle_client'

Dotenv.load

class WorkoutPlaylistGenerator
  def initialize
    @spotify = SpotifyClient.new
    @chatgpt = ChatgptClient.new
    @dalle = DalleClient.new
    @calendar_url = ENV['ICAL_FEED_URL']
  end

  def generate_playlist
    workouts = get_workouts
    workouts.each do |workout|
      workout_name = workout.summary.split(' - ').last.strip
      search_term = workout.summary.include?("Run") ? "Today’s Running Workout:" : "Today’s Cycling Workout:"
      playlist_name = "#{search_term} #{workout_name}"

      puts "\nGenerating your playlist for \"#{workout_name}\", please wait…\n\n"

      chatgpt_response = @chatgpt.ask_for_json(chatgpt_system_prompt, "#{workout.summary}\n\n#{workout.description}")
      return puts "Oops, failed to generate a playlist. Please try again!" if chatgpt_response.nil?

      playlist_id = @spotify.search_playlists(search_term)

      if playlist_id.nil?
        playlist_id = @spotify.create_playlist(playlist_name, chatgpt_response['description'])
      else
        @spotify.modify_playlist(playlist_id, playlist_name, chatgpt_response['description'])
      end

      playlist_url = "https://open.spotify.com/playlist/#{playlist_id}"
      puts "#{playlist_name}\n#{chatgpt_response['description']}\n#{playlist_url}\n\n"

      track_uris = chatgpt_response['tracks'].map { |track| @spotify.search_tracks(track['track'], track['artist']) }.compact
      @spotify.replace_playlist_tracks(playlist_id, track_uris)

      puts "\nGenerating a cover for your playlist: #{chatgpt_response['cover_prompt']}"
      png_data = @dalle.generate(chatgpt_response['cover_prompt'])
      @spotify.set_playlist_cover(playlist_id, png_data)
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
      - The user's most-listened genres are: #{@spotify.get_top_genres.join(", ")}. You may use this information to guide your choices, but don't limit yourself to these genres; you may stray from this list as long as it fits within the playlist and fulfills the needs of the workout.
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
