class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:lock, :regenerate]

  def lock
    @playlist.update(locked: !@playlist.locked?)
    redirect_to root_path, notice: "Playlist has been #{@playlist.locked? ? 'locked' : 'unlocked'}."
  end

  def regenerate
    if @playlist.locked?
      redirect_to root_path, alert: 'Cannot regenerate a locked playlist.'
    else
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      @playlist.update(processing: true)
      redirect_to root_path, notice: 'Playlist is being regenerated.'
    end
  end

  def regenerate_all
    if @todays_playlists.any?(&:processing?)
      redirect_to root_path, alert: "Playlist are already being regenerated."
    elsif @todays_playlists.all?(&:locked?)
      redirect_to root_path, alert: 'All playlists are locked.'
    else
      ProcessUserWorkoutsJob.perform_async(current_user.id)
      redirect_to root_path, notice: 'Playlists are being regenerated.'
    end
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  end
end
