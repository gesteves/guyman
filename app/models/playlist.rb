class Playlist < ApplicationRecord
  belongs_to :user
  has_many :tracks, dependent: :destroy

  validates :name, presence: true
  validates :workout_name, presence: true
  validates :workout_type, presence: true
end
