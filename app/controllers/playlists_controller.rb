class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:toggle_lock, :regenerate, :regenerate_cover, :toggle_follow]

  def index
    page = params[:page]&.to_i || 1
    @playlists = current_user.playlists.page(page).per(10)
    @page_title = "Playlists"
    redirect_to tracks_path if @playlists.empty? && page > 1
  end

  def toggle_lock
    @playlist.update(locked: !@playlist.locked?)
    if @playlist.locked?
      flash[:success] = 'The playlist is now locked.'
    else
      flash[:success] = 'The playlist is now unlocked'
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_notification }
      format.html { redirect_to root_path }
    end
  end

  def toggle_follow
    if @playlist.following?
      UnfollowSpotifyPlaylistJob.perform_inline(current_user.id, @playlist.spotify_playlist_id)
      flash[:success]  = 'The playlist has been removed from your Spotify library.'
    else
      FollowSpotifyPlaylistJob.perform_inline(current_user.id, @playlist.spotify_playlist_id)
      flash[:success]  = 'The playlist has been added to your Spotify library.'
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_notification }
      format.html { redirect_to playlists_path }
    end
  end

  def regenerate
    if @playlist.processing?
      flash[:warning] = 'The playlist is already being regenerated.'
    elsif @playlist.locked?
      flash[:warning] = 'The playlist can’t be regenerated while it’s locked.'
    else
      @playlist.processing!
      GeneratePlaylistJob.perform_async(current_user.id, @playlist.id)
      flash[:success] = 'The playlist is being regenerated. This may take a minute.'
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_notification }
      format.html { redirect_to root_path }
    end
  end

  def regenerate_cover
    if @playlist.processing?
      flash[:warning] = 'The playlist’s cover can’t be regenerated while the playlist itself is being regenerated.'
    elsif @playlist.locked?
      flash[:warning] = 'The playlist’s cover can’be be regenerated while the playlist is locked.'
    elsif @playlist.generating_cover_image?
      flash[:warning] = 'The playlist’s cover is already being regenerated.'
    elsif @playlist.cover_dalle_prompt.blank?
      flash[:warning] = 'The playlist’s cover can’t be regenerated at this time.'
    else
      @playlist.generating_cover_image!
      GenerateCoverImageJob.perform_async(current_user.id, @playlist.id)
      flash[:success] = 'The playlist’s cover is being regenerated. This may take a minute.'
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_notification }
      format.html { redirect_to root_path }
    end
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  end
end
