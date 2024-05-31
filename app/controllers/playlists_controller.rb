class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:toggle_lock, :regenerate, :regenerate_cover, :follow, :unfollow]

  def index
    page = params[:page]&.to_i || 1
    @playlists = current_user.playlists.page(page).per(100)
    @page_title = "Playlists"
    redirect_to tracks_path if @playlists.empty? && page > 1
  end

  def toggle_lock
    @playlist.update(locked: !@playlist.locked?)
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to root_path, notice: "Your playlist is now #{@playlist.locked? ? 'locked 🔒' : 'unlocked 🔓'}" }
    end
  end

  def regenerate
    if @playlist.processing? || @playlist.locked?
      redirect_to root_path, alert: 'Your playlist can’t be generated at this time.'
    else
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to root_path, notice: 'Your playlist is being generated ✨' }
      end
    end
  end

  def regenerate_cover
    if @playlist.processing? || @playlist.locked? || @playlist.cover_dalle_prompt.blank?
      redirect_to root_path, alert: 'Your playlist’s cover art can’t be regenerated at this time.'
    else
      GenerateCoverImageJob.perform_async(current_user.id, @playlist.id)
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to root_path, notice: 'Your playlist’s cover art is being regenerated ✨' }
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
