class AddUserToWorkouts < ActiveRecord::Migration[7.1]
  def change
    add_reference :workouts, :user, null: false, foreign_key: true
  end
end
