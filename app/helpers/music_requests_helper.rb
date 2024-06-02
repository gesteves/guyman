module MusicRequestsHelper
  def music_request_buttons_disabled(request)
    request.user.music_requests.count <= 1 ||
    request.user.todays_playlists.any?(&:processing?)
  end
end
