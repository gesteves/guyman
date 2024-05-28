require 'test_helper'

class MusicRequestTest < ActiveSupport::TestCase
  def setup
    @user = users(:basic)
    @music_request = music_requests(:upbeat_pop_songs)
  end

  test "should be valid with a prompt" do
    assert @music_request.valid?
  end

  test "should be invalid without a prompt" do
    @music_request.prompt = nil
    assert_not @music_request.valid?
  end

  test "should set only one active music request" do
    another_request = @user.music_requests.create(prompt: "Chill vibes", active: true)
    assert another_request.reload.active?
    assert_not @music_request.reload.active?

    @music_request.update(active: true)
    assert @music_request.reload.active?
    assert_not another_request.reload.active?
  end

  test "should set last_used_at when used! is called" do
    @music_request.used!
    assert_not_nil @music_request.reload.last_used_at
  end

  test "should set active to true when active! is called" do
    @music_request.active!
    assert @music_request.reload.active?
  end

  test "should set active to false when inactive! is called" do
    @music_request.update(active: true)
    @music_request.inactive!
    assert_not @music_request.reload.active?
  end

  test "should order by active and last_used_at by default" do
    old_request = @user.music_requests.create(prompt: "Old song list", last_used_at: 1.week.ago)
    new_request = @user.music_requests.create(prompt: "New song list", last_used_at: Time.current)
    @music_request.update(active: true)
    @music_request.reload

    assert_equal @music_request, @user.music_requests.first
    assert_equal new_request, @user.music_requests.second
    assert_equal old_request, @user.music_requests.last
  end

  test "should update existing active music request instead of creating duplicate" do
    existing_request = @user.music_requests.create(prompt: "Upbeat pop songs", active: true)
    assert_no_difference 'MusicRequest.count' do
      existing_request.used!
    end
    assert existing_request.reload.active?
  end

  test "should set next most recent as active when destroying the current active request" do
    @music_request.update(active: true)
    recent_request = @user.music_requests.create(prompt: "Chill vibes", last_used_at: Time.current)
    @music_request.destroy
    assert recent_request.reload.active?
  end

  test "should not set next most recent as active if destroying an inactive request" do
    recent_request = @user.music_requests.create(prompt: "Some vibes", last_used_at: Time.current, active: false)
    inactive_request = @user.music_requests.create(prompt: "Old vibes", last_used_at: 1.week.ago, active: false)
    inactive_request.destroy
    assert @music_request.reload.active?
    assert_not recent_request.reload.active?
  end

  test "should normalize prompt before save" do
    @music_request.prompt = "Test Prompt\r\nWith Newlines\r\n"
    @music_request.save
    assert_equal "Test Prompt\nWith Newlines", @music_request.reload.prompt
  end
end
