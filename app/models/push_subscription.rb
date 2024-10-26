class PushSubscription < ApplicationRecord
  require 'uri'

  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validate :valid_endpoint_url
  validates :p256dh, presence: true
  validates :auth, presence: true

  private

  def valid_endpoint_url
    uri = URI.parse(endpoint)
    errors.add(:endpoint, 'is not a valid URL') unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:endpoint, 'is not a valid URL')
  end
end
