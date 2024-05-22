class AddLockedToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :locked, :boolean, default: false
  end
end
