class HomeController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @preference = current_user&.preference
    @todays_playlists = current_user&.todays_playlists
    @page_title = "Today’s Playlists"
  end
end
