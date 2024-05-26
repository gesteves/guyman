# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  layout 'simple', only: [:new]
  
  def new
    super
  end
end
