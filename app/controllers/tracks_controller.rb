class TracksController < ApplicationController
  before_action :authenticate_user!

  def index
    @recent_tracks = current_user.playlists.joins(:tracks)
      .where.not(tracks: { spotify_uri: nil })
      .where('tracks.created_at >= ?', 2.weeks.ago)
      .select('tracks.spotify_uri, tracks.artist, tracks.title, tracks.created_at')
      .order('tracks.created_at DESC')
    @page_title = "Recent Tracks"
  end

  def destroy
    @track = current_user.playlists.joins(:tracks).find_by(tracks: { id: params[:id] })
    @track.destroy
    redirect_to tracks_path, notice: 'Your track has been deleted!'
  end
end
