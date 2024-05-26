module ApplicationHelper
  def notification_class(key)
    case key
    when "notice"
      "is-success"
    when "alert"
      "is-warning"
    else
      "is-info"
    end
  end
end
