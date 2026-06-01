set :output, "log/cron.log"

every 1.minute do
  rake "crypto_prices:refresh"
end
