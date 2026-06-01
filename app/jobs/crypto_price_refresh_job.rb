class CryptoPriceRefreshJob < ApplicationJob
  CACHE_EXPIRY = 5.minutes

  queue_as :default

  def perform
    Crypto::COINS.each_key do |coin_id|
      price = fetch_price(coin_id)
      crypto = Crypto.find_or_initialize_by(name: Crypto::COINS.fetch(coin_id))
      crypto.update!(price: price, currency_code: Crypto::CURRENCY_CODE)
      cache_payload(coin_id, crypto)
    end
  end

  private

  def fetch_price(coin_id)
    response = Faraday.get("https://api.coingecko.com/api/v3/simple/price") do |request|
      request.params["ids"] = coin_id
      request.params["vs_currencies"] = Crypto::CURRENCY_CODE.downcase
      request.headers["accept"] = "application/json"
      request.headers["x-cg-demo-api-key"] = Rails.application.credentials.API_KEY
    end
    raise Faraday::Error, "CoinGecko request failed" unless response.success?
    price = JSON.parse(response.body).dig(coin_id, Crypto::CURRENCY_CODE.downcase)
    raise "CoinGecko price unavailable for #{coin_id}" unless price.is_a?(Numeric)
    price
  end

  def cache_payload(coin_id, crypto)
    key = Crypto.cache_key_for(coin_id)
    payload = Crypto.payload_for(coin_id, crypto)
    Rails.cache.write(key, payload, expires_in: CACHE_EXPIRY)
  rescue StandardError => error
    Rails.logger.warn("Cache write failed: #{error.class} - #{error.message}")
  end
end
