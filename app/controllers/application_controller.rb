class ApplicationController < ActionController::Base
  helper_method :turbo_stream_flash

  after_action :clear_flash

  def turbo_stream_notification
    return if flash.blank?
    turbo_stream.update("notification", partial: "shared/flash")
  end

  private
  def clear_flash
    if turbo_frame_request?
      # Render Turbo Stream response for flash notifications
      flash.clear
    end
  end

  def turbo_frame_request?
    request.headers["Turbo-Frame"]
  end
end
