class RenameWorkoutTypeToSportInPlaylists < ActiveRecord::Migration[7.1]
  def change
    rename_column :playlists, :workout_type, :sport
  end
end
