# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_05_26_212658) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "authentications", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "token"
    t.string "refresh_token"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_authentications_on_user_id"
  end

  create_table "music_requests", force: :cascade do |t|
    t.text "prompt"
    t.boolean "active", default: true
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_music_requests_on_user_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.text "description"
    t.text "workout_description"
    t.string "sport"
    t.string "workout_name"
    t.string "cover_dalle_prompt"
    t.integer "workout_duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "spotify_playlist_id"
    t.boolean "following", default: false, null: false
    t.boolean "processing", default: false
    t.boolean "locked", default: false
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "calendar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "timezone"
    t.boolean "automatically_clean_up_old_playlists", default: false, null: false
    t.boolean "public_playlists", default: true
    t.index ["user_id"], name: "index_preferences_on_user_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "playlist_id", null: false
    t.string "title"
    t.string "artist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "spotify_uri"
    t.integer "position", default: 0, null: false
    t.index ["playlist_id"], name: "index_tracks_on_playlist_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "authentications", "users"
  add_foreign_key "music_requests", "users"
  add_foreign_key "playlists", "users"
  add_foreign_key "preferences", "users"
  add_foreign_key "tracks", "playlists"
end
