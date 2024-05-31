class AddWorkoutAndMusicRequestToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_reference :playlists, :workout, null: false, foreign_key: true
    add_reference :playlists, :music_request, null: false, foreign_key: true
  end
end
