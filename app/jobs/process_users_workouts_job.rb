class ProcessUsersWorkoutsJob < ApplicationJob
  queue_as :high

  # This job generates the playlists for today's workouts for every user, if one hasn't been created yet.
  def perform
    return unless Rails.env.production?
    User.includes(:preference).where.not(preferences: { id: nil }).find_each do |user|
      preference = user.preference

      todays_workouts = TrainerroadClient.new(preference.calendar_url, preference.timezone).get_workouts_for_today

      todays_workouts.each do |workout|
        # Find any playlists already created for this workout today.
        playlist = user.playlist_for_todays_workout(workout[:name])

        # If a playlist has already been created for this workout today, skip it.
        next if playlist.present?

        # Otherwise, create the playlist...
        playlist = user.playlists.create!(
          name: workout[:name],
          workout_name: workout[:name],
          workout_description: workout[:description],
          workout_type: workout[:type],
          workout_duration: workout[:duration]
        )

        # ...and enqueue a job to generate the rest of the details with ChatGPT.
        GeneratePlaylistJob.perform_async(user.id, playlist.id)
      end
    end
  end
end
