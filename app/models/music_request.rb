class MusicRequest < ApplicationRecord
  belongs_to :user

  validates :prompt, presence: true

  default_scope { order(active: :desc, last_used_at: :desc) }

  after_save :ensure_only_one_active, if: :active?

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

  # Ensures that only one music request is active at a time for the user.
  def ensure_only_one_active
    user.music_requests.where.not(id: id).update_all(active: false)
  end
end
