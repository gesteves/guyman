require 'httparty'
require 'base64'
require 'mini_magick'

# A class that interacts with the Spotify API to perform various operations such as creating playlists, modifying playlists, searching tracks, and more.
class SpotifyClient
  SPOTIFY_API_URL = 'https://api.spotify.com/v1'
  MAX_IMAGE_FILE_SIZE = 250 * 1024
  MIN_IMAGE_QUALITY = 10

  # Initializes a new instance of the SpotifyClient class.
  #
  # @param refresh_token [String] The refresh token used to obtain an access token.
  def initialize(refresh_token)
    @refresh_token = refresh_token
    @access_token = refresh_access_token
    @user_id = get_spotify_user_id
  end

  # Creates a new playlist with the given name and description.
  # 
  # @param playlist_name [String] The name of the playlist.
  # @param playlist_description [String] The description of the playlist (optional).
  # @param public [Boolean] Whether the playlist is public or private. Defaults to true.
  # @return [String] The ID of the created playlist.
  def create_playlist(playlist_name, playlist_description = '', public = true)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { name: playlist_name, description: playlist_description, public: public }.to_json
    }
    response = HTTParty.post("#{SPOTIFY_API_URL}/users/#{@user_id}/playlists", options)
    handle_response(response)['id']
  end

  # Modifies an existing playlist with the given ID by updating its name and description.
  #
  # @param playlist_id [String] The ID of the playlist to modify.
  # @param name [String] The new name of the playlist.
  # @param description [String] The new description of the playlist.
  # @return [Hash] The modified playlist object.
  def modify_playlist(playlist_id, name, description)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { name: name, description: description }.to_json
    }
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}", options)
    handle_response(response)
  end

  # Replaces the tracks in a playlist with the given track URIs.
  #
  # @param playlist_id [String] The ID of the playlist to modify.
  # @param track_uris [Array<String>] An array of track URIs.
  # @return [Hash] The modified playlist object.
  def update_playlist_tracks(playlist_id, track_uris)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "application/json" },
      body: { uris: track_uris }.to_json
    }
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/tracks", options)
    handle_response(response)
  end

  # Follows a playlist with the given ID. This adds the playlist to the user's library.
  #
  # @param playlist_id [String] The ID of the playlist to follow.
  # @raise [RuntimeError] If following the playlist fails.
  def follow_playlist(playlist_id)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}" }
    }
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/followers", options)
    unless response.success?
      raise "Failed to follow Spotify playlist with ID #{playlist_id}: #{response.message}"
    end
  end

  # Unfollows a playlist with the given ID. This is equivalent to "deleting" the playlist from the user's library.
  #
  # @param playlist_id [String] The ID of the playlist to unfollow.
  # @raise [RuntimeError] If unfollowing the playlist fails.
  def unfollow_playlist(playlist_id)
    options = {
      headers: { "Authorization" => "Bearer #{@access_token}" }
    }
    response = HTTParty.delete("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/followers", options)
    unless response.success?
      raise "Failed to unfollow Spotify playlist with ID #{playlist_id}: #{response.message}"
    end
  end

  # Searches for a track with the given name and artist name.
  #
  # @param track_name [String] The name of the track.
  # @param artist_name [String] The name of the artist.
  # @return [Hash] The first matching track object.
  def search_tracks(track_name, artist_name)
    return if track_name.nil? || artist_name.nil?
    query = "#{track_name} artist:#{artist_name}"
    response = HTTParty.get("#{SPOTIFY_API_URL}/search", query: { type: 'track', limit: 1, q: query }, headers: { "Authorization" => "Bearer #{@access_token}" })
    handle_response(response)['tracks']['items'].first
  end

  # Sets the cover image of a playlist with the given ID.
  #
  # @param playlist_id [String] The ID of the playlist to modify.
  # @param url [String] The URL of the image to set as the cover.
  # @return [Hash] The modified playlist object.
  def set_playlist_cover(playlist_id, url)
    jpg_data = png_to_base64_jpg(url)
    return if jpg_data.nil?

    options = {
      headers: { "Authorization" => "Bearer #{@access_token}", "Content-Type" => "image/jpeg" },
      body: jpg_data
    }
    
    response = HTTParty.put("#{SPOTIFY_API_URL}/playlists/#{playlist_id}/images", options)

    handle_response(response)
  end

  private

  # Handles the response from the Spotify API.
  #
  # @param response [HTTParty::Response] The response object.
  # @return [Hash] The parsed response body if the request was successful.
  # @raise [RuntimeError] If the request failed.
  def handle_response(response)
    if response.success?
      response.parsed_response
    else
      raise "Spotify API request failed with status code #{response.code}: #{response.message}"
    end
  end

  # Refreshes the access token using the refresh token.
  #
  # @return [String] The new access token.
  def refresh_access_token
    options = {
      body: { grant_type: 'refresh_token', refresh_token: @refresh_token },
      headers: { "Authorization" => "Basic " + Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}"), "Content-Type" => "application/x-www-form-urlencoded" }
    }
    response = HTTParty.post("https://accounts.spotify.com/api/token", options)
    handle_response(response)['access_token']
  end

  # Retrieves the user ID associated with the access token.
  #
  # @return [String] The user ID.
  def get_spotify_user_id
    response = HTTParty.get("#{SPOTIFY_API_URL}/me", headers: { "Authorization" => "Bearer #{@access_token}" })
    handle_response(response)['id']
  end
  
  # Converts a PNG image to a base64-encoded JPEG image, keeping it under the given file size.
  #
  # @param image_url [String] The URL of the PNG image.
  # @return [String] The base64-encoded JPEG image data.
  # @raise [RuntimeError] If fetching or converting the image fails.
  def png_to_base64_jpg(image_url)
    response = HTTParty.get(image_url)
    if response.success?
      image_data = response.body
      image = MiniMagick::Image.read(image_data)
      image.format("jpeg")
      image.resize("640x640")
      quality = 80
      image.quality(quality)
      jpeg_data = image.to_blob
  
      base64_image = Base64.strict_encode64(jpeg_data)
  
      # Reduce the quality until the base64 size is less than MAX_IMAGE_FILE_SIZE
      while base64_image.bytesize > MAX_IMAGE_FILE_SIZE && quality > MIN_IMAGE_QUALITY
        quality -= 5
        image.quality(quality)
        jpeg_data = image.to_blob
        base64_image = Base64.strict_encode64(jpeg_data)
      end
  
      return if quality <= MIN_IMAGE_QUALITY
      base64_image
    else
      raise "Failed to fetch image: HTTP Status #{response.code}"
    end
  rescue => e
    raise "Failed to convert image: #{e.message}"
  end
end
