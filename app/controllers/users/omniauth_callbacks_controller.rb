module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def spotify
      handle_auth "Spotify"
    end

    def handle_auth(kind)
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: kind) if is_navigational_format?
      else
        session["devise.#{kind.downcase}_data"] = request.env["omniauth.auth"]
        redirect_to new_user_registration_url
      end
    end
  end
end
