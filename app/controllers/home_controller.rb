class HomeController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @todays_playlists = current_user&.todays_playlists
    @music_request = current_user&.current_music_request || current_user.music_requests.build
    @page_title = "Today’s Playlists"
  end
end
