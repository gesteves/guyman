class AddGeneratingCoverImageToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :generating_cover_image, :boolean, default: false, null: false
  end
end
