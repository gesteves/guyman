class HomeController < ApplicationController
  def index
    @preference = current_user&.preference
    @todays_playlists = current_user&.todays_playlists
  end

  def regenerate_playlists
    GenerateUserPlaylistsJob.perform_async(current_user.id)
    redirect_to root_path, notice: 'Playlists are being regenerated. This may take a few minutes.'
  end
end
