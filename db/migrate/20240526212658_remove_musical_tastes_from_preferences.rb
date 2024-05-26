class RemoveMusicalTastesFromPreferences < ActiveRecord::Migration[7.1]
  def change
    remove_column :preferences, :musical_tastes, :text
  end
end
