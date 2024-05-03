require 'httparty'
require 'dotenv'
require 'json'

Dotenv.load

class ChatgptClient
  OPENAI_API_URL = 'https://api.openai.com/v1'

  def initialize
    @api_key = ENV['OPENAI_API_KEY']
  end

  def ask_for_json(system_prompt, user_prompt)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'gpt-4-turbo-preview',
        response_format: { type: "json_object" },
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
    JSON.parse(response.parsed_response['choices'].first['message']['content']) if response.success?
  end
end
