class CreatePreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.text :likes
      t.text :dislikes
      t.string :calendar_url

      t.timestamps
    end
  end
end
