class AddDeletedAtToMusicRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :music_requests, :deleted_at, :datetime
    add_index :music_requests, :deleted_at
  end
end
