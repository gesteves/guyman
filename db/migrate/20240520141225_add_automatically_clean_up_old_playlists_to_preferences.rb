class AddAutomaticallyCleanUpOldPlaylistsToPreferences < ActiveRecord::Migration[7.1]
  def change
    add_column :preferences, :automatically_clean_up_old_playlists, :boolean, default: false, null: false
  end
end
