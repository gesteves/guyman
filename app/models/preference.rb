class Preference < ApplicationRecord
  belongs_to :user

  validates :musical_tastes, presence: true
  validates :calendar_url, presence: true
  validates :timezone, presence: true
  validate :calendar_url_domain

  # List of valid domains for calendar URLs
  VALID_DOMAINS = ['trainerroad.com', 'trainingpeaks.com']

  # Checks if the calendar URL is from TrainerRoad
  #
  # @return [Boolean] True if the calendar URL is from TrainerRoad, false otherwise
  def has_trainerroad_calendar?
    calendar_domain_matches?('trainerroad.com')
  end

  # Checks if the calendar URL is from TrainingPeaks
  #
  # @return [Boolean] True if the calendar URL is from TrainingPeaks, false otherwise
  def has_trainingpeaks_calendar?
    calendar_domain_matches?('trainingpeaks.com')
  end

  private

  # Checks if the domain of the calendar URL matches the given domain
  #
  # @param domain [String] The domain to check against
  # @return [Boolean] True if the domain matches, false otherwise
  def calendar_domain_matches?(domain)
    uri = URI.parse(calendar_url)
    calendar_domain = PublicSuffix.parse(uri.host).domain
    calendar_domain == domain
  rescue URI::InvalidURIError, PublicSuffix::DomainInvalid
    false
  end

  # Validates the domain of the calendar URL
  #
  # Adds an error to the calendar_url attribute if the domain is not valid
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
