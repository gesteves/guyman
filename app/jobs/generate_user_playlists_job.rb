class GenerateUserPlaylistsJob < ApplicationJob
  queue_as :high

  # This job regenerates the playlists for today's workouts for a given user.
  def perform(user_id)
    user = User.find(user_id)
    return unless user.has_valid_spotify_token?
    return unless user.current_music_request.present?
    
    user.todays_workouts.each do |workout|
      # Find any playlists already created for this workout today.
      playlist = user.playlist_for_todays_workout(workout[:name])

      # Skip if:
      # - A playlist already exists for this workout today and it's being processed.
      # - A playlist already exists for this workout today and it's locked.
      next if playlist&.processing? || playlist&.locked?
      
      # Otherwise, create the playlist if it doesn't exist.
      if playlist.blank?
        playlist = user.playlists.create!(
          workout_name: workout[:name],
          workout_description: workout[:description],
          workout_duration: workout[:duration],
          processing: true
        )
      end

      # ...and then enqueue a job to generate the rest of the details with ChatGPT.
      GeneratePlaylistJob.perform_async(user.id, playlist.id)
    end
  end
end

