module HomeHelper

  def regenerate_playlists_disabled?
    @todays_playlists.any?(&:processing?) || @todays_playlists.all?(&:locked?)
  end
end
