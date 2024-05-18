require 'httparty'

class DalleClient
  OPENAI_API_URL = 'https://api.openai.com/v1'

  def initialize(user_id)
    @api_key = ENV['OPENAI_API_KEY']
    @user_id = user_id
  end

  def generate(prompt)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: "1024x1024",
        response_format: "url",
        quality: 'hd',
        user: @user_id
      }.to_json
    }
    response = HTTParty.post("#{OPENAI_API_URL}/images/generations", options)
    if response.success?
      response.parsed_response['data']&.first['url']
    else
      raise "DALL-E API request failed with status code #{response.code}: #{response.message}"
    end
  end
end
