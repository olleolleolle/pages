ActiveJob::Base.queue_adapter = if Rails.env.test?
                                  :test
                                else
                                  :delayed_job
                                end
