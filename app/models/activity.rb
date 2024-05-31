class Activity < ApplicationRecord
  belongs_to :user
  has_one :playlist, dependent: :destroy

  validates :name, presence: true
end
