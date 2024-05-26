class MusicRequest < ApplicationRecord
  belongs_to :user

  validates :prompt, presence: true
  validate :no_duplicate_active_prompt, if: :active?

  default_scope { order(active: :desc, created_at: :desc) }

  before_save :ensure_only_one_active

  scope :active, -> { where(active: true) }

  private

  def no_duplicate_active_prompt
    return unless user.music_requests.active.where(prompt: prompt).exists?

    errors.add(:prompt, 'already exists.')
  end

  def ensure_only_one_active
    if active
      user.music_requests.update_all(active: false)
    end
  end
end
