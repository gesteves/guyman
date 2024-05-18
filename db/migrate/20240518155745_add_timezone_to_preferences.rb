class AddTimezoneToPreferences < ActiveRecord::Migration[7.1]
  def change
    add_column :preferences, :timezone, :string
  end
end
