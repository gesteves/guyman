class AddProcessingToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :processing, :boolean, default: false
  end
end
