class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:lock, :regenerate, :follow, :unfollow]

  def index
    @playlists = current_user.playlists
    @page_title = "Playlists"
  end

  def lock
    @playlist.update(locked: !@playlist.locked?)
    redirect_to root_path, notice: "Your playlist is now #{@playlist.locked? ? 'locked 🔒' : 'unlocked 🔓'}"
  end

  def regenerate
    if @playlist.locked?
      redirect_to root_path, alert: 'Your playlist can’t be regenerated while it’s locked.'
    else
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      @playlist.processing!
      redirect_to root_path, notice: 'Your playlist is being regenerated ✨'
    end
  end

  def regenerate_all
    if current_user.todays_playlists.any?(&:processing?)
      redirect_to root_path, alert: "Your playlists are already being regenerated."
    elsif current_user.todays_playlists.all?(&:locked?)
      redirect_to root_path, alert: 'All playlists are locked and can’t be regenerated.'
    else
      GenerateUserPlaylistsJob.perform_inline(current_user.id)
      current_user.todays_playlists.each(&:processing!)
      redirect_to root_path, notice: 'Your playlists are being regenerated ✨'
    end
  end

  def follow
    if !@playlist.following?
      FollowSpotifyPlaylistJob.perform_inline(current_user.id, @playlist.spotify_playlist_id)
      redirect_to playlists_path, notice: 'The playlist has been added to your Spotify library.'
    else
      redirect_to playlists_path, alert: 'This playlist is already in your Spotify library.'
    end
  end

  def unfollow
    if @playlist.following?
      UnfollowSpotifyPlaylistJob.perform_inline(current_user.id, @playlist.spotify_playlist_id)
      redirect_to playlists_path, notice: 'The playlist has been removed from your Spotify library.'
    else
      redirect_to playlists_path, alert: 'This playlist is not in your Spotify library.'
    end
  end

  def destroy_all
    if Rails.env.development?
      Playlist.destroy_all
      redirect_to root_path, notice: 'All playlists have been deleted.'
    end
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  end
end
