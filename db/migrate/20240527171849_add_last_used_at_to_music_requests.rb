class AddLastUsedAtToMusicRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :music_requests, :last_used_at, :datetime
  end
end
