class AddOriginalDescriptionToActivities < ActiveRecord::Migration[7.1]
  def change
    add_column :activities, :original_description, :text
  end
end
