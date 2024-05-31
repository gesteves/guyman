class MusicRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_request, only: [:activate, :destroy]

  def index
    page = params[:page]&.to_i || 1
    @todays_playlists = current_user.todays_playlists
    @music_requests = current_user.music_requests.page(page).per(100)
    
    redirect_to tracks_path if @music_requests.empty? && page > 1
  end

  def activate
    @music_request.active!
    redirect_to music_requests_path, notice: 'Your music request has been restored!'
  end

  def create
    current_request = current_user.current_music_request
    @music_request = MusicRequest.find_or_create_and_activate(current_user, music_request_params[:prompt])
  
    CleanUpPlaylistsForUserJob.perform_async(current_user.id)
    ProcessNewWorkoutsForUserJob.perform_async(current_user.id)
    current_user.regenerate_todays_playlists! if current_request != @music_request
  
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to root_path, notice: 'Your playlists are being generated ✨' }
    end
  end
  

  def destroy
    if current_user.music_requests.count > 1
      @music_request.destroy
      redirect_to music_requests_path, notice: 'Your music request has been deleted!'
    else
      redirect_to music_requests_path, alert: 'You can’t delete your only music request!'
    end
  end

  private

  def music_request_params
    params.require(:music_request).permit(:prompt)
  end

  def set_request
    @music_request = current_user.music_requests.find(params[:id])
  end
end
