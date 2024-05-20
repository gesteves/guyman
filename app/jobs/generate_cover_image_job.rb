class GenerateCoverImageJob < ApplicationJob
  queue_as :default

  def perform(user_id, spotify_playlist_id, cover_prompt)
    # Use the Dall-E prompt ChatGPT generated for us to create the cover image for the playlist...
    image_url = DalleClient.new.generate(cover_prompt, user_id)
    # ...then schedule a job to set the playlist cover on Spotify.
    SetPlaylistCoverJob.perform_async(user_id, spotify_playlist_id, image_url)
  end
end
