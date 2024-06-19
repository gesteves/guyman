module ApplicationHelper
  # Converts the duration from minutes to HH:MM format.
  #
  # @param minutes [Integer] The duration in minutes.
  # @return [String] The duration in HH:MM format.
  def convert_minutes_to_duration(minutes)
    hours = minutes / 60
    remaining_minutes = minutes % 60
    format('%02d:%02d', hours, remaining_minutes)
  end

  def non_breaking_time_ago(from_time, options = {})
    "#{time_ago_in_words(from_time, options)} ago".gsub(/\s+/, "&nbsp;").html_safe
  end

  def flash_level(key)
    case key.to_s
    when 'notice'
      'success'
    when 'alert'
      'warning'
    else
      key
    end
  end

  def sport_icon(sport)
    icon = case sport.downcase
    when 'swimming'
      "fa-person-swimming"
    when 'cycling'
      "fa-person-biking"
    when 'running'
      "fa-person-running-fast"
    when 'strength training'
      "fa-dumbbell"
    else
      "fa-circle-question"
    end

    if sport == 'swimming'
      tag.i class: "fa-solid #{icon}", style: "transform: scaleX(-1);"
    else
      tag.i class: "fa-solid #{icon}"
    end
  end

  def activity_type_icon(activity_type)
    icon = case activity_type.downcase
    when 'workout'
      "fa-heart-pulse"
    when 'race'
      "fa-medal"
    else
      "fa-circle-question"
    end

    tag.i class: "fa-solid #{icon}"
  end
end
