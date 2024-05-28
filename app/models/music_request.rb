class MusicRequest < ApplicationRecord
  belongs_to :user

  validates :prompt, presence: true

  default_scope { order(active: :desc, last_used_at: :desc) }

  before_save :ensure_only_one_active, if: :active?
  before_save :normalize_prompt
  before_destroy :set_next_most_recent_as_active, if: :active?

  scope :active, -> { where(active: true) }

  def used!
    update!(last_used_at: Time.current)
  end

  def active!
    update!(active: true)
  end

  def inactive!
    update!(active: false)
  end

  private

  def normalize_prompt
    self.prompt = prompt.gsub("\r\n", "\n")
  end

  # Ensures that only one music request is active at a time for the user.
  def ensure_only_one_active
    user.music_requests.where.not(id: id).update_all(active: false)
  end

  # Sets the next most recently used music request as active if the current one is active and is being destroyed.
  def set_next_most_recent_as_active
    next_most_recent_request = user.music_requests.where.not(id: id).order(last_used_at: :desc).first
    next_most_recent_request.active! if next_most_recent_request.present?
  end
end
