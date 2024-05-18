class ProcessUserWorkoutsWorker < ApplicationWorker
  queue_as :high

  def perform(user_id)
    user = User.find(user_id)
    preference = user.preference

    todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today
    todays_workouts.each do |workout|
      GeneratePlaylistWorker.perform_async(user.id, workout[:name], workout[:description], workout[:type], workout[:duration])
    end
  end
end
