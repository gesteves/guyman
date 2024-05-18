class ProcessUsersWorkoutsWorker < ApplicationWorker
  queue_as :default

  def perform
    User.includes(:preference).where.not(preferences: { id: nil }).find_each do |user|
      preference = user.preference

      current_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today

      current_workouts.each do |workout|
        existing_playlist = user.playlists.find_by(workout_name: workout[:name])
        
        next if existing_playlist

        GeneratePlaylistWorker.perform_async(user.id, workout[:name], workout[:description], workout[:type], workout[:duration])
      end
    end
  end
end
