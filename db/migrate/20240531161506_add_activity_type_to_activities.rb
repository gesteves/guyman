class AddActivityTypeToActivities < ActiveRecord::Migration[7.1]
  def change
    add_column :activities, :activity_type, :string
  end
end
