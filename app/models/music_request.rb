class MusicRequest < ApplicationRecord
  belongs_to :user

  validates :prompt, presence: true

  default_scope { order(active: :desc, last_used_at: :desc) }

  before_save :ensure_only_one_active, if: :active?
  before_save :normalize_prompt
  before_destroy :set_next_most_recent_as_active, if: :active?
  after_create_commit -> { broadcast_create }
  after_update_commit -> { broadcast_update }
  after_destroy_commit -> { broadcast_destroy }

  scope :active, -> { where(active: true) }

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
    self.prompt = self.class.normalize_prompt_text(prompt)
  end

  def self.normalize_prompt_text(text)
    text.gsub("\r\n", "\n").strip
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

  private

  def broadcast_create
    return if Rails.env.test?
    broadcast_replace_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists } if active?
  end

  def broadcast_update
    return if Rails.env.test?
    broadcast_replace_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists } if active?
  end

  def broadcast_destroy
    return if Rails.env.test?
    broadcast_replace_to "music_requests:form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request, todays_playlists: self.user.todays_playlists } if active?
  end
end
