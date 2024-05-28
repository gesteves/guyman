class AddDurationMsToTracks < ActiveRecord::Migration[7.1]
  def change
    add_column :tracks, :duration_ms, :integer
  end
end
