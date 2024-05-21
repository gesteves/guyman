class Track < ApplicationRecord
  belongs_to :playlist

  validates :title, presence: true
  validates :artist, presence: true

  default_scope { order(:position) }
end
