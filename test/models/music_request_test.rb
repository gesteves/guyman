require 'test_helper'

class MusicRequestTest < ActiveSupport::TestCase
  def setup
    @user = users(:basic)
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
