class FetchEventsForUserJob < ApplicationJob
  queue_as :high

  # This job generates the playlists for today's workouts for a given user.
  def perform(user_id)
    user = User.find(user_id)

    user.todays_calendar_events.each do |event|
      # Find any playlists already created for this workout today.
      activity = user.activity_for_calendar_event(event[:name])

      next if activity.present? && activity.original_description == event[:description] && activity.duration == event[:duration]

      if activity.present?
        activity.update!(original_description: event[:description], duration: event[:duration])
        activity.playlist.update!(music_request_id: user.current_music_request.id) unless activity.playlist.locked?
      else
        activity = user.activities.create!(name: event[:name], original_description: event[:description], duration: event[:duration])
        Playlist.create!(user_id: user.id, activity_id: activity.id, music_request_id: user.current_music_request.id)
      end

      # Enqueue a job to generate the rest of the details with ChatGPT.
      GenerateActivityDetailsJob.perform_async(user.id, activity.id)
    end
  end
end

