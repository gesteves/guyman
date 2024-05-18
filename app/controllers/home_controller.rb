class HomeController < ApplicationController
  def index
    @preference = current_user&.preference
  end
end
