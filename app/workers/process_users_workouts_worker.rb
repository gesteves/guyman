class ProcessUsersWorkoutsWorker < ApplicationWorker
  queue_as :default

  def perform
    User.includes(:preference).where.not(preferences: { id: nil }).find_each do |user|
      preference = user.preference

      todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today

      todays_workouts.each do |workout|
        current_date = Time.current.in_time_zone(preference.timezone).to_date

        existing_playlist = user.playlists.where(workout_name: workout[:name])
                                          .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
                                          .exists?

        next if existing_playlist

        GeneratePlaylistWorker.perform_async(user.id, workout[:name], workout[:description], workout[:type], workout[:duration])
      end
    end
  end
end
