class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @preference = current_user.preference || current_user.build_preference
    @page_title = 'Your Settings'
  end

  def update
    @preference = current_user.preference || current_user.build_preference
    if @preference.update(preference_params)
      CleanUpPlaylistsForUserJob.perform_async(current_user.id)
      redirect_to settings_path, notice: 'Your changes have been saved.'
    else
      render :edit
    end
  end

  private

  def preference_params
    params.require(:preference).permit(:calendar_url, :timezone, :automatically_clean_up_old_playlists, :public_playlists)
  end
end
