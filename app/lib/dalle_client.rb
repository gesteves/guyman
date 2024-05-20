require 'httparty'

# Represents a client for interacting with the DALL-E API.
class DalleClient
  OPENAI_API_URL = 'https://api.openai.com/v1'

  # Initializes a new instance of the DalleClient class.
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    @user_id = user_id
  end

  # Generates an image using the DALL-E API.
  #
  # @param prompt [String] The prompt for generating the image.
  # @param user_id [Int] The ID of the user making the request.
  # @return [String] The URL of the generated image.
  # @raise [RuntimeError] If the DALL-E API request fails.
  def generate(prompt, user_id)
    options = {
      headers: { "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}", "Content-Type" => "application/json" },
      body: {
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: "1024x1024",
        response_format: "url",
        quality: 'hd',
        user: user_id.to_s
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
