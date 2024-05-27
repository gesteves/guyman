class TracksController < ApplicationController
  before_action :authenticate_user!

  def index
    page = params[:page]&.to_i || 1
    @recent_tracks = current_user.recent_tracks.page(page).per(500)
    @page_title = "Recent Tracks"
    redirect_to tracks_path if @recent_tracks.empty? && page > 1
  end

  def destroy
    @track = current_user.playlists.joins(:tracks).find_by(tracks: { id: params[:id] })
    @track.destroy
    redirect_to tracks_path, notice: 'Your track has been deleted!'
  end
end
