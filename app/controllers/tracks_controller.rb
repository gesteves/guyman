class TracksController < ApplicationController
  before_action :authenticate_user!

  def index
    page = params[:page]&.to_i || 1
    @recent_tracks = current_user.recent_tracks.page(page).per(500)
    @page_title = "Recent Tracks"
    redirect_to tracks_path if @recent_tracks.empty? && page > 1
  end

  def destroy
    @track = Track.joins(playlist: :user)
                .where(playlists: { user_id: current_user.id })
                .find_by(id: params[:id])
    @track.destroy
    redirect_to tracks_path, notice: "The track <strong>#{@track.title}</strong> by <strong>#{@track.artist}</strong> has been deleted."
  end
end
