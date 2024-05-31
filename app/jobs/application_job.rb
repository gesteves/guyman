class ApplicationJob
  include Sidekiq::Job
  sidekiq_options queue: 'default'

  sidekiq_retry_in do |count, exception, jobhash|
    case exception
    when FrozenError, ActiveRecord::RecordNotFound
      :kill
    end
  end
end
