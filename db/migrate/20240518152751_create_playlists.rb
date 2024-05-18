class CreatePlaylists < ActiveRecord::Migration[7.1]
  def change
    create_table :playlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.text :workout_description
      t.string :workout_type
      t.string :workout_name
      t.string :cover_dalle_prompt
      t.integer :workout_duration

      t.timestamps
    end
  end
end
