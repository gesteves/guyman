class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, dependent: :destroy
end
