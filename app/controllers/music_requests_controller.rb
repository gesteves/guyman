class MusicRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_request, only: [:activate, :destroy]

  def index
    page = params[:page]&.to_i || 1
    @todays_playlists = current_user.todays_playlists
    @music_requests = current_user.music_requests.page(page).per(10)

    redirect_to tracks_path if @music_requests.empty? && page > 1
  end

  def activate
    @music_request.active!
    redirect_to music_requests_path, notice: 'Your music request has been restored!'
  end

  def create
    @music_request = MusicRequest.find_or_create_and_activate(current_user, music_request_params[:prompt])

    CleanUpEventsForUserJob.perform_inline(current_user.id)
    FetchNewEventsForUserJob.perform_inline(current_user.id)
    updateable_playlists = current_user.todays_playlists.where(locked: false).where.not(music_request_id: @music_request.id)
    updateable_playlists.each do |playlist|
      playlist.processing!
      playlist.update!(music_request_id: @music_request.id)
      GeneratePlaylistJob.perform_async(current_user.id, playlist.id)
    end

    notification = if current_user.todays_playlists.present?
      if updateable_playlists.present? || current_user.todays_playlists.any? { |p| p.tracks.blank? }
        nil
      else
        { message: 'You don’t have any new workouts on your calendar! Go add some and try again.', level: 'warning' }
      end
    else
      { message: 'You don’t have any workouts on your calendar! Go add some and try again.', level: 'warning'}
    end

    respond_to do |format|
      format.turbo_stream {
        if notification.present?
          render turbo_stream: turbo_stream_notification(notification)
        else
          head :no_content
        end
      }
      format.html { redirect_to root_path }
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
