namespace :crypto_prices do
  desc "Enqueue a background job to refresh crypto prices from CoinGecko"
  task refresh: :environment do
    CryptoPriceRefreshJob.perform_later
  end
end
