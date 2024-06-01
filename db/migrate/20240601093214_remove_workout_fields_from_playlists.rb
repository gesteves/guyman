class RemoveWorkoutFieldsFromPlaylists < ActiveRecord::Migration[7.1]
  def change
    remove_column :playlists, :workout_name, :string
    remove_column :playlists, :workout_description, :text
    remove_column :playlists, :workout_duration, :integer
  end
end
