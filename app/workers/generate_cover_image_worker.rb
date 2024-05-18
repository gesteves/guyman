class GenerateCoverImageWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, spotify_playlist_id, cover_prompt)
    image_url = DalleClient.new(user_id).generate(cover_prompt)
    SetPlaylistCoverWorker.perform_async(user_id, spotify_playlist_id, image_url)
  end
end
