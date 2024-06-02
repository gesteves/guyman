require 'test_helper'

class MusicRequestTest < ActiveSupport::TestCase
  def setup
    @user = users(:basic)
  end

  test "should be valid with a prompt" do
    request = @user.music_requests.create(prompt: "Upbeat pop songs")
    assert request.valid?
  end

  test "should be invalid without a prompt" do
    request = @user.music_requests.create(prompt: nil)
    assert_not request.valid?
  end

  test "should set active to true when active! is called" do
    request = @user.music_requests.create(prompt: "Upbeat pop songs")
    request.active!
    assert request.reload.active?
  end

  test "should set active to false when inactive! is called" do
    request = @user.music_requests.create(prompt: "Upbeat pop songs", active: true)
    request.inactive!
    assert_not request.reload.active?
  end

  test "should order by active and updated_at by default" do
    old_request = @user.music_requests.create(prompt: "Old song list", updated_at: 1.week.ago, active: false)
    new_request = @user.music_requests.create(prompt: "New song list", updated_at: 1.day.ago, active: true)
    newer_request = @user.music_requests.create(prompt: "Newer song list", updated_at: Time.now, active: false)

    assert_equal new_request, @user.music_requests.first
    assert_equal newer_request, @user.music_requests.second
    assert_equal old_request, @user.music_requests.last
  end

  test "should set next most recent as active when destroying the current active request" do
    @user.music_requests.destroy_all
    old_request = @user.music_requests.create!(prompt: "Old song list", updated_at: 1.week.ago)
    new_request = @user.music_requests.create!(prompt: "New song list", updated_at: 1.day.ago, active: true)

    new_request.destroy
    old_request.reload
    assert old_request.active?, "Old request should be set to active"
  end

  test "should not set next most recent as active if destroying an inactive request" do
    @user.music_requests.destroy_all
    old_request = @user.music_requests.create(prompt: "Old song list", updated_at: 1.week.ago)
    new_request = @user.music_requests.create(prompt: "New song list", updated_at: 1.day.ago)
    newer_request = @user.music_requests.create(prompt: "Newer song list", updated_at: 1.hour.ago, active: true)

    old_request.destroy
    assert newer_request.reload.active?
    assert_not new_request.reload.active?
  end

  test "should find existing music request and activate it" do
    existing_request = MusicRequest.find_or_create_and_activate(@user, "Upbeat pop songs")
    music_request = MusicRequest.find_or_create_and_activate(@user, "Upbeat pop songs")

    assert_equal existing_request.id, music_request.id
    assert music_request.active?
  end

  test "should create new music request if none exists" do
    assert_difference '@user.music_requests.count', 1 do
      music_request = MusicRequest.find_or_create_and_activate(@user, "New prompt")
      assert_equal "New prompt", music_request.prompt
      assert music_request.active?
    end
  end

  test "should normalize prompt before saving" do
    raw_prompt = " Hard rock songs\r\nwith a twist "
    normalized_prompt = "Hard rock songs\nwith a twist"

    music_request = MusicRequest.find_or_create_and_activate(@user, raw_prompt)

    assert_equal normalized_prompt, music_request.prompt
    assert music_request.active?
  end

  test "should activate existing normalized prompt" do
    raw_prompt = "Upbeat pop songs\r\nwith a twist"
    normalized_prompt = "Upbeat pop songs\nwith a twist"
    existing_request = @user.music_requests.create!(prompt: normalized_prompt, active: false)

    music_request = MusicRequest.find_or_create_and_activate(@user, raw_prompt)

    assert_equal existing_request.id, music_request.id
    assert music_request.active?
  end

  test "should ensure only one active music request" do
    first_request = MusicRequest.find_or_create_and_activate(@user, "First request")
    second_request = MusicRequest.find_or_create_and_activate(@user, "Second request")

    assert_not first_request.reload.active?
    assert second_request.active?
  end
end
