class RenameWorkoutsToActivities < ActiveRecord::Migration[7.1]
  def change
    rename_table :workouts, :activities
  end
end
