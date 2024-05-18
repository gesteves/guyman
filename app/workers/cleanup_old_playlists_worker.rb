class CleanupOldPlaylistsWorker < ApplicationWorker
  queue_as :low

  def perform
    Playlist.where('created_at < ?', 1.month.ago).destroy_all
  end
end
