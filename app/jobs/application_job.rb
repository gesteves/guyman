class ApplicationJob
  include Sidekiq::Job
  sidekiq_options queue: 'default'
end
