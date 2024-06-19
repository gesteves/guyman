class CleanUpEventsForUserJob < ApplicationJob
  queue_as :low

  def perform(user_id)
    user = User.find(user_id)
    user.destroy_activities_removed_from_calendar
  end
end
