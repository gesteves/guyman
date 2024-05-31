class ApplicationController < ActionController::Base
  helper_method :turbo_stream_flash

  def turbo_stream_notification(options)
    turbo_stream.update("notification", partial: "shared/flash", locals: options)
  end
end
