class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:toggle_lock, :regenerate, :follow, :unfollow]

  def index
    page = params[:page]&.to_i || 1
    @playlists = current_user.playlists.page(page).per(100)
    @page_title = "Playlists"
    redirect_to tracks_path if @playlists.empty? && page > 1
  end

  def toggle_lock
    @playlist.update(locked: !@playlist.locked?)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_notification({ message: "Your playlist is now #{@playlist.locked? ? 'locked 🔒' : 'unlocked 🔓'}", level: 'success' }) }
      format.html { redirect_to root_path }
    end
  end

  def regenerate
    if @playlist.processing? || @playlist.locked?
      redirect_to root_path, alert: 'Your playlist can’t be generated at this time.'
    else
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_notification({ message: 'Your playlist is being generated ✨', level: 'success' }) }
        format.html { redirect_to root_path }
      end
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

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  end
end
