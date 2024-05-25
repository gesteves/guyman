class HomeController < ApplicationController
  def index
    @preference = current_user&.preference
    @todays_playlists = current_user&.todays_playlists
  end
end
