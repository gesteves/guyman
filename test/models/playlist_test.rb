require "test_helper"

class PlaylistTest < ActiveSupport::TestCase

  setup do
    @user = users(:basic)
    @playlist = playlists(:one)
  end

  test "should be valid with valid attributes" do
    assert @playlist.valid?
  end

  test "should be invalid without a workout_name" do
    @playlist.workout_name = nil
    assert_not @playlist.valid?
    assert_includes @playlist.errors[:workout_name], "can't be blank"
  end

  test "should have ordered tracks" do
    track1 = @playlist.tracks.create!(title: "Track 1", artist: "Artist 1", position: 2)
    track2 = @playlist.tracks.create!(title: "Track 2", artist: "Artist 2", position: 1)
    assert_equal [track2, track1], @playlist.tracks
  end

  test "spotify_uris should return an array of Spotify URIs" do
    @playlist.tracks.create!(title: "Track 1", artist: "Artist 1", spotify_uri: "spotify:track:1")
    @playlist.tracks.create!(title: "Track 2", artist: "Artist 2", spotify_uri: nil)
    @playlist.tracks.create!(title: "Track 3", artist: "Artist 3", spotify_uri: "spotify:track:3")

    assert_equal ["spotify:track:1", "spotify:track:3"], @playlist.spotify_uris
  end

  test "recent_track_uris_from_other_playlists should return unique URIs from other playlists" do
    other_playlist = @user.playlists.create!(workout_name: "Other Workout")
    other_playlist.tracks.create!(title: "Track 1", artist: "Artist 1", spotify_uri: "spotify:track:1", created_at: 1.second.ago)
    other_playlist.tracks.create!(title: "Track 2", artist: "Artist 2", spotify_uri: "spotify:track:2", created_at: 2.second.ago)
    other_playlist.tracks.create!(title: "Track 3", artist: "Artist 3", spotify_uri: "spotify:track:3", created_at: 3.second.ago)

    playlist_with_tracks = playlists(:with_tracks)

    assert_equal ["spotify:track:1", "spotify:track:2", "spotify:track:3"], playlist_with_tracks.recent_track_uris_from_other_playlists
  end
end
