module MusicRequestsHelper
  def music_request_buttons_disabled
    current_user.music_requests.count <= 1 ||
    current_user.todays_playlists.any?(&:processing?)
  end
end
