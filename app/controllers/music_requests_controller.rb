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
    return redirect_to root_path, alert: 'Your playlists can’t be generated if you leave your request blank!' if music_request_params[:prompt].strip.blank?
    
    @music_request = MusicRequest.find_or_create_and_activate(current_user, music_request_params[:prompt])

    ProcessNewWorkoutsForUserJob.perform_inline(current_user.id)
    CleanUpPlaylistsForUserJob.perform_inline(current_user.id)

    if current_user.todays_playlists.blank?
      redirect_to root_path, alert: "You don’t have any workouts on your calendar! Add some first, and then try again."
    elsif current_user.todays_playlists.any?(&:processing?)
      redirect_to root_path, notice: 'Your playlists are being generated ✨'
    else
      redirect_to root_path, alert: "You don’t have any new workouts on your calendar! Add some first, and then try again."
    end
  end

  def destroy
    if current_user.music_requests.count > 1
      active = @music_request.active?
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
