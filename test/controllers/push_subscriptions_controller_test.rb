require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get push_subscriptions_create_url
    assert_response :success
  end

  test "should get destroy" do
    get push_subscriptions_destroy_url
    assert_response :success
  end
end
