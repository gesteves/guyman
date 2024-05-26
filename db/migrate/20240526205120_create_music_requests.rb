class CreateMusicRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :music_requests do |t|
      t.text :prompt
      t.boolean :active, default: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
