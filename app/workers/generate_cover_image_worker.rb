class GenerateCoverImageWorker < ApplicationWorker
  queue_as :default

  def perform(user_id, spotify_playlist_id, cover_prompt)
    # Use the Dall-E prompt ChatGPT generated for us to create the cover image for the playlist...
    image_url = DalleClient.new(user_id).generate(cover_prompt)
    # ...then schedule a job to set the playlist cover on Spotify.
    SetPlaylistCoverWorker.perform_async(user_id, spotify_playlist_id, image_url)
  end
end
