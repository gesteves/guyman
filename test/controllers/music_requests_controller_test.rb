require "test_helper"

class MusicRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get music_requests_index_url
    assert_response :success
  end

  test "should get update" do
    get music_requests_update_url
    assert_response :success
  end
end
