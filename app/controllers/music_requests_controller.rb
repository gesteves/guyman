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
    if current_user.can_regenerate_playlists?
      GenerateUserPlaylistsJob.perform_inline(current_user.id) 
      current_user.todays_playlists.each(&:processing!)
    end
    redirect_to music_requests_path, notice: 'Your music request has been restored!'
  end

  def create
    @music_request = current_user.music_requests.find_by(prompt: music_request_params[:prompt])
  
    if @music_request.present?
      @music_request.active!
    else
      @music_request = current_user.music_requests.build(music_request_params)
      @music_request.active = true
      @music_request.save
    end
  
    if @music_request&.prompt.present? && current_user.can_regenerate_playlists?
      GenerateUserPlaylistsJob.perform_inline(current_user.id)
      current_user.todays_playlists.each(&:processing!)
      redirect_to root_path, notice: current_user.todays_playlists.present? ? "Your playlists are being generated ✨" : "You don’t have any workouts on your calendar!"
    elsif !current_user.can_regenerate_playlists?
      redirect_to root_path, alert: 'Your playlists can’t be generated at this time.'
    elsif @music_request&.prompt.blank?
      redirect_to root_path, alert: 'Your playlists can’t be generated if you leave your request blank!'
    end
  end

  def destroy
    if current_user.music_requests.count > 1
      @music_request.destroy
      if current_user.can_regenerate_playlists?
        GenerateUserPlaylistsJob.perform_inline(current_user.id) 
        current_user.todays_playlists.each(&:processing!)
      end
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
