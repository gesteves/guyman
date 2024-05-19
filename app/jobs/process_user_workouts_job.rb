class ProcessUserWorkoutsJob < ApplicationJob
  queue_as :high

  # This job regenerates the playlists for today's workouts for a given user.
  def perform(user_id)
    user = User.find(user_id)
    preference = user.preference

    todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    todays_workouts.each do |workout|
      # Find any playlists already created for this workout today.
      existing_playlist = user.playlist_for_todays_workout(workout[:name])

      GeneratePlaylistJob.perform_async(user.id, workout[:name], workout[:description], workout[:type], workout[:duration], existing_playlist&.id)
    end
  end
end

