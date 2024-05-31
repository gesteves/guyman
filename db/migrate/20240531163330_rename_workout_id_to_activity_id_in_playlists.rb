class RenameWorkoutIdToActivityIdInPlaylists < ActiveRecord::Migration[7.1]
  def change
    rename_column :playlists, :workout_id, :activity_id
  end
end
