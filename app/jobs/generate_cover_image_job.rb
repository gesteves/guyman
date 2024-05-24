class GenerateCoverImageJob < ApplicationJob
  queue_as :default

  def perform(user_id, playlist_id)
    user = User.find(user_id)
    playlist = Playlist.find(playlist_id)
    # Use the Dall-E prompt ChatGPT generated for us to create the cover image for the playlist...
    image_url = DalleClient.new.generate(playlist.cover_dalle_prompt, user.id)
    # ...then schedule a job to set the playlist cover on Spotify.
    SetSpotifyPlaylistCoverJob.perform_async(user.id, playlist.id, image_url)
  end
end
