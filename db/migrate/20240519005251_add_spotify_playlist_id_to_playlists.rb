class AddSpotifyPlaylistIdToPlaylists < ActiveRecord::Migration[7.1]
  def change
    add_column :playlists, :spotify_playlist_id, :string
  end
end
