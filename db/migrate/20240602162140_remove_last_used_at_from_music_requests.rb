class RemoveLastUsedAtFromMusicRequests < ActiveRecord::Migration[7.1]
  def change
    remove_column :music_requests, :last_used_at, :datetime
  end
end
