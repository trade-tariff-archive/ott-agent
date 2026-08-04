Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(
      "standing_intent_check" => {
        "cron" => "0 */6 * * *",
        "class" => "StandingIntentCheckJob",
      },
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
