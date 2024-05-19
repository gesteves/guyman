class Preference < ApplicationRecord
  belongs_to :user

  validates :musical_tastes, presence: true
  validates :calendar_url, presence: true
  validates :timezone, presence: true
  validates_format_of :calendar_url, with: /\A(https?:\/\/)?(api\.)?trainerroad\.com\/.+\z/i, message: "must be a valid TrainerRoad calendar URL"
end
