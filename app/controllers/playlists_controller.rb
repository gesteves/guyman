class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:lock, :regenerate]

  def lock
    @playlist.update(locked: !@playlist.locked?)
    redirect_to root_path, notice: "Your playlist is now #{@playlist.locked? ? 'locked 🔒' : 'unlocked 🔓'}."
  end

  def regenerate
    if @playlist.locked?
      redirect_to root_path, alert: 'Your playlist can’t be regenerated while it’s locked.'
    else
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      @playlist.update(processing: true)
      redirect_to root_path, notice: 'Your playlist is being regenerated ✨'
    end
  end

  def regenerate_all
    if @todays_playlists.any?(&:processing?)
      redirect_to root_path, alert: "Your playlists are already being regenerated."
    elsif @todays_playlists.all?(&:locked?)
      redirect_to root_path, alert: 'All playlists are locked and can’t be regenerated.'
    else
      GenerateUserPlaylistsJob.perform_async(current_user.id)
      redirect_to root_path, notice: 'Your playlists are being regenerated ✨'
    end
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  end
end
