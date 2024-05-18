class Preference < ApplicationRecord
  belongs_to :user

  validates :musical_tastes, presence: true
  validates :calendar_url, presence: true
  validates :timezone, presence: true
end
