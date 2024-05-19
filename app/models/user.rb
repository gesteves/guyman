class User < ApplicationRecord
  devise :rememberable, :omniauthable, omniauth_providers: %i[spotify]

  has_many :authentications, dependent: :destroy
  has_one :preference, dependent: :destroy
  has_many :playlists, dependent: :destroy

  def self.from_omniauth(auth)
    authentication = Authentication.where(provider: auth.provider, uid: auth.uid).first_or_initialize
    if authentication.user.blank?
      user = User.where(email: auth.info.email).first_or_initialize do |user|
        user.email = auth.info.email # Ensure the email is set
      end
      user.save!
      authentication.user = user
    end
    authentication.token = auth.credentials.token
    authentication.refresh_token = auth.credentials.refresh_token
    authentication.save!
    authentication.user
  end

  def recent_tracks(count = 500)
    playlists.joins(:tracks).distinct.order(created_at: :asc).pluck('tracks.artist', 'tracks.title').last(count)
  end
end
