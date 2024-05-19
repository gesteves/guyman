class CleanUpOldPlaylistsJob < ApplicationJob
  queue_as :low

  def perform
    # We only keep playlists for a certain period.
    # We use them to exclude songs that have already been used from the ChatGPT prompt,
    # but it's fine to reuse songs after a while, so we can delete older playlists.

    # Default playlist age to 7 days if the environment variable is not set
    playlist_age_days = ENV.fetch('MAX_PLAYLIST_AGE_DAYS', 7).to_i

    # Calculate the cutoff date
    cutoff_date = playlist_age_days.days.ago

    # Delete playlists older than the cutoff date
    Playlist.where('created_at < ?', cutoff_date).destroy_all
  end
end
