require 'test_helper'

class PreferenceTest < ActiveSupport::TestCase
  setup do
    @user = users(:basic)
    @preference = @user.preference
  end

  test "should be valid with valid attributes" do
    assert @preference.valid?
  end

  test "should be invalid without musical_tastes" do
    @preference.musical_tastes = nil
    assert_not @preference.valid?
    assert_includes @preference.errors[:musical_tastes], "can't be blank"
  end

  test "should be invalid without calendar_url" do
    @preference.calendar_url = nil
    assert_not @preference.valid?
    assert_includes @preference.errors[:calendar_url], "can't be blank"
  end

  test "should be invalid without timezone" do
    @preference.timezone = nil
    assert_not @preference.valid?
    assert_includes @preference.errors[:timezone], "can't be blank"
  end

  test "should be invalid with an incorrect calendar_url format" do
    @preference.calendar_url = "invalid_url"
    assert_not @preference.valid?
    assert_includes @preference.errors[:calendar_url], "must be a valid URL"
  end

  test "should be invalid with an incorrect calendar_url domain" do
    @preference.calendar_url = "https://www.example.com/calendar"
    assert_not @preference.valid?
    assert_includes @preference.errors[:calendar_url], "must be a valid URL from an accepted domain"
  end

  test "should be valid with a correct calendar_url domain" do
    @preference.calendar_url = "https://www.trainerroad.com/app/career/user/calendar"
    assert @preference.valid?
  end

  test "has_trainerroad_calendar? returns true for trainerroad domain" do
    @preference.calendar_url = "https://www.trainerroad.com/app/career/user/calendar"
    assert @preference.has_trainerroad_calendar?
  end

  test "has_trainerroad_calendar? returns false for non-trainerroad domain" do
    @preference.calendar_url = "https://www.example.com/calendar"
    assert_not @preference.has_trainerroad_calendar?
  end

  test "has_trainerroad_calendar? returns false for invalid URL" do
    @preference.calendar_url = "invalid_url"
    assert_not @preference.has_trainerroad_calendar?
  end
end
