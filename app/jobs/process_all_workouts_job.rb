class ProcessAllWorkoutsJob < ApplicationJob
  queue_as :high

  # This job generates the playlists for today's workouts for every user, if one hasn't been created yet.
  def perform
    return unless Rails.env.production?
    User.includes(:preference).where.not(preferences: { id: nil }).find_each do |user|
      next unless user.has_valid_spotify_token?
      next unless user.current_music_request.present?

      user.todays_workouts.each do |workout|
        # Find any playlists already created for this workout today.
        playlist = user.playlist_for_todays_workout(workout[:name])

        # Skip if:
        # - A playlist already exists for this workout today and has tracks.
        # - A playlist already exists for this workout today and is being processed.
        # - A playlist already exists for this workout today and is locked.
        next if playlist&.tracks&.any? || playlist&.processing? || playlist&.locked?

        # Otherwise, create the playlist if it doesn't exist.
        if playlist.blank?
          playlist = user.playlists.create!(
            workout_name: workout[:name],
            workout_description: workout[:description],
            workout_duration: workout[:duration]
          )
        end

        # Enqueue a job to generate the rest of the details with ChatGPT.
        GeneratePlaylistJob.perform_async(user.id, playlist.id)
      end
    end
  end
end
