require 'httparty'
require 'json'

class ChatgptClient
  OPENAI_API_URL = 'https://api.openai.com/v1'

  def initialize(user_id)
    @api_key = ENV['OPENAI_API_KEY']
    @user_id = user_id
  end

  def ask_for_json(system_prompt, user_prompt)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'gpt-4o',
        response_format: { type: "json_object" },
        user: @user_id.to_s,
        messages: [
          {
            role: 'system',
            content: system_prompt
          },
          {
            role: 'user',
            content: user_prompt
          }
        ]
      }.to_json
    }
    response = HTTParty.post("#{OPENAI_API_URL}/chat/completions", options)
    if response.success?
      JSON.parse(response.parsed_response['choices'].first['message']['content'])
    else
      raise "ChatGPT API request failed with status code #{response.code}: #{response.message}"
    end
  end
end
