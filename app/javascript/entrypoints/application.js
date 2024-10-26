// app/javascript/entrypoints/application.js

import "@hotwired/turbo-rails"
import "../controllers"
import "../../assets/stylesheets/application.scss"

Turbo.start()

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/',
    updateViaCache: 'none'
  });
}
