class AddCoverImageUpdatedAtToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :cover_image_updated_at, :datetime
  end
end
