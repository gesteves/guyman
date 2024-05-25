class GenerateUserPlaylistsJob < ApplicationJob
  queue_as :high

  # This job regenerates the playlists for today's workouts for a given user.
  def perform(user_id)
    user = User.find(user_id)
    return unless user.has_valid_spotify_token?
    
    preference = user.preference
    return if preference.blank?

    todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    
    todays_workouts.each do |workout|
      # Find any playlists already created for this workout today,
      # or create one if it doesn't exist...
      playlist = user.playlist_for_todays_workout(workout[:name]) || user.playlists.create!(
        workout_name: workout[:name],
        workout_description: workout[:description],
        workout_duration: workout[:duration]
      )

      # Skip if it's being processed or is locked.
      next if playlist.processing? || playlist.locked?

      # ...and then enqueue a job to generate the rest of the details with ChatGPT.
      GeneratePlaylistJob.perform_async(user.id, playlist.id)
    end
  end
end

