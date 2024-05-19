class BasicAuth
  def initialize(app)
    @app = app
  end

  def call(env)
    if ENV['BASIC_AUTH_USERNAME'].present? && ENV['BASIC_AUTH_PASSWORD'].present?
      auth = Rack::Auth::Basic::Request.new(env)

      if auth.provided? && auth.basic? && auth.credentials && auth.credentials == [ENV['BASIC_AUTH_USERNAME'], ENV['BASIC_AUTH_PASSWORD']]
        @app.call(env)
      else
        unauthorized
      end
    else
      @app.call(env)
    end
  end

  private

  def unauthorized
    [
      401,
      { 'Content-Type' => 'text/plain', 'Content-Length' => '0', 'WWW-Authenticate' => 'Basic realm="Restricted Area"' },
      []
    ]
  end
end
