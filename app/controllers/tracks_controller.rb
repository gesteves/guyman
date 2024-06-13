class TracksController < ApplicationController
  before_action :authenticate_user!

  def index
    @tracks = current_user.recent_tracks
    @page_title = "Recent Tracks"
  end

  def destroy
    @track = Track.joins(playlist: :user)
                 .where(playlists: { user_id: current_user.id })
                 .find_by(id: params[:id])
  
    if @track.present?
      tracks = Track.joins(playlist: :user)
                    .where(playlists: { user_id: current_user.id })
                    .where(spotify_uri: @track.spotify_uri)
      tracks.destroy_all
      flash[:success] = "The track <strong>#{@track.title}</strong> by <strong>#{@track.artist}</strong> has been removed from your recent tracks."
      respond_to do |format|
        format.html { redirect_to tracks_path }
        format.turbo_stream
      end
    else
      flash[:warning] = "Track not found."
      redirect_to tracks_path
    end
  end
end
