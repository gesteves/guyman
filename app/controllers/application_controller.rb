class ApplicationController < ActionController::Base
  helper_method :turbo_stream_flash

  def turbo_stream_notification
    return if flash.blank?
    turbo_stream.update("notification", partial: "shared/flash")
  end
end
