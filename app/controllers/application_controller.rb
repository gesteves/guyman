class ApplicationController < ActionController::Base
  helper_method :turbo_stream_flash

  after_action :clear_flash_after_turbo_frame_request

  def turbo_stream_notification
    return if flash.blank?
    turbo_stream.update("notifications", partial: "shared/flash")
  end

  private
  def clear_flash_after_turbo_frame_request
    flash.clear if turbo_frame_request?
  end

  def turbo_frame_request?
    request.headers["Turbo-Frame"]
  end
end
