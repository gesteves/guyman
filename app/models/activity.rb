class Activity < ApplicationRecord
  belongs_to :user
  has_one :playlist, dependent: :destroy

  validates :name, presence: true

  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destroy

  def processing?
    description.blank? && sport.blank? && activity_type.blank?
  end

  private

  def broadcast_create
    return if Rails.env.test?
    broadcast_update_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  rescue Redis::CannotConnectError
    nil
  end

  def broadcast_update
    return if Rails.env.test?
    broadcast_update_to "playlists:user:#{user.id}", partial: "playlists/card", locals: { playlist: playlist }
    broadcast_update_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  rescue Redis::CannotConnectError
    nil
  end

  def broadcast_destroy
    return if Rails.env.test?
    broadcast_update_to "music_request_form:user:#{user.id}", target: "music_request_form", partial: "home/music_request_form", locals: { music_request: self.user.current_music_request }
  rescue Redis::CannotConnectError
    nil
  end
end
