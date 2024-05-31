module HomeHelper
  def generate_playlists_button_class(playlists)
    css_class = ["button is-fullwidth"]
    css_class << "is-loading" if playlists.present? && playlists.any?(&:processing)
    css_class.join(" ")
  end
end
