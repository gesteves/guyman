class ProcessNewWorkoutsJob < ApplicationJob
  queue_as :high

  # This job generates the playlists for today's workouts for every user, if one hasn't been created yet.
  def perform
    return unless Rails.env.production?
    User.joins(:preference, :music_requests).where.not(preferences: { id: nil }).where(music_requests: { active: true }).distinct.find_each do |user|
      next unless user.has_valid_spotify_token?
      next unless user.current_music_request.present?

      user.todays_workouts.each do |workout|
        # Find any playlists already created for this workout today.
        playlist = user.playlist_for_todays_workout(workout[:name])

        next unless playlist&.can_be_processed?

        # Otherwise, create the playlist if it doesn't exist.
        if playlist.blank?
          playlist = user.playlists.create!(
            workout_name: workout[:name],
            workout_description: workout[:description],
            workout_duration: workout[:duration],
            processing: true
          )
        end

        # Enqueue a job to generate the rest of the details with ChatGPT.
        GeneratePlaylistJob.perform_async(user.id, playlist.id)
      end
    end
  end
end
