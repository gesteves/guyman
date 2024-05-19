class ProcessUserWorkoutsWorker < ApplicationWorker
  queue_as :high

  def perform(user_id)
    user = User.find(user_id)
    preference = user.preference

    todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    todays_workouts.each do |workout|
      # Find any playlists already created for this workout today.
      current_date = Time.current.in_time_zone(preference.timezone).to_date
      existing_playlist = user.playlists.where(workout_name: workout[:name])
                                        .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
                                        .first

      GeneratePlaylistWorker.perform_async(user.id, workout[:name], workout[:description], workout[:type], workout[:duration], existing_playlist&.id)
    end
  end
end

