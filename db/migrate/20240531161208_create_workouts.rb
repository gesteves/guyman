class CreateWorkouts < ActiveRecord::Migration[7.1]
  def change
    create_table :workouts do |t|
      t.string :name
      t.text :description
      t.string :sport
      t.integer :duration

      t.timestamps
    end
  end
end
