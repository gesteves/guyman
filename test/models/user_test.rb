require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def setup
    @user = users(:basic)
    @auth = OpenStruct.new(
      provider: "spotify",
      uid: "54321",
      info: OpenStruct.new(email: "test@example.com"),
      credentials: OpenStruct.new(token: "mock_token", refresh_token: "mock_refresh_token")
    )
  end

  test "from_omniauth creates a new user and authentication if none exists" do
    assert_difference 'User.count', 1 do
      assert_difference 'Authentication.count', 1 do
        user = User.from_omniauth(@auth)
        assert_equal 'test@example.com', user.email
      end
    end
  end

  test "from_omniauth links to existing user if email matches" do
    @user.update(email: 'test@example.com')
    assert_no_difference 'User.count' do
      assert_difference 'Authentication.count', 1 do
        user = User.from_omniauth(@auth)
        assert_equal @user, user
      end
    end
  end

  test "todays_playlists returns playlists created today" do
    playlist = @user.playlists.create!(workout_name: 'Test Workout', created_at: Time.current)
    assert_includes @user.todays_playlists, playlist
  end

  test "todays_playlists returns empty array if no preference" do
    user = User.create!
    assert_equal [], user.todays_playlists
  end

  test "playlist_for_todays_workout returns the correct playlist" do
    playlist = @user.playlists.create!(workout_name: 'Test Workout', created_at: Time.current)
    assert_equal playlist, @user.playlist_for_todays_workout('Test Workout')
  end

  test "recent_tracks returns unique recent tracks" do
    playlist = @user.playlists.create!(workout_name: 'Test Workout')
    playlist.tracks.create!(spotify_uri: 'uri1', artist: 'Artist1', title: 'Title1', created_at: 1.day.ago)
    playlist.tracks.create!(spotify_uri: 'uri2', artist: 'Artist2', title: 'Title2', created_at: 2.days.ago)
    assert_equal [['uri1', 'Artist1', 'Title1'], ['uri2', 'Artist2', 'Title2']], @user.recent_tracks
  end

  test "excluded_tracks_string returns formatted string of recent tracks" do
    playlist = @user.playlists.create!(workout_name: 'Test Workout')
    playlist.tracks.create!(spotify_uri: 'uri1', artist: 'Artist1', title: 'Title1', created_at: 1.day.ago)
    playlist.tracks.create!(spotify_uri: 'uri2', artist: 'Artist2', title: 'Title2', created_at: 2.days.ago)
    expected_string = "The following songs have already been used in previous playlists, don't include them:\n- Artist1 - Title1\n- Artist2 - Title2"
    assert_equal expected_string, @user.excluded_tracks_string
  end

  test "has_valid_spotify_token? returns false if no spotify authentication" do
    user = User.create!
    assert_not user.has_valid_spotify_token?
  end
end
