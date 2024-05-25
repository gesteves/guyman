class Preference < ApplicationRecord
  belongs_to :user

  validates :musical_tastes, presence: true
  validates :calendar_url, presence: true
  validates :timezone, presence: true
  validate :calendar_url_domain

  VALID_DOMAINS = ['trainerroad.com']

  def has_trainerroad_calendar?
    calendar_domain_matches?('trainerroad.com')
  end

  private

  def calendar_domain_matches?(domain)
    uri = URI.parse(calendar_url)
    calendar_domain = PublicSuffix.parse(uri.host).domain
    calendar_domain == domain
  rescue URI::InvalidURIError, PublicSuffix::DomainInvalid
    false
  end

  def calendar_url_domain
    begin
      uri = URI.parse(calendar_url)
      domain = PublicSuffix.parse(uri.host).domain
      unless VALID_DOMAINS.include?(domain)
        errors.add(:calendar_url, "must be a valid URL from an accepted domain")
      end
    rescue URI::InvalidURIError, PublicSuffix::DomainInvalid
      errors.add(:calendar_url, "must be a valid URL")
    end
  end
end
