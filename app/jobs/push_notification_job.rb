class PushNotificationJob < ApplicationJob
  include ActionView::Helpers::AssetUrlHelper

  def perform(push_subscription_id, playlist_id)
    push_subscription = PushSubscription.find(push_subscription_id)
    playlist = Playlist.find(playlist_id)

    return if push_subscription.blank? || playlist.blank?

    vapid_keys = {
      subject: "mailto:#{ENV['VAPID_MAILTO_ADDRESS']}",
      public_key: ENV['VAPID_PUBLIC_KEY'],
      private_key: ENV['VAPID_PRIVATE_KEY']
    }

    message = {
      title: playlist.name,
      body: playlist.description,
      icon: playlist.cover_image_url,
      url: playlist.spotify_url,
    }

    begin
      WebPush.payload_send(
        message: JSON.generate(message),
        endpoint: push_subscription.endpoint,
        p256dh: push_subscription.p256dh,
        auth: push_subscription.auth,
        vapid: vapid_keys,
        ttl: 86400
      )
    rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription
      push_subscription.destroy
    end
  end
end
