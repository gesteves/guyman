class UpdatePreferencesTable < ActiveRecord::Migration[7.1]
  def change
    rename_column :preferences, :likes, :musical_tastes
    remove_column :preferences, :dislikes, :text
  end
end
