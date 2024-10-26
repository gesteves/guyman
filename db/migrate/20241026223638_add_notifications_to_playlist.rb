class AddNotificationsToPlaylist < ActiveRecord::Migration[7.2]
  def change
    add_column :playlists, :push_notifications_sent, :boolean, default: false
  end
end
