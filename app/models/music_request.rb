class MusicRequest < ApplicationRecord
  acts_as_paranoid
  belongs_to :user
  has_many :playlists

  validates :prompt, presence: true

  default_scope { order(active: :desc, updated_at: :desc) }

  before_save :ensure_only_one_active, if: :should_ensure_only_one_active?
  before_save :normalize_prompt
  after_destroy :handle_after_destroy, if: :active?
  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destroy

  scope :active, -> { where(active: true) }

  # Tries to prevent duplicate music requests from being created.
  # If an existing one with the same prompt exists, it becomes the active one.
  # Otherwise, a new one is created and activated.
  def self.find_or_create_and_activate(user, prompt)
    music_request = user.music_requests.find_by(prompt: normalize_prompt_text(prompt))
    if music_request.present?
      music_request.active!
    else
      music_request = user.music_requests.build(prompt: prompt)
      music_request.active = true
      music_request.save
    end
    music_request
  end

  # Updates the time the request was last used.
  def used!
    update!(last_used_at: Time.current)
  end

  # Makes a request the active one.
  def active!
    update!(active: true)
  end

  # Makes a request inactive.
  def inactive!
    update!(active: false)
  end

  private

  # Performs some normalization on the prompt text before saving to
  # try to prevent duplicates from being created.
  def normalize_prompt
    self.prompt = self.class.normalize_prompt_text(prompt)
  end

  # Normalizes the prompt text by:
  # - Replacing Windows-style line endings with Unix-style line endings
  def self.normalize_prompt_text(text)
    text.gsub("\r\n", "\n").strip
  end

  def should_ensure_only_one_active?
    active? && !deleted?
  end

  # Ensures that only one music request is active at a time for the user.
  def ensure_only_one_active
    user.music_requests.where.not(id: id).update_all(active: false)
  end

  # Sets the next most recently used music request as active if the current one is active and is being destroyed.
  def handle_after_destroy
    update_column(:active, false)
    next_most_recent_request = user.music_requests.without_deleted.where.not(id: id).order(last_used_at: :desc).first
    next_most_recent_request.update!(active: true) if next_most_recent_request.present?
  end

  private

  def broadcast_create
    return if Rails.env.test?
    broadcast_replace_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  end

  def broadcast_update
    return if Rails.env.test?
    broadcast_replace_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  end

  def broadcast_destroy
    return if Rails.env.test?
    broadcast_replace_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  end
end
