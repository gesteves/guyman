class AddSpotifyUriToTracks < ActiveRecord::Migration[7.1]
  def change
    add_column :tracks, :spotify_uri, :string
  end
end
