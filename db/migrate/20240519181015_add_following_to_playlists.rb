class AddFollowingToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :following, :boolean, default: false, null: false
  end
end
