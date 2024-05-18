class CleanupOldPlaylistsWorker < ApplicationWorker
  queue_as :low

  def perform
    # We only keep playlist for a certain period.
    # We use them to exclude songs that have already been used from the ChatGPT prompt,
    # but it's fine to reuse songs after a while, so we can delete older playlists.
    Playlist.where('created_at < ?', 1.month.ago).destroy_all
  end
end
