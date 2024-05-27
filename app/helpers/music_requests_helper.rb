module MusicRequestsHelper

  def music_request_delete_confirmation_message(request)
    if request.active?
      'Deleting this request will regenerate today’s playlists using the next one. Are you sure you want to continue? This can’t be undone.'
    else
      'Are you sure you want to delete this request? This can’t be undone.'
    end
  end

  def music_request_buttons_disabled
    current_user.music_requests.count <= 1 ||
    current_user.todays_playlists.any?(&:processing?)
  end
end
