class AddPublicPlaylistsToPreferences < ActiveRecord::Migration[7.1]
  def change
    add_column :preferences, :public_playlists, :boolean, default: true
  end
end
