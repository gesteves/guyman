require 'httparty'
require 'dotenv'
require 'icalendar'
require 'json'

require_relative 'spotify_client'
require_relative 'chatgpt_client'
require_relative 'dalle_client'

Dotenv.load

class WorkoutPlaylistGenerator
  RECENTLY_ADDED_TRACKS_FILE = 'recently_added_tracks.txt'
  MAX_TRACKS = 100

  def initialize
    @spotify = SpotifyClient.new
    @chatgpt = ChatgptClient.new
    @dalle = DalleClient.new
    @calendar_url = ENV['ICAL_FEED_URL']
  end

  def generate_playlist
    workouts = get_workouts
    @recently_added_tracks = load_recently_added_tracks

    workouts.each do |workout|
      next if workout.summary.include?("Swim")
      workout_duration = extract_workout_duration(workout.summary)
      workout_name = workout.summary.split(' - ').last.strip
      search_term = if workout.summary.include?("Run")
                      "Today’s Running Workout:"
                    else
                      "Today’s Cycling Workout:"
                    end
      playlist_name = "#{search_term} #{workout_name}"

      puts "\nGenerating your playlist for \"#{workout_name}\", please wait…\n\n"

      chatgpt_response = @chatgpt.ask_for_json(chatgpt_system_prompt, chatgpt_user_prompt(workout))
      return puts "Oops, failed to generate a playlist. Please try again!" if chatgpt_response.nil?

      playlist_id = @spotify.search_playlists(search_term)

      if playlist_id.nil?
        playlist_id = @spotify.create_playlist(playlist_name, chatgpt_response['description'])
      else
        @spotify.modify_playlist(playlist_id, playlist_name, chatgpt_response['description'])
      end

      playlist_url = "https://open.spotify.com/playlist/#{playlist_id}"
      puts "#{playlist_name}\n#{chatgpt_response['description']}\n#{playlist_url}\n\n"

      total_duration = 0
      track_uris = []
      chatgpt_response['tracks'].each do |track|
        spotify_track = @spotify.search_tracks(track['track'], track['artist'])
        if spotify_track
          @recently_added_tracks << "#{track['artist']} - #{track['track']}"
          track_uris << spotify_track['uri']
          total_duration += spotify_track['duration_ms']
        end
        break if total_duration >= workout_duration
      end

      @spotify.replace_playlist_tracks(playlist_id, track_uris)

      puts "\nGenerating a cover for your playlist: #{chatgpt_response['cover_prompt']}"
      image_url = @dalle.generate(chatgpt_response['cover_prompt'])
      @spotify.set_playlist_cover(playlist_id, image_url)
    end

    save_recently_added_tracks
  end

  private

  def get_workouts
    calendar_data = HTTParty.get(@calendar_url)
    calendars = Icalendar::Calendar.parse(calendar_data)
    calendar = calendars.first
  
    today = Time.current.in_time_zone('America/Denver').to_date
    calendar.events.select { |e| e.dtstart.value.to_date == today && e.summary.match?(/^\d{1}:\d{2}/) }
  end

  def extract_workout_duration(summary)
    duration_str = summary.split(' - ').first.strip
    hours, minutes = duration_str.split(':').map(&:to_i)
    (hours * 60 + minutes) * 60 * 1000 # Convert to milliseconds
  end

  def load_recently_added_tracks
    return [] unless File.exist?(RECENTLY_ADDED_TRACKS_FILE)
    File.read(RECENTLY_ADDED_TRACKS_FILE).split("\n").map(&:strip)
  end

  def save_recently_added_tracks
    File.open(RECENTLY_ADDED_TRACKS_FILE, 'w') do |file|
      file.puts(@recently_added_tracks.uniq.last(MAX_TRACKS))
    end
  end

  def chatgpt_system_prompt
    File.read('prompts/system.txt')
  end

  def chatgpt_user_prompt(workout)
    preferences = File.read('prompts/user_preferences.txt')
    exclusions = @recently_added_tracks.any? ? "Do not include the following recently-played tracks in the playlist: #{@recently_added_tracks.join(', ')}." : ""

    <<~PROMPT
      Today's workout is: "#{workout.summary.split(' - ').last.strip}"
      #{workout.description.strip}

      #{preferences}
      #{exclusions}

      Please generate a playlist for this workout.
    PROMPT
  end
end

generator = WorkoutPlaylistGenerator.new
generator.generate_playlist
