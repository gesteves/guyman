class CreateAuthentications < ActiveRecord::Migration[7.1]
  def change
    create_table :authentications do |t|
      t.string :provider
      t.string :uid
      t.string :token
      t.string :refresh_token
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
