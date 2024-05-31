class CleanUpEventsJob < ApplicationJob
  queue_as :low

  def perform
    return unless Rails.env.production?
    User.joins(:preference).includes(:preference, :playlists).find_each do |user|
      preference = user.preference

      current_date = Time.current.in_time_zone(preference.timezone)
      event_names = user.todays_calendar_events.map { |event| event[:name] }

      # If the user has enabled it, unfollow any Spotify playlists created before the current day and are still being followed.
      # These playlists were likely used in a workout, so we want to unfollow them
      # to avoid cluttering the user's Spotify account, but we don't want to delete them
      # from the database so we don't reuse their songs in future playlists.
      if preference.automatically_clean_up_old_playlists
        user.playlists.where('created_at < ?', current_date.beginning_of_day).where(following: true, locked: false).each do |playlist|
          UnfollowSpotifyPlaylistJob.perform_async(user.id, playlist.spotify_playlist_id)
        end
      end

      # Unfollow and delete from the database any events created today that don't match today's events in the calendar,
      # and don't have any locked playlists
      # These events probably reference a workout that was previously scheduled for today and has since been removed
      # from the calendar, probably because the user either deleted it, rescheduled it, replaced it with an alternate,
      # or TrainerRoad adapted the plan.
      user.activities.joins(:playlist)
          .where(created_at: current_date.beginning_of_day..current_date.end_of_day)
          .where(playlists: { locked: false })
          .where.not(name: event_names)
          .each do |activity|
        activity.destroy
      end
    end
  end
end
