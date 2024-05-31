class GenerateActivityDetailsJob < ApplicationJob
  queue_as :high
  sidekiq_options retry_for: 5.minutes

  def perform(user_id, activity_id)
    user = User.find(user_id)    
    activity = user.activities.find(activity_id)

    prompt = chatgpt_user_prompt(activity)
    response = ChatgptClient.new.ask_for_json(chatgpt_system_prompt, prompt, user_id)

    validate_response(response)

    description = response['description']
    sport = response['sport']
    activity_type = response['activity_type']

    # Update the activity with the ChatGPT data
    activity.update!(description: description, sport: sport, activity_type: activity_type)

    # Enqueue a job to generate the playlist for this activity.
    GeneratePlaylistJob.perform_async(user.id, activity.playlist.id)
  end

  private

  # ChatGPT's JSON mode doesn't guarantee that the response will match the structure specified in the prompt,
  # only that it's valid JSON, so we must validate it.
  # This also guards against prompt injection, e.g. if someone enters "disregard all previous instructions"
  # as their musical taste.
  def validate_response(response)
    required_keys = ['name', 'description', 'sport', 'activity_type']
    missing_keys = required_keys.select { |key| response[key].blank? }

    if missing_keys.any?
      raise "Invalid response from ChatGPT: Missing keys: #{missing_keys.join(', ')}"
    end
  end

  def chatgpt_system_prompt
    <<~PROMPT
      You are a helpful fitness assistant tasked with generating structured data about an exercise activity from a snippet of text describing it. Your task is the following:

      - You will receive the name of the user's activity, followed by a description of the activity.
      - You must generate a new description that summarizes the activity in about 300 characters. If the description is very short, you can add more details to make it more informative.
      - You must determine the sport of the activity, which is usually "Cycling", "Running", or "Swimming", but could be something else, such as "Yoga" or "Strength Training".
      - You must determine the type of activity, which can be either "Workout" or "Race".
      
      You must return your response in JSON format using this exact structure:
      
      {
        "name": "The name of the workout",
        "description": "The 300-character summary of the activity or workout.",
        "sport": "The sport of the activity or workout",
        "activity_type": "The type of activity, i.e. Race or Workout"
      }    
    PROMPT
  end

  def chatgpt_user_prompt(activity)  
    <<~PROMPT
      #{activity.name}

      #{activity.description}
    PROMPT
  end
end
