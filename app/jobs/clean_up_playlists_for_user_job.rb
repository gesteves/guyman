class CleanUpPlaylistsForUserJob < ApplicationJob
  queue_as :low

  def perform(user_id)
    user = User.find(user_id)
    user.unfollow_old_playlists
  end
end
